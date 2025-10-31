//
//  TestSessionService.swift
//  en01
//
//  Created by AI Assistant on 2024/12/19.
//
import Foundation
import Combine
import SwiftData

/// 测试会话服务 - 专门管理测试会话的生命周期
@MainActor class TestSessionService: BaseService {
    
    // MARK: - Properties
    private let dictionaryService: DictionaryServiceProtocol
    private var activeTests: [UUID: VocabularyTest] = [:]
    private var testWords: [UUID: [DictionaryWord]] = [:]
    private var testResponses: [UUID: [WordTestResponse]] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        dictionaryService: DictionaryServiceProtocol,
        modelContext: ModelContext,
        cacheManager: CacheManagerProtocol,
        errorHandler: ErrorHandlerProtocol
    ) {
        self.dictionaryService = dictionaryService
        super.init(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        )
    }
    
    // MARK: - Test Session Management
    
    /// 开始词汇量测试
    func startVocabularyTest(dictionary: DictionaryInfo, sampleSize: Int = 100) -> AnyPublisher<VocabularyTest, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestSessionError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    // 检查是否存在该词典的现有测试记录
                    let existingTest = try await self.getExistingTestForDictionary(dictionary.fileName)
                    
                    if let existing = existingTest {
                        // 如果存在现有测试，删除它以确保唯一性
                        try await self.deleteExistingTest(existing)
                        print("🔄 [TestSessionService] 删除词典 \(dictionary.name) 的现有测试记录")
                    }
                    
                    // 获取未测试单词（实现去重功能）
                    let untestedWords = try await self.getUntestedWordsSync(from: dictionary)
                    let testWords = self.selectTestWords(from: untestedWords, count: sampleSize)
                    
                    print("✅ [TestSessionService] 词典 \(dictionary.name) 共有 \(untestedWords.count) 个未测试单词，选择 \(testWords.count) 个进行测试")
                    
                    // 创建测试实例
                    let test = VocabularyTest(
                        dictionaryName: dictionary.name,
                        sampleSize: testWords.count
                    )
                    test.dictionaryId = dictionary.id
                    test.dictionaryFileName = dictionary.fileName
                    test.totalWords = testWords.count
                    test.isDictionarySpecific = true  // 设置为词典专属测试
                    
                    // 保存到活跃测试
                    await MainActor.run {
                        self.activeTests[test.id] = test
                        self.testWords[test.id] = testWords
                        self.testResponses[test.id] = []
                    }
                    
                    // 保存到数据库
                    try await self.saveTestToDatabase(test)
                    
                    print("✅ [TestSessionService] 为词典 \(dictionary.name) 创建新测试记录: \(test.id)")
                    promise(.success(test))
                } catch {
                    self.errorHandler.handle(error, context: "开始词汇量测试")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 暂停测试
    func pauseTest(testId: UUID) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestSessionError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    guard let test = self.activeTests[testId] else {
                        throw TestSessionError.testNotFound
                    }
                    
                    test.isPaused = true
                    
                    await MainActor.run {
                        self.activeTests[testId] = test
                    }
                    
                    try await self.updateTestInDatabase(test)
                    promise(.success(()))
                } catch {
                    self.errorHandler.handle(error, context: "暂停测试")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 恢复测试
    func resumeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestSessionError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    guard let test = self.activeTests[testId] else {
                        throw TestSessionError.testNotFound
                    }
                    
                    test.isPaused = false
                    
                    await MainActor.run {
                        self.activeTests[testId] = test
                    }
                    
                    try await self.updateTestInDatabase(test)
                    promise(.success(test))
                } catch {
                    self.errorHandler.handle(error, context: "恢复测试")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 完成测试
    func completeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestSessionError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    guard let test = self.activeTests[testId] else {
                        throw TestSessionError.testNotFound
                    }
                    
                    let responses = self.testResponses[testId] ?? []
                    
                    // 计算测试结果
                    test.currentWordIndex = responses.count
                    test.knownWords = responses.filter { $0.isCorrect }.count
                    test.estimatedVocabulary = self.calculateVocabularySize(from: responses)
                    test.completedAt = Date()
                    test.isCompleted = true
                    
                    await MainActor.run {
                        self.activeTests[testId] = test
                    }
                    
                    try await self.updateTestInDatabase(test)
                    promise(.success(test))
                } catch {
                    self.errorHandler.handle(error, context: "完成测试")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 删除测试
    func deleteTest(testId: UUID) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestSessionError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    // 从活跃测试中移除
                    await MainActor.run {
                        self.activeTests.removeValue(forKey: testId)
                        self.testWords.removeValue(forKey: testId)
                        self.testResponses.removeValue(forKey: testId)
                    }
                    
                    // 从数据库中删除
                    try await self.deleteTestFromDatabase(testId)
                    promise(.success(()))
                } catch {
                    self.errorHandler.handle(error, context: "删除测试")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 记录测试结果
    func recordTestResult(testId: UUID, word: String, isCorrect: Bool, responseTime: TimeInterval) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestSessionError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    guard self.activeTests[testId] != nil else {
                        throw TestSessionError.testNotFound
                    }
                    
                    let masteryLevel: MasteryLevel = isCorrect ? .mastered : .unfamiliar
                    let response = WordTestResponse(
                        word: word,
                        masteryLevel: masteryLevel,
                        responseTime: responseTime,
                        isCorrect: isCorrect
                    )
                    
                    await MainActor.run {
                        if self.testResponses[testId] == nil {
                            self.testResponses[testId] = []
                        }
                        self.testResponses[testId]?.append(response)
                    }
                    
                    promise(.success(()))
                } catch {
                    self.errorHandler.handle(error, context: "记录测试结果")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Getters
    
    /// 获取活跃测试
    func getActiveTest(testId: UUID) -> VocabularyTest? {
        return activeTests[testId]
    }
    
    /// 获取测试单词
    func getTestWords(testId: UUID) -> [DictionaryWord] {
        return testWords[testId] ?? []
    }
    
    /// 获取测试响应
    func getTestResponses(testId: UUID) -> [WordTestResponse] {
        return testResponses[testId] ?? []
    }
    
    /// 获取当前单词
    func getCurrentWord(testId: UUID) -> DictionaryWord? {
        guard let words = testWords[testId],
              let responses = testResponses[testId] else {
            return nil
        }
        
        let currentIndex = responses.count
        return currentIndex < words.count ? words[currentIndex] : nil
    }
    
    /// 获取剩余时间
    func getRemainingTime(testId: UUID) -> TimeInterval {
        guard let test = activeTests[testId] else { return 0 }
        
        // 假设每个测试有时间限制
        let timeLimit: TimeInterval = 30 * 60 // 30分钟
        let elapsed = Date().timeIntervalSince(test.createdAt)
        return max(0, timeLimit - elapsed)
    }
    
    /// 检查测试是否超时
    func isTestTimedOut(testId: UUID) -> Bool {
        return getRemainingTime(testId: testId) <= 0
    }
    
    /// 获取词典的当前有效测试记录
    func getCurrentTestForDictionary(_ dictionaryFileName: String) -> AnyPublisher<VocabularyTest?, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestSessionError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    let test = try await self.getExistingTestForDictionary(dictionaryFileName)
                    promise(.success(test))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 保存测试到数据库
    func saveTestToDatabase(_ test: VocabularyTest) async throws {
        // modelContext 是非可选的，直接使用
        modelContext.insert(test)
        try modelContext.save()
    }
    
    /// 更新数据库中的测试
    func updateTestInDatabase(_ test: VocabularyTest) async throws {
        // modelContext 是非可选的，直接使用
        try modelContext.save()
    }
}

// MARK: - Private Methods
private extension TestSessionService {
    
    /// 获取未测试单词（同步版本）
    func getUntestedWordsSync(from dictionary: DictionaryInfo) async throws -> [DictionaryWord] {
        // 创建WordMasteryService实例，使用继承自BaseService的属性
        let wordMasteryService = WordMasteryService(
            dictionaryService: dictionaryService,
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        )
        
        // 直接使用async/await，避免continuation泄漏
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            var cancellable: AnyCancellable?
            
            // 设置超时机制（30秒）
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !hasResumed {
                    hasResumed = true
                    cancellable?.cancel()
                    continuation.resume(throwing: TestSessionError.timeout)
                }
            }
            
            cancellable = wordMasteryService.getUntestedWords(from: dictionary)
                .sink(
                    receiveCompletion: { completion in
                        guard !hasResumed else { return }
                        hasResumed = true
                        timeoutTask.cancel()
                        
                        switch completion {
                        case .finished:
                            // 如果没有收到值就完成了，返回空数组
                            continuation.resume(returning: [])
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { words in
                        guard !hasResumed else { return }
                        hasResumed = true
                        timeoutTask.cancel()
                        continuation.resume(returning: words)
                    }
                )
        }
    }
    
    /// 选择测试单词
    func selectTestWords(from words: [DictionaryWord], count: Int) -> [DictionaryWord] {
        guard count > 0 else { return [] }
        
        if words.count <= count {
            return words
        }
        
        // 随机选择指定数量的单词
        return Array(words.shuffled().prefix(count))
    }
    
    /// 计算词汇量大小
    func calculateVocabularySize(from responses: [WordTestResponse]) -> Int {
        let correctCount = responses.filter { $0.isCorrect }.count
        let totalCount = responses.count
        
        guard totalCount > 0 else { return 0 }
        
        // 简单的词汇量估算公式
        let accuracy = Double(correctCount) / Double(totalCount)
        return Int(accuracy * 10000) // 假设总词汇量为10000
    }
    
    /// 从数据库删除测试
    func deleteTestFromDatabase(_ testId: UUID) async throws {
        let descriptor = FetchDescriptor<VocabularyTest>(
            predicate: #Predicate<VocabularyTest> { test in
                test.id == testId
            }
        )
        
        let tests = try modelContext.fetch(descriptor)
        for test in tests {
            modelContext.delete(test)
        }
        try modelContext.save()
    }
    
    /// 获取词典的现有测试记录
    func getExistingTestForDictionary(_ dictionaryFileName: String) async throws -> VocabularyTest? {
        let descriptor = FetchDescriptor<VocabularyTest>(
            predicate: #Predicate<VocabularyTest> { test in
                test.dictionaryFileName == dictionaryFileName
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        let tests = try modelContext.fetch(descriptor)
        return tests.first
    }
    
    /// 删除现有测试记录
    func deleteExistingTest(_ test: VocabularyTest) async throws {
        // 从活跃测试中移除
        await MainActor.run {
            self.activeTests.removeValue(forKey: test.id)
            self.testWords.removeValue(forKey: test.id)
            self.testResponses.removeValue(forKey: test.id)
        }
        
        // 从数据库中删除
        modelContext.delete(test)
        try modelContext.save()
    }
}

// MARK: - Error Types
enum TestSessionError: LocalizedError {
    case testNotFound
    case serviceUnavailable
    case invalidTestData
    case timeout
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .testNotFound:
            return "测试未找到"
        case .serviceUnavailable:
            return "测试服务不可用"
        case .invalidTestData:
            return "测试数据无效"
        case .timeout:
            return "测试超时"
        case .cancelled:
            return "测试被取消"
        }
    }
}

// MARK: - Supporting Types
struct WordTestResponse {
    let word: String
    let masteryLevel: MasteryLevel
    let responseTime: TimeInterval
    let isCorrect: Bool
    let timestamp: Date
    
    init(word: String, masteryLevel: MasteryLevel, responseTime: TimeInterval, isCorrect: Bool) {
        self.word = word
        self.masteryLevel = masteryLevel
        self.responseTime = responseTime
        self.isCorrect = isCorrect
        self.timestamp = Date()
    }
}