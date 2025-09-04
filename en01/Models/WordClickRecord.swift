//
//  WordClickRecord.swift
//  en01
//
//  Created by SOLO Coding on 2025/1/18.
//

import Foundation
import SwiftData
import SwiftUI

// 单词点击记录模型
@Model
final class WordClickRecord: @unchecked Sendable {
    var id: UUID
    var word: String // 点击的单词
    var clickDate: Date // 点击时间
    var articleID: String? // 文章ID（如果在文章中点击）
    var articleTitle: String? // 文章标题
    var context: String // 单词出现的上下文
    var sentence: String // 完整句子
    var clickPosition: Int // 在句子中的位置
    var sessionID: String // 学习会话ID
    var responseTime: TimeInterval // 响应时间（从显示到点击的时间）
    var isFromTest: Bool // 是否来自词汇量测试
    var testID: String? // 测试ID（如果来自测试）
    var userAction: WordClickAction // 用户操作类型
    var masteryLevelBefore: MasteryLevel? // 点击前的掌握程度
    var masteryLevelAfter: MasteryLevel? // 点击后的掌握程度
    
    // 设备和环境信息
    var deviceType: String // 设备类型
    var appVersion: String // 应用版本
    
    init(word: String, context: String, sentence: String, clickPosition: Int = 0, sessionID: String, userAction: WordClickAction = .lookup, articleID: String? = nil, articleTitle: String? = nil) {
        self.id = UUID()
        self.word = word.lowercased()
        self.clickDate = Date()
        self.articleID = articleID
        self.articleTitle = articleTitle
        self.context = context
        self.sentence = sentence
        self.clickPosition = clickPosition
        self.sessionID = sessionID
        self.responseTime = 0
        self.isFromTest = false
        self.testID = nil
        self.userAction = userAction
        self.masteryLevelBefore = nil
        self.masteryLevelAfter = nil
        self.deviceType = "iOS"
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// 用户点击操作类型
enum WordClickAction: String, CaseIterable, Codable {
    case lookup = "查词" // 查看释义
    case addToReview = "加入复习" // 添加到复习列表
    case markAsMastered = "标记掌握" // 标记为已掌握
    case markAsFamiliar = "标记熟悉" // 标记为熟悉
    case markAsUnfamiliar = "标记生疏" // 标记为生疏
    case addNote = "添加笔记" // 添加笔记
    case playAudio = "播放音频" // 播放发音
    case viewExamples = "查看例句" // 查看例句
    case translate = "翻译" // 翻译
    case share = "分享" // 分享单词
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .lookup: return "book.fill"
        case .addToReview: return "plus.circle.fill"
        case .markAsMastered: return "checkmark.circle.fill"
        case .markAsFamiliar: return "circle.fill"
        case .markAsUnfamiliar: return "xmark.circle.fill"
        case .addNote: return "note.text"
        case .playAudio: return "speaker.wave.2.fill"
        case .viewExamples: return "list.bullet"
        case .translate: return "globe"
        case .share: return "square.and.arrow.up"
        }
    }
    
    var color: Color {
        switch self {
        case .lookup: return .blue
        case .addToReview: return .orange
        case .markAsMastered: return .green
        case .markAsFamiliar: return .yellow
        case .markAsUnfamiliar: return .red
        case .addNote: return .purple
        case .playAudio: return .cyan
        case .viewExamples: return .indigo
        case .translate: return .mint
        case .share: return .gray
        }
    }
}

// 学习会话类型
enum StudySessionType: String, CaseIterable, Codable {
    case reading = "阅读"
    case vocabularyTest = "词汇测试"
    case review = "复习"
    case practice = "练习"
    case browse = "浏览"
    
    var displayName: String {
        return self.rawValue
    }
}

extension WordClickRecord {
    // 设置测试相关信息
    func setTestInfo(testID: String, isFromTest: Bool = true) {
        self.testID = testID
        self.isFromTest = isFromTest
    }
    
    // 设置掌握程度变化
    func setMasteryLevelChange(from before: MasteryLevel?, to after: MasteryLevel?) {
        self.masteryLevelBefore = before
        self.masteryLevelAfter = after
    }
    
    // 设置响应时间
    func setResponseTime(_ time: TimeInterval) {
        self.responseTime = time
    }
    
    // 是否是有效的学习行为
    var isLearningAction: Bool {
        switch userAction {
        case .lookup, .addToReview, .markAsMastered, .markAsFamiliar, .markAsUnfamiliar, .addNote:
            return true
        default:
            return false
        }
    }
    
    // 是否改变了掌握程度
    var didChangeMasteryLevel: Bool {
        return masteryLevelBefore != masteryLevelAfter
    }
    
    // 获取掌握程度提升
    var masteryImprovement: Int {
        guard let before = masteryLevelBefore?.level,
              let after = masteryLevelAfter?.level else {
            return 0
        }
        return after - before
    }
    
    // 格式化点击时间
    var formattedClickDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: clickDate)
    }
    
    // 格式化响应时间
    var formattedResponseTime: String {
        if responseTime < 1 {
            return String(format: "%.0fms", responseTime * 1000)
        } else {
            return String(format: "%.1fs", responseTime)
        }
    }
    
    // 获取上下文摘要（限制长度）
    var contextSummary: String {
        if context.count > 50 {
            return String(context.prefix(47)) + "..."
        }
        return context
    }
    
    // 获取学习价值评分（0-10）
    var learningValue: Int {
        var score = 0
        
        // 基础分数
        if isLearningAction {
            score += 3
        }
        
        // 掌握程度提升加分
        score += max(0, masteryImprovement * 2)
        
        // 响应时间合理性加分
        if responseTime > 0.5 && responseTime < 10 {
            score += 2
        }
        
        // 来自测试的额外加分
        if isFromTest {
            score += 1
        }
        
        return min(10, score)
    }
    
    // 自定义格式化时间戳
    func formatTimestamp(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: clickDate)
    }
}

// 点击统计模型
struct ClickStatistics {
    let totalClicks: Int
    let uniqueWords: Int
    let averageResponseTime: TimeInterval
    let mostClickedWords: [String]
    let clicksByAction: [WordClickAction: Int]
    let clicksByHour: [Int: Int] // 按小时统计
    let learningEfficiency: Double // 学习效率（0-1）
    
    var clicksPerWord: Double {
        guard uniqueWords > 0 else { return 0 }
        return Double(totalClicks) / Double(uniqueWords)
    }
    
    var formattedAverageResponseTime: String {
        return String(format: "%.1fs", averageResponseTime)
    }
}