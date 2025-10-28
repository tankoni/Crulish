//
//  RetestModels.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import SwiftData
import Foundation

/// 重测配置模型
@Model
class RetestConfiguration {
    var id: UUID
    var name: String
    var selectedDictionaryIds: [UUID]
    var selectedMasteryLevels: [MasteryLevel]
    var testMode: VocabularyTestMode
    var createdAt: Date
    var lastUsedAt: Date
    var isActive: Bool
    
    init(
        name: String,
        selectedDictionaryIds: [UUID] = [],
        selectedMasteryLevels: [MasteryLevel] = [],
        testMode: VocabularyTestMode = .chineseToEnglish
    ) {
        self.id = UUID()
        self.name = name
        self.selectedDictionaryIds = selectedDictionaryIds
        self.selectedMasteryLevels = selectedMasteryLevels
        self.testMode = testMode
        self.createdAt = Date()
        self.lastUsedAt = Date()
        self.isActive = true
    }
}

// MasteryLevel 已在 Word.swift 中定义为独立枚举，无需类型别名

/// 重测词汇筛选器
struct RetestWordFilters {
    var dictionaryIds: Set<UUID>
    var masteryLevels: Set<MasteryLevel>
    var excludeRecentlyTested: Bool
    var recentTestThreshold: TimeInterval // 最近测试的时间阈值（秒）
    
    init(
        dictionaryIds: Set<UUID> = [],
        masteryLevels: Set<MasteryLevel> = [],
        excludeRecentlyTested: Bool = false,
        recentTestThreshold: TimeInterval = 24 * 60 * 60 // 默认24小时
    ) {
        self.dictionaryIds = dictionaryIds
        self.masteryLevels = masteryLevels
        self.excludeRecentlyTested = excludeRecentlyTested
        self.recentTestThreshold = recentTestThreshold
    }
    
    var isEmpty: Bool {
        return dictionaryIds.isEmpty || masteryLevels.isEmpty
    }
}

/// 重测设置
struct RetestSettings {
    var resultOverwriteMode: ResultOverwriteMode
    var testSize: Int
    var shuffleWords: Bool
    var showProgress: Bool
    
    init(
        resultOverwriteMode: ResultOverwriteMode = .overwrite,
        testSize: Int = 50,
        shuffleWords: Bool = true,
        showProgress: Bool = true
    ) {
        self.resultOverwriteMode = resultOverwriteMode
        self.testSize = testSize
        self.shuffleWords = shuffleWords
        self.showProgress = showProgress
    }
}

/// 结果覆盖模式
enum ResultOverwriteMode: String, CaseIterable, Codable {
    case overwrite = "overwrite"        // 覆盖原有结果
    case createNew = "createNew"        // 创建新的测试记录
    case merge = "merge"                // 合并结果（保留更好的结果）
    
    var displayName: String {
        switch self {
        case .overwrite:
            return "覆盖原有结果"
        case .createNew:
            return "创建新测试记录"
        case .merge:
            return "合并测试结果"
        }
    }
    
    var description: String {
        switch self {
        case .overwrite:
            return "重测结果将直接替换原有的测试结果"
        case .createNew:
            return "重测将创建新的测试记录，保留原有结果"
        case .merge:
            return "保留更好的测试结果，合并到原有记录中"
        }
    }
}

/// 重测会话模型
@Model
class RetestSession: @unchecked Sendable {
    var id: UUID
    var configurationId: UUID
    var startTime: Date
    var endTime: Date?
    var totalWords: Int
    var completedWords: Int
    var correctAnswers: Int
    var isCompleted: Bool
    var testResults: [RetestResult]
    
    init(configurationId: UUID, totalWords: Int) {
        self.id = UUID()
        self.configurationId = configurationId
        self.startTime = Date()
        self.endTime = nil
        self.totalWords = totalWords
        self.completedWords = 0
        self.correctAnswers = 0
        self.isCompleted = false
        self.testResults = []
    }
    
    var progress: Double {
        guard totalWords > 0 else { return 0 }
        return Double(completedWords) / Double(totalWords)
    }
    
    var accuracy: Double {
        guard completedWords > 0 else { return 0 }
        return Double(correctAnswers) / Double(completedWords)
    }
}

/// 重测结果模型
@Model
class RetestResult {
    var id: UUID
    var sessionId: UUID
    var wordId: UUID
    var dictionaryId: UUID
    var originalMasteryLevel: MasteryLevel
    var newMasteryLevel: MasteryLevel
    var isCorrect: Bool
    var responseTime: TimeInterval
    var timestamp: Date
    
    init(
        sessionId: UUID,
        wordId: UUID,
        dictionaryId: UUID,
        originalMasteryLevel: MasteryLevel,
        newMasteryLevel: MasteryLevel,
        isCorrect: Bool,
        responseTime: TimeInterval
    ) {
        self.id = UUID()
        self.sessionId = sessionId
        self.wordId = wordId
        self.dictionaryId = dictionaryId
        self.originalMasteryLevel = originalMasteryLevel
        self.newMasteryLevel = newMasteryLevel
        self.isCorrect = isCorrect
        self.responseTime = responseTime
        self.timestamp = Date()
    }
}

/// 重测统计信息
struct RetestStatistics {
    let totalWords: Int
    let improvedWords: Int
    let maintainedWords: Int
    let declinedWords: Int
    let averageResponseTime: TimeInterval
    let accuracy: Double
    
    var improvementRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(improvedWords) / Double(totalWords)
    }
    
    var maintenanceRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(maintainedWords) / Double(totalWords)
    }
    
    var declineRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(declinedWords) / Double(totalWords)
    }
}

/// 重测词汇项
struct RetestWordItem: Identifiable, Hashable {
    let id: PersistentIdentifier
    let word: Word
    let dictionaryName: String
    let currentMasteryLevel: MasteryLevel
    let lastTestDate: Date?
    let testCount: Int
    
    init(word: Word, dictionaryName: String, currentMasteryLevel: MasteryLevel, lastTestDate: Date? = nil, testCount: Int = 0) {
        self.id = word.id
        self.word = word
        self.dictionaryName = dictionaryName
        self.currentMasteryLevel = currentMasteryLevel
        self.lastTestDate = lastTestDate
        self.testCount = testCount
    }
}

/// 重测模式状态
enum RetestModeState {
    case configuration  // 配置阶段
    case testing       // 测试阶段
    case results       // 结果阶段
    case completed     // 完成阶段
}