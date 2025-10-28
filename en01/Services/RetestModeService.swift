//
//  RetestModeService.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import SwiftData
import Foundation
import Combine

/// 重测模式服务协议
protocol RetestModeServiceProtocol {
    func getAvailableDictionaries() async throws -> [DictionaryInfo]
    func getTestedWordsForDictionaries(_ dictionaryIds: [UUID], masteryLevels: [MasteryLevel]) async throws -> [RetestWordItem]
    func createRetestSession(configuration: RetestConfiguration, words: [RetestWordItem]) async throws -> RetestSession
    func updateTestResult(sessionId: UUID, wordId: UUID, isCorrect: Bool, responseTime: TimeInterval) async throws
    func completeRetestSession(_ sessionId: UUID, overwriteMode: ResultOverwriteMode) async throws -> RetestStatistics
    func getRetestHistory() async -> [RetestSession]
    func deleteRetestSession(_ sessionId: UUID) async throws
}

/// 重测模式服务实现
class RetestModeService: RetestModeServiceProtocol {
    private let modelContext: ModelContext
    private let dictionaryService: DictionaryServiceProtocol
    private let testDataService: TestDataService
    private var cancellables = Set<AnyCancellable>()
    
    init(
        modelContext: ModelContext,
        testDataService: TestDataService,
        dictionaryService: DictionaryServiceProtocol
    ) {
        self.modelContext = modelContext
        self.testDataService = testDataService
        self.dictionaryService = dictionaryService
    }
    
    /// 获取可用的词典列表
    func getAvailableDictionaries() async throws -> [DictionaryInfo] {
        return try await withCheckedThrowingContinuation { continuation in
            dictionaryService.getAvailableDictionaries()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { dictionaries in
                        let enabledDictionaries = dictionaries.filter { $0.isEnabled }
                        continuation.resume(returning: enabledDictionaries)
                    }
                )
                .store(in: &self.cancellables)
        }
    }
    
    /// 获取已测试的单词列表
    func getTestedWords(for dictionaryId: UUID) async throws -> [TestedWord] {
        do {
            let descriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.testSessionId != nil
                },
                sortBy: [SortDescriptor(\.lastTestedDate, order: .reverse)]
            )
            
            let testedWords = try modelContext.fetch(descriptor)
            
            // 获取词典信息以匹配词典ID
            let dictionaries = try await getAvailableDictionaries()
            
            // 根据词典ID匹配词典
            let targetDictionary = dictionaries.first { dictionary in
                dictionary.id == dictionaryId
            }
            guard let dictionary = targetDictionary else {
                return []
            }
            
            return testedWords.filter { $0.dictionaryFileName == dictionary.fileName }
        } catch {
            print("❌ [RetestModeService] 获取已测试单词失败: \(error.localizedDescription)")
            throw RetestError.noWordsFound
        }
    }
    
    // MARK: - 获取测试过的单词
    func getTestedWordsForDictionaries(_ dictionaryIds: [UUID], masteryLevels: [MasteryLevel]) async throws -> [RetestWordItem] {
        do {
            var allRetestWords: [RetestWordItem] = []
            
            for dictionaryId in dictionaryIds {
                let words = try await getTestedWordsForDictionary(dictionaryId, masteryLevels: masteryLevels)
                allRetestWords.append(contentsOf: words)
            }
            
            // 按单词拼写去重（跨词典）
            let uniqueWords = removeDuplicateWords(allRetestWords)
            
            print("✅ 获取到 \(uniqueWords.count) 个可重测单词")
            return uniqueWords
        } catch {
            print("❌ 获取测试过的单词失败: \(error.localizedDescription)")
            throw RetestError.noWordsFound
        }
    }
    
    private func getTestedWordsForDictionary(_ dictionaryId: UUID, masteryLevels: [MasteryLevel]) async throws -> [RetestWordItem] {
        // 获取词典信息
        let dictionaries = try await getAvailableDictionaries()
        guard let dictionary = dictionaries.first(where: { $0.id == dictionaryId }) else {
            throw RetestError.dictionaryNotFound
        }
        
        // 获取测试记录
        let testDescriptor = FetchDescriptor<VocabularyTest>(
            predicate: #Predicate<VocabularyTest> { test in
                test.dictionaryId == dictionaryId
            }
        )
        let tests = try modelContext.fetch(testDescriptor)
        
        guard let latestTest = tests.max(by: { $0.testDate < $1.testDate }) else {
            return []
        }
        
        // 获取测试过的单词
        let testSessionId = latestTest.id
        let testedWordDescriptor = FetchDescriptor<TestedWord>(
            predicate: #Predicate<TestedWord> { testedWord in
                testedWord.testSessionId == testSessionId
            }
        )
        let testedWords = try modelContext.fetch(testedWordDescriptor)
        
        // 加载词典单词
            let words = try await withCheckedThrowingContinuation { continuation in
                dictionaryService.loadDictionary(fileName: dictionary.fileName)
                    .first()
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            case .finished:
                                break
                            }
                        },
                        receiveValue: { words in
                            continuation.resume(returning: words)
                        }
                    )
                    .store(in: &self.cancellables)
            }
            
            let wordDict = Dictionary<String, DictionaryWord>(uniqueKeysWithValues: words.map { ($0.word, $0) })
        
        var retestWords: [RetestWordItem] = []
        
        for testedWord in testedWords {
            guard let word = wordDict[testedWord.word] else { continue }
            
            let masteryLevel = determineMasteryLevel(testedWord)
            
            // 筛选指定掌握程度的单词
            if masteryLevels.contains(masteryLevel) {
                let retestWordItem = RetestWordItem(
                    word: word,
                    dictionaryName: dictionary.displayName,
                    currentMasteryLevel: masteryLevel,
                    lastTestDate: testedWord.lastTestedDate,
                    testCount: testedWord.testCount
                )
                retestWords.append(retestWordItem)
            }
        }
        
        return retestWords
    }
    
    private func determineMasteryLevel(_ testedWord: TestedWord) -> MasteryLevel {
        if testedWord.isKnown {
            return .mastered
        } else if testedWord.isFamiliar {
            return .familiar
        } else {
            return .unfamiliar
        }
    }
    
    // MARK: - 跨词典去重
    private func removeDuplicateWords(_ words: [RetestWordItem]) -> [RetestWordItem] {
        var uniqueWords: [String: RetestWordItem] = [:]
        
        for word in words {
            let key = word.word.word.lowercased()
            
            // 如果已存在相同拼写的单词，保留掌握程度较低的（优先重测不熟悉的）
            if let existingWord = uniqueWords[key] {
                let currentPriority = masteryLevelPriority(word.currentMasteryLevel)
                let existingPriority = masteryLevelPriority(existingWord.currentMasteryLevel)
                
                if currentPriority > existingPriority {
                    uniqueWords[key] = word
                }
            } else {
                uniqueWords[key] = word
            }
        }
        
        return Array(uniqueWords.values)
    }
    
    private func masteryLevelPriority(_ level: MasteryLevel) -> Int {
        switch level {
        case .unfamiliar: return 3  // 最高优先级
        case .familiar: return 2
        case .mastered: return 1    // 最低优先级
        }
    }
    
    // MARK: - 创建重测会话
    func createRetestSession(configuration: RetestConfiguration, words: [RetestWordItem]) async throws -> RetestSession {
        let session = RetestSession(
            configurationId: configuration.id,
            totalWords: words.count
        )
        
        modelContext.insert(session)
        
        do {
            try modelContext.save()
            print("✅ 创建重测会话成功，共 \(words.count) 个单词")
            return session
        } catch {
            print("❌ 创建重测会话失败: \(error.localizedDescription)")
            throw RetestError.sessionCreationFailed
        }
    }
    
    // MARK: - 更新测试结果
    func updateTestResult(sessionId: UUID, wordId: UUID, isCorrect: Bool, responseTime: TimeInterval) async throws {
        // 获取会话
        let sessionDescriptor = FetchDescriptor<RetestSession>(
            predicate: #Predicate<RetestSession> { session in
                session.id == sessionId
            }
        )
        
        guard let session = try modelContext.fetch(sessionDescriptor).first else {
            throw RetestError.sessionNotFound
        }
        
        // 更新会话统计
        session.completedWords += 1
        if isCorrect {
            session.correctAnswers += 1
        }
        
        // 创建测试结果记录
        let result = RetestResult(
            sessionId: sessionId,
            wordId: wordId,
            dictionaryId: UUID(), // 需要从上下文获取
            originalMasteryLevel: .unfamiliar, // 需要从原始记录获取
            newMasteryLevel: isCorrect ? .mastered : .unfamiliar,
            isCorrect: isCorrect,
            responseTime: responseTime
        )
        
        modelContext.insert(result)
        session.testResults.append(result)
        
        try modelContext.save()
    }
    
    /// 更新测试结果
    func updateTestResult(
        sessionId: UUID,
        word: String,
        isCorrect: Bool,
        responseTime: TimeInterval
    ) async throws {
        do {
            // 查找测试会话
            let sessionDescriptor = FetchDescriptor<VocabularyTest>(
                predicate: #Predicate<VocabularyTest> { test in
                    test.id == sessionId
                }
            )
            let sessions = try modelContext.fetch(sessionDescriptor)
            
            guard let session = sessions.first else {
                throw RetestError.sessionNotFound
            }
            
            // 查找对应的 TestedWord 记录
            let sessionDictionaryFileName = session.dictionaryFileName
            let wordDescriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { testedWord in
                    testedWord.word == word && testedWord.dictionaryFileName == sessionDictionaryFileName
                }
            )
            let testedWords = try modelContext.fetch(wordDescriptor)
            
            if let testedWord = testedWords.first {
                // 更新测试结果
                testedWord.updateMasteryLevel(isCorrect ? .mastered : .unfamiliar)
                testedWord.testSessionId = sessionId
            }
            
            // 更新会话统计
            if isCorrect {
                session.knownWords += 1
                session.masteredCount += 1
            } else {
                session.unknownWords += 1
                session.unfamiliarCount += 1
            }
            
            session.currentWordIndex += 1
            
            try modelContext.save()
        } catch {
            throw RetestError.sessionNotFound
        }
    }
    
    // MARK: - 完成重测会话
    func completeRetestSession(_ sessionId: UUID, overwriteMode: ResultOverwriteMode) async throws -> RetestStatistics {
        do {
            // 查找测试会话
            let sessionDescriptor = FetchDescriptor<VocabularyTest>(
                predicate: #Predicate<VocabularyTest> { test in
                    test.id == sessionId
                }
            )
            let sessions = try modelContext.fetch(sessionDescriptor)
            
            guard let session = sessions.first else {
                throw RetestError.sessionNotFound
            }
            
            // 查找该会话的所有测试结果
            let wordDescriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { testedWord in
                    testedWord.testSessionId == sessionId
                }
            )
            let retestWords = try modelContext.fetch(wordDescriptor)
            
            // 处理重测结果
            switch overwriteMode {
            case .overwrite:
                try await overwriteOriginalResults(retestWords)
            case .createNew:
                // 不需要额外处理，重测结果已经作为新记录保存
                break
            case .merge:
                try await mergeWithOriginalResults(retestWords)
            }
            
            // 标记会话为完成
            session.isCompleted = true
            session.completedAt = Date()
            
            // 计算统计信息
            let statistics = calculateRetestStatistics(session: session, retestWords: retestWords)
            
            try modelContext.save()
            
            return statistics
        } catch {
            throw RetestError.sessionNotFound
        }
    }
    
    private func processRetestResults(_ session: RetestSession, overwriteMode: ResultOverwriteMode) async throws {
        switch overwriteMode {
        case .overwrite:
            try await overwriteOriginalResults(session.testResults.compactMap { result in
                // 将 RetestResult 转换为 TestedWord 或使用其他适当的方法
                // 这里需要根据实际需求实现转换逻辑
                return nil // 临时返回 nil，需要实际实现
            })
        case .createNew:
            // 不需要额外处理，重测结果已经作为新记录保存
            break
        case .merge:
            try await mergeWithOriginalResults(session.testResults.compactMap { result in
                // 将 RetestResult 转换为 TestedWord 或使用其他适当的方法
                // 这里需要根据实际需求实现转换逻辑
                return nil // 临时返回 nil，需要实际实现
            })
        }
    }
    
    private func overwriteOriginalResults(_ retestWords: [TestedWord]) async throws {
        // 实现覆盖原有结果的逻辑
        for testedWord in retestWords {
            // 查找并更新原有的TestedWord记录
            let wordText = testedWord.word
            let dictionaryFileName = testedWord.dictionaryFileName
            
            let wordDescriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.word == wordText && word.dictionaryFileName == dictionaryFileName
                }
            )
            
            let existingWords = try modelContext.fetch(wordDescriptor)
            if let existingWord = existingWords.first {
                // 更新掌握程度
                existingWord.masteryLevel = testedWord.masteryLevel
                existingWord.lastTestedDate = testedWord.lastTestedDate
                existingWord.testCount = testedWord.testCount
            }
        }
    }
    
    private func mergeWithOriginalResults(_ retestWords: [TestedWord]) async throws {
        // 实现合并结果的逻辑（保留更好的结果）
        for testedWord in retestWords {
            let wordText = testedWord.word
            let dictionaryFileName = testedWord.dictionaryFileName
            let wordDescriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.word == wordText && word.dictionaryFileName == dictionaryFileName
                }
            )
            
            let existingWords = try modelContext.fetch(wordDescriptor)
            if let existingWord = existingWords.first {
                let originalLevel = determineMasteryLevel(existingWord)
                let newLevel = determineMasteryLevel(testedWord)
                
                // 只有新结果更好时才更新
                if masteryLevelPriority(newLevel) < masteryLevelPriority(originalLevel) {
                    existingWord.masteryLevel = testedWord.masteryLevel
                    existingWord.lastTestedDate = testedWord.lastTestedDate
                    existingWord.testCount = testedWord.testCount
                }
            }
        }
    }
    
    private func calculateRetestStatistics(session: VocabularyTest, retestWords: [TestedWord]) -> RetestStatistics {
        let totalWords = retestWords.count
        
        var improvedWords = 0
        var maintainedWords = 0
        var declinedWords = 0
        var totalResponseTime: TimeInterval = 0
        
        for testedWord in retestWords {
            totalResponseTime += testedWord.responseTime
            
            // 简化统计逻辑，基于掌握程度判断
            let masteryLevel = determineMasteryLevel(testedWord)
            switch masteryLevel {
            case .mastered:
                improvedWords += 1
            case .familiar:
                maintainedWords += 1
            case .unfamiliar:
                declinedWords += 1
            }
        }
        
        let averageResponseTime = totalWords > 0 ? totalResponseTime / Double(totalWords) : 0
        let accuracy = session.accuracy
        
        return RetestStatistics(
            totalWords: totalWords,
            improvedWords: improvedWords,
            maintainedWords: maintainedWords,
            declinedWords: declinedWords,
            averageResponseTime: averageResponseTime,
            accuracy: accuracy
        )
    }
    
    // MARK: - 获取重测历史
    func getRetestHistory() async -> [RetestSession] {
        do {
            let descriptor = FetchDescriptor<RetestSession>(
                sortBy: [SortDescriptor(\.startTime, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ 获取重测历史失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 删除重测会话
    func deleteRetestSession(_ sessionId: UUID) async throws {
        let sessionDescriptor = FetchDescriptor<RetestSession>(
            predicate: #Predicate<RetestSession> { session in
                session.id == sessionId
            }
        )
        
        guard let session = try modelContext.fetch(sessionDescriptor).first else {
            throw RetestError.sessionNotFound
        }
        
        // 删除相关的测试结果
        let resultDescriptor = FetchDescriptor<RetestResult>(
            predicate: #Predicate<RetestResult> { result in
                result.sessionId == sessionId
            }
        )
        
        let results = try modelContext.fetch(resultDescriptor)
        for result in results {
            modelContext.delete(result)
        }
        
        modelContext.delete(session)
        try modelContext.save()
        
        print("✅ 删除重测会话成功")
    }
}

// MARK: - 错误定义
enum RetestError: LocalizedError {
    case dictionaryNotFound
    case sessionCreationFailed
    case sessionNotFound
    case invalidConfiguration
    case noWordsFound
    
    var errorDescription: String? {
        switch self {
        case .dictionaryNotFound:
            return "找不到指定的词典"
        case .sessionCreationFailed:
            return "创建重测会话失败"
        case .sessionNotFound:
            return "找不到重测会话"
        case .invalidConfiguration:
            return "重测配置无效"
        case .noWordsFound:
            return "没有找到符合条件的单词"
        }
    }
}

// MARK: - Mock服务
class MockRetestModeService: RetestModeServiceProtocol {
    func getAvailableDictionaries() async throws -> [DictionaryInfo] {
        return [
            DictionaryInfo(name: "kaoyan_vocabulary", displayName: "考研词汇", fileName: "kaoyan.json", filePath: "kaoyan.json", description: "考研必备词汇", totalWords: 5500),
            DictionaryInfo(name: "cet4_vocabulary", displayName: "四级词汇", fileName: "cet4.json", filePath: "cet4.json", description: "大学英语四级词汇", totalWords: 4000)
        ]
    }
    
    func getTestedWordsForDictionaries(_ dictionaryIds: [UUID], masteryLevels: [MasteryLevel]) async throws -> [RetestWordItem] {
        return []
    }
    
    func createRetestSession(configuration: RetestConfiguration, words: [RetestWordItem]) async throws -> RetestSession {
        return RetestSession(configurationId: configuration.id, totalWords: words.count)
    }
    
    func updateTestResult(sessionId: UUID, wordId: UUID, isCorrect: Bool, responseTime: TimeInterval) async throws {
        // Mock implementation
    }
    
    func completeRetestSession(_ sessionId: UUID, overwriteMode: ResultOverwriteMode) async throws -> RetestStatistics {
        return RetestStatistics(
            totalWords: 50,
            improvedWords: 30,
            maintainedWords: 15,
            declinedWords: 5,
            averageResponseTime: 2.5,
            accuracy: 0.8
        )
    }
    
    func getRetestHistory() async -> [RetestSession] {
        return []
    }
    
    func deleteRetestSession(_ sessionId: UUID) async throws {
        // Mock implementation
    }
}

// MARK: - 协议实现

// MARK: - 私有扩展

private extension RetestModeService {
    func getRetestWords(for configuration: RetestConfiguration) async throws -> [TestedWord] {
        var allRetestWords: [TestedWord] = []
        
        for dictionaryId in configuration.selectedDictionaryIds {
            // 获取指定词典的已测试单词
            let predicate = #Predicate<TestedWord> { word in
                word.dictionaryFileName == dictionaryId.uuidString
            }
            let descriptor = FetchDescriptor<TestedWord>(predicate: predicate)
            let testedWords = try modelContext.fetch(descriptor)
            
            // 根据掌握程度过滤
            let filteredWords = testedWords.filter { word in
                configuration.selectedMasteryLevels.contains(word.masteryLevelEnum)
            }
            
            allRetestWords.append(contentsOf: filteredWords)
        }
        
        // 去重（基于单词内容）
        var uniqueWords: [String: TestedWord] = [:]
        for word in allRetestWords {
            let key = word.word.lowercased()
            if uniqueWords[key] == nil {
                uniqueWords[key] = word
            }
        }
        
        let finalWords = Array(uniqueWords.values)
        
        // 根据配置限制数量（如果有的话）
        // 注意：RetestConfiguration 没有 maxWords 属性，这里暂时移除该逻辑
        
        return finalWords.shuffled()
    }
}