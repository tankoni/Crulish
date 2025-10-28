//
//  GlobalWord.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import SwiftData
import Foundation

/// 全局词汇模型 - 共享词汇数据库的核心
/// 统一管理所有词汇的测试记录，不区分来源词典
@Model
class GlobalWord {
    /// 唯一标识符
    var id: UUID
    
    /// 单词拼写（小写，用于去重和查找）
    var word: String
    
    /// 原始单词拼写（保持原始大小写）
    var originalWord: String
    
    /// 当前掌握程度
    var masteryLevel: String
    
    /// 是否已掌握
    var isKnown: Bool
    
    /// 是否熟悉
    var isFamiliar: Bool
    
    /// 测试次数
    var testCount: Int
    
    /// 正确次数
    var correctCount: Int
    
    /// 掌握度分数（0-100）
    var masteryScore: Double
    
    /// 首次测试时间
    var firstTestedDate: Date
    
    /// 最后测试时间
    var lastTestedDate: Date
    
    /// 平均响应时间（秒）
    var averageResponseTime: TimeInterval
    
    /// 最后响应时间（秒）
    var lastResponseTime: TimeInterval
    
    /// 时间衰减因子
    var timeDecayFactor: Double
    
    /// 难度等级（1-5）
    var difficultyLevel: Int
    
    /// 创建时间
    var createdAt: Date
    
    /// 更新时间
    var updatedAt: Date
    
    // MARK: - 计算属性
    
    /// 掌握程度枚举
    var masteryLevelEnum: MasteryLevel {
        get {
            return MasteryLevel(rawValue: masteryLevel) ?? .unfamiliar
        }
        set {
            masteryLevel = newValue.rawValue
            updateMasteryFlags(newValue)
        }
    }
    
    /// 是否已掌握（基于掌握程度）
    var isMastered: Bool {
        return masteryLevelEnum == .mastered
    }
    
    /// 准确率
    var accuracyRate: Double {
        guard testCount > 0 else { return 0 }
        return Double(correctCount) / Double(testCount)
    }
    
    /// 当前掌握度分数（考虑时间衰减）
    var currentMasteryScore: Double {
        let daysSinceLastTest = Date().timeIntervalSince(lastTestedDate) / (24 * 60 * 60)
        let decayedScore = masteryScore * pow(timeDecayFactor, daysSinceLastTest)
        return max(0, min(100, decayedScore))
    }
    
    /// 学习进度描述
    var progressDescription: String {
        switch masteryLevelEnum {
        case .mastered:
            return "已掌握"
        case .familiar:
            return "熟悉"
        case .unfamiliar:
            return "不熟悉"
        }
    }
    
    // MARK: - 初始化
    
    init(
        word: String,
        masteryLevel: MasteryLevel = .unfamiliar,
        difficultyLevel: Int = 1
    ) {
        self.id = UUID()
        self.word = word.lowercased()
        self.originalWord = word
        self.masteryLevel = masteryLevel.rawValue
        self.isKnown = masteryLevel == .mastered
        self.isFamiliar = masteryLevel == .familiar
        self.testCount = 0
        self.correctCount = 0
        self.masteryScore = 0
        self.firstTestedDate = Date()
        self.lastTestedDate = Date()
        self.averageResponseTime = 0
        self.lastResponseTime = 0
        self.timeDecayFactor = 0.95 // 每天衰减5%
        self.difficultyLevel = max(1, min(5, difficultyLevel))
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - 测试结果更新
    
    /// 更新测试结果
    func updateTestResult(isCorrect: Bool, responseTime: TimeInterval) {
        testCount += 1
        if isCorrect {
            correctCount += 1
        }
        
        // 更新响应时间
        updateResponseTime(responseTime)
        
        // 更新掌握度
        updateMasteryScore(isCorrect: isCorrect, responseTime: responseTime)
        
        // 更新掌握程度
        updateMasteryLevel()
        
        // 更新时间戳
        lastTestedDate = Date()
        updatedAt = Date()
        
        print("✅ [GlobalWord] 更新单词 '\(originalWord)' 测试结果: \(isCorrect ? "正确" : "错误"), 掌握度: \(masteryScore)")
    }
    
    /// 更新响应时间
    private func updateResponseTime(_ responseTime: TimeInterval) {
        lastResponseTime = responseTime
        
        if testCount == 1 {
            averageResponseTime = responseTime
        } else {
            // 使用加权平均，新的响应时间权重更高
            let weight = 0.3
            averageResponseTime = averageResponseTime * (1 - weight) + responseTime * weight
        }
    }
    
    /// 更新掌握度分数
    private func updateMasteryScore(isCorrect: Bool, responseTime: TimeInterval) {
        let baseScore = isCorrect ? 20.0 : -10.0
        
        // 响应时间影响（越快越好）
        let timeBonus = max(0, 10 - responseTime) * 2
        
        // 难度影响
        let difficultyMultiplier = 1.0 + (Double(difficultyLevel - 1) * 0.2)
        
        let scoreChange = (baseScore + timeBonus) * difficultyMultiplier
        masteryScore = max(0, min(100, masteryScore + scoreChange))
    }
    
    /// 更新掌握程度
    private func updateMasteryLevel() {
        let newLevel: MasteryLevel
        
        if masteryScore >= 80 && accuracyRate >= 0.8 {
            newLevel = .mastered
        } else if masteryScore >= 50 && accuracyRate >= 0.6 {
            newLevel = .familiar
        } else {
            newLevel = .unfamiliar
        }
        
        masteryLevelEnum = newLevel
    }
    
    /// 更新掌握标志
    private func updateMasteryFlags(_ level: MasteryLevel) {
        isKnown = (level == .mastered)
        isFamiliar = (level == .familiar)
    }
    
    // MARK: - 数据合并
    
    /// 合并另一个测试结果
    func mergeTestResult(from other: GlobalWord) {
        guard word == other.word else { return }
        
        // 合并测试统计
        testCount += other.testCount
        correctCount += other.correctCount
        
        // 更新时间（保留最早的首次测试时间，最晚的最后测试时间）
        if other.firstTestedDate < firstTestedDate {
            firstTestedDate = other.firstTestedDate
        }
        if other.lastTestedDate > lastTestedDate {
            lastTestedDate = other.lastTestedDate
        }
        
        // 合并掌握度（取较高值）
        masteryScore = max(masteryScore, other.masteryScore)
        
        // 更新掌握程度
        updateMasteryLevel()
        
        // 更新时间戳
        updatedAt = Date()
        
        print("✅ [GlobalWord] 合并单词 '\(originalWord)' 的测试结果")
    }
    
    // MARK: - 导入导出支持
    
    /// 从导出数据创建GlobalWord
    static func fromExportData(
        word: String,
        masteryLevel: String,
        testCount: Int = 0,
        correctCount: Int = 0,
        masteryScore: Double = 0,
        lastTestedDate: Date? = nil
    ) -> GlobalWord {
        let globalWord = GlobalWord(
            word: word,
            masteryLevel: MasteryLevel(rawValue: masteryLevel) ?? .unfamiliar
        )
        
        globalWord.testCount = testCount
        globalWord.correctCount = correctCount
        globalWord.masteryScore = masteryScore
        
        if let testDate = lastTestedDate {
            globalWord.firstTestedDate = testDate
            globalWord.lastTestedDate = testDate
        }
        
        return globalWord
    }
    
    /// 转换为导出数据
    func toExportData() -> [String: Any] {
        return [
            "word": originalWord,
            "masteryLevel": masteryLevel,
            "testCount": testCount,
            "correctCount": correctCount,
            "masteryScore": masteryScore,
            "accuracyRate": accuracyRate,
            "firstTestedDate": firstTestedDate.ISO8601Format(),
            "lastTestedDate": lastTestedDate.ISO8601Format(),
            "averageResponseTime": averageResponseTime,
            "difficultyLevel": difficultyLevel
        ]
    }
}

// MARK: - 扩展方法

extension GlobalWord {
    /// 重置测试数据
    func resetTestData() {
        testCount = 0
        correctCount = 0
        masteryScore = 0
        masteryLevelEnum = .unfamiliar
        firstTestedDate = Date()
        lastTestedDate = Date()
        averageResponseTime = 0
        lastResponseTime = 0
        updatedAt = Date()
    }
    
    /// 检查是否需要重新测试（基于时间衰减）
    func needsRetest(threshold: Double = 60.0) -> Bool {
        return currentMasteryScore < threshold
    }
    
    /// 获取学习建议
    func getLearningAdvice() -> String {
        switch masteryLevelEnum {
        case .mastered:
            if needsRetest() {
                return "建议复习巩固"
            } else {
                return "掌握良好，继续保持"
            }
        case .familiar:
            return "需要加强练习"
        case .unfamiliar:
            return "需要重点学习"
        }
    }
}

// MARK: - 查询扩展

extension GlobalWord {
    /// 按掌握程度查询的谓词
    static func predicateForMasteryLevel(_ level: MasteryLevel) -> Predicate<GlobalWord> {
        return #Predicate<GlobalWord> { word in
            word.masteryLevel == level.rawValue
        }
    }
    
    /// 按单词查询的谓词
    static func predicateForWord(_ wordText: String) -> Predicate<GlobalWord> {
        let lowercaseWord = wordText.lowercased()
        return #Predicate<GlobalWord> { word in
            word.word == lowercaseWord
        }
    }
    
    /// 按测试时间范围查询的谓词
    static func predicateForDateRange(from startDate: Date, to endDate: Date) -> Predicate<GlobalWord> {
        return #Predicate<GlobalWord> { word in
            word.lastTestedDate >= startDate && word.lastTestedDate <= endDate
        }
    }
    
    /// 需要重测的单词谓词
    static func predicateForRetestNeeded(threshold: Double = 60.0) -> Predicate<GlobalWord> {
        let daysSinceThreshold = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7天前
        return #Predicate<GlobalWord> { word in
            word.lastTestedDate < daysSinceThreshold || word.masteryScore < threshold
        }
    }
}