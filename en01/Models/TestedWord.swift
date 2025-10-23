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
    var dictionaryName: String // 主要词典名称
    var dictionaryFileName: String // 主要词典文件名
    var masteryLevel: String // 掌握程度：mastered, familiar, unfamiliar
    var testedAt: Date // 首次测试时间
    var lastTestedDate: Date? // 最后测试时间
    var testSessionId: UUID? // 测试会话ID，用于关联同一次测试
    var difficulty: String // 单词难度级别
    var responseTime: Double // 平均回答时间（秒）
    
    // MARK: - 累加式更新字段
    private var relatedDictionariesString: String = "" // 相关词典文件名列表（分号分隔的字符串存储）
    var testCount: Int = 0 // 总测试次数
    var correctCount: Int = 0 // 正确次数（mastered=2分, familiar=1分, unfamiliar=0分）
    var masteryScore: Double = 0.0 // 累加掌握程度分数（0.0-1.0）
    var timeDecayFactor: Double = 1.0 // 时间衰减因子
    
    // 计算属性，用于访问相关词典数组
    var relatedDictionaries: [String] {
        get {
            return relatedDictionariesString.isEmpty ? [] : relatedDictionariesString.components(separatedBy: ";")
        }
        set {
            relatedDictionariesString = newValue.joined(separator: ";")
        }
    }
    
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
        let now = Date()
        self.testedAt = now
        self.lastTestedDate = now
        self.testSessionId = testSessionId
        self.difficulty = difficulty
        self.responseTime = responseTime
        
        // 初始化累加式更新字段
        self.relatedDictionaries = [dictionaryFileName]
        self.testCount = 1
        self.correctCount = masteryLevel.scoreValue
        self.masteryScore = Double(masteryLevel.scoreValue) / 2.0 // 初始分数
        self.timeDecayFactor = 1.0
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
    
    /// 获取相关词典列表
    var relatedDictionaryList: [String] {
        return relatedDictionaries
    }
    
    /// 正确率
    var accuracyRate: Double {
        guard testCount > 0 else { return 0.0 }
        return Double(correctCount) / (Double(testCount) * 2.0) // 最高分是2分
    }
    
    /// 当前掌握程度分数（考虑时间衰减）
    var currentMasteryScore: Double {
        guard let lastTestDate = lastTestedDate else { return masteryScore }
        let daysSinceLastTest = Calendar.current.dateComponents([.day], from: lastTestDate, to: Date()).day ?? 0
        let decay = max(0.5, 1.0 - Double(daysSinceLastTest) * 0.01) // 每天衰减1%，最低50%
        return masteryScore * decay
    }
    
    // MARK: - Methods
    
    /// 更新掌握程度
    func updateMasteryLevel(_ level: MasteryLevel, fromDictionary: String? = nil) {
        self.masteryLevel = level.rawValue
        self.lastTestedDate = Date()
        self.testCount += 1
        self.correctCount += level.scoreValue
        
        // 更新相关词典列表
        if let dictionary = fromDictionary, !relatedDictionaries.contains(dictionary) {
            relatedDictionaries.append(dictionary)
        }
        
        // 重新计算掌握程度分数
        recalculateMasteryScore()
    }
    
    /// 重新计算掌握程度分数和等级
    private func recalculateMasteryScore() {
        // 基础分数：正确率 * 0.7
        let baseScore = accuracyRate * 0.7
        
        // 频次奖励：min(测试次数 / 10, 0.2)
        let frequencyBonus = min(Double(testCount) / 10.0, 0.2)
        
        // 时间因子：根据最后测试时间计算 * 0.1
        let daysSinceLastTest: Int
        if let lastTestDate = lastTestedDate {
            daysSinceLastTest = Calendar.current.dateComponents([.day], from: lastTestDate, to: Date()).day ?? 0
        } else {
            daysSinceLastTest = 0
        }
        let timeFactor = max(0.0, 1.0 - Double(daysSinceLastTest) * 0.01) * 0.1
        
        // 计算最终分数
        masteryScore = min(1.0, baseScore + frequencyBonus + timeFactor)
        
        // 更新掌握程度等级
        if masteryScore >= 0.8 {
            masteryLevel = MasteryLevel.mastered.rawValue
        } else if masteryScore >= 0.5 {
            masteryLevel = MasteryLevel.familiar.rawValue
        } else {
            masteryLevel = MasteryLevel.unfamiliar.rawValue
        }
        
        // 更新时间衰减因子
        timeDecayFactor = max(0.5, 1.0 - Double(daysSinceLastTest) * 0.01)
    }
    
    /// 更新回答时间（计算平均值）
    func updateResponseTime(_ time: Double) {
        let totalTime = self.responseTime * Double(testCount - 1) + time
        self.responseTime = totalTime / Double(testCount)
    }
    
    /// 合并来自其他词典的测试结果
    func mergeTestResult(from otherWord: TestedWord) {
        // 合并测试次数和正确次数
        self.testCount += otherWord.testCount
        self.correctCount += otherWord.correctCount
        
        // 合并相关词典列表
        for dictionary in otherWord.relatedDictionaries {
            if !self.relatedDictionaries.contains(dictionary) {
                self.relatedDictionaries.append(dictionary)
            }
        }
        
        // 更新最后测试时间为较新的时间
        if let otherLastTestDate = otherWord.lastTestedDate,
           let selfLastTestDate = self.lastTestedDate {
            if otherLastTestDate > selfLastTestDate {
                self.lastTestedDate = otherLastTestDate
            }
        } else if otherWord.lastTestedDate != nil {
            self.lastTestedDate = otherWord.lastTestedDate
        }
        
        // 更新平均回答时间
        let totalTime = self.responseTime * Double(self.testCount - otherWord.testCount) + 
                       otherWord.responseTime * Double(otherWord.testCount)
        self.responseTime = totalTime / Double(self.testCount)
        
        // 重新计算掌握程度分数
        recalculateMasteryScore()
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