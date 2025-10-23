//
//  TestResultHistory.swift
//  en01
//
//  Created by AI Assistant on 2024/12/17.
//

import Foundation
import SwiftData

/// 测试结果历史记录模型
/// 用于存储每次词汇测试的详细历史记录，支持累加式更新机制
@Model
class TestResultHistory {
    
    // MARK: - Properties
    
    /// 唯一标识符
    var id: UUID
    
    /// 测试的单词
    var word: String
    
    /// 词典名称
    var dictionaryName: String
    
    /// 词典文件名
    var dictionaryFileName: String
    
    /// 测试时的掌握程度（原始值）
    var masteryLevel: String
    
    /// 测试时间
    var testedAt: Date
    
    /// 测试会话ID
    var testSessionId: String
    
    /// 难度等级
    var difficulty: String
    
    /// 回答时间（秒）
    var responseTime: Double
    
    /// 是否正确回答
    var isCorrect: Bool
    
    /// 测试类型（词汇测试、复习等）
    var testType: String
    
    /// 测试上下文信息（可选）
    var testContext: String?
    
    /// 用户设备信息（可选）
    var deviceInfo: String?
    
    // MARK: - Initialization
    
    init(
        word: String,
        dictionaryName: String,
        dictionaryFileName: String,
        masteryLevel: String,
        testSessionId: String,
        difficulty: String = "normal",
        responseTime: Double = 0.0,
        isCorrect: Bool = true,
        testType: String = "vocabulary_test",
        testContext: String? = nil,
        deviceInfo: String? = nil
    ) {
        self.id = UUID()
        self.word = word
        self.dictionaryName = dictionaryName
        self.dictionaryFileName = dictionaryFileName
        self.masteryLevel = masteryLevel
        self.testedAt = Date()
        self.testSessionId = testSessionId
        self.difficulty = difficulty
        self.responseTime = responseTime
        self.isCorrect = isCorrect
        self.testType = testType
        self.testContext = testContext
        self.deviceInfo = deviceInfo
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
    
    /// 测试分数（基于掌握程度）
    var testScore: Int {
        switch masteryLevelEnum {
        case .mastered:
            return 2
        case .familiar:
            return 1
        case .unfamiliar:
            return 0
        }
    }
    
    /// 格式化的测试时间
    var formattedTestedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: testedAt)
    }
    
    /// 测试效率评分（基于回答时间和正确性）
    var efficiencyScore: Double {
        guard isCorrect else { return 0.0 }
        
        // 理想回答时间：掌握 < 2秒，熟悉 < 4秒，不熟悉 < 6秒
        let idealTime: Double
        switch masteryLevelEnum {
        case .mastered:
            idealTime = 2.0
        case .familiar:
            idealTime = 4.0
        case .unfamiliar:
            idealTime = 6.0
        }
        
        if responseTime <= idealTime {
            return 1.0
        } else {
            return max(0.1, idealTime / responseTime)
        }
    }
    
    // MARK: - Methods
    
    /// 更新测试上下文信息
    func updateTestContext(_ context: String) {
        self.testContext = context
    }
    
    /// 更新设备信息
    func updateDeviceInfo(_ info: String) {
        self.deviceInfo = info
    }
    
    /// 获取测试详情描述
    func getTestDescription() -> String {
        let masteryText = masteryLevelEnum.masteryDisplayName
        let timeText = String(format: "%.1f秒", responseTime)
        let resultText = isCorrect ? "正确" : "错误"
        
        return "\(word) - \(masteryText) (\(timeText), \(resultText))"
    }
    
    /// 判断是否为同一测试会话
    func isSameSession(as other: TestResultHistory) -> Bool {
        return self.testSessionId == other.testSessionId
    }
    
    /// 判断是否为同一词典
    func isSameDictionary(as other: TestResultHistory) -> Bool {
        return self.dictionaryFileName == other.dictionaryFileName
    }
    
    /// 获取测试统计信息
    static func getTestStatistics(from histories: [TestResultHistory]) -> TestSessionStats {
        let totalTests = histories.count
        let _ = histories.filter { $0.isCorrect }.count
        let averageResponseTime = histories.isEmpty ? 0.0 : histories.map { $0.responseTime }.reduce(0, +) / Double(totalTests)
        
        let masteredCount = histories.filter { $0.isMastered }.count
        let familiarCount = histories.filter { $0.isFamiliar }.count
        let unfamiliarCount = histories.filter { $0.isUnfamiliar }.count
        
        return TestSessionStats(
            sessionId: UUID(),
            dictionaryName: histories.first?.dictionaryName ?? "",
            totalTested: totalTests,
            masteredCount: masteredCount,
            familiarCount: familiarCount,
            unfamiliarCount: unfamiliarCount,
            averageResponseTime: averageResponseTime,
            testDate: Date()
        )
    }
}

// MARK: - Extensions

extension TestResultHistory {
    
    /// 按测试时间排序（最新的在前）
    static func sortByDate(_ histories: [TestResultHistory]) -> [TestResultHistory] {
        return histories.sorted { $0.testedAt > $1.testedAt }
    }
    
    /// 按单词字母顺序排序
    static func sortByWord(_ histories: [TestResultHistory]) -> [TestResultHistory] {
        return histories.sorted { $0.word.lowercased() < $1.word.lowercased() }
    }
    
    /// 按掌握程度排序（掌握 > 熟悉 > 不熟悉）
    static func sortByMastery(_ histories: [TestResultHistory]) -> [TestResultHistory] {
        return histories.sorted { $0.masteryLevelEnum.level > $1.masteryLevelEnum.level }
    }
    
    /// 按测试效率排序（效率高的在前）
    static func sortByEfficiency(_ histories: [TestResultHistory]) -> [TestResultHistory] {
        return histories.sorted { $0.efficiencyScore > $1.efficiencyScore }
    }
}

// MARK: - Query Extensions

extension TestResultHistory {
    
    /// 查询指定单词的测试历史
    static func getHistoryForWord(_ word: String, in histories: [TestResultHistory]) -> [TestResultHistory] {
        return histories.filter { $0.word.lowercased() == word.lowercased() }
    }
    
    /// 查询指定词典的测试历史
    static func getHistoryForDictionary(_ dictionaryFileName: String, in histories: [TestResultHistory]) -> [TestResultHistory] {
        return histories.filter { $0.dictionaryFileName == dictionaryFileName }
    }
    
    /// 查询指定测试会话的历史
    static func getHistoryForSession(_ sessionId: String, in histories: [TestResultHistory]) -> [TestResultHistory] {
        return histories.filter { $0.testSessionId == sessionId }
    }
    
    /// 查询指定时间范围的测试历史
    static func getHistoryInDateRange(from startDate: Date, to endDate: Date, in histories: [TestResultHistory]) -> [TestResultHistory] {
        return histories.filter { $0.testedAt >= startDate && $0.testedAt <= endDate }
    }
    
    /// 查询指定掌握程度的测试历史
    static func getHistoryByMastery(_ mastery: MasteryLevel, in histories: [TestResultHistory]) -> [TestResultHistory] {
        return histories.filter { $0.masteryLevelEnum == mastery }
    }
}