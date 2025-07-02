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
final class DictionaryWord {
    var word: String
    var phonetic: String?
    var definitions: [WordDefinition] // 多个释义
    var frequency: Int // 在考研真题中的出现频率
    var difficulty: WordDifficulty
    var tags: [String] // 标签，如"高频词", "核心词汇"等
    
    init(word: String, phonetic: String? = nil, definitions: [WordDefinition], frequency: Int = 0, difficulty: WordDifficulty = .medium, tags: [String] = []) {
        self.word = word.lowercased()
        self.phonetic = phonetic
        self.definitions = definitions
        self.frequency = frequency
        self.difficulty = difficulty
        self.tags = tags
    }
}

// 单词释义
struct WordDefinition: Codable, Identifiable {
    var id = UUID()
    let partOfSpeech: PartOfSpeech // 词性
    let meaning: String // 中文释义
    let englishMeaning: String? // 英文释义（可选）
    let examples: [String] // 例句
    let contextKeywords: [String] // 上下文关键词，用于智能匹配
    
    init(partOfSpeech: PartOfSpeech, meaning: String, englishMeaning: String? = nil, examples: [String] = [], contextKeywords: [String] = []) {
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
        self.englishMeaning = englishMeaning
        self.examples = examples
        self.contextKeywords = contextKeywords
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
final class UserWordRecord {
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
    
    // 关联的文章
    var article: Article?
    
    init(word: String, context: String, sentence: String, selectedDefinition: WordDefinition? = nil) {
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
    }
}

// 掌握程度
enum MasteryLevel: String, CaseIterable, Codable {
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

extension UserWordRecord {
    // 更新掌握程度
    func updateMasteryLevel(_ level: MasteryLevel) {
        self.masteryLevel = level
        self.lastReviewDate = Date()
        
        // 根据新的掌握程度计算下次复习时间
        self.nextReviewDate = Calendar.current.date(byAdding: .second, value: Int(level.nextReviewInterval), to: Date())
        
        // 如果已掌握，可以减少复习频率
        if level == .mastered {
            self.isMarkedForReview = false
        }
    }
    
    // 增加查询次数
    func incrementLookupCount() {
        self.lookupCount += 1
        self.lastLookupDate = Date()
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
    let mostLookedUpWords: [UserWordRecord]
    
    var masteryPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWords) * 100
    }
    
    var familiarityPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(familiarWords + masteredWords) / Double(totalWords) * 100
    }
}