//
//  VocabularyTestService.swift
//  en01
//
//  Created by 谭康 on 2024/12/19.
//  Refactored by AI Assistant on 2024/12/19.
//

import Foundation
import Combine
import SwiftData

// MARK: - Protocol Definition
@MainActor
protocol VocabularyTestServiceProtocol {
    // 基础功能
    func getAvailableDictionaries() -> AnyPublisher<[DictionaryInfo], Error>
    
    // 词典加载
    func loadDictionaryWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error>
    
    // 测试管理
    func startVocabularyTest(dictionary: DictionaryInfo, sampleSize: Int) -> AnyPublisher<VocabularyTest, Error>
    func pauseTest(testId: UUID) -> AnyPublisher<Void, Error>
    func resumeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error>
    func completeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error>
    func deleteTest(testId: UUID) -> AnyPublisher<Void, Error>
    
    // 测试进度和统计
    func getTestProgress(for dictionaryFileName: String) -> AnyPublisher<TestProgress, Error>
    func getDictionaryTestResults(for dictionaryFileName: String) -> AnyPublisher<DictionaryTestResults, Error>
    func getArticleWordMasteryDistribution(words: [String], dictionaryFileName: String) -> AnyPublisher<WordMasteryDistribution, Error>
    func calculateImprovementRate() -> AnyPublisher<Double, Error>
    
    // 当前测试状态
    func getCurrentWord() -> AnyPublisher<DictionaryWord?, Error>
    func getRemainingTime() -> AnyPublisher<TimeInterval, Error>
    func isTestTimedOut() -> AnyPublisher<Bool, Error>
    
    // 已测试单词清理
    func clearTestedWords(for dictionaryFileName: String) -> AnyPublisher<Void, Error>
    
    // 词汇掌握度记录
    func recordWordMastery(testId: UUID, word: String, masteryLevel: MasteryLevel, responseTime: TimeInterval) -> AnyPublisher<Void, Error>
    func recordWordClick(word: String, testId: UUID) -> AnyPublisher<Void, Error>
    
    // 测试结果保存
    func saveTestResult(testId: UUID, word: String, isCorrect: Bool, responseTime: TimeInterval) -> AnyPublisher<Void, Error>
    func saveTestResult(_ test: VocabularyTest) -> AnyPublisher<Void, Error>
    func updateTestInDatabase(_ test: VocabularyTest) -> AnyPublisher<Void, Error>
    
    // 测试历史
    func getTestHistory(limit: Int) -> AnyPublisher<[VocabularyTest], Error>
    func getTestHistory(for dictionaryId: UUID) -> AnyPublisher<[VocabularyTest], Error>
    func getTestHistory(for dictionaryFileName: String, limit: Int) -> AnyPublisher<[VocabularyTest], Error>
    func getLatestTest() -> AnyPublisher<VocabularyTest?, Error>
    func getLatestTest(for dictionaryId: UUID) -> AnyPublisher<VocabularyTest?, Error>
    func getIncompleteTest(for dictionaryFileName: String) -> AnyPublisher<VocabularyTest?, Error>
    func deleteTestRecord(_ test: VocabularyTest) -> AnyPublisher<Void, Error>
    
    // 当前测试管理
    func getCurrentTestForDictionary(_ dictionaryFileName: String) -> AnyPublisher<VocabularyTest?, Error>
    
    // 测试统计
    func getTestStatistics() -> AnyPublisher<TestStatistics, Error>
    
    // 已测试单词管理
    func saveTestedWord(_ word: DictionaryWord, mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String, testSessionId: UUID?) -> AnyPublisher<Void, Error>
    func getTestedWords(for dictionaryFileName: String) -> AnyPublisher<[TestedWord], Error>
    func getUntestedWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error>
    func getWordMastery(word: String, dictionaryFileName: String) -> AnyPublisher<MasteryLevel?, Error>
    func updateWordMastery(word: String, dictionaryFileName: String, mastery: MasteryLevel) -> AnyPublisher<Void, Error>
    func getWordsByMastery(dictionaryFileName: String, mastery: MasteryLevel) -> AnyPublisher<[DictionaryWord], Error>
    func getWordStatistics(dictionaryFileName: String) -> AnyPublisher<WordStatistics, Error>
    
    // 批量掌握度更新
    func batchUpdateWordMastery(words: [String], mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String) -> AnyPublisher<Void, Error>
    
    // 重测功能
    func loadWordsForRetest(dictionary: DictionaryInfo, masteryLevels: [MasteryLevel], sampleSize: Int) -> AnyPublisher<[DictionaryWord], Error>
    func startRetestVocabularyTest(dictionary: DictionaryInfo, masteryLevels: [MasteryLevel], sampleSize: Int) -> AnyPublisher<VocabularyTest, Error>
    
    // 缓存管理
    func clearCache()
    func clearCacheForDictionary(_ dictionaryFileName: String)
    
    // MARK: - 词典专属测试记录管理
    
    /// 获取词典专属测试历史记录
    func getDictionarySpecificTestHistory(for dictionaryId: UUID, limit: Int) -> AnyPublisher<[VocabularyTest], Error>
    
    /// 获取总测试历史记录（非词典专属）
    func getGeneralTestHistory(limit: Int) -> AnyPublisher<[VocabularyTest], Error>
    
    /// 获取词典的最新专属测试记录
    func getLatestDictionarySpecificTest(for dictionaryId: UUID) -> AnyPublisher<VocabularyTest?, Error>
    
    /// 获取最新总测试记录
    func getLatestGeneralTest() -> AnyPublisher<VocabularyTest?, Error>
    
    /// 创建词典专属测试
    func startDictionarySpecificTest(dictionary: DictionaryInfo, sampleSize: Int) -> AnyPublisher<VocabularyTest, Error>
    
    /// 创建总测试
    func startGeneralTest(dictionary: DictionaryInfo, sampleSize: Int) -> AnyPublisher<VocabularyTest, Error>
    
    /// 按词典分组获取测试记录
    func getTestHistoryGroupedByDictionary() -> AnyPublisher<[UUID: [VocabularyTest]], Error>
}

// MARK: - WordStatistics Model
struct WordStatistics {
    let totalWords: Int
    let masteredWords: Int
    let familiarWords: Int
    let unfamiliarWords: Int
    let averageResponseTime: TimeInterval
    let testAccuracy: Double
    
    var masteryRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWords)
    }
    
    var familiarityRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(familiarWords + masteredWords) / Double(totalWords)
    }
}

// MARK: - Main Service Implementation
/// 词汇量测试服务 - 协调器模式，委托具体功能给专门的服务
@MainActor class VocabularyTestService: BaseService, VocabularyTestServiceProtocol {
    
    // MARK: - Dependencies
    private let dictionaryService: DictionaryServiceProtocol
    private let testSessionService: TestSessionService
    private let testDataService: TestDataService
    private let wordMasteryService: WordMasteryService
    
    // MARK: - State
    private var currentTestId: UUID?
    private var cancellables = Set<AnyCancellable>()
    
    // 同步触发器管理器
    private weak var syncTriggerManager: SyncTriggerManager?
    
    // MARK: - Initialization
    init(
        dictionaryService: DictionaryServiceProtocol,
        modelContext: ModelContext,
        cacheManager: CacheManagerProtocol,
        errorHandler: ErrorHandlerProtocol
    ) {
        self.dictionaryService = dictionaryService
        
        // 初始化专门的服务
        self.testSessionService = TestSessionService(
            dictionaryService: dictionaryService,
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        )
        
        self.testDataService = TestDataService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        )
        
        self.wordMasteryService = WordMasteryService(
            dictionaryService: dictionaryService,
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        )
        
        super.init(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        )
    }
    
    // MARK: - Dependency Injection
    
    func setSyncTriggerManager(_ manager: SyncTriggerManager) {
        self.syncTriggerManager = manager
        wordMasteryService.setSyncTriggerManager(manager)
    }
    
    // MARK: - Dictionary Management
    
    func getAvailableDictionaries() -> AnyPublisher<[DictionaryInfo], Error> {
        return dictionaryService.getAvailableDictionaries()
    }
    
    func loadDictionaryWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        return dictionaryService.loadDictionary(fileName: dictionary.fileName)
    }
    
    // MARK: - Test Session Management
    
    func startVocabularyTest(dictionary: DictionaryInfo, sampleSize: Int = 100) -> AnyPublisher<VocabularyTest, Error> {
        return testSessionService.startVocabularyTest(dictionary: dictionary, sampleSize: sampleSize)
            .handleEvents(receiveOutput: { [weak self] test in
                self?.currentTestId = test.id
            })
            .eraseToAnyPublisher()
    }
    
    func pauseTest(testId: UUID) -> AnyPublisher<Void, Error> {
        return testSessionService.pauseTest(testId: testId)
    }
    
    func resumeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        return testSessionService.resumeTest(testId: testId)
            .handleEvents(receiveOutput: { [weak self] test in
                self?.currentTestId = test.id
            })
            .eraseToAnyPublisher()
    }
    
    func completeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        return testSessionService.completeTest(testId: testId)
            .handleEvents(receiveOutput: { [weak self] test in
                if self?.currentTestId == testId {
                    self?.currentTestId = nil
                }
                // 触发测试会话完成同步
                self?.syncTriggerManager?.triggerAfterTestSession(
                    dictionaryFileName: test.dictionaryFileName,
                    testSessionId: testId,
                    wordsCount: test.totalWords
                )
            })
            .eraseToAnyPublisher()
    }
    
    func deleteTest(testId: UUID) -> AnyPublisher<Void, Error> {
        return testSessionService.deleteTest(testId: testId)
            .handleEvents(receiveOutput: { [weak self] _ in
                if self?.currentTestId == testId {
                    self?.currentTestId = nil
                }
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Word Mastery Management
    
    func recordWordMastery(testId: UUID, word: String, masteryLevel: MasteryLevel, responseTime: TimeInterval) -> AnyPublisher<Void, Error> {
        return wordMasteryService.recordWordMastery(testId: testId, word: word, masteryLevel: masteryLevel, responseTime: responseTime)
    }
    
    func recordWordClick(word: String, testId: UUID) -> AnyPublisher<Void, Error> {
        return wordMasteryService.recordWordClick(word: word, testId: testId)
    }
    
    // MARK: - Test Results Management
    
    func saveTestResult(testId: UUID, word: String, isCorrect: Bool, responseTime: TimeInterval) -> AnyPublisher<Void, Error> {
        return testSessionService.recordTestResult(testId: testId, word: word, isCorrect: isCorrect, responseTime: responseTime)
    }
    
    func saveTestResult(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        return Future { promise in
            // 测试结果已经在 completeTest 中保存
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
    
    func updateTestInDatabase(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    try await self.testSessionService.updateTestInDatabase(test)
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Test History Management
    
    func getTestHistory(limit: Int = 20) -> AnyPublisher<[VocabularyTest], Error> {
        return testDataService.getTestHistory(limit: limit)
    }
    
    func getTestHistory(for dictionaryId: UUID) -> AnyPublisher<[VocabularyTest], Error> {
        return testDataService.getTestHistory(for: dictionaryId)
    }
    
    func getTestHistory(for dictionaryFileName: String, limit: Int = 20) -> AnyPublisher<[VocabularyTest], Error> {
        return testDataService.getTestHistory(for: dictionaryFileName, limit: limit)
    }
    
    func getLatestTest(for dictionaryId: UUID) -> AnyPublisher<VocabularyTest?, Error> {
        return testDataService.getLatestTest(for: dictionaryId)
    }
    
    func getLatestTest() -> AnyPublisher<VocabularyTest?, Error> {
        return testDataService.getLatestTest()
    }
    
    func getIncompleteTest(for dictionaryFileName: String) -> AnyPublisher<VocabularyTest?, Error> {
        return testDataService.getIncompleteTest(for: dictionaryFileName)
    }
    
    func deleteTestRecord(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        return testDataService.deleteTestRecord(test)
    }
    
    // MARK: - Current Test Management
    
    /// 获取词典的当前有效测试记录
    func getCurrentTestForDictionary(_ dictionaryFileName: String) -> AnyPublisher<VocabularyTest?, Error> {
        return testSessionService.getCurrentTestForDictionary(dictionaryFileName)
    }
    
    // MARK: - Tested Words Management
    
    func saveTestedWord(_ word: DictionaryWord, mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String, testSessionId: UUID?) -> AnyPublisher<Void, Error> {
        return testDataService.saveTestedWord(word, mastery: mastery, dictionaryName: dictionaryName, dictionaryFileName: dictionaryFileName, testSessionId: testSessionId)
    }
    
    func getTestedWords(for dictionaryFileName: String) -> AnyPublisher<[TestedWord], Error> {
        return testDataService.getTestedWords(for: dictionaryFileName)
    }
    
    func getWordsByMastery(dictionaryFileName: String, mastery: MasteryLevel) -> AnyPublisher<[DictionaryWord], Error> {
        return wordMasteryService.getWordsByMastery(dictionaryFileName: dictionaryFileName, mastery: mastery)
    }
    
    func getWordMastery(word: String, dictionaryFileName: String) -> AnyPublisher<MasteryLevel?, Error> {
        return wordMasteryService.getWordMastery(word: word, dictionaryFileName: dictionaryFileName)
    }
    
    func updateWordMastery(word: String, dictionaryFileName: String, mastery: MasteryLevel) -> AnyPublisher<Void, Error> {
        return wordMasteryService.updateWordMastery(word: word, dictionaryFileName: dictionaryFileName, mastery: mastery)
    }
    
    func getWordStatistics(dictionaryFileName: String) -> AnyPublisher<WordStatistics, Error> {
        return wordMasteryService.getWordMasteryDistribution(for: dictionaryFileName)
            .map { distribution in
                WordStatistics(
                    totalWords: distribution.total,
                    masteredWords: distribution.mastered,
                    familiarWords: distribution.familiar,
                    unfamiliarWords: distribution.unfamiliar,
                    averageResponseTime: 0.0, // 暂时设为0，后续可以从测试记录中计算
                    testAccuracy: distribution.total > 0 ? Double(distribution.mastered + distribution.familiar) / Double(distribution.total) : 0.0
                )
            }
            .eraseToAnyPublisher()
    }
    
    func getUntestedWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        return wordMasteryService.getUntestedWords(from: dictionary)
    }
    
    func clearTestedWords(for dictionaryFileName: String) -> AnyPublisher<Void, Error> {
        return testDataService.clearTestedWords(for: dictionaryFileName)
    }
    
    func batchUpdateWordMastery(words: [String], mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String) -> AnyPublisher<Void, Error> {
        return testDataService.batchUpdateWordMastery(words: words, mastery: mastery, dictionaryName: dictionaryName, dictionaryFileName: dictionaryFileName)
    }
    
    // MARK: - Test Progress and Statistics
    
    func getTestProgress(for dictionaryFileName: String) -> AnyPublisher<TestProgress, Error> {
        return testDataService.getTestProgress(for: dictionaryFileName)
    }
    
    func getDictionaryTestResults(for dictionaryFileName: String) -> AnyPublisher<DictionaryTestResults, Error> {
        return testDataService.getDictionaryTestResults(for: dictionaryFileName)
    }
    
    func getArticleWordMasteryDistribution(words: [String], dictionaryFileName: String) -> AnyPublisher<WordMasteryDistribution, Error> {
        return testDataService.getArticleWordMasteryDistribution(words: words, dictionaryFileName: dictionaryFileName)
    }
    
    func getTestStatistics() -> AnyPublisher<TestStatistics, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            Task {
                let stats = await self.wordMasteryService.getTestStatistics()
                promise(.success(stats))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func calculateImprovementRate() -> AnyPublisher<Double, Error> {
        return wordMasteryService.calculateImprovementRate()
    }
    
    // MARK: - Current Test State
    
    func getCurrentWord() -> AnyPublisher<DictionaryWord?, Error> {
        return Future { [weak self] promise in
            guard let testId = self?.currentTestId else {
                promise(.success(nil))
                return
            }
            
            let currentWord = self?.testSessionService.getCurrentWord(testId: testId)
            promise(.success(currentWord))
        }
        .eraseToAnyPublisher()
    }
    
    func getRemainingTime() -> AnyPublisher<TimeInterval, Error> {
        return Future { [weak self] promise in
            guard let testId = self?.currentTestId else {
                promise(.success(0))
                return
            }
            
            let remainingTime = self?.testSessionService.getRemainingTime(testId: testId) ?? 0
            promise(.success(remainingTime))
        }
        .eraseToAnyPublisher()
    }
    
    func isTestTimedOut() -> AnyPublisher<Bool, Error> {
        return Future { [weak self] promise in
            guard let testId = self?.currentTestId else {
                promise(.success(false))
                return
            }
            
            let isTimedOut = self?.testSessionService.isTestTimedOut(testId: testId) ?? false
            promise(.success(isTimedOut))
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Retest Methods
    
    func loadWordsForRetest(dictionary: DictionaryInfo, masteryLevels: [MasteryLevel], sampleSize: Int) -> AnyPublisher<[DictionaryWord], Error> {
        Future<[DictionaryWord], Error> { promise in
            Task {
                do {
                    // 获取指定掌握程度的已测试单词
                    var retestWords: [DictionaryWord] = []
                    
                    for masteryLevel in masteryLevels {
                        let wordsForMastery = try await withCheckedThrowingContinuation { continuation in
                            self.getWordsByMastery(
                                dictionaryFileName: dictionary.fileName,
                                mastery: masteryLevel
                            )
                            .sink(
                                receiveCompletion: { completion in
                                    if case .failure(let error) = completion {
                                        continuation.resume(throwing: error)
                                    }
                                },
                                receiveValue: { words in
                                    continuation.resume(returning: words)
                                }
                            )
                            .store(in: &self.cancellables)
                        }
                        retestWords.append(contentsOf: wordsForMastery)
                    }
                    
                    // 随机打乱并限制数量
                    // 当 sampleSize < 0（例如 .all）时，表示取全部重测单词
                    let shuffledWords = retestWords.shuffled()
                    let effectiveCount = sampleSize < 0 ? retestWords.count : sampleSize
                    let limitedWords = Array(shuffledWords.prefix(effectiveCount))

                    promise(.success(limitedWords))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func startRetestVocabularyTest(dictionary: DictionaryInfo, masteryLevels: [MasteryLevel], sampleSize: Int) -> AnyPublisher<VocabularyTest, Error> {
        Future<VocabularyTest, Error> { promise in
            Task {
                do {
                    // 加载重测单词
                    let retestWords = try await withCheckedThrowingContinuation { continuation in
                        self.loadWordsForRetest(
                            dictionary: dictionary,
                            masteryLevels: masteryLevels,
                            sampleSize: sampleSize
                        )
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    continuation.resume(throwing: error)
                                }
                            },
                            receiveValue: { words in
                                continuation.resume(returning: words)
                            }
                        )
                        .store(in: &self.cancellables)
                    }
                    
                    // 创建重测实例
                    let test = VocabularyTest(
                        dictionaryName: dictionary.name,
                        sampleSize: retestWords.count
                    )
                    
                    // 设置词典相关信息
                    test.dictionaryId = dictionary.id
                    test.dictionaryFileName = dictionary.fileName
                    test.totalWords = retestWords.count
                    test.isDictionarySpecific = true  // 设置为词典专属测试
                    
                    // 保存测试实例
                    _ = try await self.saveTestResult(test).values.first(where: { _ in true })
                    
                    // 设置当前测试ID
                    self.currentTestId = test.id
                    
                    promise(.success(test))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        testDataService.clearCache()
        wordMasteryService.clearCache()
    }
    
    func clearCacheForDictionary(_ dictionaryFileName: String) {
        testDataService.clearCacheForDictionary(dictionaryFileName)
        wordMasteryService.clearCacheForDictionary(dictionaryFileName)
    }
    
    // MARK: - 词典专属测试记录管理
    
    /// 获取词典专属测试历史记录
    func getDictionarySpecificTestHistory(for dictionaryId: UUID, limit: Int = 20) -> AnyPublisher<[VocabularyTest], Error> {
        return testDataService.getDictionarySpecificTestHistory(for: dictionaryId, limit: limit)
    }
    
    /// 获取总测试历史记录（非词典专属）
    func getGeneralTestHistory(limit: Int = 20) -> AnyPublisher<[VocabularyTest], Error> {
        return testDataService.getGeneralTestHistory(limit: limit)
    }
    
    /// 获取词典的最新专属测试记录
    func getLatestDictionarySpecificTest(for dictionaryId: UUID) -> AnyPublisher<VocabularyTest?, Error> {
        return testDataService.getLatestDictionarySpecificTest(for: dictionaryId)
    }
    
    /// 获取最新总测试记录
    func getLatestGeneralTest() -> AnyPublisher<VocabularyTest?, Error> {
        return testDataService.getLatestGeneralTest()
    }
    
    /// 创建词典专属测试
    func startDictionarySpecificTest(dictionary: DictionaryInfo, sampleSize: Int = 100) -> AnyPublisher<VocabularyTest, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    let test = VocabularyTest.createDictionarySpecificRecord(
                        dictionaryId: dictionary.id,
                        dictionaryName: dictionary.name,
                        sampleSize: sampleSize
                    )
                    
                    try await self.testSessionService.saveTestToDatabase(test)
                    await MainActor.run {
                        self.currentTestId = test.id
                        promise(.success(test))
                    }
                } catch {
                    await MainActor.run {
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 创建总测试
    func startGeneralTest(dictionary: DictionaryInfo, sampleSize: Int = 100) -> AnyPublisher<VocabularyTest, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    let test = VocabularyTest.createGeneralRecord(
                        dictionaryName: dictionary.name,
                        sampleSize: sampleSize
                    )
                    
                    try await self.testSessionService.saveTestToDatabase(test)
                    await MainActor.run {
                        self.currentTestId = test.id
                        promise(.success(test))
                    }
                } catch {
                    await MainActor.run {
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 按词典分组获取测试记录
    func getTestHistoryGroupedByDictionary() -> AnyPublisher<[UUID: [VocabularyTest]], Error> {
        return testDataService.getTestRecordsByDictionary()
    }
}

// MARK: - Error Types
enum VocabularyTestError: LocalizedError {
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
            return "服务不可用"
        case .invalidTestData:
            return "测试数据无效"
        case .timeout:
            return "操作超时"
        case .cancelled:
            return "操作被取消"
        }
    }
}
