//
//  LearningAnalytics.swift
//  en01
//
//  Created by AI Assistant on 2025/1/20.
//

import Foundation
import SwiftData

// MARK: - 学习分析数据模型

/// 用户学习行为分析结果
struct LearningBehaviorAnalysis {
    let userId: String
    let analysisDate: Date
    let timeRange: TimeInterval // 分析时间范围（秒）
    
    // 阅读行为分析
    let readingPatterns: ReadingPatterns
    
    // 词汇学习分析
    let vocabularyLearning: VocabularyLearningAnalysis
    
    // 难度偏好分析
    let difficultyPreference: DifficultyPreferenceAnalysis
    
    // 学习效率分析
    let learningEfficiency: LearningEfficiencyAnalysis
    
    // 推荐的调整策略
    let recommendedAdjustments: [AdaptiveAdjustment]
}

/// 阅读模式分析
struct ReadingPatterns {
    let averageReadingSpeed: Double // 平均阅读速度（词/分钟）
    let preferredSessionLength: TimeInterval // 偏好的学习时长
    let peakLearningHours: [Int] // 学习效率最高的时间段
    let consistencyScore: Double // 学习一致性评分（0-1）
    let focusScore: Double // 专注度评分（0-1）
    
    // 阅读偏好
    let preferredArticleLength: ArticleLengthPreference
    let preferredTopics: [String]
    let skipRate: Double // 跳过文章的比率
}

/// 词汇学习分析
struct VocabularyLearningAnalysis {
    let masteryRate: Double // 掌握率（0-1）
    let retentionRate: Double // 记忆保持率（0-1）
    let learningVelocity: Double // 学习速度（新词/天）
    let reviewEfficiency: Double // 复习效率（0-1）
    
    // 词汇难度分析
    let comfortableDifficultyRange: ClosedRange<Double>
    let challengeThreshold: Double // 挑战阈值
    let frustrationThreshold: Double // 挫折阈值
    
    // 学习策略偏好
    let preferredLearningMethods: [LearningMethod]
    let optimalNewWordCount: Int // 每篇文章最佳新词数量
    
    var optimalNewWordPercentage: Double {
        // 基于学习速度和掌握率计算最佳新词百分比
        let basePercentage = 0.15 // 基础15%
        let velocityAdjustment = min(learningVelocity / 10.0, 0.1) // 根据学习速度调整，最多增加10%
        let masteryAdjustment = masteryRate * 0.05 // 根据掌握率调整，最多增加5%
        return min(basePercentage + velocityAdjustment + masteryAdjustment, 0.3) // 最大不超过30%
    }
}

/// 难度偏好分析
struct DifficultyPreferenceAnalysis {
    let currentLevel: Double // 当前水平（1-5）
    let optimalDifficulty: Double // 最佳难度（1-5）
    let difficultyTolerance: Double // 难度容忍度
    let progressionRate: Double // 进步速度
    
    // 不同难度下的表现
    let performanceByDifficulty: [Double: PerformanceMetrics]
    
    // 自适应建议
    let suggestedDifficultyAdjustment: Double
    let confidenceLevel: Double // 建议的置信度
}

/// 学习效率分析
struct LearningEfficiencyAnalysis {
    let overallEfficiency: Double // 整体效率评分（0-1）
    let timeUtilization: Double // 时间利用率
    let cognitiveLoad: Double // 认知负荷
    let motivationLevel: Double // 动机水平
    
    // 效率影响因素
    let efficiencyFactors: [EfficiencyFactor]
    
    // 优化建议
    let optimizationSuggestions: [OptimizationSuggestion]
}

/// 性能指标
struct PerformanceMetrics {
    let completionRate: Double // 完成率
    let accuracyRate: Double // 准确率
    let engagementScore: Double // 参与度评分
    let satisfactionScore: Double // 满意度评分
    let timeSpent: TimeInterval // 花费时间
}

/// 自适应调整策略
struct AdaptiveAdjustment {
    let type: AdjustmentType
    let priority: AdjustmentPriority
    let description: String
    let expectedImpact: Double // 预期影响（0-1）
    let implementationComplexity: AdjustmentComplexity
    
    // 调整参数
    let parameters: [String: Any]
    
    // 生效条件
    let conditions: [AdjustmentCondition]
}

// MARK: - 枚举定义

enum ArticleLengthPreference: String, CaseIterable {
    case short = "short" // < 500词
    case medium = "medium" // 500-1500词
    case long = "long" // > 1500词
    case mixed = "mixed" // 混合
    
    var optimalWordCount: Int {
        switch self {
        case .short: return 300
        case .medium: return 1000
        case .long: return 2000
        case .mixed: return 1000
        }
    }
}

enum LearningMethod: String, CaseIterable {
    case contextual = "contextual" // 上下文学习
    case repetition = "repetition" // 重复学习
    case visual = "visual" // 视觉学习
    case audio = "audio" // 听觉学习
    case interactive = "interactive" // 互动学习
}

enum AdjustmentType: String, CaseIterable {
    case difficultyLevel = "difficulty_level"
    case contentRecommendation = "content_recommendation"
    case learningPace = "learning_pace"
    case reviewFrequency = "review_frequency"
    case vocabularyFocus = "vocabulary_focus"
    case sessionLength = "session_length"
}

enum AdjustmentPriority: String, CaseIterable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
}

enum AdjustmentComplexity: String, CaseIterable {
    case simple = "simple"
    case moderate = "moderate"
    case complex = "complex"
}

enum AdjustmentCondition: String, CaseIterable {
    case userConsent = "user_consent"
    case performanceThreshold = "performance_threshold"
    case timeBasedTrigger = "time_based_trigger"
    case behaviorPattern = "behavior_pattern"
}

/// 效率影响因素
struct EfficiencyFactor {
    let name: String
    let impact: Double // 影响程度（-1到1）
    let confidence: Double // 置信度（0-1）
    let description: String
}

/// 优化建议
struct OptimizationSuggestion {
    let title: String
    let description: String
    let category: OptimizationCategory
    let priority: AdjustmentPriority
    let estimatedImprovement: Double // 预期改善程度（0-1）
}

enum OptimizationCategory: String, CaseIterable {
    case timeManagement = "time_management"
    case contentSelection = "content_selection"
    case learningStrategy = "learning_strategy"
    case motivationBoost = "motivation_boost"
    case cognitiveLoad = "cognitive_load"
}

// MARK: - 学习分析配置

/// 自适应学习配置
struct AdaptiveLearningConfig {
    // 分析参数
    let analysisWindow: TimeInterval // 分析时间窗口（默认7天）
    let minDataPoints: Int // 最少数据点数量
    let confidenceThreshold: Double // 置信度阈值
    
    // 调整参数
    let maxDifficultyChange: Double // 最大难度变化
    let adjustmentSensitivity: Double // 调整敏感度
    let stabilityPeriod: TimeInterval // 稳定期（调整后的观察期）
    
    // 安全参数
    let maxAdjustmentsPerDay: Int // 每天最大调整次数
    let userOverrideEnabled: Bool // 是否允许用户覆盖
    
    static let `default` = AdaptiveLearningConfig(
        analysisWindow: 7 * 24 * 3600, // 7天
        minDataPoints: 10,
        confidenceThreshold: 0.7,
        maxDifficultyChange: 0.5,
        adjustmentSensitivity: 0.3,
        stabilityPeriod: 2 * 24 * 3600, // 2天
        maxAdjustmentsPerDay: 3,
        userOverrideEnabled: true
    )
}

// MARK: - 实时学习状态

/// 实时学习状态跟踪
@Model
final class LearningSession: @unchecked Sendable {
    var id: UUID
    var userId: String
    var startTime: Date
    var endTime: Date?
    var articleId: String?
    
    // 会话数据
    var wordsEncountered: Int
    var wordsLookedUp: Int
    var timeSpent: TimeInterval
    var completionRate: Double
    
    // 实时指标
    var focusScore: Double // 专注度评分
    var difficultyRating: Double // 用户感知难度
    var satisfactionRating: Double? // 满意度评分
    
    // 行为数据
    private var _clickPatterns: String = "[]" // JSON 字符串存储点击模式记录
    private var _pauseDurations: String = "[]" // JSON 字符串存储暂停时长记录
    private var _scrollBehavior: String = "[]" // JSON 字符串存储滚动行为记录
    
    // 计算属性：将 JSON 字符串转换为 [String] 数组
    var clickPatterns: [String] {
        get {
            guard let data = _clickPatterns.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: data, encoding: .utf8) {
                _clickPatterns = jsonString
            } else {
                _clickPatterns = "[]"
            }
        }
    }
    
    // 计算属性：暂停时长（JSON字符串存储）
    var pauseDurations: [TimeInterval] {
        get {
            guard let data = _pauseDurations.data(using: .utf8),
                  let array = try? JSONDecoder().decode([TimeInterval].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: data, encoding: .utf8) {
                _pauseDurations = jsonString
            } else {
                _pauseDurations = "[]"
            }
        }
    }

    var scrollBehavior: [String] {
        get {
            guard let data = _scrollBehavior.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: data, encoding: .utf8) {
                _scrollBehavior = jsonString
            } else {
                _scrollBehavior = "[]"
            }
        }
    }

    init(userId: String, startTime: Date = Date(), articleId: String? = nil) {
        self.id = UUID()
        self.userId = userId
        self.startTime = startTime
        self.endTime = nil
        self.articleId = articleId
        self.wordsEncountered = 0
        self.wordsLookedUp = 0
        self.timeSpent = 0
        self.completionRate = 0
        self.focusScore = 0
        self.difficultyRating = 0
        self.satisfactionRating = nil
        self._clickPatterns = "[]"
        self._pauseDurations = "[]"
        self._scrollBehavior = "[]"
    }
    
    init(userId: String, articleId: String? = nil) {
        self.id = UUID()
        self.userId = userId
        self.startTime = Date()
        self.articleId = articleId
        self.wordsEncountered = 0
        self.wordsLookedUp = 0
        self.timeSpent = 0
        self.completionRate = 0
        self.focusScore = 1.0
        self.difficultyRating = 3.0
        self.pauseDurations = []
        // 使用私有属性初始化
        self._clickPatterns = "[]"
        self._scrollBehavior = "[]"
    }
}

// MARK: - Learning Patterns from LearningBehaviorAnalyzer

struct TemporalPattern {
    let preferredTimeSlots: [TimeSlot]
    let peakPerformanceHours: [Int]
    let learningFrequency: Double
    let sessionDurationPattern: [DurationRange: Double]
    let learningIntervals: [Double]
    let consistencyScore: Double
}

struct BehavioralPattern {
    let interactionStyle: InteractionStyle
    let navigationPattern: NavigationPattern
    let focusPattern: Double
    let adaptabilityScore: Double
    let preferredLearningModes: [LearningMode]
}

struct PerformancePattern {
    let trendDirection: TrendDirection
    let performanceAreas: [PerformanceArea: Double]
}

struct EngagementPattern {
    let retentionRisk: RetentionRisk
    let distractionTriggers: [DistractionTrigger]
    let engagementFactors: [EngagementFactor]
}

struct LearningBehaviorPattern {
    let userId: String
    let timeRange: DateInterval
    let temporalPattern: TemporalPattern
    let behavioralPattern: BehavioralPattern
    let performancePattern: PerformancePattern
    let engagementPattern: EngagementPattern
    let analysisDate: Date
}

// MARK: - Missing Type Definitions for LearningBehaviorAnalyzer

/// 学习频率分析结果
struct LearningFrequency {
    let sessionsPerWeek: Double // 每周学习次数
    let averageInterval: TimeInterval // 平均学习间隔（秒）
    let regularity: Double // 规律性评分（0-1）
}

/// 学习时长模式分析结果
struct SessionDurationPattern {
    let average: TimeInterval // 平均时长
    let median: TimeInterval // 中位数时长
    let range: ClosedRange<TimeInterval> // 时长范围
    let distribution: [DurationRange: Double] // 时长分布
}

/// 学习间隔分析结果
struct LearningIntervals {
    let averageGap: TimeInterval // 平均间隔
    let shortestGap: TimeInterval // 最短间隔
    let longestGap: TimeInterval // 最长间隔
    let gapVariability: Double // 间隔变异性
}

/// 专注度模式分析结果
struct FocusPattern {
    let averageFocus: Double // 平均专注度
    let focusVariability: Double // 专注度变异性
    let sustainedAttentionSpan: TimeInterval // 持续专注时长
    let distractionTriggers: [DistractionTrigger] // 分心触发因素
}