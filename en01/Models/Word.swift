//
//  Word.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData
import SwiftUI

// 词典中的单词模型
@Model
final class DictionaryWord: @unchecked Sendable {
    var word: String
    var phonetic: String?
    var definitions: [WordDefinition] // 多个释义
    var frequency: Int // 在考研真题中的出现频率
    var difficulty: WordDifficulty
    private var tagsString: String // 内部存储，用分号分隔
    private var categoriesString: String // 内部存储，用分号分隔
    
    // 计算属性，用于访问标签数组
    var tags: [String] {
        get {
            return tagsString.isEmpty ? [] : tagsString.components(separatedBy: ";")
        }
        set {
            tagsString = newValue.joined(separator: ";")
        }
    }
    
    // 计算属性，用于访问分组数组
    var categories: [String]? {
        get {
            return categoriesString.isEmpty ? nil : categoriesString.components(separatedBy: ";")
        }
        set {
            categoriesString = newValue?.joined(separator: ";") ?? ""
        }
    }
    
    init(word: String, phonetic: String? = nil, definitions: [WordDefinition], frequency: Int = 0, difficulty: WordDifficulty = .medium, tags: [String] = [], categories: [String]? = nil) {
        self.word = word.lowercased()
        self.phonetic = phonetic
        self.definitions = definitions
        self.frequency = frequency
        self.difficulty = difficulty
        self.tagsString = tags.joined(separator: ";")
        self.categoriesString = categories?.joined(separator: ";") ?? ""
    }
}

// 单词释义
@Model
final class WordDefinition: @unchecked Sendable {
    var id = UUID()
    var partOfSpeech: PartOfSpeech // 词性
    var meaning: String // 中文释义
    var englishMeaning: String? // 英文释义（可选）
    private var examplesString: String // 内部存储，用分号分隔
    private var contextKeywordsString: String // 内部存储，用分号分隔
    
    // 计算属性，用于访问例句数组
    var examples: [String] {
        get {
            return examplesString.isEmpty ? [] : examplesString.components(separatedBy: ";")
        }
        set {
            examplesString = newValue.joined(separator: ";")
        }
    }
    
    // 计算属性，用于访问上下文关键词数组
    var contextKeywords: [String] {
        get {
            return contextKeywordsString.isEmpty ? [] : contextKeywordsString.components(separatedBy: ";")
        }
        set {
            contextKeywordsString = newValue.joined(separator: ";")
        }
    }
    
    init(partOfSpeech: PartOfSpeech, meaning: String, englishMeaning: String? = nil, examples: [String] = [], contextKeywords: [String] = []) {
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
        self.englishMeaning = englishMeaning
        self.examplesString = examples.joined(separator: ";")
        self.contextKeywordsString = contextKeywords.joined(separator: ";")
    }
}

// 词性枚举
enum PartOfSpeech: String, CaseIterable, Codable {
    case noun = "n."
    case verb = "v."
    case adjective = "adj."
    case adverb = "adv."
    case preposition = "prep."
    case conjunction = "conj."
    case pronoun = "pron."
    case interjection = "int."
    case article = "art."
    case auxiliary = "aux."
    case modal = "modal"
    case phrasal = "phr."
    
    var fullName: String {
        switch self {
        case .noun: return "名词"
        case .verb: return "动词"
        case .adjective: return "形容词"
        case .adverb: return "副词"
        case .preposition: return "介词"
        case .conjunction: return "连词"
        case .pronoun: return "代词"
        case .interjection: return "感叹词"
        case .article: return "冠词"
        case .auxiliary: return "助动词"
        case .modal: return "情态动词"
        case .phrasal: return "短语"
        }
    }
    
    var displayName: String {
        return fullName
    }
    
    var color: String {
        switch self {
        case .noun: return "blue"
        case .verb: return "green"
        case .adjective: return "orange"
        case .adverb: return "purple"
        case .preposition: return "gray"
        case .conjunction: return "brown"
        case .pronoun: return "pink"
        case .interjection: return "red"
        case .article: return "cyan"
        case .auxiliary: return "indigo"
        case .modal: return "mint"
        case .phrasal: return "yellow"
        }
    }
    
    /// 从字符串创建词性枚举
    static func fromString(_ string: String?) -> PartOfSpeech? {
        guard let string = string?.lowercased() else { return nil }
        
        switch string {
        case "n", "noun", "n.":
            return .noun
        case "v", "verb", "v.", "vt", "vi":
            return .verb
        case "adj", "adjective", "adj.":
            return .adjective
        case "adv", "adverb", "adv.":
            return .adverb
        case "prep", "preposition", "prep.":
            return .preposition
        case "conj", "conjunction", "conj.":
            return .conjunction
        case "pron", "pronoun", "pron.":
            return .pronoun
        case "int", "interjection", "int.":
            return .interjection
        case "art", "article", "art.":
            return .article
        case "aux", "auxiliary", "aux.":
            return .auxiliary
        case "modal":
            return .modal
        case "phr", "phrasal", "phr.":
            return .phrasal
        default:
            return nil
        }
    }
}

// 单词难度
enum WordDifficulty: String, CaseIterable, Codable {
    case basic = "基础"
    case medium = "中等"
    case advanced = "高级"
    case expert = "专家"
    
    var level: Int {
        switch self {
        case .basic: return 1
        case .medium: return 2
        case .advanced: return 3
        case .expert: return 4
        }
    }
    
    var color: String {
        switch self {
        case .basic: return "green"
        case .medium: return "blue"
        case .advanced: return "orange"
        case .expert: return "red"
        }
    }
}

// 用户查词记录
@Model
final class UserWord: @unchecked Sendable {
    
    var id: UUID
    var word: String
    var selectedDefinition: WordDefinition? // 用户在特定上下文中选择的释义
    var context: String // 单词出现的上下文
    var sentence: String // 完整句子
    var masteryLevel: MasteryLevel
    var lookupCount: Int // 查询次数
    var firstLookupDate: Date
    var lastLookupDate: Date
    var lastReviewDate: Date?
    var nextReviewDate: Date?
    var isMarkedForReview: Bool
    var notes: String? // 用户笔记
    
    // 存储文章ID而不是直接引用，避免复杂的关系管理
    var articleID: String?
    
    // 新增：测试相关字段
    var testSource: String? // 测试来源（词典名称）
    var isFromTest: Bool // 是否来自词汇量测试
    var testID: String? // 关联的测试ID
    var clickCount: Int // 点击次数（包括查词、复习等所有交互）
    var lastClickDate: Date? // 最后点击时间
    
    // 新增：学习行为追踪
    var studySessionCount: Int // 学习会话次数
    var totalStudyTime: TimeInterval // 总学习时间（秒）
    var averageResponseTime: TimeInterval // 平均响应时间
    var correctAnswers: Int // 正确回答次数（在测试或复习中）
    var incorrectAnswers: Int // 错误回答次数
    
    // 新增：智能排序相关
    var learningPriority: Double // 学习优先级（0-100）
    var difficultyRating: Double // 用户感知难度（0-10）
    var importanceRating: Double // 重要性评级（0-10）
    var lastPriorityUpdate: Date? // 优先级最后更新时间
    
    // 新增：记忆曲线相关
    var memoryStrength: Double // 记忆强度（0-1）
    var forgettingCurve: Double // 遗忘曲线参数
    var optimalReviewInterval: TimeInterval // 最佳复习间隔
    var reviewHistory: String // 复习历史记录（JSON格式）
    
    init(word: String, context: String, sentence: String, selectedDefinition: WordDefinition? = nil, testSource: String? = nil, isFromTest: Bool = false) {
        self.id = UUID()
        self.word = word.lowercased()
        self.selectedDefinition = selectedDefinition
        self.context = context
        self.sentence = sentence
        self.masteryLevel = .unfamiliar
        self.lookupCount = 1
        self.firstLookupDate = Date()
        self.lastLookupDate = Date()
        self.lastReviewDate = nil
        self.nextReviewDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        self.isMarkedForReview = true
        self.notes = nil
        
        // 初始化新字段
        self.testSource = testSource
        self.isFromTest = isFromTest
        self.testID = nil
        self.clickCount = 1
        self.lastClickDate = Date()
        
        self.studySessionCount = 1
        self.totalStudyTime = 0
        self.averageResponseTime = 0
        self.correctAnswers = 0
        self.incorrectAnswers = 0
        
        self.learningPriority = isFromTest ? 80.0 : 50.0 // 测试来源的单词优先级更高
        self.difficultyRating = 5.0 // 默认中等难度
        self.importanceRating = 5.0 // 默认中等重要性
        self.lastPriorityUpdate = Date()
        
        self.memoryStrength = 0.1 // 初始记忆强度很低
        self.forgettingCurve = 0.5 // 默认遗忘曲线参数
        self.optimalReviewInterval = 24 * 60 * 60 // 默认24小时
        self.reviewHistory = "[]"
    }


}

// 掌握程度
enum MasteryLevel: String, CaseIterable, Codable, Comparable {
    case unfamiliar = "生疏"
    case familiar = "熟悉"
    case mastered = "掌握"
    
    var level: Int {
        switch self {
        case .unfamiliar: return 1
        case .familiar: return 2
        case .mastered: return 3
        }
    }
    
    // MARK: - Comparable 协议实现
    static func < (lhs: MasteryLevel, rhs: MasteryLevel) -> Bool {
        return lhs.level < rhs.level
    }
    
    /// 用于累加式更新的分数值
    var scoreValue: Int {
        switch self {
        case .unfamiliar: return 0
        case .familiar: return 1
        case .mastered: return 2
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .unfamiliar: return .red
        case .familiar: return .orange
        case .mastered: return .green
        }
    }
    
    var nextReviewInterval: TimeInterval {
        switch self {
        case .unfamiliar: return 24 * 60 * 60 // 1天
        case .familiar: return 3 * 24 * 60 * 60 // 3天
        case .mastered: return 7 * 24 * 60 * 60 // 7天
        }
    }
}

extension UserWord {
    // 更新掌握程度
    func updateMasteryLevel(_ level: MasteryLevel) {
        // 直接修改存储属性
        masteryLevel = level
        lastReviewDate = Date()

        updateReviewDate(basedOn: level)

        // 如果已掌握，可以减少复习频率
        if level == .mastered {
            isMarkedForReview = false
        }
    }

    func updateReviewDate(basedOn level: MasteryLevel) {
        // 根据新的掌握程度计算下次复习时间
        self.nextReviewDate = Calendar.current.date(byAdding: .second, value: Int(level.nextReviewInterval), to: Date())
    }
    
    // 增加查询次数
    func incrementLookupCount() {
        self.lookupCount += 1
        self.lastLookupDate = Date()
        self.clickCount += 1
        self.lastClickDate = Date()
    }
    
    // 新增：记录点击行为
    func recordClick(responseTime: TimeInterval = 0) {
        self.clickCount += 1
        self.lastClickDate = Date()
        
        if responseTime > 0 {
            // 更新平均响应时间
            let totalResponseTime = averageResponseTime * Double(clickCount - 1) + responseTime
            self.averageResponseTime = totalResponseTime / Double(clickCount)
        }
    }
    
    // 新增：记录学习会话
    func recordStudySession(duration: TimeInterval) {
        self.studySessionCount += 1
        self.totalStudyTime += duration
    }
    
    // 新增：记录测试结果
    func recordTestResult(isCorrect: Bool, responseTime: TimeInterval) {
        if isCorrect {
            correctAnswers += 1
            // 正确回答提升记忆强度
            memoryStrength = min(1.0, memoryStrength + 0.1)
        } else {
            incorrectAnswers += 1
            // 错误回答降低记忆强度
            memoryStrength = max(0.0, memoryStrength - 0.05)
        }
        
        // 同步更新masteryLevel属性，基于答题比例计算
        let newMasteryLevel = calculateMasteryLevelFromAnswers()
        if newMasteryLevel != masteryLevel {
            updateMasteryLevel(newMasteryLevel)
        }
        
        recordClick(responseTime: responseTime)
        updateOptimalReviewInterval()
    }
    
    // 新增：基于答题比例计算掌握程度
    private func calculateMasteryLevelFromAnswers() -> MasteryLevel {
        if correctAnswers >= 3 && incorrectAnswers == 0 {
            return .mastered
        } else {
            let ratio = correctAnswers > 0 ? Double(correctAnswers) / Double(correctAnswers + incorrectAnswers) : 0
            return ratio >= 0.6 ? .familiar : .unfamiliar
        }
    }
    
    // 新增：更新学习优先级
    func updateLearningPriority() {
        var priority: Double = 50.0 // 基础优先级
        
        // 基于掌握程度调整
        switch masteryLevel {
        case .unfamiliar:
            priority += 30.0
        case .familiar:
            priority += 10.0
        case .mastered:
            priority -= 20.0
        }
        
        // 基于错误率调整
        let totalAnswers = correctAnswers + incorrectAnswers
        if totalAnswers > 0 {
            let errorRate = Double(incorrectAnswers) / Double(totalAnswers)
            priority += errorRate * 20.0
        }
        
        // 基于记忆强度调整
        priority += (1.0 - memoryStrength) * 15.0
        
        // 基于用户评级调整
        priority += (difficultyRating - 5.0) * 2.0
        priority += (importanceRating - 5.0) * 3.0
        
        // 基于时间衰减调整
        if let lastClick = lastClickDate {
            let daysSinceLastClick = Date().timeIntervalSince(lastClick) / (24 * 60 * 60)
            priority += min(10.0, daysSinceLastClick * 2.0)
        }
        
        self.learningPriority = max(0.0, min(100.0, priority))
        self.lastPriorityUpdate = Date()
    }
    
    // 新增：更新最佳复习间隔
    private func updateOptimalReviewInterval() {
        // 基于记忆强度和遗忘曲线计算最佳复习间隔
        let baseInterval: TimeInterval = 24 * 60 * 60 // 24小时
        let strengthMultiplier = 1.0 + memoryStrength * 6.0 // 1-7倍
        let masteryMultiplier: Double
        
        switch masteryLevel {
        case .unfamiliar: masteryMultiplier = 1.0
        case .familiar: masteryMultiplier = 2.0
        case .mastered: masteryMultiplier = 4.0
        }
        
        self.optimalReviewInterval = baseInterval * strengthMultiplier * masteryMultiplier
    }
    
    // 新增：添加复习记录
    func addReviewRecord(result: ReviewResult) {
        var history = getReviewHistory()
        history.append(result)
        
        // 只保留最近20条记录
        if history.count > 20 {
            history = Array(history.suffix(20))
        }
        
        do {
            let data = try JSONEncoder().encode(history)
            self.reviewHistory = String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            print("Failed to encode review history: \(error)")
        }
    }
    
    // 新增：获取复习历史
    func getReviewHistory() -> [ReviewResult] {
        guard let data = reviewHistory.data(using: .utf8) else { return [] }
        
        do {
            return try JSONDecoder().decode([ReviewResult].self, from: data)
        } catch {
            return []
        }
    }
    
    // 是否需要复习
    var needsReview: Bool {
        guard let nextReview = nextReviewDate else { return false }
        return Date() >= nextReview && isMarkedForReview
    }
    
    // 获取学习天数
    var studyDays: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: firstLookupDate, to: Date()).day ?? 0
        return max(0, days)
    }
    
    // 兼容性属性
    var queryCount: Int {
        return lookupCount
    }
    
    var firstQueryDate: Date {
        return firstLookupDate
    }
    
    var lastQueryDate: Date {
        return lastLookupDate
    }
    
    // 新增：计算学习效率
    var learningEfficiency: Double {
        let totalAnswers = correctAnswers + incorrectAnswers
        guard totalAnswers > 0 else { return 0 }
        return Double(correctAnswers) / Double(totalAnswers) * 100
    }
    
    // 新增：计算平均学习时间
    var averageStudyTime: TimeInterval {
        guard studySessionCount > 0 else { return 0 }
        return totalStudyTime / Double(studySessionCount)
    }
    
    // 新增：是否需要紧急复习
    var needsUrgentReview: Bool {
        guard let nextReview = nextReviewDate else { return false }
        let urgentThreshold = Date().addingTimeInterval(-24 * 60 * 60) // 超期1天
        return nextReview < urgentThreshold
    }
    
    // 新增：获取记忆状态描述
    var memoryStatusDescription: String {
        switch memoryStrength {
        case 0.8...1.0: return "记忆牢固"
        case 0.6..<0.8: return "记忆良好"
        case 0.4..<0.6: return "记忆一般"
        case 0.2..<0.4: return "记忆模糊"
        default: return "几乎遗忘"
        }
    }
    
    // 新增：获取学习建议
    var learningRecommendation: String {
        if needsUrgentReview {
            return "建议立即复习"
        } else if memoryStrength < 0.3 {
            return "建议加强练习"
        } else if learningEfficiency < 60 {
            return "建议重点学习"
        } else if masteryLevel == .mastered {
            return "可以减少复习频率"
        } else {
            return "继续保持学习"
        }
    }

}

// 复习结果记录
struct ReviewResult: Codable {
    let date: Date
    let isCorrect: Bool
    let responseTime: TimeInterval
    let masteryLevelBefore: MasteryLevel
    let masteryLevelAfter: MasteryLevel
    let reviewType: ReviewType

    enum ReviewType: String, Codable {
        case scheduled = "定时复习"
        case manual = "手动复习"
        case test = "测试复习"
        case practice = "练习复习"
    }
}

// 词汇统计模型
struct VocabularyStats {
    let totalWords: Int
    let unfamiliarWords: Int
    let familiarWords: Int
    let masteredWords: Int
    let todayLookups: Int
    let weeklyLookups: Int
    let averageLookupPerDay: Double
    let mostLookedUpWords: [UserWord]
    
    var masteryPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWords) * 100
    }
    
    var familiarityPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(familiarWords + masteredWords) / Double(totalWords) * 100
    }
}