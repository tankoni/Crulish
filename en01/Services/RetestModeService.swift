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
    func getFilteredWords(filters: RetestWordFilters) async throws -> [RetestWordItem]
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
    private var hasRunNormalization = false
    
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
    
    /// 获取掌握程度统计信息
    func getMasteryStats() async -> [MasteryLevel: Int] {
        await runMasteryNormalizationIfNeeded()
        let records = dictionaryService.getGeneralUserWordRecords()
        var stats: [MasteryLevel: Int] = [
            .mastered: 0,
            .familiar: 0,
            .unfamiliar: 0
        ]
        for r in records {
            stats[r.masteryLevel, default: 0] += 1
        }
        print("✅ [RetestModeService] 掌握程度统计: \(stats)")
        return stats
    }
    
    /// 获取已测试的单词列表
    func getTestedWords(for dictionaryId: UUID) async throws -> [TestedWord] {
        do {
            // 获取词典信息以匹配词典ID
            let dictionaries = try await getAvailableDictionaries()
            guard let dictionary = dictionaries.first(where: { $0.id == dictionaryId }) else {
                throw RetestError.dictionaryNotFound
            }

            // 查询链接到测试会话的记录（常规）
            let linkedDescriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.testSessionId != nil && word.dictionaryFileName == dictionary.fileName
                },
                sortBy: [SortDescriptor(\.lastTestedDate, order: .reverse)]
            )
            let linkedRecords = try modelContext.fetch(linkedDescriptor)

            // 兼容导入生成的“孤立记录”：没有 testSessionId，但 dictionaryFileName 匹配
            let orphanDescriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.testSessionId == nil && word.dictionaryFileName == dictionary.fileName
                }
            )
            let orphanRecords = try modelContext.fetch(orphanDescriptor)

            // 纳入“总测试记录”：获取所有总测试会话并匹配对应 TestedWord
            let generalTestsDescriptor = FetchDescriptor<VocabularyTest>(
                predicate: #Predicate<VocabularyTest> { test in
                    test.isDictionarySpecific == false
                }
            )
            let generalTests = try modelContext.fetch(generalTestsDescriptor)
            let generalTestIds = Set(generalTests.map { $0.id })

            let allLinkedDescriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { record in
                    record.testSessionId != nil
                },
                sortBy: [SortDescriptor(\.lastTestedDate, order: .reverse)]
            )
            let allLinkedRecords = try modelContext.fetch(allLinkedDescriptor)
            let generalLinkedRecords = allLinkedRecords.filter { rec in
                guard let sid = rec.testSessionId else { return false }
                return generalTestIds.contains(sid)
            }

            // 合并并按单词去重（保留最近一次测试记录）
            var merged: [String: TestedWord] = [:]
            for record in linkedRecords + orphanRecords + generalLinkedRecords {
                let key = record.word.lowercased()
                if let existing = merged[key] {
                    let lhs = record.lastTestedDate ?? record.testedAt
                    let rhs = existing.lastTestedDate ?? existing.testedAt
                    if lhs > rhs { merged[key] = record }
                } else {
                    merged[key] = record
                }
            }

            let result = Array(merged.values).sorted { 
                ($0.lastTestedDate ?? Date.distantPast) > ($1.lastTestedDate ?? Date.distantPast) 
            }

            print("✅ [RetestModeService] 词典 \(dictionary.displayName) 已测试记录：链接 \(linkedRecords.count)，孤立 \(orphanRecords.count)，总记录 \(generalLinkedRecords.count)，合并后 \(result.count)")
            return result
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
    
    // MARK: - 根据过滤器获取单词
    func getFilteredWords(filters: RetestWordFilters) async throws -> [RetestWordItem] {
        // 检查过滤器是否有效
        guard !filters.isEmpty else {
            throw RetestError.invalidConfiguration
        }
        
        do {
            // 获取基础单词列表
            let words = try await getTestedWordsForDictionaries(
                Array(filters.dictionaryIds),
                masteryLevels: Array(filters.masteryLevels)
            )
            
            // 应用额外的过滤条件
            var filteredWords = words
            
            // 排除最近测试的单词（使用显式循环避免 filter 与 SwiftData 的 Predicate 解析冲突）
            if filters.excludeRecentlyTested {
                let cutoffDate = Date().addingTimeInterval(-filters.recentTestThreshold)
                var result: [RetestWordItem] = []
                for item in Swift.Array(filteredWords) {
                    if let last = item.lastTestDate {
                        if last < cutoffDate { result.append(item) }
                    } else {
                        // 没有最近测试日期则保留
                        result.append(item)
                    }
                }
                filteredWords = result
            }
            
            print("✅ 过滤后获得 \(filteredWords.count) 个单词")
            return filteredWords
        } catch {
            print("❌ 根据过滤器获取单词失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func getTestedWordsForDictionary(_ dictionaryId: UUID, masteryLevels: [MasteryLevel]) async throws -> [RetestWordItem] {
        // 获取词典信息
        let dictionaries = try await getAvailableDictionaries()
        guard let dictionary = dictionaries.first(where: { $0.id == dictionaryId }) else {
            throw RetestError.dictionaryNotFound
        }

        // 规范化掌握程度，避免筛选阶段受历史值影响
        await runMasteryNormalizationIfNeeded()
        
        // 使用WordMasteryService获取已测试单词，确保正确处理词典专属记录
        let wordMasteryService = WordMasteryService(
            dictionaryService: dictionaryService,
            modelContext: modelContext,
            cacheManager: CacheManager(),
            errorHandler: ErrorHandler()
        )
        
        let testedWords = try await wordMasteryService.getTestedWordsSync(for: dictionary.fileName)

        let textProcessor = TextProcessor()
        let userRecords = dictionary.isVirtual
            ? dictionaryService.getGeneralUserWordRecords()
            : dictionaryService.getDictionarySpecificUserWordRecords(for: dictionary.id)
        var userMasteryMap: [String: MasteryLevel] = [:]
        for r in userRecords {
            userMasteryMap[textProcessor.cleanWord(r.word)] = r.masteryLevel
        }

        // 虚拟词典（我的学习记录）直接基于已测词构建条目
        if dictionary.isVirtual {
            var retestWords: [RetestWordItem] = []
            for testedWord in testedWords {
                let cleaned = textProcessor.cleanWord(testedWord.word)
                let masteryLevel = userMasteryMap[cleaned] ?? determineMasteryLevel(testedWord)
                if !masteryLevels.contains(masteryLevel) { continue }
                let placeholder = DictionaryWord(
                    word: cleaned,
                    definitions: [WordDefinition(partOfSpeech: .noun, meaning: "学习记录中的测试词条")],
                    frequency: 0,
                    difficulty: .medium,
                    tags: []
                )
                let item = RetestWordItem(
                    word: placeholder,
                    dictionaryName: dictionary.displayName,
                    currentMasteryLevel: masteryLevel,
                    lastTestDate: testedWord.lastTestedDate,
                    testCount: testedWord.testCount
                )
                retestWords.append(item)
            }
            print("✅ [RetestModeService] 虚拟词典 \(dictionary.displayName) 生成重测词条: \(retestWords.count)")
            return retestWords
        }
        
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
            
        // 创建规范化后的查找表（统一大小写与标点），重复键保留首个
        var wordDict = [String: DictionaryWord]()
        for w in words {
            let key = textProcessor.cleanWord(w.word)
            if wordDict[key] == nil { wordDict[key] = w }
        }
        
        var retestWords: [RetestWordItem] = []
        
        let morphology = WordMorphologyProcessor.shared
        for testedWord in testedWords {
            let testedKey = textProcessor.cleanWord(testedWord.word)
            var matched = wordDict[testedKey]
            if matched == nil {
                let forms = morphology.getAllPossibleForms(for: testedKey)
                for form in forms {
                    if let candidate = wordDict[form] { matched = candidate; break }
                }
            }
            guard let word = matched else { continue }
            
            let masteryLevel = userMasteryMap[testedKey] ?? determineMasteryLevel(testedWord)
            
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
        
        print("✅ [RetestModeService] 词典 \(dictionary.displayName) 匹配到重测词条: \(retestWords.count)/\(testedWords.count)")
        return retestWords
    }
    
    private func determineMasteryLevel(_ testedWord: TestedWord) -> MasteryLevel {
        // 直接基于 TestedWord 的枚举值进行判定，避免 isKnown 覆盖熟悉级别
        return testedWord.masteryLevelEnum
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
        // 实现合并结果的逻辑（使用最新时间戳的记录）
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
                // 使用最新时间戳的记录（重测结果更新）
                let testedDate = testedWord.lastTestedDate ?? Date.distantPast
                let existingDate = existingWord.lastTestedDate ?? Date.distantPast
                
                if testedDate > existingDate {
                    existingWord.masteryLevel = testedWord.masteryLevel
                    existingWord.lastTestedDate = testedWord.lastTestedDate
                    existingWord.testCount = existingWord.testCount + testedWord.testCount
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
    
    func getFilteredWords(filters: RetestWordFilters) async throws -> [RetestWordItem] {
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
    @MainActor
    func runMasteryNormalizationIfNeeded() async {
        guard !hasRunNormalization else { return }
        do {
            let migration = DataMigrationService()
            _ = try migration.normalizeTestedWordMasteryLevels(context: modelContext)
            hasRunNormalization = true
        } catch {
            print("⚠️ [RetestModeService] 规范化掌握程度失败: \(error.localizedDescription)")
        }
    }
    func getRetestWords(for configuration: RetestConfiguration) async throws -> [TestedWord] {
        var allRetestWords: [TestedWord] = []

        // 先取可用词典列表，按 id -> fileName 映射
        let dictionaries = try await getAvailableDictionaries()

        for dictionaryId in configuration.selectedDictionaryIds {
            guard let dict = dictionaries.first(where: { $0.id == dictionaryId }) else { continue }

            // 获取指定词典的已测试单词（按 fileName 匹配）
            let predicate = #Predicate<TestedWord> { word in
                word.dictionaryFileName == dict.fileName
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
