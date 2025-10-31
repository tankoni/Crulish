//
//  TestDataService.swift
//  en01
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
import Combine
import SwiftData
import CryptoKit

/// 测试数据服务 - 专门管理测试数据的持久化和查询
class TestDataService: BaseService {
    
    // MARK: - Properties
    private var testedWordsCache: [String: (words: [TestedWord], timestamp: Date)] = [:]
    private var untestedWordsCache: [String: (words: [DictionaryWord], timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟缓存有效期
    private var loadingStates: [String: Bool] = [:] // 防止并发调用
    
    // MARK: - Test History Management
    
    /// 获取测试历史
    func getTestHistory(limit: Int = 20) -> AnyPublisher<[VocabularyTest], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            Task { @MainActor in
                do {
                    var descriptor = FetchDescriptor<VocabularyTest>(
                        sortBy: [SortDescriptor(\.testDate, order: .reverse)]
                    )
                    descriptor.fetchLimit = limit
                    
                    let tests = try self.modelContext.fetch(descriptor)
                    promise(.success(tests))
                } catch {
                    self.errorHandler.handle(error, context: "获取测试历史")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取特定词典的测试历史
    func getTestHistory(for dictionaryId: UUID) -> AnyPublisher<[VocabularyTest], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            Task { @MainActor in
                do {
                    // 首先尝试使用新的稳定ID查询
                    let descriptor = FetchDescriptor<VocabularyTest>(
                        predicate: #Predicate { $0.dictionaryId == dictionaryId },
                        sortBy: [SortDescriptor(\.testDate, order: .reverse)]
                    )
                    
                    var tests = try self.modelContext.fetch(descriptor)
                    
                    // 如果没有找到测试记录，尝试基于文件名的备用查询机制
                    if tests.isEmpty {
                        tests = try self.findTestsByFileName(for: dictionaryId)
                    }
                    
                    promise(.success(tests))
                } catch {
                    self.errorHandler.handle(error, context: "获取词典测试历史")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取特定词典文件名的测试历史
    func getTestHistory(for dictionaryFileName: String, limit: Int = 20) -> AnyPublisher<[VocabularyTest], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            Task { @MainActor in
                do {
                    var descriptor = FetchDescriptor<VocabularyTest>(
                        predicate: #Predicate { $0.dictionaryFileName == dictionaryFileName },
                        sortBy: [SortDescriptor(\.testDate, order: .reverse)]
                    )
                    descriptor.fetchLimit = limit
                    
                    let tests = try self.modelContext.fetch(descriptor)
                    promise(.success(tests))
                } catch {
                    self.errorHandler.handle(error, context: "获取词典文件测试历史")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 基于文件名的备用查询机制
    /// 用于处理ID变更后的数据迁移
    @MainActor
    private func findTestsByFileName(for dictionaryId: UUID) throws -> [VocabularyTest] {
        // 从DictionaryInfo中获取对应的文件名
        guard let fileName = try findDictionaryFileName(for: dictionaryId) else {
            return []
        }
        
        // 基于文件名查询测试记录
        let descriptor = FetchDescriptor<VocabularyTest>(
            predicate: #Predicate { $0.dictionaryFileName == fileName },
            sortBy: [SortDescriptor(\.testDate, order: .reverse)]
        )
        
        let tests = try modelContext.fetch(descriptor)
        
        // 如果找到了测试记录，更新它们的dictionaryId为新的稳定ID
        if !tests.isEmpty {
            for test in tests {
                test.dictionaryId = dictionaryId
            }
            try modelContext.save()
        }
        
        return tests
    }
    
    /// 根据词典ID查找对应的文件名
    @MainActor
    private func findDictionaryFileName(for dictionaryId: UUID) throws -> String? {
        // 这里需要从DictionaryLoader或其他服务获取词典信息
        // 由于我们无法直接访问DictionaryLoader，我们使用一个简化的方法
        // 实际应用中可能需要通过依赖注入获取DictionaryLoader实例
        
        // 临时解决方案：从现有的测试记录中推断文件名模式
        let allTestsDescriptor = FetchDescriptor<VocabularyTest>(
            sortBy: [SortDescriptor(\.testDate, order: .reverse)]
        )
        
        let allTests = try modelContext.fetch(allTestsDescriptor)
        
        // 尝试从文件名推断对应的ID
        for test in allTests {
            let fileName = test.dictionaryFileName
            // 使用与DictionaryInfo相同的ID生成逻辑
            let expectedId = generateStableID(fileName: fileName)
            if expectedId == dictionaryId {
                return fileName
            }
        }
        
        return nil
    }
    
    /// 生成稳定ID（与DictionaryInfo中的逻辑保持一致）
    private func generateStableID(fileName: String) -> UUID {
        // 使用SHA-1哈希算法生成基于文件名的稳定UUID
        let data = fileName.data(using: .utf8) ?? Data()
        let hash = Insecure.SHA1.hash(data: data)
        
        // 将哈希值转换为UUID格式
        let hashBytes = Array(hash)
        
        // 构造UUID字节数组（16字节）
        var uuidBytes: [UInt8] = Array(hashBytes.prefix(16))
        
        // 设置版本号为5（基于名称的UUID）
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x50
        // 设置变体位
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        
        // 创建UUID
        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }
    
    /// 获取最新测试
    func getLatestTest(for dictionaryId: UUID) -> AnyPublisher<VocabularyTest?, Error> {
        return getTestHistory(for: dictionaryId)
            .map { $0.first }
            .eraseToAnyPublisher()
    }
    
    /// 获取最新测试（所有词典）
    func getLatestTest() -> AnyPublisher<VocabularyTest?, Error> {
        return getTestHistory(limit: 1)
            .map { $0.first }
            .eraseToAnyPublisher()
    }
    
    /// 获取未完成的测试
    func getIncompleteTest(for dictionaryFileName: String) -> AnyPublisher<VocabularyTest?, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            Task { @MainActor in
                do {
                    let predicate = #Predicate<VocabularyTest> { test in
                        test.dictionaryFileName == dictionaryFileName
                    }
                    
                    var descriptor = FetchDescriptor<VocabularyTest>(
                        predicate: predicate,
                        sortBy: [SortDescriptor(\.testDate, order: .reverse)]
                    )
                    descriptor.fetchLimit = 1
                    
                    let tests = try self.modelContext.fetch(descriptor)
                    promise(.success(tests.first))
                } catch {
                    self.errorHandler.handle(error, context: "获取未完成测试")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 删除测试记录
    func deleteTestRecord(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            Task { @MainActor in
                do {
                    self.modelContext.delete(test)
                    try self.modelContext.save()
                    promise(.success(()))
                } catch {
                    self.errorHandler.handle(error, context: "删除测试记录失败")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Tested Words Management
    
    /// 保存已测试单词
    @MainActor
    func saveTestedWord(_ word: DictionaryWord, mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String, testSessionId: UUID?) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    // 检查是否已存在
                    let wordText = word.word
                    let fileName = dictionaryFileName
                    let descriptor = FetchDescriptor<TestedWord>(
                        predicate: #Predicate<TestedWord> { testedWord in
                            testedWord.word == wordText && testedWord.dictionaryFileName == fileName
                        }
                    )
                    
                    let existingWords = try self.modelContext.fetch(descriptor)
                    
                    if let existingWord = existingWords.first {
                        // 更新现有记录
                        existingWord.masteryLevel = mastery.rawValue
                        existingWord.lastTestedDate = Date()
                        existingWord.testCount += 1
                        if let sessionId = testSessionId {
                            existingWord.testSessionId = sessionId
                        }
                    } else {
                        // 创建新记录
                        let testedWord = TestedWord(
                            word: word.word,
                            dictionaryName: dictionaryName,
                            dictionaryFileName: dictionaryFileName,
                            masteryLevel: mastery,
                            testSessionId: testSessionId
                        )
                        self.modelContext.insert(testedWord)
                    }
                    
                    try self.modelContext.save()
                    
                    // 清除相关缓存
                    self.clearCacheForDictionary(dictionaryFileName)
                    
                    promise(.success(()))
                } catch {
                    self.errorHandler.handle(error, context: "保存已测试单词")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取已测试单词
    @MainActor
    func getTestedWords(for dictionaryFileName: String) -> AnyPublisher<[TestedWord], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            // 检查缓存
            if let cached = self.testedWordsCache[dictionaryFileName],
               Date().timeIntervalSince(cached.timestamp) < self.cacheValidityDuration {
                promise(.success(cached.words))
                return
            }
            
            // 防止并发调用
            if self.loadingStates[dictionaryFileName] == true {
                promise(.failure(TestDataError.operationInProgress))
                return
            }
            
            self.loadingStates[dictionaryFileName] = true
            
            Task {
                do {
                    let words = try await self.getTestedWordsSync(for: dictionaryFileName)
                    
                    // 更新缓存
                    await MainActor.run {
                        self.testedWordsCache[dictionaryFileName] = (words, Date())
                        self.loadingStates[dictionaryFileName] = false
                    }
                    
                    promise(.success(words))
                } catch {
                    await MainActor.run {
                        self.loadingStates[dictionaryFileName] = false
                    }
                    self.errorHandler.handle(error, context: "获取已测试单词")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 清除已测试单词
    @MainActor
    func clearTestedWords(for dictionaryFileName: String) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    let descriptor = FetchDescriptor<TestedWord>(
                        predicate: #Predicate { $0.dictionaryFileName == dictionaryFileName }
                    )
                    
                    let words = try self.modelContext.fetch(descriptor)
                    for word in words {
                        self.modelContext.delete(word)
                    }
                    
                    try self.modelContext.save()
                    
                    // 清除缓存
                    self.clearCacheForDictionary(dictionaryFileName)
                    
                    promise(.success(()))
                } catch {
                    self.errorHandler.handle(error, context: "清除已测试单词")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 批量更新单词掌握度
    @MainActor
    func batchUpdateWordMastery(words: [String], mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    for word in words {
                        let wordText = word
                        let fileName = dictionaryFileName
                        let descriptor = FetchDescriptor<TestedWord>(
                            predicate: #Predicate<TestedWord> { testedWord in
                                testedWord.word == wordText && testedWord.dictionaryFileName == fileName
                            }
                        )
                        
                        let existingWords = try self.modelContext.fetch(descriptor)
                        
                        if let existingWord = existingWords.first {
                            existingWord.masteryLevel = mastery.rawValue
                            existingWord.lastTestedDate = Date()
                            existingWord.testCount += 1
                        } else {
                            let testedWord = TestedWord(
                                word: word,
                                dictionaryName: dictionaryName,
                                dictionaryFileName: dictionaryFileName,
                                masteryLevel: mastery,
                                testSessionId: nil
                            )
                            self.modelContext.insert(testedWord)
                        }
                    }
                    
                    try self.modelContext.save()
                    
                    // 清除相关缓存
                    self.clearCacheForDictionary(dictionaryFileName)
                    
                    promise(.success(()))
                } catch {
                    self.errorHandler.handle(error, context: "批量更新单词掌握度")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Test Progress and Statistics
    
    /// 获取测试进度
    @MainActor
    func getTestProgress(for dictionaryFileName: String) -> AnyPublisher<TestProgress, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    let testedWords = try await self.getTestedWordsSync(for: dictionaryFileName)
                    
                    // 获取词典信息
                    let dictionaryName = dictionaryFileName.replacingOccurrences(of: ".json", with: "")
                    
                    // 计算统计信息
                    let masteredWords = testedWords.filter { $0.masteryLevel == MasteryLevel.mastered.rawValue }.count
                    let familiarWords = testedWords.filter { $0.masteryLevel == MasteryLevel.familiar.rawValue }.count
                    let unfamiliarWords = testedWords.filter { $0.masteryLevel == MasteryLevel.unfamiliar.rawValue }.count
                    
                    // 计算总单词数
                    let totalWords = 1000 // 临时值，应该从词典服务获取
                    
                    let progress = TestProgress(
                        dictionaryFileName: dictionaryFileName,
                        dictionaryName: dictionaryName,
                        totalWords: totalWords,
                        testedWords: testedWords.count,
                        untestedWords: max(0, totalWords - testedWords.count),
                        masteredWords: masteredWords,
                        familiarWords: familiarWords,
                        unfamiliarWords: unfamiliarWords,
                        currentIndex: testedWords.count
                    )
                    
                    promise(.success(progress))
                } catch {
                    self.errorHandler.handle(error, context: "获取测试进度")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取词典测试结果
    @MainActor
    func getDictionaryTestResults(for dictionaryFileName: String) -> AnyPublisher<DictionaryTestResults, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    let testedWords = try await self.getTestedWordsSync(for: dictionaryFileName)
                    let results = self.calculateDictionaryTestResults(from: testedWords, dictionaryFileName: dictionaryFileName)
                    promise(.success(results))
                } catch {
                    self.errorHandler.handle(error, context: "获取词典测试结果")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取文章单词掌握度分布
    @MainActor
    func getArticleWordMasteryDistribution(words: [String], dictionaryFileName: String) -> AnyPublisher<WordMasteryDistribution, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TestDataError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    let testedWords = try await self.getTestedWordsSync(for: dictionaryFileName)
                    
                    var masteredWords = 0
                    var familiarWords = 0
                    var unfamiliarWords = 0
                    var unknownWords = 0
                    
                    for word in words {
                        if let testedWord = testedWords.first(where: { $0.word == word }) {
                            switch testedWord.masteryLevel {
                            case MasteryLevel.mastered.rawValue:
                                masteredWords += 1
                            case MasteryLevel.familiar.rawValue:
                                familiarWords += 1
                            case MasteryLevel.unfamiliar.rawValue:
                                unfamiliarWords += 1
                            default:
                                unfamiliarWords += 1
                            }
                        } else {
                            unknownWords += 1
                        }
                    }
                    
                    let distribution = WordMasteryDistribution(
                        totalWords: words.count,
                        masteredWords: masteredWords,
                        familiarWords: familiarWords,
                        unfamiliarWords: unfamiliarWords,
                        unknownWords: unknownWords
                    )
                    
                    promise(.success(distribution))
                } catch {
                    self.errorHandler.handle(error, context: "获取文章单词掌握度分布")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Cache Management
    
    /// 清除所有缓存
    func clearCache() {
        testedWordsCache.removeAll()
        untestedWordsCache.removeAll()
        loadingStates.removeAll()
    }
    
    /// 清除特定词典的缓存
    func clearCacheForDictionary(_ dictionaryFileName: String) {
        testedWordsCache.removeValue(forKey: dictionaryFileName)
        untestedWordsCache.removeValue(forKey: dictionaryFileName)
        loadingStates.removeValue(forKey: dictionaryFileName)
    }
    
    // MARK: - 词典专属测试记录管理
    
    /// 获取词典专属测试历史记录
    func getDictionarySpecificTestHistory(for dictionaryId: UUID, limit: Int = 20) -> AnyPublisher<[VocabularyTest], Error> {
        return Future { [weak self] promise in
            Task { @MainActor in
                guard let self = self else {
                    promise(.failure(TestDataError.serviceUnavailable))
                    return
                }
                
                do {
                    var descriptor = FetchDescriptor<VocabularyTest>(
                        predicate: #Predicate { test in
                            test.dictionaryId == dictionaryId && test.isDictionarySpecific == true
                        },
                        sortBy: [SortDescriptor(\.testDate, order: .reverse)]
                    )
                    descriptor.fetchLimit = limit
                    
                    let tests = try self.modelContext.fetch(descriptor)
                    promise(.success(tests))
                } catch {
                    print("❌ 获取词典专属测试历史失败: \(error.localizedDescription)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取总测试历史记录
    func getGeneralTestHistory(limit: Int = 20) -> AnyPublisher<[VocabularyTest], Error> {
        return Future { [weak self] promise in
            Task { @MainActor in
                guard let self = self else {
                    promise(.failure(TestDataError.serviceUnavailable))
                    return
                }
                
                do {
                    var descriptor = FetchDescriptor<VocabularyTest>(
                        predicate: #Predicate { test in
                            test.isDictionarySpecific == false
                        },
                        sortBy: [SortDescriptor(\.testDate, order: .reverse)]
                    )
                    descriptor.fetchLimit = limit
                    
                    let tests = try self.modelContext.fetch(descriptor)
                    promise(.success(tests))
                } catch {
                    print("❌ 获取总测试历史失败: \(error.localizedDescription)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取最新的词典专属测试记录
    func getLatestDictionarySpecificTest(for dictionaryId: UUID) -> AnyPublisher<VocabularyTest?, Error> {
        return getDictionarySpecificTestHistory(for: dictionaryId, limit: 1)
            .map { $0.first }
            .eraseToAnyPublisher()
    }
    
    /// 获取最新的总测试记录
    func getLatestGeneralTest() -> AnyPublisher<VocabularyTest?, Error> {
        return getGeneralTestHistory(limit: 1)
            .map { $0.first }
            .eraseToAnyPublisher()
    }
    
    /// 按词典分组获取测试记录
    func getTestRecordsByDictionary() -> AnyPublisher<[UUID: [VocabularyTest]], Error> {
        return Future { [weak self] promise in
            Task { @MainActor in
                guard let self = self else {
                    promise(.failure(TestDataError.serviceUnavailable))
                    return
                }
                
                do {
                    let descriptor = FetchDescriptor<VocabularyTest>(
                        sortBy: [SortDescriptor(\.testDate, order: .reverse)]
                    )
                    
                    let allTests = try self.modelContext.fetch(descriptor)
                    // 过滤掉dictionaryId为nil的测试记录
                    let validTests = allTests.filter { $0.dictionaryId != nil }
                    let groupedTests = Dictionary(grouping: validTests) { $0.dictionaryId! }
                    
                    promise(.success(groupedTests))
                } catch {
                    print("❌ 按词典分组获取测试记录失败: \(error.localizedDescription)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Private Methods
private extension TestDataService {
    
    /// 同步获取已测试单词
    @MainActor
    func getTestedWordsSync(for dictionaryFileName: String) async throws -> [TestedWord] {
        let descriptor = FetchDescriptor<TestedWord>(
            predicate: #Predicate { $0.dictionaryFileName == dictionaryFileName },
            sortBy: [SortDescriptor(\.lastTestedDate, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// 计算词典测试结果
    func calculateDictionaryTestResults(from testedWords: [TestedWord], dictionaryFileName: String) -> DictionaryTestResults {
        let totalTestedWords = testedWords.count
        let masteredWords = testedWords.filter { $0.masteryLevel == MasteryLevel.mastered.rawValue }.count
                    let familiarWords = testedWords.filter { $0.masteryLevel == MasteryLevel.familiar.rawValue }.count
                    let unfamiliarWords = testedWords.filter { $0.masteryLevel == MasteryLevel.unfamiliar.rawValue }.count
                    let masteryRate = totalTestedWords > 0 ? Double(masteredWords + familiarWords) / Double(totalTestedWords) : 0.0
                    let lastTestDate = testedWords.compactMap { $0.lastTestedDate }.max()
        
        return DictionaryTestResults(
            dictionaryFileName: dictionaryFileName,
            totalTestedWords: totalTestedWords,
            masteredWords: masteredWords,
            familiarWords: familiarWords,
            unfamiliarWords: unfamiliarWords,
            masteryRate: masteryRate,
            lastTestDate: lastTestDate
        )
    }
}

// MARK: - Error Types
enum TestDataError: LocalizedError {
    case serviceUnavailable
    case dataNotFound
    case operationInProgress
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "测试数据服务不可用"
        case .dataNotFound:
            return "数据未找到"
        case .operationInProgress:
            return "操作正在进行中"
        case .invalidData:
            return "数据无效"
        }
    }
}

// MARK: - Supporting Types

struct DictionaryTestResults {
    let dictionaryFileName: String
    let totalTestedWords: Int
    let masteredWords: Int
    let familiarWords: Int
    let unfamiliarWords: Int
    let masteryRate: Double
    let lastTestDate: Date?
    
    var masteredRate: Double {
        guard totalTestedWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalTestedWords)
    }
    
    var familiarRate: Double {
        guard totalTestedWords > 0 else { return 0 }
        return Double(familiarWords) / Double(totalTestedWords)
    }
    
    var unfamiliarRate: Double {
        guard totalTestedWords > 0 else { return 0 }
        return Double(unfamiliarWords) / Double(totalTestedWords)
    }
}

struct WordMasteryDistribution {
    let totalWords: Int
    let masteredWords: Int
    let familiarWords: Int
    let unfamiliarWords: Int
    let unknownWords: Int
    
    var masteredRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWords)
    }
    
    var familiarRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(familiarWords) / Double(totalWords)
    }
    
    var unfamiliarRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(unfamiliarWords) / Double(totalWords)
    }
    
    var unknownRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(unknownWords) / Double(totalWords)
    }
    
    var recommendationScore: Double {
        guard totalWords > 0 else { return 0 }
        
        let masteredRate = Double(masteredWords) / Double(totalWords)
        let familiarRate = Double(familiarWords) / Double(totalWords)
        let unfamiliarRate = Double(unfamiliarWords) / Double(totalWords)
        
        let idealMasteredRate = 0.375 // 37.5%
        let idealFamiliarRate = 0.375 // 37.5%
        let idealUnfamiliarRate = 0.25 // 25%
        
        let masteredDiff = abs(masteredRate - idealMasteredRate)
        let familiarDiff = abs(familiarRate - idealFamiliarRate)
        let unfamiliarDiff = abs(unfamiliarRate - idealUnfamiliarRate)
        
        let totalDiff = masteredDiff + familiarDiff + unfamiliarDiff
        return max(0, 1.0 - totalDiff)
    }
}