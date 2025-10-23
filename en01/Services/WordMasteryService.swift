//
//  WordMasteryService.swift
//  en01
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
import Combine
import SwiftData

/// 单词掌握度服务 - 专门管理单词掌握度的记录和统计
class WordMasteryService: BaseService {
    
    // MARK: - Properties
    private let dictionaryService: DictionaryServiceProtocol
    private var masteryCache: [String: (mastery: [String: MasteryLevel], timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟缓存有效期
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
    
    // MARK: - Word Mastery Recording
    
    /// 记录单词掌握度
    @MainActor
    func recordWordMastery(testId: UUID, word: String, masteryLevel: MasteryLevel, responseTime: TimeInterval) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(WordMasteryError.serviceUnavailable))
                return
            }
            
            Task { @MainActor in
                do {
                    let context = self.modelContext
                    
                    // 查找或创建测试记录
                    let testDescriptor = FetchDescriptor<VocabularyTest>(
                        predicate: #Predicate { $0.id == testId }
                    )
                    
                    guard let test = try context.fetch(testDescriptor).first else {
                        throw WordMasteryError.testNotFound
                    }
                    
                    // 查找或创建已测试单词记录 - 拆分复杂的Predicate为简单形式
                    let dictionaryFileName = test.dictionaryFileName
                    let wordDescriptor = FetchDescriptor<TestedWord>(
                        predicate: #Predicate<TestedWord> { testedWord in
                            testedWord.word == word
                        }
                    )
                    
                    let allMatchingWords = try context.fetch(wordDescriptor)
                    let existingWords = allMatchingWords.filter { $0.dictionaryFileName == dictionaryFileName }
                    
                    if let existingWord = existingWords.first {
                        // 更新现有记录
                        existingWord.masteryLevel = masteryLevel.rawValue
                        existingWord.lastTestedDate = Date()
                        existingWord.testCount += 1
                        existingWord.responseTime = (existingWord.responseTime * Double(existingWord.testCount - 1) + responseTime) / Double(existingWord.testCount)
                        existingWord.testSessionId = testId
                    } else {
                        // 创建新记录
                        let testedWord = TestedWord(
                            word: word,
                            dictionaryName: test.dictionaryName,
                            dictionaryFileName: test.dictionaryFileName,
                            masteryLevel: masteryLevel,
                            testSessionId: testId
                        )
                        testedWord.responseTime = responseTime
                        context.insert(testedWord)
                    }
                    
                    try context.save()
                    
                    // 清除相关缓存
                    self.clearCacheForDictionary(test.dictionaryFileName)
                    
                    promise(.success(()))
                } catch {
                    self.errorHandler.handle(error, context: "记录单词掌握度")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 记录单词点击
    func recordWordClick(word: String, testId: UUID) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard self != nil else {
                promise(.failure(WordMasteryError.serviceUnavailable))
                return
            }
            
            // 这里可以记录用户的单词点击行为，用于分析学习模式
            print("✅ 记录单词点击: \(word) in test \(testId)")
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Untested Words Management
    
    /// 获取未测试单词
    @MainActor
    func getUntestedWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(WordMasteryError.serviceUnavailable))
                return
            }
            
            Task {
                do {
                    // 获取词典中的所有单词
                    let allWords = try await self.loadDictionaryWordsSync(from: dictionary)
                    
                    // 获取已测试的单词
                    let testedWords = try await self.getTestedWordsSync(for: dictionary.fileName)
                    let testedWordSet = Set(testedWords.map { $0.word })
                    
                    // 过滤出未测试的单词
                    let untestedWords = allWords.filter { !testedWordSet.contains($0.word) }
                    
                    promise(.success(untestedWords))
                } catch {
                    self.errorHandler.handle(error, context: "获取未测试单词")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Statistics and Analysis
    
    /// 获取测试统计
    func getTestStatistics() async -> TestStatistics {
        let context = modelContext
        
        do {
            // 获取已完成的测试
            let completedTests = try context.fetch(
                FetchDescriptor<VocabularyTest>(
                    predicate: #Predicate<VocabularyTest> { test in
                        test.isCompleted
                    }
                )
            )
            
            let totalTests = completedTests.count
            let scores = completedTests.compactMap { test in
                test.totalWords > 0 ? Double(test.knownWords) / Double(test.totalWords) * 100 : nil
            }
            
            let averageScore = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
            let bestScore = Int(scores.max() ?? 0)
            
            // 计算改进率（简化版本）
            let improvementRate = self.calculateSimpleImprovementRate(from: scores)
            
            return TestStatistics(
                totalTests: totalTests,
                averageScore: averageScore,
                bestScore: bestScore,
                improvementRate: improvementRate
            )
        } catch {
            errorHandler.handle(error, context: "获取测试统计")
            return TestStatistics(totalTests: 0, averageScore: 0.0, bestScore: 0, improvementRate: 0.0)
        }
    }
    
    /// 计算改进率
    func calculateImprovementRate() -> AnyPublisher<Double, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(WordMasteryError.serviceUnavailable))
                return
            }
            
            Task { @MainActor in
                let statistics = await self.getTestStatistics()
                promise(.success(statistics.improvementRate))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取单词掌握度分布
    func getWordMasteryDistribution(for dictionaryFileName: String) -> AnyPublisher<MasteryDistribution, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(WordMasteryError.serviceUnavailable))
                return
            }
            
            Task { @MainActor in
                do {
                    let testedWords = try await self.getTestedWordsSync(for: dictionaryFileName)
                    
                    let masteredCount = testedWords.filter { $0.masteryLevelEnum == MasteryLevel.mastered }.count
                    let familiarCount = testedWords.filter { $0.masteryLevelEnum == MasteryLevel.familiar }.count
                    let unfamiliarCount = testedWords.filter { $0.masteryLevelEnum == MasteryLevel.unfamiliar }.count
                    
                    let distribution = MasteryDistribution(
                        mastered: masteredCount,
                        familiar: familiarCount,
                        unfamiliar: unfamiliarCount,
                        total: testedWords.count
                    )
                    
                    promise(.success(distribution))
                } catch {
                self.errorHandler.handle(error, context: "获取单词掌握度分布")
                promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取学习建议
    func getLearningRecommendations(for dictionaryFileName: String) -> AnyPublisher<[LearningRecommendation], Error> {
        return getWordMasteryDistribution(for: dictionaryFileName)
            .map { [weak self] distribution in
                self?.generateLearningRecommendations(from: distribution) ?? []
            }
            .eraseToAnyPublisher()
    }
    
    /// 根据掌握程度获取单词列表
    func getWordsByMastery(dictionaryFileName: String, mastery: MasteryLevel) -> AnyPublisher<[DictionaryWord], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(WordMasteryError.serviceUnavailable))
                return
            }
            
            Task { @MainActor in
                do {
                    // 获取指定掌握程度的已测试单词
                    let testedWords = try await self.getTestedWordsSync(for: dictionaryFileName)
                    let filteredWords = testedWords.filter { $0.masteryLevelEnum == mastery }
                    
                    // 转换为DictionaryWord格式
                    let dictionaryWords = filteredWords.map { testedWord in
                        DictionaryWord(
                            word: testedWord.word,
                            phonetic: nil,
                            definitions: [WordDefinition(partOfSpeech: .noun, meaning: "暂无定义")],
                            frequency: 1,
                            difficulty: .basic,
                            tags: [],
                            categories: nil
                        )
                    }
                    
                    promise(.success(dictionaryWords))
                } catch {
                    self.errorHandler.handle(error, context: "根据掌握程度获取单词")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取单词掌握度
    func getWordMastery(word: String, dictionaryFileName: String) -> AnyPublisher<MasteryLevel?, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(WordMasteryError.serviceUnavailable))
                return
            }
            
            Task { @MainActor in
                do {
                    let testedWords = try await self.getTestedWordsSync(for: dictionaryFileName)
                    let testedWord = testedWords.first { $0.word == word }
                    promise(.success(testedWord?.masteryLevelEnum))
                } catch {
                    self.errorHandler.handle(error, context: "获取单词掌握度")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 更新单词掌握度
    func updateWordMastery(word: String, dictionaryFileName: String, mastery: MasteryLevel) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(WordMasteryError.serviceUnavailable))
                return
            }
            
            Task { @MainActor in
                do {
                    let context = self.modelContext
                    let descriptor = FetchDescriptor<TestedWord>(
                        predicate: #Predicate<TestedWord> { testedWord in
                            testedWord.word == word && testedWord.dictionaryFileName == dictionaryFileName
                        }
                    )
                    
                    let existingWords = try context.fetch(descriptor)
                    
                    if let existingWord = existingWords.first {
                        existingWord.masteryLevel = mastery.rawValue
                        existingWord.lastTestedDate = Date()
                        existingWord.testCount += 1
                    } else {
                        let testedWord = TestedWord(
                            word: word,
                            dictionaryName: "",
                            dictionaryFileName: dictionaryFileName,
                            masteryLevel: mastery
                        )
                        context.insert(testedWord)
                    }
                    
                    try context.save()
                    promise(.success(()))
                } catch {
                    self.errorHandler.handle(error, context: "更新单词掌握度")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Cache Management
    
    /// 清除所有缓存
    func clearCache() {
        masteryCache.removeAll()
    }
    
    /// 清除特定词典的缓存
    func clearCacheForDictionary(_ dictionaryFileName: String) {
        masteryCache.removeValue(forKey: dictionaryFileName)
    }
}

// MARK: - Private Methods
private extension WordMasteryService {
    
    /// 同步加载词典单词
    func loadDictionaryWordsSync(from dictionary: DictionaryInfo) async throws -> [DictionaryWord] {
        return try await withCheckedThrowingContinuation { continuation in
            dictionaryService.loadDictionary(fileName: dictionary.fileName)
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
                .store(in: &cancellables)
        }
    }
    
    /// 同步获取已测试单词
    @MainActor
    func getTestedWordsSync(for dictionaryFileName: String) async throws -> [TestedWord] {
        let context = modelContext
        
        let descriptor = FetchDescriptor<TestedWord>(
            predicate: #Predicate<TestedWord> { testedWord in
                testedWord.dictionaryFileName == dictionaryFileName
            },
            sortBy: [SortDescriptor(\.lastTestedDate, order: .reverse)]
        )
        
        return try context.fetch(descriptor)
    }
    
    /// 计算简单改进率
    func calculateSimpleImprovementRate(from scores: [Double]) -> Double {
        guard scores.count >= 2 else { return 0 }
        
        let recentScores = Array(scores.suffix(5)) // 最近5次测试
        let earlierScores = Array(scores.prefix(5)) // 最早5次测试
        
        let recentAverage = recentScores.reduce(0, +) / Double(recentScores.count)
        let earlierAverage = earlierScores.reduce(0, +) / Double(earlierScores.count)
        
        return recentAverage - earlierAverage
    }
    
    /// 生成学习建议
    func generateLearningRecommendations(from distribution: MasteryDistribution) -> [LearningRecommendation] {
        var recommendations: [LearningRecommendation] = []
        
        let masteryRate = distribution.masteryRate
        let familiarRate = distribution.familiarRate
        let unfamiliarRate = distribution.unfamiliarRate
        
        if masteryRate < 0.3 {
            recommendations.append(
                LearningRecommendation(
                    type: .reviewBasics,
                    priority: .high,
                    description: "建议加强基础词汇的学习，当前掌握率较低",
                    actionItems: ["重复学习已测试的单词", "增加学习时间", "使用多种学习方法"]
                )
            )
        }
        
        if unfamiliarRate > 0.5 {
            recommendations.append(
                LearningRecommendation(
                    type: .focusOnWeakWords,
                    priority: .high,
                    description: "有较多不熟悉的单词，建议重点攻克",
                    actionItems: ["制作单词卡片", "增加复习频率", "联想记忆法"]
                )
            )
        }
        
        if familiarRate > 0.4 {
            recommendations.append(
                LearningRecommendation(
                    type: .consolidateKnowledge,
                    priority: .medium,
                    description: "有不少熟悉的单词，建议巩固提升至掌握级别",
                    actionItems: ["在语境中使用单词", "造句练习", "定期复习"]
                )
            )
        }
        
        if masteryRate > 0.7 {
            recommendations.append(
                LearningRecommendation(
                    type: .expandVocabulary,
                    priority: .low,
                    description: "掌握率很好，可以扩展词汇量",
                    actionItems: ["学习更高级词汇", "阅读更多文章", "挑战更难的词典"]
                )
            )
        }
        
        return recommendations
    }
}

// MARK: - Error Types
enum WordMasteryError: LocalizedError {
    case serviceUnavailable
    case testNotFound
    case wordNotFound
    case invalidMasteryLevel
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "单词掌握度服务不可用"
        case .testNotFound:
            return "测试未找到"
        case .wordNotFound:
            return "单词未找到"
        case .invalidMasteryLevel:
            return "无效的掌握级别"
        }
    }
}

// MARK: - Supporting Types
struct TestStatistics {
    let totalTests: Int
    let averageScore: Double
    let bestScore: Int
    let improvementRate: Double
}

struct MasteryDistribution {
    let mastered: Int
    let familiar: Int
    let unfamiliar: Int
    let total: Int
    
    var masteryRate: Double {
        guard total > 0 else { return 0 }
        return Double(mastered) / Double(total)
    }
    
    var familiarRate: Double {
        guard total > 0 else { return 0 }
        return Double(familiar) / Double(total)
    }
    
    var unfamiliarRate: Double {
        guard total > 0 else { return 0 }
        return Double(unfamiliar) / Double(total)
    }
}

struct LearningRecommendation {
    let type: RecommendationType
    let priority: Priority
    let description: String
    let actionItems: [String]
    
    enum RecommendationType {
        case reviewBasics
        case focusOnWeakWords
        case consolidateKnowledge
        case expandVocabulary
    }
    
    enum Priority {
        case high
        case medium
        case low
    }
}