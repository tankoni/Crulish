//
//  TestedWord.swift
//  en01
//
//  Created by SOLO Coding on 2025/1/18.
//

import Foundation
import SwiftData

// MARK: - 已测试单词记录模型

/// 用于记录已测试单词的掌握程度和测试时间
@Model
final class TestedWord: @unchecked Sendable {
    var id: UUID
    var word: String // 单词
    var dictionaryName: String // 所属词典名称
    var dictionaryFileName: String // 词典文件名
    var masteryLevel: String // 掌握程度：mastered, familiar, unfamiliar
    var testedAt: Date // 测试时间
    var testSessionId: UUID? // 测试会话ID，用于关联同一次测试
    var difficulty: String // 单词难度级别
    var responseTime: Double // 回答时间（秒）
    
    init(
        word: String,
        dictionaryName: String,
        dictionaryFileName: String,
        masteryLevel: MasteryLevel,
        testSessionId: UUID? = nil,
        difficulty: String = "unknown",
        responseTime: Double = 0.0
    ) {
        self.id = UUID()
        self.word = word
        self.dictionaryName = dictionaryName
        self.dictionaryFileName = dictionaryFileName
        self.masteryLevel = masteryLevel.rawValue
        self.testedAt = Date()
        self.testSessionId = testSessionId
        self.difficulty = difficulty
        self.responseTime = responseTime
    }
    
    // MARK: - Computed Properties
    
    /// 获取掌握程度枚举值
    var masteryLevelEnum: MasteryLevel {
        return MasteryLevel(rawValue: masteryLevel) ?? .unfamiliar
    }
    
    /// 是否为已掌握
    var isMastered: Bool {
        return masteryLevelEnum == .mastered
    }
    
    /// 是否为熟悉
    var isFamiliar: Bool {
        return masteryLevelEnum == .familiar
    }
    
    /// 是否为不熟悉
    var isUnfamiliar: Bool {
        return masteryLevelEnum == .unfamiliar
    }
    
    /// 是否为已知单词（掌握或熟悉）
    var isKnown: Bool {
        return isMastered || isFamiliar
    }
    
    // MARK: - Methods
    
    /// 更新掌握程度
    func updateMasteryLevel(_ level: MasteryLevel) {
        self.masteryLevel = level.rawValue
        self.testedAt = Date()
    }
    
    /// 更新回答时间
    func updateResponseTime(_ time: Double) {
        self.responseTime = time
    }
}

// MARK: - 扩展方法

extension TestedWord {
    /// 获取格式化的测试时间
    var formattedTestedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: testedAt)
    }
    
    /// 获取掌握程度的显示文本
    var masteryDisplayText: String {
        switch masteryLevelEnum {
        case .mastered:
            return "已掌握"
        case .familiar:
            return "熟悉"
        case .unfamiliar:
            return "不熟悉"
        }
    }
    
    /// 获取掌握程度的颜色
    var masteryColor: String {
        switch masteryLevelEnum {
        case .mastered:
            return "green"
        case .familiar:
            return "orange"
        case .unfamiliar:
            return "red"
        }
    }
}

// MARK: - 测试会话统计

/// 测试会话统计信息
struct TestSessionStats {
    let sessionId: UUID
    let dictionaryName: String
    let totalTested: Int
    let masteredCount: Int
    let familiarCount: Int
    let unfamiliarCount: Int
    let averageResponseTime: Double
    let testDate: Date
    
    var masteryRate: Double {
        guard totalTested > 0 else { return 0 }
        return Double(masteredCount + familiarCount) / Double(totalTested)
    }
    
    var masteryPercentage: String {
        return String(format: "%.1f%%", masteryRate * 100)
    }
}