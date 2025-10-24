//
//  CommonTypes.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import CoreGraphics
import SwiftUI


// MARK: - Shared Enums

enum ArticleDifficulty: String, CaseIterable, Codable {
    case easy = "简单"
    case medium = "中等"
    case hard = "困难"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .easy:
            return .green
        case .medium:
            return .orange
        case .hard:
            return .red
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .easy:
            return 1
        case .medium:
            return 2
        case .hard:
            return 3
        }
    }
    
    static func from(string: String) -> ArticleDifficulty? {
        return ArticleDifficulty.allCases.first { $0.rawValue == string }
    }
}

enum ExperienceAction {
    case readArticle
    case lookupWord
    case completeReview
    case consecutiveDay
    case achievementUnlocked
    case levelUp
    case bookmarkArticle
}


// MARK: - Article Category Types

/// 文章分类类型枚举
enum ArticleCategoryType {
    case examOne    // 考研英语一
    case examTwo    // 考研英语二  
    case general    // 考研英语[通用]
    case cet        // 大学四六级
    
    var displayTitle: String {
        switch self {
        case .examOne: return "考研英语一"
        case .examTwo: return "考研英语二"
        case .general: return "真题列表"
        case .cet: return "大学四六级"
        }
    }
    
    var examTypeFilter: String {
        switch self {
        case .examOne: return "考研一"
        case .examTwo: return "考研二"
        case .general: return "通用"
        case .cet: return "四六级"
        }
    }
}

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
    let layoutInfo: LayoutInfo? // 新增：布局信息
    let textAlignment: TextAlignment? // 新增：文本对齐方式
    let indentation: CGFloat? // 新增：缩进信息
    
    enum CodingKeys: String, CodingKey {
        case content, type, bounds, fontInfo, level, layoutInfo, textAlignment, indentation
    }
    
    // 为了向后兼容，提供不包含新属性的初始化方法
    init(content: String, type: ElementType, bounds: CGRect, fontInfo: FontInfo, level: Int? = nil, layoutInfo: LayoutInfo? = nil, textAlignment: TextAlignment? = nil, indentation: CGFloat? = nil) {
        self.content = content
        self.type = type
        self.bounds = bounds
        self.fontInfo = fontInfo
        self.level = level
        self.layoutInfo = layoutInfo
        self.textAlignment = textAlignment
        self.indentation = indentation
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

/// 布局信息
struct LayoutInfo: Codable {
    let lineHeight: CGFloat
    let paragraphSpacing: CGFloat
    let margins: EdgeInsets
    let columnCount: Int?
    let columnSpacing: CGFloat?
    let backgroundColor: String? // 颜色的十六进制表示
    let borderInfo: BorderInfo?
}

/// 边框信息
struct BorderInfo: Codable {
    let width: CGFloat
    let color: String // 颜色的十六进制表示
    let style: BorderStyle
}

/// 边框样式
enum BorderStyle: String, Codable {
    case solid = "solid"
    case dashed = "dashed"
    case dotted = "dotted"
    case none = "none"
}

/// 边距信息
struct EdgeInsets: Codable {
    let top: CGFloat
    let leading: CGFloat
    let bottom: CGFloat
    let trailing: CGFloat
    
    init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}

/// 文本对齐方式
enum TextAlignment: String, Codable {
    case leading = "leading"
    case center = "center"
    case trailing = "trailing"
    case justified = "justified"
    
    var displayName: String {
        switch self {
        case .leading: return "左对齐"
        case .center: return "居中对齐"
        case .trailing: return "右对齐"
        case .justified: return "两端对齐"
        }
    }
    
    /// 英文名称
    var englishName: String {
        switch self {
        case .leading:
            return "Leading"
        case .center:
            return "Center"
        case .trailing:
            return "Trailing"
        case .justified:
            return "Justified"
        }
    }
    
    /// 转换为SwiftUI的TextAlignment
    func toSwiftUITextAlignment() -> SwiftUI.TextAlignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        case .justified:
            return .leading // SwiftUI不直接支持两端对齐，使用左对齐
        }
    }
    
    /// 转换为SwiftUI的Alignment
    func toSwiftUIAlignment() -> SwiftUI.Alignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        case .justified:
            return .leading // SwiftUI不直接支持两端对齐，使用左对齐
        }
    }
}

/// 文本元数据
struct TextMetadata: Codable {
    let totalPages: Int
    let extractionDate: Date
    let sourceURL: URL?
    let language: String?
    let wordCount: Int
}

/// 文本块（用于PDF文本提取）
struct TextBlock: Codable {
    let content: String
    let position: CGPoint
    let size: CGSize
    let elementType: ElementType
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

// MARK: - Time Range Enum

/// 时间范围枚举，用于数据聚合和图表展示
enum TimeRange: String, CaseIterable, Codable {
    case day = "day"
    case week = "week"
    case month = "month"
    case threeMonths = "threeMonths"
    case year = "year"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .day:
            return "今日"
        case .week:
            return "本周"
        case .month:
            return "本月"
        case .threeMonths:
            return "三个月"
        case .year:
            return "今年"
        case .all:
            return "全部"
        }
    }
    
    var shortName: String {
        switch self {
        case .day:
            return "日"
        case .week:
            return "周"
        case .month:
            return "月"
        case .threeMonths:
            return "三月"
        case .year:
            return "年"
        case .all:
            return "全部"
        }
    }
    
    var days: Int {
        switch self {
        case .day:
            return 1
        case .week:
            return 7
        case .month:
            return 30
        case .threeMonths:
            return 90
        case .year:
            return 365
        case .all:
            return 3650 // 约10年
        }
    }
    
    /// 获取对应的日期范围
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .day:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            return (startOfDay, endOfDay)
            
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? now
            return (startOfWeek, endOfWeek)
            
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
            return (startOfMonth, endOfMonth)
            
        case .threeMonths:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (threeMonthsAgo, now)
            
        case .year:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) ?? now
            return (startOfYear, endOfYear)
            
        case .all:
            // 返回一个很早的日期作为开始，当前时间作为结束
            let distantPast = Date(timeIntervalSince1970: 0)
            return (distantPast, now)
        }
    }
}

// MARK: - Achievement Types

enum AchievementType: String, CaseIterable, Codable {
    // 阅读相关成就
    case firstArticle = "首次阅读"
    case read10Articles = "阅读达人"
    case read50Articles = "阅读专家"
    case read100Articles = "阅读大师"
    
    // 词汇相关成就
    case firstWord = "初识单词"
    case lookup100Words = "词汇探索者"
    case lookup500Words = "词汇收集家"
    case lookup1000Words = "词汇大师"
    case master100Words = "词汇掌握者"
    
    // 时间相关成就
    case study1Hour = "专注学习"
    case study10Hours = "勤奋学者"
    case study50Hours = "学习达人"
    case study100Hours = "学习专家"
    
    // 连续学习成就
    case streak3Days = "三日坚持"
    case streak7Days = "一周坚持"
    case streak30Days = "月度坚持"
    case streak100Days = "百日坚持"
    
    var title: String {
        return rawValue
    }
    
    var displayName: String {
        switch self {
        case .firstArticle, .read10Articles, .read50Articles, .read100Articles:
            return "阅读成就"
        case .firstWord, .lookup100Words, .lookup500Words, .lookup1000Words, .master100Words:
            return "词汇成就"
        case .study1Hour, .study10Hours, .study50Hours, .study100Hours:
            return "学习时长成就"
        case .streak3Days, .streak7Days, .streak30Days, .streak100Days:
            return "连续学习成就"
        }
    }
    
    var description: String {
        switch self {
        case .firstArticle: return "完成第一篇文章阅读"
        case .read10Articles: return "累计阅读10篇文章"
        case .read50Articles: return "累计阅读50篇文章"
        case .read100Articles: return "累计阅读100篇文章"
        case .firstWord: return "查询第一个单词"
        case .lookup100Words: return "累计查询100个单词"
        case .lookup500Words: return "累计查询500个单词"
        case .lookup1000Words: return "累计查询1000个单词"
        case .master100Words: return "掌握100个单词"
        case .study1Hour: return "累计学习1小时"
        case .study10Hours: return "累计学习10小时"
        case .study50Hours: return "累计学习50小时"
        case .study100Hours: return "累计学习100小时"
        case .streak3Days: return "连续学习3天"
        case .streak7Days: return "连续学习7天"
        case .streak30Days: return "连续学习30天"
        case .streak100Days: return "连续学习100天"
        }
    }
    
    var icon: String {
        switch self {
        case .firstArticle, .read10Articles, .read50Articles, .read100Articles:
            return "book"
        case .firstWord, .lookup100Words, .lookup500Words, .lookup1000Words, .master100Words:
            return "textbook"
        case .study1Hour, .study10Hours, .study50Hours, .study100Hours:
            return "clock"
        case .streak3Days, .streak7Days, .streak30Days, .streak100Days:
            return "flame"
        }
    }
    
    var experienceReward: Int {
        switch self {
        case .firstArticle, .firstWord: return 10
        case .read10Articles, .lookup100Words, .study1Hour, .streak3Days: return 20
        case .read50Articles, .lookup500Words, .study10Hours, .streak7Days: return 50
        case .read100Articles, .lookup1000Words, .master100Words, .study50Hours, .streak30Days: return 100
        case .study100Hours, .streak100Days: return 200
        }
    }
}

// MARK: - Learning Analytics Types

/// 学习模式枚举
enum LearningPattern: String, CaseIterable, Codable {
    case intensive = "intensive"
    case gradual = "gradual"
    case mixed = "mixed"
    case exploratory = "exploratory"
    case balanced = "balanced"
}

/// 学习趋势枚举
enum LearningTrend: String, CaseIterable, Codable {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"
}

/// 学习洞察数据结构
struct LearningInsights: Codable {
    let learningPattern: LearningPattern
    let recommendationConfidence: Double
    let adaptabilityScore: Double
    let vocabularyTrend: LearningTrend
    let readingSpeedTrend: LearningTrend
    let comprehensionTrend: LearningTrend
    let vocabularyMasteryRate: Int
    let averageReadingSpeed: Int
    let comprehensionAccuracy: Int
    let recommendationReasons: [String]
    let learningRecommendations: [String]
    
    init(
        learningPattern: LearningPattern,
        recommendationConfidence: Double,
        adaptabilityScore: Double,
        vocabularyTrend: LearningTrend,
        readingSpeedTrend: LearningTrend,
        comprehensionTrend: LearningTrend,
        vocabularyMasteryRate: Int,
        averageReadingSpeed: Int,
        comprehensionAccuracy: Int,
        recommendationReasons: [String],
        learningRecommendations: [String]
    ) {
        self.learningPattern = learningPattern
        self.recommendationConfidence = recommendationConfidence
        self.adaptabilityScore = adaptabilityScore
        self.vocabularyTrend = vocabularyTrend
        self.readingSpeedTrend = readingSpeedTrend
        self.comprehensionTrend = comprehensionTrend
        self.vocabularyMasteryRate = vocabularyMasteryRate
        self.averageReadingSpeed = averageReadingSpeed
        self.comprehensionAccuracy = comprehensionAccuracy
        self.recommendationReasons = recommendationReasons
        self.learningRecommendations = learningRecommendations
    }
}
// MARK: - Fallback Learning Behavior Types
// These definitions ensure compile-time availability of learning behavior types
// in case Models/LearningBehavior.swift is not included in the target membership.
public struct LearningBehavior {
    public let timestamp: Date
    public let behaviorType: LearningBehaviorType
    public let context: [String: String]
    public let outcome: LearningOutcome
    public let duration: TimeInterval
    
    public init(timestamp: Date,
                behaviorType: LearningBehaviorType,
                context: [String: String],
                outcome: LearningOutcome,
                duration: TimeInterval) {
        self.timestamp = timestamp
        self.behaviorType = behaviorType
        self.context = context
        self.outcome = outcome
        self.duration = duration
    }
}

public enum LearningBehaviorType: String, CaseIterable, Codable {
    case articleRead = "article_read"
    case wordLookup = "word_lookup"
    case vocabularyReview = "vocabulary_review"
    case comprehensionTest = "comprehension_test"
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case difficultyAdjustment = "difficulty_adjustment"
    case contentSkip = "content_skip"
    case bookmarkAdd = "bookmark_add"
    case noteCreate = "note_create"
}

public enum LearningOutcome: String, CaseIterable, Codable {
    case success = "success"
    case partial = "partial"
    case failure = "failure"
    case skipped = "skipped"
    case abandoned = "abandoned"
}

// MARK: - 智能排序相关类型

// MARK: - 基础排序选项
enum BasicSortOption: String, CaseIterable {
    case matchScore = "匹配度"
    case difficulty = "难度"
    case recommendation = "推荐度"
    case unknownWords = "生词数量"
    case articleLength = "文章长度"
    
    func toRankingSortOption() -> RankingSortOption {
        switch self {
        case .matchScore: return .matchScore
        case .difficulty: return .difficulty
        case .recommendation: return .recommendation
        case .unknownWords: return .unknownWords
        case .articleLength: return .articleLength
        }
    }
}

// MARK: - 关键词排序选项
enum KeywordSortOption: String, CaseIterable {
    case none = "无"
    case reading = "阅读理解"
    case translation = "翻译"
    case writing = "写作"
    case knowledge = "知识运用"
    
    func toRankingSortOption() -> RankingSortOption {
        switch self {
        case .none: return .matchScore // 默认使用匹配度排序
        case .reading: return .keywordReading
        case .translation: return .keywordTranslation
        case .writing: return .keywordWriting
        case .knowledge: return .keywordKnowledge
        }
    }
}

// MARK: - 排序选项（保持向后兼容）
enum RankingSortOption: String, CaseIterable, Codable {
    case matchScore = "匹配度"
    case difficulty = "难度"
    case recommendation = "推荐度"
    case unknownWords = "生词数量"
    case articleLength = "文章长度"
    case keywordReading = "阅读理解"
    case keywordTranslation = "翻译"
    case keywordWriting = "写作"
    case keywordKnowledge = "知识运用"
    
    // 转换为基础排序选项
    var asBasicOption: BasicSortOption? {
        switch self {
        case .matchScore: return .matchScore
        case .difficulty: return .difficulty
        case .recommendation: return .recommendation
        case .unknownWords: return .unknownWords
        case .articleLength: return .articleLength
        default: return nil
        }
    }
    
    // 转换为关键词排序选项
    var asKeywordOption: KeywordSortOption? {
        switch self {
        case .keywordReading: return .reading
        case .keywordTranslation: return .translation
        case .keywordWriting: return .writing
        case .keywordKnowledge: return .knowledge
        default: return nil
        }
    }
}

// MARK: - 智能排序难度级别
enum IntelligentRankingDifficultyLevel: String, CaseIterable {
    case beginner = "初级"
    case elementary = "基础"
    case intermediate = "中级"
    case upperIntermediate = "中高级"
    case advanced = "高级"
    case expert = "专家"
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .elementary: return .mint
        case .intermediate: return .orange
        case .upperIntermediate: return .yellow
        case .advanced: return .red
        case .expert: return .purple
        }
    }
}

// MARK: - 推荐级别
enum RecommendationLevel: String, CaseIterable {
    case perfect = "完美匹配"
    case excellent = "强烈推荐"
    case good = "推荐"
    case fair = "一般"
    case poor = "不推荐"
    
    var color: Color {
        switch self {
        case .perfect: return .green
        case .excellent: return .blue
        case .good: return .orange
        case .fair: return .yellow
        case .poor: return .red
        }
    }
    
    var priority: Int {
        switch self {
        case .perfect: return 5
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        }
    }
}

// MARK: - 文章匹配结果
struct ArticleMatchResult {
    let article: Article
    let matchScore: Double
    let totalWords: Int
    let unknownWords: Int
    let familiarWords: Int
    let masteredWords: Int
    let difficulty: IntelligentRankingDifficultyLevel
    let recommendation: RecommendationLevel
    
    var unknownPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(unknownWords) / Double(totalWords) * 100
    }
    
    var masteredPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWords) * 100
    }
}
