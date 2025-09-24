//
//  AdaptiveRecommendationEngine.swift
//  en01
//
//  Created by AI Assistant on 2025/1/20.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

/// 自适应推荐引擎 - 基于学习行为的动态文章推荐
@MainActor
class AdaptiveRecommendationEngine: ObservableObject {
    
    // MARK: - Properties
    
    @Published var adaptiveRecommendations: [AdaptiveArticleRecommendation] = []
    @Published var isGeneratingRecommendations = false
    @Published var lastRecommendationUpdate: Date?
    
    private let modelContext: ModelContext
    private let config: AdaptiveRecommendationConfig
    
    // 依赖服务
    private let adaptiveLearningService: AdaptiveLearningService
    private let intelligentRankingService: IntelligentRankingService
    private let learningBehaviorAnalyzer: LearningBehaviorAnalyzer
    
    // 推荐缓存
    private var recommendationCache: [String: [AdaptiveArticleRecommendation]] = [:]
    private let cacheValidityDuration: TimeInterval = 1800 // 30分钟
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        adaptiveLearningService: AdaptiveLearningService,
        intelligentRankingService: IntelligentRankingService,
        learningBehaviorAnalyzer: LearningBehaviorAnalyzer,
        config: AdaptiveRecommendationConfig = .default
    ) {
        self.modelContext = modelContext
        self.adaptiveLearningService = adaptiveLearningService
        self.intelligentRankingService = intelligentRankingService
        self.learningBehaviorAnalyzer = learningBehaviorAnalyzer
        self.config = config
    }
    
    // MARK: - 核心推荐方法
    
    /// 生成自适应文章推荐
    func generateAdaptiveRecommendations(
        articles: [Article],
        userVocabulary: [UserWord],
        userId: String = "default"
    ) async throws -> [AdaptiveArticleRecommendation] {
        
        isGeneratingRecommendations = true
        defer { isGeneratingRecommendations = false }
        
        // 检查缓存
        if let cachedRecommendations = getCachedRecommendations(userId: userId) {
            return cachedRecommendations
        }
        
        // 获取学习行为分析
        let behaviorAnalysis = try await adaptiveLearningService.performLearningAnalysis(userId: userId)
        
        // 获取基础推荐结果
        let baseRecommendations = await intelligentRankingService.rankArticles(articles, userVocabulary: userVocabulary)
        
        // 应用自适应调整
        let adaptiveRecommendations = await applyAdaptiveAdjustments(
            baseRecommendations: baseRecommendations,
            behaviorAnalysis: behaviorAnalysis,
            userVocabulary: userVocabulary
        )
        
        // 缓存结果
        cacheRecommendations(adaptiveRecommendations, userId: userId)
        
        // 更新发布属性
        self.adaptiveRecommendations = adaptiveRecommendations
        self.lastRecommendationUpdate = Date()
        
        return adaptiveRecommendations
    }
    
    // MARK: - 自适应调整算法
    
    /// 应用自适应调整到基础推荐结果
    private func applyAdaptiveAdjustments(
        baseRecommendations: [ArticleMatchResult],
        behaviorAnalysis: LearningBehaviorAnalysis,
        userVocabulary: [UserWord]
    ) async -> [AdaptiveArticleRecommendation] {
        
        return await withTaskGroup(of: AdaptiveArticleRecommendation?.self) { group in
            for baseRecommendation in baseRecommendations {
                group.addTask {
                    await self.createAdaptiveRecommendation(
                        from: baseRecommendation,
                        behaviorAnalysis: behaviorAnalysis,
                        userVocabulary: userVocabulary
                    )
                }
            }
            
            var adaptiveRecommendations: [AdaptiveArticleRecommendation] = []
            for await recommendation in group {
                if let recommendation = recommendation {
                    adaptiveRecommendations.append(recommendation)
                }
            }
            
            // 根据自适应分数排序
            return adaptiveRecommendations.sorted { $0.adaptiveScore > $1.adaptiveScore }
        }
    }
    
    /// 创建单个自适应推荐
    private func createAdaptiveRecommendation(
        from baseRecommendation: ArticleMatchResult,
        behaviorAnalysis: LearningBehaviorAnalysis,
        userVocabulary: [UserWord]
    ) async -> AdaptiveArticleRecommendation? {
        
        // 计算各项自适应因子
        let difficultyFactor = calculateDifficultyAdaptationFactor(
            articleDifficulty: baseRecommendation.difficulty,
            userPreference: behaviorAnalysis.difficultyPreference
        )
        
        let lengthFactor = calculateLengthAdaptationFactor(
            articleLength: baseRecommendation.totalWords,
            userPreference: behaviorAnalysis.readingPatterns.preferredArticleLength
        )
        
        let vocabularyFactor = calculateVocabularyAdaptationFactor(
            articleWords: baseRecommendation,
            vocabularyAnalysis: behaviorAnalysis.vocabularyLearning
        )
        
        let timingFactor = calculateTimingAdaptationFactor(
            readingPatterns: behaviorAnalysis.readingPatterns
        )
        
        let motivationFactor = calculateMotivationAdaptationFactor(
            efficiency: behaviorAnalysis.learningEfficiency
        )
        
        // 计算综合自适应分数
        let adaptiveScore = calculateAdaptiveScore(
            baseScore: baseRecommendation.matchScore,
            factors: AdaptiveFactors(
                difficulty: difficultyFactor,
                length: lengthFactor,
                vocabulary: vocabularyFactor,
                timing: timingFactor,
                motivation: motivationFactor
            )
        )
        
        // 生成推荐理由
        let reasons = generateRecommendationReasons(
            baseRecommendation: baseRecommendation,
            factors: AdaptiveFactors(
                difficulty: difficultyFactor,
                length: lengthFactor,
                vocabulary: vocabularyFactor,
                timing: timingFactor,
                motivation: motivationFactor
            ),
            behaviorAnalysis: behaviorAnalysis
        )
        
        return AdaptiveArticleRecommendation(
            id: UUID(),
            baseRecommendation: baseRecommendation,
            adaptiveScore: adaptiveScore,
            adaptiveFactors: AdaptiveFactors(
                difficulty: difficultyFactor,
                length: lengthFactor,
                vocabulary: vocabularyFactor,
                timing: timingFactor,
                motivation: motivationFactor
            ),
            recommendationReasons: reasons,
            confidence: calculateConfidence(factors: [difficultyFactor, lengthFactor, vocabularyFactor, timingFactor, motivationFactor]),
            generatedDate: Date()
        )
    }
    
    // MARK: - 适应因子计算
    
    /// 计算难度适应因子
    private func calculateDifficultyAdaptationFactor(
        articleDifficulty: IntelligentRankingDifficultyLevel,
        userPreference: DifficultyPreferenceAnalysis
    ) -> Double {
        let articleDifficultyValue = articleDifficulty.numericValue
        let optimalDifficulty = userPreference.optimalDifficulty
        let tolerance = userPreference.difficultyTolerance
        
        let distance = abs(articleDifficultyValue - optimalDifficulty)
        
        if distance <= tolerance {
            return 1.0 // 完美匹配
        } else {
            // 距离越远，因子越小
            let factor = max(0.1, 1.0 - (distance - tolerance) / (1.0 - tolerance))
            return factor
        }
    }
    
    /// 计算长度适应因子
    private func calculateLengthAdaptationFactor(
        articleLength: Int,
        userPreference: ArticleLengthPreference
    ) -> Double {
        let optimalLength = userPreference.optimalWordCount
        let tolerance = Double(optimalLength) * 0.3 // 30%容忍度
        
        let distance = abs(Double(articleLength) - Double(optimalLength))
        
        if distance <= tolerance {
            return 1.0
        } else {
            let factor = max(0.2, 1.0 - (distance - tolerance) / (Double(optimalLength) * 0.7))
            return factor
        }
    }
    
    /// 计算词汇适应因子
    private func calculateVocabularyAdaptationFactor(
        articleWords: ArticleMatchResult,
        vocabularyAnalysis: VocabularyLearningAnalysis
    ) -> Double {
        let unknownPercentage = articleWords.unknownPercentage
        let optimalNewWordPercentage = vocabularyAnalysis.optimalNewWordPercentage
        
        let distance = abs(unknownPercentage - optimalNewWordPercentage)
        
        if distance <= 5.0 { // 5%容忍度
            return 1.0
        } else {
            let factor = max(0.3, 1.0 - distance / 50.0) // 最大50%距离
            return factor
        }
    }
    
    /// 计算时机适应因子
    private func calculateTimingAdaptationFactor(
        readingPatterns: ReadingPatterns
    ) -> Double {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let peakHours = readingPatterns.peakLearningHours
        
        if peakHours.contains(currentHour) {
            return 1.2 // 峰值时间加成
        } else if peakHours.contains(where: { abs($0 - currentHour) <= 1 }) {
            return 1.0 // 接近峰值时间
        } else {
            return 0.8 // 非峰值时间
        }
    }
    
    /// 计算动机适应因子
    private func calculateMotivationAdaptationFactor(
        efficiency: LearningEfficiencyAnalysis
    ) -> Double {
        let motivationLevel = efficiency.motivationLevel
        
        if motivationLevel >= 0.8 {
            return 1.1 // 高动机时推荐稍难内容
        } else if motivationLevel >= 0.6 {
            return 1.0 // 正常推荐
        } else {
            return 0.9 // 低动机时推荐简单内容
        }
    }
    
    /// 计算综合自适应分数
    private func calculateAdaptiveScore(
        baseScore: Double,
        factors: AdaptiveFactors
    ) -> Double {
        let weights = config.factorWeights
        
        let weightedFactorScore = (
            factors.difficulty * weights.difficulty +
            factors.length * weights.length +
            factors.vocabulary * weights.vocabulary +
            factors.timing * weights.timing +
            factors.motivation * weights.motivation
        )
        
        // 基础分数与适应因子的加权平均
        return baseScore * config.baseScoreWeight + weightedFactorScore * config.adaptiveFactorWeight
    }
    
    /// 计算推荐置信度
    private func calculateConfidence(factors: [Double]) -> Double {
        let variance = factors.reduce(0) { sum, factor in
            sum + pow(factor - factors.reduce(0, +) / Double(factors.count), 2)
        } / Double(factors.count)
        
        // 方差越小，置信度越高
        return max(0.5, 1.0 - variance)
    }
    
    // MARK: - 推荐理由生成
    
    /// 生成推荐理由
    private func generateRecommendationReasons(
        baseRecommendation: ArticleMatchResult,
        factors: AdaptiveFactors,
        behaviorAnalysis: LearningBehaviorAnalysis
    ) -> [RecommendationReason] {
        var reasons: [RecommendationReason] = []
        
        // 难度匹配理由
        if factors.difficulty >= 0.9 {
            reasons.append(RecommendationReason(
                type: .difficultyMatch,
                description: "文章难度与您的学习水平完美匹配",
                impact: .positive,
                confidence: factors.difficulty
            ))
        }
        
        // 词汇学习理由
        if factors.vocabulary >= 0.8 {
            let newWordCount = baseRecommendation.unknownWords
            reasons.append(RecommendationReason(
                type: .vocabularyOptimal,
                description: "包含 \(newWordCount) 个新词汇，适合您的学习进度",
                impact: .positive,
                confidence: factors.vocabulary
            ))
        }
        
        // 长度适配理由
        if factors.length >= 0.9 {
            reasons.append(RecommendationReason(
                type: .lengthPreference,
                description: "文章长度符合您的阅读习惯",
                impact: .positive,
                confidence: factors.length
            ))
        }
        
        // 时机推荐理由
        if factors.timing > 1.0 {
            reasons.append(RecommendationReason(
                type: .optimalTiming,
                description: "当前是您的最佳学习时间",
                impact: .positive,
                confidence: factors.timing
            ))
        }
        
        // 动机调节理由
        if factors.motivation != 1.0 {
            let description = factors.motivation > 1.0 
                ? "根据您的学习状态，推荐稍有挑战性的内容"
                : "考虑到当前学习状态，推荐轻松易读的内容"
            reasons.append(RecommendationReason(
                type: .motivationAdjustment,
                description: description,
                impact: .neutral,
                confidence: abs(factors.motivation - 1.0) + 0.5
            ))
        }
        
        return reasons
    }
    
    // MARK: - 缓存管理
    
    private func getCachedRecommendations(userId: String) -> [AdaptiveArticleRecommendation]? {
        guard let cached = recommendationCache[userId] else { return nil }
        
        // 检查缓存是否过期
        if let lastUpdate = lastRecommendationUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheValidityDuration {
            return cached
        }
        
        return nil
    }
    
    private func cacheRecommendations(_ recommendations: [AdaptiveArticleRecommendation], userId: String) {
        recommendationCache[userId] = recommendations
        
        // 限制缓存大小
        if recommendationCache.count > 10 {
            let oldestKey = recommendationCache.keys.first!
            recommendationCache.removeValue(forKey: oldestKey)
        }
    }
    
    /// 清除推荐缓存
    func clearRecommendationCache() {
        recommendationCache.removeAll()
        lastRecommendationUpdate = nil
    }
    
    // MARK: - 公共方法
    
    /// 获取特定类型的推荐
    func getRecommendationsByType(_ type: RecommendationType) -> [AdaptiveArticleRecommendation] {
        return adaptiveRecommendations.filter { recommendation in
            recommendation.recommendationReasons.contains { $0.type == type }
        }
    }
    
    /// 获取高置信度推荐
    func getHighConfidenceRecommendations(threshold: Double = 0.8) -> [AdaptiveArticleRecommendation] {
        return adaptiveRecommendations.filter { $0.confidence >= threshold }
    }
}

// MARK: - 数据结构

/// 自适应文章推荐
struct AdaptiveArticleRecommendation: Identifiable {
    let id: UUID
    let baseRecommendation: ArticleMatchResult
    let adaptiveScore: Double
    let adaptiveFactors: AdaptiveFactors
    let recommendationReasons: [RecommendationReason]
    let confidence: Double
    let generatedDate: Date
    
    var article: Article {
        baseRecommendation.article
    }
}

/// 自适应因子
struct AdaptiveFactors {
    let difficulty: Double
    let length: Double
    let vocabulary: Double
    let timing: Double
    let motivation: Double
}

/// 推荐理由
struct RecommendationReason {
    let type: RecommendationType
    let description: String
    let impact: RecommendationImpact
    let confidence: Double
}

/// 推荐类型
enum RecommendationType {
    case difficultyMatch
    case vocabularyOptimal
    case lengthPreference
    case optimalTiming
    case motivationAdjustment
}

/// 推荐影响
enum RecommendationImpact {
    case positive
    case neutral
    case negative
}

/// 自适应推荐配置
struct AdaptiveRecommendationConfig {
    let factorWeights: FactorWeights
    let baseScoreWeight: Double
    let adaptiveFactorWeight: Double
    
    static let `default` = AdaptiveRecommendationConfig(
        factorWeights: FactorWeights(
            difficulty: 0.3,
            length: 0.2,
            vocabulary: 0.25,
            timing: 0.15,
            motivation: 0.1
        ),
        baseScoreWeight: 0.6,
        adaptiveFactorWeight: 0.4
    )
}

/// 因子权重
struct FactorWeights {
    let difficulty: Double
    let length: Double
    let vocabulary: Double
    let timing: Double
    let motivation: Double
}

// MARK: - 扩展

extension IntelligentRankingDifficultyLevel {
    var numericValue: Double {
        switch self {
        case .beginner: return 0.2
        case .elementary: return 0.4
        case .intermediate: return 0.6
        case .upperIntermediate: return 0.8
        case .advanced: return 1.0
        case .expert: return 1.2
        }
    }
}