//
//  GlobalWordService.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import SwiftData
import Foundation
import Combine

/// 全局词汇服务协议
protocol GlobalWordServiceProtocol {
    func getOrCreateWord(_ word: String) async throws -> GlobalWord
    func updateWordTestResult(_ word: String, isCorrect: Bool, responseTime: TimeInterval) async throws
    func getWordsByMasteryLevel(_ level: MasteryLevel) async throws -> [GlobalWord]
    func getWordsForDictionary(_ dictionaryWords: [String]) async throws -> [GlobalWord]
    func clearAllTestData() async throws
    func importWordsFromExport(_ exportData: [String: Any]) async throws
    func exportAllWords() async throws -> [String: Any]
    func getTestStatistics() async throws -> GlobalWordStatistics
}

/// 全局词汇服务实现
class GlobalWordService: GlobalWordServiceProtocol {
    private let modelContext: ModelContext
    private let errorHandler: ErrorHandlerProtocol
    
    // 缓存
    private var wordCache: [String: GlobalWord] = [:]
    private let cacheQueue = DispatchQueue(label: "GlobalWordService.cache", attributes: .concurrent)
    
    init(modelContext: ModelContext, errorHandler: ErrorHandlerProtocol) {
        self.modelContext = modelContext
        self.errorHandler = errorHandler
    }
    
    // MARK: - 核心词汇操作
    
    /// 获取或创建单词记录
    func getOrCreateWord(_ word: String) async throws -> GlobalWord {
        let lowercaseWord = word.lowercased()
        
        // 先检查缓存
        if let cachedWord = await getCachedWord(lowercaseWord) {
            return cachedWord
        }
        
        // 从数据库查询
        let predicate = GlobalWord.predicateForWord(lowercaseWord)
        let descriptor = FetchDescriptor<GlobalWord>(predicate: predicate)
        
        do {
            let existingWords = try modelContext.fetch(descriptor)
            
            if let existingWord = existingWords.first {
                await setCachedWord(lowercaseWord, existingWord)
                return existingWord
            } else {
                // 创建新单词记录
                let newWord = GlobalWord(word: word)
                modelContext.insert(newWord)
                try modelContext.save()
                
                await setCachedWord(lowercaseWord, newWord)
                print("✅ [GlobalWordService] 创建新单词记录: \(word)")
                return newWord
            }
        } catch {
            errorHandler.handle(error, context: "获取或创建单词记录")
            throw error
        }
    }
    
    /// 更新单词测试结果
    func updateWordTestResult(_ word: String, isCorrect: Bool, responseTime: TimeInterval) async throws {
        do {
            let globalWord = try await getOrCreateWord(word)
            globalWord.updateTestResult(isCorrect: isCorrect, responseTime: responseTime)
            
            try modelContext.save()
            
            // 更新缓存
            await setCachedWord(word.lowercased(), globalWord)
            
            print("✅ [GlobalWordService] 更新单词测试结果: \(word) - \(isCorrect ? "正确" : "错误")")
        } catch {
            errorHandler.handle(error, context: "更新单词测试结果")
            throw error
        }
    }
    
    // MARK: - 查询操作
    
    /// 按掌握程度获取单词
    func getWordsByMasteryLevel(_ level: MasteryLevel) async throws -> [GlobalWord] {
        let predicate = GlobalWord.predicateForMasteryLevel(level)
        let descriptor = FetchDescriptor<GlobalWord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\GlobalWord.lastTestedDate, order: .reverse)]
        )
        
        do {
            let words = try modelContext.fetch(descriptor)
            print("✅ [GlobalWordService] 获取 \(level.rawValue) 掌握程度的单词: \(words.count) 个")
            return words
        } catch {
            errorHandler.handle(error, context: "按掌握程度获取单词")
            throw error
        }
    }
    
    /// 获取词典对应的单词记录
    func getWordsForDictionary(_ dictionaryWords: [String]) async throws -> [GlobalWord] {
        var result: [GlobalWord] = []
        
        for word in dictionaryWords {
            do {
                let globalWord = try await getOrCreateWord(word)
                result.append(globalWord)
            } catch {
                print("⚠️ [GlobalWordService] 获取单词记录失败: \(word) - \(error.localizedDescription)")
                // 继续处理其他单词，不中断整个流程
            }
        }
        
        print("✅ [GlobalWordService] 获取词典单词记录: \(result.count)/\(dictionaryWords.count)")
        return result
    }
    
    /// 获取已测试的单词（用于预处理）
    func getTestedWords(from dictionaryWords: [String]) async throws -> [GlobalWord] {
        let testedWords = try await getWordsForDictionary(dictionaryWords)
        let actuallyTested = testedWords.filter { $0.testCount > 0 }
        
        print("✅ [GlobalWordService] 词典中已测试单词: \(actuallyTested.count)/\(dictionaryWords.count)")
        return actuallyTested
    }
    
    /// 获取未测试的单词（用于测试）
    func getUntestedWords(from dictionaryWords: [String]) async throws -> [String] {
        let testedWords = try await getTestedWords(from: dictionaryWords)
        let testedWordSet = Set(testedWords.map { $0.word })
        
        let untestedWords = dictionaryWords.filter { word in
            !testedWordSet.contains(word.lowercased())
        }
        
        print("✅ [GlobalWordService] 词典中未测试单词: \(untestedWords.count)/\(dictionaryWords.count)")
        return untestedWords
    }
    
    // MARK: - 数据管理
    
    /// 清除所有测试数据
    func clearAllTestData() async throws {
        do {
            let descriptor = FetchDescriptor<GlobalWord>()
            let allWords = try modelContext.fetch(descriptor)
            
            for word in allWords {
                modelContext.delete(word)
            }
            
            try modelContext.save()
            
            // 清除缓存
            await clearCache()
            
            print("✅ [GlobalWordService] 清除所有测试数据: \(allWords.count) 个单词")
        } catch {
            errorHandler.handle(error, context: "清除所有测试数据")
            throw error
        }
    }
    
    /// 从导出数据导入单词
    func importWordsFromExport(_ exportData: [String: Any]) async throws {
        guard let wordsData = exportData["words"] as? [[String: Any]] else {
            throw GlobalWordError.invalidExportFormat
        }
        
        var importedCount = 0
        var errorCount = 0
        
        for wordData in wordsData {
            do {
                guard let word = wordData["word"] as? String,
                      let masteryLevel = wordData["masteryLevel"] as? String else {
                    continue
                }
                
                let testCount = wordData["testCount"] as? Int ?? 0
                let correctCount = wordData["correctCount"] as? Int ?? 0
                let masteryScore = wordData["masteryScore"] as? Double ?? 0
                
                var lastTestedDate: Date?
                if let dateString = wordData["lastTestedDate"] as? String {
                    lastTestedDate = ISO8601DateFormatter().date(from: dateString)
                }
                
                let globalWord = GlobalWord.fromExportData(
                    word: word,
                    masteryLevel: masteryLevel,
                    testCount: testCount,
                    correctCount: correctCount,
                    masteryScore: masteryScore,
                    lastTestedDate: lastTestedDate
                )
                
                modelContext.insert(globalWord)
                importedCount += 1
                
            } catch {
                errorCount += 1
                print("⚠️ [GlobalWordService] 导入单词失败: \(error.localizedDescription)")
            }
        }
        
        try modelContext.save()
        await clearCache() // 清除缓存以确保数据一致性
        
        print("✅ [GlobalWordService] 导入完成: 成功 \(importedCount) 个，失败 \(errorCount) 个")
    }
    
    /// 导出所有单词数据
    func exportAllWords() async throws -> [String: Any] {
        do {
            let descriptor = FetchDescriptor<GlobalWord>(
                sortBy: [SortDescriptor(\GlobalWord.word)]
            )
            let allWords = try modelContext.fetch(descriptor)
            
            let wordsData = allWords.map { $0.toExportData() }
            
            let exportData: [String: Any] = [
                "exportDate": Date().ISO8601Format(),
                "version": "1.0",
                "totalWords": allWords.count,
                "words": wordsData
            ]
            
            print("✅ [GlobalWordService] 导出数据: \(allWords.count) 个单词")
            return exportData
        } catch {
            errorHandler.handle(error, context: "导出所有单词数据")
            throw error
        }
    }
    
    /// 获取测试统计信息
    func getTestStatistics() async throws -> GlobalWordStatistics {
        do {
            let descriptor = FetchDescriptor<GlobalWord>()
            let allWords = try modelContext.fetch(descriptor)
            
            let totalWords = allWords.count
            let testedWords = allWords.filter { $0.testCount > 0 }
            let masteredWords = allWords.filter { $0.masteryLevelEnum == .mastered }
            let familiarWords = allWords.filter { $0.masteryLevelEnum == .familiar }
            let unfamiliarWords = allWords.filter { $0.masteryLevelEnum == .unfamiliar }
            
            let totalTests = testedWords.reduce(0) { $0 + $1.testCount }
            let totalCorrect = testedWords.reduce(0) { $0 + $1.correctCount }
            let averageAccuracy = totalTests > 0 ? Double(totalCorrect) / Double(totalTests) : 0
            
            let averageResponseTime = testedWords.isEmpty ? 0 : 
                testedWords.reduce(0) { $0 + $1.averageResponseTime } / Double(testedWords.count)
            
            return GlobalWordStatistics(
                totalWords: totalWords,
                testedWords: testedWords.count,
                masteredWords: masteredWords.count,
                familiarWords: familiarWords.count,
                unfamiliarWords: unfamiliarWords.count,
                totalTests: totalTests,
                averageAccuracy: averageAccuracy,
                averageResponseTime: averageResponseTime
            )
        } catch {
            errorHandler.handle(error, context: "获取测试统计信息")
            throw error
        }
    }
    
    // MARK: - 缓存管理
    
    private func getCachedWord(_ word: String) async -> GlobalWord? {
        return await withCheckedContinuation { continuation in
            cacheQueue.async {
                continuation.resume(returning: self.wordCache[word])
            }
        }
    }
    
    private func setCachedWord(_ word: String, _ globalWord: GlobalWord) async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                self.wordCache[word] = globalWord
                continuation.resume()
            }
        }
    }
    
    private func clearCache() async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                self.wordCache.removeAll()
                continuation.resume()
            }
        }
    }
}

// MARK: - 统计数据结构

struct GlobalWordStatistics {
    let totalWords: Int
    let testedWords: Int
    let masteredWords: Int
    let familiarWords: Int
    let unfamiliarWords: Int
    let totalTests: Int
    let averageAccuracy: Double
    let averageResponseTime: TimeInterval
    
    var masteryRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWords)
    }
    
    var testCoverage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(testedWords) / Double(totalWords)
    }
}

// MARK: - 错误定义

enum GlobalWordError: LocalizedError {
    case invalidExportFormat
    case wordNotFound
    case databaseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidExportFormat:
            return "导出数据格式无效"
        case .wordNotFound:
            return "找不到指定的单词"
        case .databaseError(let error):
            return "数据库错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - Mock实现

class MockGlobalWordService: GlobalWordServiceProtocol {
    private var mockWords: [String: GlobalWord] = [:]
    
    func getOrCreateWord(_ word: String) async throws -> GlobalWord {
        let key = word.lowercased()
        if let existing = mockWords[key] {
            return existing
        }
        
        let newWord = GlobalWord(word: word)
        mockWords[key] = newWord
        return newWord
    }
    
    func updateWordTestResult(_ word: String, isCorrect: Bool, responseTime: TimeInterval) async throws {
        let globalWord = try await getOrCreateWord(word)
        globalWord.updateTestResult(isCorrect: isCorrect, responseTime: responseTime)
    }
    
    func getWordsByMasteryLevel(_ level: MasteryLevel) async throws -> [GlobalWord] {
        return Array(mockWords.values).filter { $0.masteryLevelEnum == level }
    }
    
    func getWordsForDictionary(_ dictionaryWords: [String]) async throws -> [GlobalWord] {
        var result: [GlobalWord] = []
        for word in dictionaryWords {
            let globalWord = try await getOrCreateWord(word)
            result.append(globalWord)
        }
        return result
    }
    
    func clearAllTestData() async throws {
        mockWords.removeAll()
    }
    
    func importWordsFromExport(_ exportData: [String: Any]) async throws {
        // Mock implementation
    }
    
    func exportAllWords() async throws -> [String: Any] {
        return [
            "exportDate": Date().ISO8601Format(),
            "version": "1.0",
            "totalWords": mockWords.count,
            "words": Array(mockWords.values).map { $0.toExportData() }
        ]
    }
    
    func getTestStatistics() async throws -> GlobalWordStatistics {
        let allWords = Array(mockWords.values)
        let testedWords = allWords.filter { $0.testCount > 0 }
        
        return GlobalWordStatistics(
            totalWords: allWords.count,
            testedWords: testedWords.count,
            masteredWords: allWords.filter { $0.masteryLevelEnum == .mastered }.count,
            familiarWords: allWords.filter { $0.masteryLevelEnum == .familiar }.count,
            unfamiliarWords: allWords.filter { $0.masteryLevelEnum == .unfamiliar }.count,
            totalTests: testedWords.reduce(0) { $0 + $1.testCount },
            averageAccuracy: 0.75,
            averageResponseTime: 2.5
        )
    }
}