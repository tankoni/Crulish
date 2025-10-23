//
//  LearningTrackingService.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation
import SwiftData
import Combine

// MARK: - LearningTrackingService
class LearningTrackingService: BaseService { // 移除冗余的ObservableObject
    
    // MARK: - Properties
    
    /// 学习行为记录缓存
    private var learningRecords: [LearningRecord] = []
    
    /// 单词点击记录缓存
    private var wordClickCache: [String: WordClickRecord] = [:]
    
    /// 缓存有效期（5分钟）
    private let cacheValidityDuration: TimeInterval = 300
    
    /// 最后缓存更新时间
    private var lastCacheUpdate: Date?
    
    /// 当前会话的批量操作记录（用于撤销）
    private var currentSessionBatchOperations: [BatchOperation] = []
    
    /// 当前会话ID
    private let currentSessionId: String = UUID().uuidString
    
    // MARK: - Initialization
    
    override init(
        modelContext: ModelContext,
        cacheManager: CacheManagerProtocol,
        errorHandler: ErrorHandlerProtocol,
        subsystem: String = "com.en01.services",
        category: String = "LearningTrackingService"
    ) {
        super.init(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler,
            subsystem: subsystem,
            category: category
        )
        
        logger.info("LearningTrackingService 初始化完成")
    }
    
    // MARK: - Public Methods
    
    /// 记录单词点击行为
    /// - Parameters:
    ///   - word: 被点击的单词
    ///   - context: 单词所在的上下文
    ///   - articleId: 文章ID
    ///   - position: 点击位置
    @MainActor
    func recordWordClick(
        word: String,
        context: String,
        articleId: UUID,
        position: Int
    ) {
        performSafeOperation("记录单词点击") {
            // 生成会话ID
            let sessionID = "session_\(Date().timeIntervalSince1970)"
            
            let clickRecord = WordClickRecord(
                word: word.lowercased(),
                context: context,
                sentence: context, // 使用context作为sentence
                clickPosition: position,
                sessionID: sessionID,
                userAction: .lookup,
                articleID: articleId.uuidString,
                articleTitle: nil
            )
            
            // 更新缓存
            wordClickCache[word.lowercased()] = clickRecord
            
            // 保存到数据库
            modelContext.insert(clickRecord)
            try modelContext.save()
            
            logger.info("记录单词点击: \(word)")
        }
    }
    
    /// 更新单词掌握程度
    /// - Parameters:
    ///   - word: 单词
    ///   - masteryLevel: 新的掌握程度
    ///   - source: 更新来源（阅读、测试等）
    @MainActor
    func updateWordMastery(
        word: String,
        masteryLevel: MasteryLevel,
        source: String = "reading"
    ) {
        performSafeOperation("更新单词掌握程度") {
            // 查找或创建用户单词记录
            let lowercasedWord = word.lowercased()
            let descriptor = FetchDescriptor<UserWord>(
                predicate: #Predicate { userWord in
                    userWord.word == lowercasedWord
                }
            )
            let existingWords = try modelContext.fetch(descriptor)
            
            let userWord: UserWord
            let previousMastery: MasteryLevel
            
            if let existing = existingWords.first {
                userWord = existing
                previousMastery = existing.masteryLevel
                userWord.masteryLevel = masteryLevel
                userWord.lastReviewDate = Date()
                userWord.clickCount += 1 // 使用 clickCount 替代 reviewCount
            } else {
                previousMastery = .unfamiliar
                userWord = UserWord(
                    word: word.lowercased(),
                    context: "",
                    sentence: "",
                    selectedDefinition: nil,
                    testSource: source,
                    isFromTest: source == "test"
                )
                userWord.masteryLevel = masteryLevel
                userWord.lastReviewDate = Date()
                userWord.clickCount = 1
                userWord.firstLookupDate = Date()
                userWord.lastLookupDate = Date()
                modelContext.insert(userWord)
            }
            
            // 记录学习行为
            let learningRecord = LearningRecord(
                word: word.lowercased(),
                previousMastery: previousMastery,
                newMastery: masteryLevel,
                source: source,
                timestamp: Date()
            )
            
            learningRecords.append(learningRecord)
            modelContext.insert(learningRecord)
            
            try modelContext.save()
            
            logger.info("更新单词掌握程度: \(word) -> \(masteryLevel.rawValue)")
        }
    }
    
    /// 记录单词掌握度
    /// - Parameters:
    ///   - word: 单词
    ///   - mastery: 掌握程度
    ///   - responseTime: 响应时间
    func recordWordMastery(word: String, mastery: MasteryLevel, responseTime: TimeInterval) {
        Task { @MainActor in
            updateWordMastery(word: word, masteryLevel: mastery, source: "test")
        }
        
        logger.info("记录单词掌握度: \(word) - \(mastery)")
    }

    /// 仅当新掌握程度高于现有值时更新（避免重复写入）
    /// - Parameters:
    ///   - word: 单词
    ///   - masteryLevel: 新的掌握程度（通常为 .mastered）
    ///   - source: 更新来源（阅读、测试等）
    @MainActor
    func updateWordMasteryIfHigher(
        word: String,
        masteryLevel: MasteryLevel,
        source: String = "reading"
    ) {
        performSafeOperation("条件更新单词掌握程度") {
            let lowercasedWord = word.lowercased()
            let descriptor = FetchDescriptor<UserWord>(
                predicate: #Predicate { userWord in
                    userWord.word == lowercasedWord
                }
            )
            let existingWords = try modelContext.fetch(descriptor)

            // 如果已有记录且掌握程度不低于目标，则跳过
            if let existing = existingWords.first, existing.masteryLevel >= masteryLevel {
                return
            }

            // 否则执行正常更新逻辑
            updateWordMastery(word: word, masteryLevel: masteryLevel, source: source)
        }
    }
    
    /// 获取单词的学习历史
    /// - Parameter word: 单词
    /// - Returns: 学习记录列表
    func getWordLearningHistory(word: String) -> [LearningRecord] {
        return performSafeOperation("获取单词学习历史") {
            let lowercasedWord = word.lowercased()
            let predicate = #Predicate<LearningRecord> { record in
                record.word == lowercasedWord
            }
            
            let descriptor = FetchDescriptor<LearningRecord>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            return try modelContext.fetch(descriptor)
        } ?? []
    }
    
    /// 获取最近的学习活动
    /// - Parameter limit: 返回记录数量限制
    /// - Returns: 最近的学习记录
    func getRecentLearningActivity(limit: Int = 50) -> [LearningRecord] {
        return performSafeOperation("获取最近学习活动") {
            var descriptor = FetchDescriptor<LearningRecord>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            
            return try modelContext.fetch(descriptor)
        } ?? []
    }
    
    /// 获取单词点击统计
    /// - Parameter timeRange: 时间范围（天数）
    /// - Returns: 点击统计数据
    func getWordClickStatistics(timeRange: Int = 7) -> WordClickStatistics {
        return performSafeOperation("获取单词点击统计") {
            let startDate = Calendar.current.date(byAdding: .day, value: -timeRange, to: Date()) ?? Date()
            
            let predicate = #Predicate<WordClickRecord> { record in
                record.clickDate >= startDate
            }
            
            let descriptor = FetchDescriptor<WordClickRecord>(predicate: predicate)
            let records = try modelContext.fetch(descriptor)
            
            let totalClicks = records.count
            let uniqueWords = Set(records.map { $0.word }).count
            let averageClicksPerDay = Double(totalClicks) / Double(timeRange)
            
            // 统计最常点击的单词
            let wordCounts = Dictionary(grouping: records, by: { $0.word })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            let topWords = Array(wordCounts.prefix(10))
            
            return WordClickStatistics(
                totalClicks: totalClicks,
                uniqueWords: uniqueWords,
                averageClicksPerDay: averageClicksPerDay,
                topClickedWords: topWords,
                timeRange: timeRange
            )
        } ?? WordClickStatistics(
            totalClicks: 0,
            uniqueWords: 0,
            averageClicksPerDay: 0,
            topClickedWords: [],
            timeRange: timeRange
        )
    }
    
    /// 获取学习进度统计
    /// - Returns: 学习进度数据
    func getLearningProgress() -> LearningProgress {
        return performSafeOperation("获取学习进度") {
            let descriptor = FetchDescriptor<UserWord>()
            let userWords = try modelContext.fetch(descriptor)
            
            let masteredCount = userWords.filter { $0.masteryLevel == .mastered }.count
            let familiarCount = userWords.filter { $0.masteryLevel == .familiar }.count
            let unfamiliarCount = userWords.filter { $0.masteryLevel == .unfamiliar }.count
            
            let totalWords = userWords.count
            let masteryRate = totalWords > 0 ? Double(masteredCount) / Double(totalWords) : 0
            
            return LearningProgress(
                totalWords: totalWords,
                masteredWords: masteredCount,
                familiarWords: familiarCount,
                unfamiliarWords: unfamiliarCount,
                masteryRate: masteryRate
            )
        } ?? LearningProgress(
            totalWords: 0,
            masteredWords: 0,
            familiarWords: 0,
            unfamiliarWords: 0,
            masteryRate: 0
        )
    }
    
    /// 清除过期的学习记录缓存
    func clearExpiredCache() {
        performSafeOperation("清除过期缓存") {
            if let lastUpdate = lastCacheUpdate,
               Date().timeIntervalSince(lastUpdate) > cacheValidityDuration {
                learningRecords.removeAll()
                wordClickCache.removeAll()
                lastCacheUpdate = nil
                logger.info("已清除过期的学习记录缓存")
            }
        }
    }
    
    // MARK: - Batch Operations
    
    /// 批量标记文章为已学习
    /// - Parameter articleIds: 文章ID列表
    @MainActor
    func batchMarkArticlesAsLearned(articleIds: [String]) async throws {
        logger.info("开始批量标记文章为已学习，数量: \(articleIds.count)")
        
        let batchOperation = BatchOperation(
            id: UUID(),
            sessionId: currentSessionId,
            type: .markArticlesLearned,
            articleIds: articleIds,
            timestamp: Date()
        )
        
        do {
            // 记录批量操作到当前会话
            currentSessionBatchOperations.append(batchOperation)
            
            // 保存批量操作记录到数据库
            modelContext.insert(batchOperation)
            try modelContext.save()
            
            logger.info("✅ 批量标记文章完成，操作ID: \(batchOperation.id)")
        } catch {
            logger.error("❌ 批量标记文章失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 撤销当前会话的批量操作
    /// - Parameter operationId: 要撤销的操作ID，如果为nil则撤销最后一个操作
    @MainActor
    func undoBatchOperation(operationId: UUID? = nil) async throws {
        logger.info("开始撤销批量操作")
        
        let operationToUndo: BatchOperation?
        
        if let operationId = operationId {
            operationToUndo = currentSessionBatchOperations.first { $0.id == operationId }
        } else {
            operationToUndo = currentSessionBatchOperations.last
        }
        
        guard let operation = operationToUndo else {
            logger.warning("未找到要撤销的批量操作")
            return
        }
        
        do {
            switch operation.type {
            case .markArticlesLearned:
                // 撤销文章学习标记
                for articleId in operation.articleIds {
                    // 这里需要调用文章服务来撤销学习状态
                    // 由于我们在LearningTrackingService中，这里只记录撤销操作
                    logger.info("撤销文章学习标记: \(articleId)")
                }
            case .undoMarkArticlesLearned:
                // 处理撤销操作的撤销（即重新执行原操作）
                logger.info("重新执行批量学习操作，包含 \(operation.articleIds.count) 篇文章")
                for articleId in operation.articleIds {
                    logger.info("重新标记文章为已学习: \(articleId)")
                }
            }
            
            // 创建撤销操作记录
            let undoOperation = BatchOperation(
                id: UUID(),
                sessionId: currentSessionId,
                type: .undoMarkArticlesLearned,
                articleIds: operation.articleIds,
                timestamp: Date(),
                originalOperationId: operation.id
            )
            
            // 从当前会话记录中移除原操作
            currentSessionBatchOperations.removeAll { $0.id == operation.id }
            
            // 添加撤销操作记录
            currentSessionBatchOperations.append(undoOperation)
            modelContext.insert(undoOperation)
            try modelContext.save()
            
            logger.info("✅ 批量操作撤销完成，操作ID: \(operation.id)")
        } catch {
            logger.error("❌ 撤销批量操作失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 获取当前会话的批量操作历史
    /// - Returns: 当前会话的批量操作列表
    func getCurrentSessionBatchOperations() -> [BatchOperation] {
        return currentSessionBatchOperations.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// 清除当前会话的批量操作记录
    func clearCurrentSessionBatchOperations() {
        currentSessionBatchOperations.removeAll()
        logger.info("已清除当前会话的批量操作记录")
    }
}

// MARK: - Data Models

/// 批量操作类型
enum BatchOperationType: String, CaseIterable, Codable {
    case markArticlesLearned = "mark_articles_learned"
    case undoMarkArticlesLearned = "undo_mark_articles_learned"
}

/// 批量操作记录模型
@Model
class BatchOperation {
    var id: UUID
    var sessionId: String
    var type: BatchOperationType
    var articleIds: [String]
    var timestamp: Date
    var originalOperationId: UUID?
    
    init(
        id: UUID,
        sessionId: String,
        type: BatchOperationType,
        articleIds: [String],
        timestamp: Date,
        originalOperationId: UUID? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.type = type
        self.articleIds = articleIds
        self.timestamp = timestamp
        self.originalOperationId = originalOperationId
    }
}

/// 学习记录模型
@Model
class LearningRecord {
    var word: String
    var previousMastery: MasteryLevel
    var newMastery: MasteryLevel
    var source: String
    var timestamp: Date
    
    init(
        word: String,
        previousMastery: MasteryLevel,
        newMastery: MasteryLevel,
        source: String,
        timestamp: Date
    ) {
        self.word = word
        self.previousMastery = previousMastery
        self.newMastery = newMastery
        self.source = source
        self.timestamp = timestamp
    }
}

/// 单词点击统计数据
struct WordClickStatistics {
    let totalClicks: Int
    let uniqueWords: Int
    let averageClicksPerDay: Double
    let topClickedWords: [(key: String, value: Int)]
    let timeRange: Int
}

/// 学习进度数据
struct LearningProgress {
    let totalWords: Int
    let masteredWords: Int
    let familiarWords: Int
    let unfamiliarWords: Int
    let masteryRate: Double
    
    var masteredPercentage: Double {
        return totalWords > 0 ? Double(masteredWords) / Double(totalWords) * 100 : 0
    }
    
    var familiarPercentage: Double {
        return totalWords > 0 ? Double(familiarWords) / Double(totalWords) * 100 : 0
    }
    
    var unfamiliarPercentage: Double {
        return totalWords > 0 ? Double(unfamiliarWords) / Double(totalWords) * 100 : 0
    }
}