//
//  CommonTypes.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import CoreGraphics

// MARK: - Structured Text Models

/// 结构化文本数据模型，用于保存PDF提取的格式化文本
struct StructuredText: Codable {
    let pages: [StructuredPage]
    let metadata: TextMetadata
}

/// 页面结构
struct StructuredPage: Codable {
    let pageNumber: Int
    let elements: [TextElement]
    let bounds: CGRect
}

/// 文本元素
struct TextElement: Codable, Identifiable {
    let id = UUID()
    let content: String
    let type: ElementType
    let bounds: CGRect
    let fontInfo: FontInfo
    let level: Int? // 用于标题层级
    
    enum CodingKeys: String, CodingKey {
        case content, type, bounds, fontInfo, level
    }
}

/// 元素类型
enum ElementType: String, Codable, CaseIterable {
    case title = "title"
    case subtitle = "subtitle"
    case paragraph = "paragraph"
    case list = "list"
    case quote = "quote"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .title: return "标题"
        case .subtitle: return "副标题"
        case .paragraph: return "段落"
        case .list: return "列表"
        case .quote: return "引用"
        case .other: return "其他"
        }
    }
}

/// 字体信息
struct FontInfo: Codable {
    let size: CGFloat
    let weight: FontWeight
    let isItalic: Bool
    let isBold: Bool
}

/// 字体粗细
enum FontWeight: String, Codable {
    case ultraLight = "ultraLight"
    case thin = "thin"
    case light = "light"
    case regular = "regular"
    case medium = "medium"
    case semibold = "semibold"
    case bold = "bold"
    case heavy = "heavy"
    case black = "black"
}

/// 文本元数据
struct TextMetadata: Codable {
    let totalPages: Int
    let extractionDate: Date
    let sourceURL: URL?
    let language: String?
    let wordCount: Int
}

// MARK: - Display Mode Enum

/// 阅读显示模式
enum DisplayMode: String, CaseIterable {
    case pdf = "pdf"           // 原生PDF显示
    case text = "text"         // 格式化文本显示
    case hybrid = "hybrid"     // 混合模式
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF模式"
        case .text: return "文本模式"
        case .hybrid: return "混合模式"
        }
    }
    
    var iconName: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .text: return "doc.text"
        case .hybrid: return "doc.text.below.ecg"
        }
    }
}

// MARK: - Activity Type Enum

/// 用户活动类型，用于经验值计算
enum ActivityType: String, CaseIterable {
    case readArticle = "read_article"
    case lookupWord = "lookup_word"
    case completeReview = "complete_review"
    case consecutiveDay = "consecutive_day"
    case achievementUnlocked = "achievement_unlocked"
    case levelUp = "level_up"
    case bookmarkArticle = "bookmark_article"
    
    var displayName: String {
        switch self {
        case .readArticle:
            return "阅读文章"
        case .lookupWord:
            return "查词"
        case .completeReview:
            return "完成复习"
        case .consecutiveDay:
            return "连续学习"
        case .achievementUnlocked:
            return "解锁成就"
        case .levelUp:
            return "升级"
        case .bookmarkArticle:
            return "收藏文章"
        }
    }
    
    var experiencePoints: Int {
        switch self {
        case .readArticle:
            return 10
        case .lookupWord:
            return 2
        case .completeReview:
            return 15
        case .consecutiveDay:
            return 5
        case .achievementUnlocked:
            return 20
        case .levelUp:
            return 50
        case .bookmarkArticle:
            return 3
        }
    }
}

// MARK: - Difficulty Level Enum

/// 通用难度等级枚举
enum DifficultyLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case elementary = "elementary"
    case intermediate = "intermediate"
    case upperIntermediate = "upper_intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .beginner:
            return "初学者"
        case .elementary:
            return "基础"
        case .intermediate:
            return "中级"
        case .upperIntermediate:
            return "中高级"
        case .advanced:
            return "高级"
        case .expert:
            return "专家"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .beginner:
            return 1
        case .elementary:
            return 2
        case .intermediate:
            return 3
        case .upperIntermediate:
            return 4
        case .advanced:
            return 5
        case .expert:
            return 6
        }
    }
    
    var color: String {
        switch self {
        case .beginner:
            return "green"
        case .elementary:
            return "blue"
        case .intermediate:
            return "orange"
        case .upperIntermediate:
            return "purple"
        case .advanced:
            return "red"
        case .expert:
            return "black"
        }
    }
}

// MARK: - Exam Type Enum

/// 考试类型枚举
enum ExamType: String, CaseIterable, Codable {
    case postgraduate1 = "考研一"
    case postgraduate2 = "考研二"
    case general = "考研通用"
    case cet4 = "四级"
    case cet6 = "六级"
    case ielts = "雅思"
    case toefl = "托福"
    case gre = "GRE"
    case gmat = "GMAT"
    case other = "其他"
    
    var displayName: String {
        return self.rawValue
    }
    
    var shortName: String {
        switch self {
        case .postgraduate1:
            return "考研一"
        case .postgraduate2:
            return "考研二"
        case .general:
            return "通用"
        case .cet4:
            return "CET-4"
        case .cet6:
            return "CET-6"
        case .ielts:
            return "IELTS"
        case .toefl:
            return "TOEFL"
        case .gre:
            return "GRE"
        case .gmat:
            return "GMAT"
        case .other:
            return "其他"
        }
    }
    
    var difficultyLevel: DifficultyLevel {
        switch self {
        case .cet4:
            return .elementary
        case .cet6:
            return .intermediate
        case .postgraduate1, .postgraduate2, .general:
            return .upperIntermediate
        case .ielts, .toefl:
            return .advanced
        case .gre, .gmat:
            return .expert
        case .other:
            return .intermediate
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .cet4:
            return 1
        case .cet6:
            return 2
        case .postgraduate1:
            return 3
        case .postgraduate2:
            return 4
        case .general:
            return 5
        case .ielts:
            return 6
        case .toefl:
            return 7
        case .gre:
            return 8
        case .gmat:
            return 9
        case .other:
            return 10
        }
    }
}

// MARK: - Helper Extensions

extension ExamType {
    /// 从字符串创建ExamType
    static func from(string: String) -> ExamType {
        return ExamType(rawValue: string) ?? .other
    }
    
    /// 获取所有考研相关的考试类型
    static var postgraduateTypes: [ExamType] {
        return [.postgraduate1, .postgraduate2, .general]
    }
    
    /// 获取所有英语水平考试类型
    static var proficiencyTypes: [ExamType] {
        return [.ielts, .toefl, .cet4, .cet6]
    }
    
    /// 获取所有研究生入学考试类型
    static var graduateTypes: [ExamType] {
        return [.gre, .gmat]
    }
}

extension DifficultyLevel {
    /// 从ArticleDifficulty转换
    static func from(articleDifficulty: ArticleDifficulty) -> DifficultyLevel {
        switch articleDifficulty {
        case .easy:
            return .elementary
        case .medium:
            return .intermediate
        case .hard:
            return .advanced
        }
    }
    
    /// 转换为ArticleDifficulty
    func toArticleDifficulty() -> ArticleDifficulty {
        switch self {
        case .beginner, .elementary:
            return .easy
        case .intermediate, .upperIntermediate:
            return .medium
        case .advanced, .expert:
            return .hard
        }
    }
}

extension ActivityType {
    /// 从ExperienceAction转换
    static func from(experienceAction: ExperienceAction) -> ActivityType {
        switch experienceAction {
        case .readArticle:
            return .readArticle
        case .lookupWord:
            return .lookupWord
        case .completeReview:
            return .completeReview
        case .consecutiveDay:
            return .consecutiveDay
        case .achievementUnlocked:
            return .achievementUnlocked
        case .levelUp:
            return .levelUp
        case .bookmarkArticle:
            return .bookmarkArticle
        }
    }
    
    /// 转换为ExperienceAction
    func toExperienceAction() -> ExperienceAction {
        switch self {
        case .readArticle:
            return .readArticle
        case .lookupWord:
            return .lookupWord
        case .completeReview:
            return .completeReview
        case .consecutiveDay:
            return .consecutiveDay
        case .achievementUnlocked:
            return .achievementUnlocked
        case .levelUp:
            return .levelUp
        case .bookmarkArticle:
            return .bookmarkArticle
        }
    }
}

// MARK: - Review Filter
enum ReviewFilter: String, CaseIterable, Codable {
    case all = "all"
    case needsReview = "needsReview"
    case dueToday = "dueToday"
    case overdue = "overdue"
    case byMastery = "byMastery"
    
    var title: String {
        switch self {
        case .all:
            return "全部"
        case .needsReview:
            return "需要复习"
        case .dueToday:
            return "今日复习"
        case .overdue:
            return "逾期复习"
        case .byMastery:
            return "按掌握程度"
        }
    }
}

// MARK: - Vocabulary Sort Option
enum VocabularySortOption: String, CaseIterable, Codable {
    case alphabetical = "alphabetical"
    case dateAdded = "dateAdded"
    case mastery = "mastery"
    case frequency = "frequency"
    case recent = "recent"
    
    var title: String {
        switch self {
        case .alphabetical:
            return "字母顺序"
        case .dateAdded:
            return "添加时间"
        case .mastery:
            return "掌握程度"
        case .frequency:
            return "查看频率"
        case .recent:
            return "最近查询"
        }
    }
    
    var displayName: String {
        return title
    }
}