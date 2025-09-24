//
//  AdaptiveLearningService.swift
//  en01
//
//  Created by AI Assistant on 2025/1/20.
//

import Foundation
import SwiftData
import SwiftUI
import Combine
import os.log

/// 自适应学习服务 - 核心自适应学习算法实现
@MainActor
class AdaptiveLearningService: ObservableObject {
    
    // MARK: - Properties
    
    @Published var currentAnalysis: LearningBehaviorAnalysis?
    @Published var adaptiveRecommendations: [AdaptiveRecommendation] = []
    @Published var isAnalyzing = false
    @Published var lastAnalysisDate: Date?
    
    private let modelContext: ModelContext
    private let config: AdaptiveLearningConfig
    private let logger = os.Logger(subsystem: "AdaptiveLearningService", category: "learning")
    
    // 依赖服务
    private let learningTrackingService: LearningTrackingService
    private let userProgressService: UserProgressService
    private let intelligentRankingService: IntelligentRankingService
    
    // 分析缓存
    private var analysisCache: [String: LearningBehaviorAnalysis] = [:]
    private let cacheValidityDuration: TimeInterval = 3600 // 1小时
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        learningTrackingService: LearningTrackingService,
        userProgressService: UserProgressService,
        intelligentRankingService: IntelligentRankingService,
        config: AdaptiveLearningConfig = .default
    ) {
        self.modelContext = modelContext
        self.learningTrackingService = learningTrackingService
        self.userProgressService = userProgressService
        self.intelligentRankingService = intelligentRankingService
        self.config = config
    }
    
    // MARK: - Learning Behavior Recording
    
    /// 记录学习行为
    func recordLearningBehavior(
        userId: String,
        behavior: LearningBehavior
    ) async throws {
        logger.info("记录学习行为: \(behavior.behaviorType.rawValue) for user: \(userId)")
        
        do {
            // 创建学习记录 - 使用正确的构造函数参数
            let learningRecord = LearningRecord(
                word: behavior.context["word"] ?? "unknown",
                previousMastery: .unfamiliar,
                newMastery: .familiar,
                source: "adaptive_learning",
                timestamp: behavior.timestamp
            )
            
            // 保存到数据库
            modelContext.insert(learningRecord)
            try modelContext.save()
            
            // 清除相关缓存，确保下次分析时使用最新数据
            analysisCache.removeValue(forKey: userId)
            
            logger.info("✅ 学习行为记录成功")
        } catch {
            logger.error("❌ 学习行为记录失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - 核心分析方法
    
    /// 执行完整的学习行为分析
    func performLearningAnalysis(userId: String = "default") async throws -> LearningBehaviorAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        logger.info("开始执行学习行为分析")
        
        // 检查缓存
        if let cachedAnalysis = getCachedAnalysis(userId: userId) {
            logger.info("使用缓存的分析结果")
            return cachedAnalysis
        }
        
        // 收集学习数据
        let learningData = try await collectLearningData(userId: userId)
        
        // 执行各项分析
        let readingPatterns = analyzeReadingPatterns(from: learningData)
        let vocabularyAnalysis = analyzeVocabularyLearning(from: learningData)
        let difficultyPreference = analyzeDifficultyPreference(from: learningData)
        let learningEfficiency = analyzeLearningEfficiency(from: learningData)
        
        // 生成自适应调整建议
        let adjustments = generateAdaptiveAdjustments(
            readingPatterns: readingPatterns,
            vocabularyAnalysis: vocabularyAnalysis,
            difficultyPreference: difficultyPreference,
            efficiency: learningEfficiency
        )
        
        // 创建分析结果
        let analysis = LearningBehaviorAnalysis(
            userId: userId,
            analysisDate: Date(),
            timeRange: config.analysisWindow,
            readingPatterns: readingPatterns,
            vocabularyLearning: vocabularyAnalysis,
            difficultyPreference: difficultyPreference,
            learningEfficiency: learningEfficiency,
            recommendedAdjustments: adjustments
        )
        
        // 缓存结果
        cacheAnalysis(analysis, userId: userId)
        
        // 更新发布的属性
        currentAnalysis = analysis
        lastAnalysisDate = Date()
        
        logger.info("学习行为分析完成")
        return analysis
    }
    
    /// 生成自适应推荐
    func generateAdaptiveRecommendations(userId: String = "default") async throws -> [AdaptiveRecommendation] {
        let analysis = try await performLearningAnalysis(userId: userId)
        
        var recommendations: [AdaptiveRecommendation] = []
        
        // 基于分析结果生成推荐
        for adjustment in analysis.recommendedAdjustments {
            let recommendation = createRecommendation(from: adjustment, analysis: analysis)
            recommendations.append(recommendation)
        }
        
        // 按优先级排序
        recommendations.sort { $0.priority.rawValue < $1.priority.rawValue }
        
        adaptiveRecommendations = recommendations
        return recommendations
    }
    
    // MARK: - 数据收集
    
    private func collectLearningData(userId: String) async throws -> LearningDataCollection {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-config.analysisWindow)
        
        // 获取用户进度数据
        let userProgress = userProgressService.getUserProgress()
        
        // 获取学习记录
        let learningRecords = learningTrackingService.getWordLearningHistory(word: "")
        
        // 获取词汇进度
        let vocabularyProgress = learningTrackingService.getLearningProgress()
        
        // 获取阅读会话数据
        let sessions = try await fetchLearningSessions(userId: userId, from: startDate, to: endDate)
        
        // 获取文章交互数据
        let articleInteractions = try await fetchArticleInteractions(userId: userId, from: startDate, to: endDate)
        
        return LearningDataCollection(
            userProgress: userProgress,
            learningRecords: learningRecords,
            vocabularyProgress: vocabularyProgress,
            sessions: sessions,
            articleInteractions: articleInteractions,
            timeRange: DateInterval(start: startDate, end: endDate)
        )
    }
    
    private func fetchLearningSessions(userId: String, from startDate: Date, to endDate: Date) async throws -> [LearningSession] {
        let predicate = #Predicate<LearningSession> { session in
            session.userId == userId &&
            session.startTime >= startDate &&
            session.startTime <= endDate
        }
        
        let descriptor = FetchDescriptor<LearningSession>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
    
    private func fetchArticleInteractions(userId: String, from startDate: Date, to endDate: Date) async throws -> [ArticleInteraction] {
        // 这里需要根据实际的ArticleInteraction模型实现
        // 暂时返回空数组
        return []
    }
    
    // MARK: - 分析算法实现
    
    private func analyzeReadingPatterns(from data: LearningDataCollection) -> ReadingPatterns {
        let sessions = data.sessions
        
        // 计算平均阅读速度
        let totalWords = sessions.reduce(0) { $0 + $1.wordsEncountered }
        let totalTime = sessions.reduce(into: 0) { result, session in
            result += session.timeSpent
        }
        let averageSpeed = totalTime > 0 ? Double(totalWords) / (totalTime / 60) : 0
        
        // 计算偏好的学习时长
        let sessionLengths = sessions.map { $0.timeSpent }
        let preferredLength = sessionLengths.isEmpty ? 0 : sessionLengths.reduce(0, +) / Double(sessionLengths.count)
        
        // 分析学习时间模式
        let peakHours = analyzePeakLearningHours(sessions: sessions)
        
        // 计算一致性评分
        let consistencyScore = calculateConsistencyScore(sessions: sessions)
        
        // 计算专注度评分
        let focusScore = sessions.isEmpty ? 0 : sessions.map { $0.focusScore }.reduce(0, +) / Double(sessions.count)
        
        // 分析文章长度偏好
        let lengthPreference = analyzeArticleLengthPreference(sessions: sessions)
        
        // 计算跳过率
        let skipRate = calculateSkipRate(sessions: sessions)
        
        return ReadingPatterns(
            averageReadingSpeed: averageSpeed,
            preferredSessionLength: preferredLength,
            peakLearningHours: peakHours,
            consistencyScore: consistencyScore,
            focusScore: focusScore,
            preferredArticleLength: lengthPreference,
            preferredTopics: [], // 需要额外的主题分析
            skipRate: skipRate
        )
    }
    
    private func analyzeVocabularyLearning(from data: LearningDataCollection) -> VocabularyLearningAnalysis {
        let vocabularyProgress = data.vocabularyProgress
        
        // 计算掌握率
        let totalWords = vocabularyProgress.totalWords
        let masteredWords = vocabularyProgress.masteredWords
        let masteryRate = totalWords > 0 ? Double(masteredWords) / Double(totalWords) : 0
        
        // 计算学习速度（基于最近的学习记录）
        let recentRecords = data.learningRecords.filter { 
            $0.timestamp > Date().addingTimeInterval(-7 * 24 * 3600) 
        }
        let learningVelocity = Double(recentRecords.count) / 7.0 // 每天新词数
        
        // 分析舒适的难度范围
        let difficultyRange = analyzeDifficultyComfortZone(sessions: data.sessions)
        
        // 计算最佳新词数量
        let optimalNewWordCount = calculateOptimalNewWordCount(sessions: data.sessions)
        
        return VocabularyLearningAnalysis(
            masteryRate: masteryRate,
            retentionRate: 0.8, // 需要更复杂的计算
            learningVelocity: learningVelocity,
            reviewEfficiency: 0.75, // 需要基于复习数据计算
            comfortableDifficultyRange: difficultyRange,
            challengeThreshold: difficultyRange.upperBound + 0.5,
            frustrationThreshold: difficultyRange.upperBound + 1.0,
            preferredLearningMethods: [.contextual, .interactive],
            optimalNewWordCount: optimalNewWordCount
        )
    }
    
    private func analyzeDifficultyPreference(from data: LearningDataCollection) -> DifficultyPreferenceAnalysis {
        let sessions = data.sessions
        
        // 分析当前水平
        let currentLevel = estimateCurrentLevel(from: data)
        
        // 分析不同难度下的表现
        let performanceByDifficulty = analyzePerformanceByDifficulty(sessions: sessions)
        
        // 找到最佳难度
        let optimalDifficulty = findOptimalDifficulty(performanceData: performanceByDifficulty)
        
        // 计算难度容忍度
        let difficultyTolerance = calculateDifficultyTolerance(sessions: sessions)
        
        return DifficultyPreferenceAnalysis(
            currentLevel: currentLevel,
            optimalDifficulty: optimalDifficulty,
            difficultyTolerance: difficultyTolerance,
            progressionRate: 0.1, // 需要基于历史数据计算
            performanceByDifficulty: performanceByDifficulty,
            suggestedDifficultyAdjustment: optimalDifficulty - currentLevel,
            confidenceLevel: 0.8
        )
    }
    
    private func analyzeLearningEfficiency(from data: LearningDataCollection) -> LearningEfficiencyAnalysis {
        let sessions = data.sessions
        
        // 计算整体效率
        let overallEfficiency = calculateOverallEfficiency(sessions: sessions)
        
        // 计算时间利用率
        let timeUtilization = calculateTimeUtilization(sessions: sessions)
        
        // 估算认知负荷
        let cognitiveLoad = estimateCognitiveLoad(sessions: sessions)
        
        // 评估动机水平
        let motivationLevel = assessMotivationLevel(from: data)
        
        // 识别效率影响因素
        let efficiencyFactors = identifyEfficiencyFactors(from: data)
        
        // 生成优化建议
        let optimizationSuggestions = generateOptimizationSuggestions(
            efficiency: overallEfficiency,
            factors: efficiencyFactors
        )
        
        return LearningEfficiencyAnalysis(
            overallEfficiency: overallEfficiency,
            timeUtilization: timeUtilization,
            cognitiveLoad: cognitiveLoad,
            motivationLevel: motivationLevel,
            efficiencyFactors: efficiencyFactors,
            optimizationSuggestions: optimizationSuggestions
        )
    }
    
    // MARK: - 辅助分析方法
    
    private func analyzePeakLearningHours(sessions: [LearningSession]) -> [Int] {
        var hourCounts: [Int: Int] = [:]
        
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourCounts[hour, default: 0] += 1
        }
        
        // 返回学习次数最多的前3个小时
        return hourCounts.sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
    
    private func calculateConsistencyScore(sessions: [LearningSession]) -> Double {
        guard sessions.count > 1 else { return 0 }
        
        // 计算学习间隔的标准差，间隔越稳定，一致性越高
        let dates = sessions.map { Calendar.current.startOfDay(for: $0.startTime) }
        let uniqueDates = Set(dates)
        
        // 简化的一致性计算：学习天数 / 总天数
        let totalDays = Calendar.current.dateComponents([.day], 
            from: dates.min() ?? Date(), 
            to: dates.max() ?? Date()).day ?? 1
        
        return Double(uniqueDates.count) / Double(max(totalDays, 1))
    }
    
    private func analyzeArticleLengthPreference(sessions: [LearningSession]) -> ArticleLengthPreference {
        // 基于会话中遇到的单词数量分析偏好
        let wordCounts = sessions.map { $0.wordsEncountered }
        guard !wordCounts.isEmpty else { return .medium }
        
        let averageWords = wordCounts.reduce(0, +) / wordCounts.count
        
        switch averageWords {
        case 0..<500:
            return .short
        case 500..<1500:
            return .medium
        case 1500...:
            return .long
        default:
            return .medium
        }
    }
    
    private func calculateSkipRate(sessions: [LearningSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        
        let incompleteCount = sessions.filter { $0.completionRate < 0.8 }.count
        return Double(incompleteCount) / Double(sessions.count)
    }
    
    private func analyzeDifficultyComfortZone(sessions: [LearningSession]) -> ClosedRange<Double> {
        let ratings = sessions.map { $0.difficultyRating }
        guard !ratings.isEmpty else { return 2.0...3.0 }
        
        let sortedRatings = ratings.sorted()
        let q1Index = sortedRatings.count / 4
        let q3Index = (sortedRatings.count * 3) / 4
        
        let lowerBound = sortedRatings[q1Index]
        let upperBound = sortedRatings[min(q3Index, sortedRatings.count - 1)]
        
        return lowerBound...upperBound
    }
    
    private func calculateOptimalNewWordCount(sessions: [LearningSession]) -> Int {
        // 基于完成率和满意度找到最佳新词数量
        let successfulSessions = sessions.filter { 
            $0.completionRate > 0.8 && ($0.satisfactionRating ?? 0) > 3.0 
        }
        
        guard !successfulSessions.isEmpty else { return 10 }
        
        let avgNewWords = successfulSessions.map { $0.wordsLookedUp }.reduce(0, +) / successfulSessions.count
        return max(5, min(20, avgNewWords)) // 限制在5-20之间
    }
    
    // MARK: - 性能分析方法
    
    private func estimateCurrentLevel(from data: LearningDataCollection) -> Double {
        let vocabularyProgress = data.vocabularyProgress
        let masteryRate = vocabularyProgress.masteryRate
        
        // 基于掌握率估算水平
        switch masteryRate {
        case 0..<0.3:
            return 1.5 // 初级
        case 0.3..<0.6:
            return 2.5 // 中级
        case 0.6..<0.8:
            return 3.5 // 高级
        default:
            return 4.5 // 专家级
        }
    }
    
    private func analyzePerformanceByDifficulty(sessions: [LearningSession]) -> [Double: PerformanceMetrics] {
        var performanceData: [Double: [LearningSession]] = [:]
        
        // 按难度分组
        for session in sessions {
            let difficulty = round(session.difficultyRating)
            performanceData[difficulty, default: []].append(session)
        }
        
        // 计算每个难度的性能指标
        var result: [Double: PerformanceMetrics] = [:]
        
        for (difficulty, sessionsForDifficulty) in performanceData {
            let completionRate = sessionsForDifficulty.map { $0.completionRate }.reduce(0, +) / Double(sessionsForDifficulty.count)
            let engagementScore = sessionsForDifficulty.map { $0.focusScore }.reduce(0, +) / Double(sessionsForDifficulty.count)
            let satisfactionScore = sessionsForDifficulty.compactMap { $0.satisfactionRating }.reduce(0, +) / Double(sessionsForDifficulty.count)
            let avgTimeSpent = sessionsForDifficulty.map { $0.timeSpent }.reduce(0, +) / Double(sessionsForDifficulty.count)
            
            result[difficulty] = PerformanceMetrics(
                completionRate: completionRate,
                accuracyRate: 0.8, // 需要更详细的准确率数据
                engagementScore: engagementScore,
                satisfactionScore: satisfactionScore,
                timeSpent: avgTimeSpent
            )
        }
        
        return result
    }
    
    private func findOptimalDifficulty(performanceData: [Double: PerformanceMetrics]) -> Double {
        var bestDifficulty = 3.0
        var bestScore = 0.0
        
        for (difficulty, metrics) in performanceData {
            // 综合评分：完成率 * 0.4 + 参与度 * 0.3 + 满意度 * 0.3
            let score = metrics.completionRate * 0.4 + 
                       metrics.engagementScore * 0.3 + 
                       metrics.satisfactionScore * 0.3
            
            if score > bestScore {
                bestScore = score
                bestDifficulty = difficulty
            }
        }
        
        return bestDifficulty
    }
    
    private func calculateDifficultyTolerance(sessions: [LearningSession]) -> Double {
        let difficultyRatings = sessions.map { $0.difficultyRating }
        guard difficultyRatings.count > 1 else { return 1.0 }
        
        // 计算难度评分的标准差作为容忍度指标
        let mean = difficultyRatings.reduce(0, +) / Double(difficultyRatings.count)
        let variance = difficultyRatings.map { pow($0 - mean, 2) }.reduce(0, +) / Double(difficultyRatings.count)
        
        return sqrt(variance)
    }
    
    // MARK: - 效率分析方法
    
    private func calculateOverallEfficiency(sessions: [LearningSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        
        let avgCompletion = sessions.map { $0.completionRate }.reduce(0, +) / Double(sessions.count)
        let avgFocus = sessions.map { $0.focusScore }.reduce(0, +) / Double(sessions.count)
        
        // 效率 = 完成率 * 专注度
        return avgCompletion * avgFocus
    }
    
    private func calculateTimeUtilization(sessions: [LearningSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        
        // 基于暂停时间计算时间利用率
        let totalActiveTime = sessions.map { session in
            let pauseTime = session.pauseDurations.reduce(0.0, +)
            return max(0, session.timeSpent - pauseTime)
        }.reduce(0.0, +)
        
        let totalTime = sessions.map { $0.timeSpent }.reduce(0.0, +)
        
        return totalTime > 0 ? totalActiveTime / totalTime : 0
    }
    
    private func estimateCognitiveLoad(sessions: [LearningSession]) -> Double {
        guard !sessions.isEmpty else { return 0.5 }
        
        // 基于查词频率和难度评分估算认知负荷
        let avgLookupRate = sessions.map { session in
            session.timeSpent > 0 ? Double(session.wordsLookedUp) / (session.timeSpent / 60) : 0
        }.reduce(0, +) / Double(sessions.count)
        
        let avgDifficulty = sessions.map { $0.difficultyRating }.reduce(0, +) / Double(sessions.count)
        
        // 认知负荷 = (查词频率 / 10) * 0.5 + (难度 / 5) * 0.5
        return min(1.0, (avgLookupRate / 10) * 0.5 + (avgDifficulty / 5) * 0.5)
    }
    
    private func assessMotivationLevel(from data: LearningDataCollection) -> Double {
        let sessions = data.sessions
        guard !sessions.isEmpty else { return 0.5 }
        
        // 基于学习频率、完成率和满意度评估动机
        let recentSessions = sessions.filter { 
            $0.startTime > Date().addingTimeInterval(-7 * 24 * 3600) 
        }
        
        let frequency = Double(recentSessions.count) / 7.0 // 每天学习频率
        let avgCompletion = sessions.map { $0.completionRate }.reduce(0, +) / Double(sessions.count)
        let avgSatisfaction = sessions.compactMap { $0.satisfactionRating }.reduce(0, +) / Double(sessions.count)
        
        // 动机水平 = 频率 * 0.4 + 完成率 * 0.3 + 满意度 * 0.3
        return min(1.0, frequency * 0.4 + avgCompletion * 0.3 + (avgSatisfaction / 5) * 0.3)
    }
    
    private func identifyEfficiencyFactors(from data: LearningDataCollection) -> [EfficiencyFactor] {
        var factors: [EfficiencyFactor] = []
        
        // 分析时间因素
        let peakHours = analyzePeakLearningHours(sessions: data.sessions)
        if !peakHours.isEmpty {
            factors.append(EfficiencyFactor(
                name: "学习时间",
                impact: 0.3,
                confidence: 0.8,
                description: "在\(peakHours.map{"\($0)点"}.joined(separator: "、"))学习效果最佳"
            ))
        }
        
        // 分析会话长度因素
        let sessions = data.sessions
        let optimalLength = sessions.map { $0.timeSpent }.sorted()[sessions.count / 2] // 中位数
        factors.append(EfficiencyFactor(
            name: "学习时长",
            impact: 0.2,
            confidence: 0.7,
            description: "最佳学习时长约为\(Int(optimalLength / 60))分钟"
        ))
        
        return factors
    }
    
    private func generateOptimizationSuggestions(
        efficiency: Double,
        factors: [EfficiencyFactor]
    ) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []
        
        if efficiency < 0.6 {
            suggestions.append(OptimizationSuggestion(
                title: "优化学习时间安排",
                description: "建议在效率最高的时间段进行学习",
                category: .timeManagement,
                priority: .high,
                estimatedImprovement: 0.2
            ))
        }
        
        if efficiency < 0.7 {
            suggestions.append(OptimizationSuggestion(
                title: "调整内容难度",
                description: "选择更适合当前水平的学习内容",
                category: .contentSelection,
                priority: .medium,
                estimatedImprovement: 0.15
            ))
        }
        
        return suggestions
    }
    
    // MARK: - 自适应调整生成
    
    private func generateAdaptiveAdjustments(
        readingPatterns: ReadingPatterns,
        vocabularyAnalysis: VocabularyLearningAnalysis,
        difficultyPreference: DifficultyPreferenceAnalysis,
        efficiency: LearningEfficiencyAnalysis
    ) -> [AdaptiveAdjustment] {
        var adjustments: [AdaptiveAdjustment] = []
        
        // 难度调整
        if abs(difficultyPreference.suggestedDifficultyAdjustment) > 0.2 {
            adjustments.append(AdaptiveAdjustment(
                type: .difficultyLevel,
                priority: .high,
                description: "调整内容难度以匹配当前学习水平",
                expectedImpact: 0.3,
                implementationComplexity: .simple,
                parameters: ["adjustment": difficultyPreference.suggestedDifficultyAdjustment],
                conditions: [.performanceThreshold]
            ))
        }
        
        // 学习节奏调整
        if efficiency.overallEfficiency < 0.6 {
            adjustments.append(AdaptiveAdjustment(
                type: .learningPace,
                priority: .medium,
                description: "调整学习节奏以提高效率",
                expectedImpact: 0.2,
                implementationComplexity: .moderate,
                parameters: ["pace_factor": 0.8],
                conditions: [.behaviorPattern]
            ))
        }
        
        // 词汇焦点调整
        if vocabularyAnalysis.masteryRate < 0.5 {
            adjustments.append(AdaptiveAdjustment(
                type: .vocabularyFocus,
                priority: .high,
                description: "增强词汇学习重点",
                expectedImpact: 0.25,
                implementationComplexity: .moderate,
                parameters: ["focus_increase": 0.3],
                conditions: [.userConsent]
            ))
        }
        
        return adjustments
    }
    
    private func createRecommendation(
        from adjustment: AdaptiveAdjustment,
        analysis: LearningBehaviorAnalysis
    ) -> AdaptiveRecommendation {
        return AdaptiveRecommendation(
            id: UUID(),
            type: adjustment.type,
            title: getRecommendationTitle(for: adjustment.type),
            description: adjustment.description,
            priority: adjustment.priority,
            expectedImpact: adjustment.expectedImpact,
            confidence: analysis.difficultyPreference.confidenceLevel,
            parameters: adjustment.parameters,
            createdDate: Date(),
            isApplied: false
        )
    }
    
    private func getRecommendationTitle(for type: AdjustmentType) -> String {
        switch type {
        case .difficultyLevel:
            return "调整学习难度"
        case .contentRecommendation:
            return "优化内容推荐"
        case .learningPace:
            return "调整学习节奏"
        case .reviewFrequency:
            return "优化复习频率"
        case .vocabularyFocus:
            return "强化词汇学习"
        case .sessionLength:
            return "调整学习时长"
        }
    }
    
    // MARK: - 缓存管理
    
    private func getCachedAnalysis(userId: String) -> LearningBehaviorAnalysis? {
        guard let analysis = analysisCache[userId] else { return nil }
        
        let cacheAge = Date().timeIntervalSince(analysis.analysisDate)
        return cacheAge < cacheValidityDuration ? analysis : nil
    }
    
    private func cacheAnalysis(_ analysis: LearningBehaviorAnalysis, userId: String) {
        analysisCache[userId] = analysis
    }
    
    // MARK: - 公共接口方法
    
    /// 应用自适应调整
    func applyAdaptiveAdjustment(_ recommendationId: UUID) async throws {
        guard let recommendation = adaptiveRecommendations.first(where: { $0.id == recommendationId }) else {
            throw AdaptiveLearningError.recommendationNotFound
        }
        
        // 实施调整逻辑
        try await implementAdjustment(recommendation)
        
        // 标记为已应用
        if let index = adaptiveRecommendations.firstIndex(where: { $0.id == recommendationId }) {
            adaptiveRecommendations[index].isApplied = true
            adaptiveRecommendations[index].appliedDate = Date()
        }
        
        logger.info("已应用自适应调整: \(recommendation.title)")
    }
    
    private func implementAdjustment(_ recommendation: AdaptiveRecommendation) async throws {
        switch recommendation.type {
        case .difficultyLevel:
            // 调整难度级别的实现
            break
        case .contentRecommendation:
            // 调整内容推荐的实现
            break
        case .learningPace:
            // 调整学习节奏的实现
            break
        case .reviewFrequency:
            // 调整复习频率的实现
            break
        case .vocabularyFocus:
            // 调整词汇焦点的实现
            break
        case .sessionLength:
            // 调整学习时长的实现
            break
        }
    }
}

// MARK: - 支持数据结构

struct LearningDataCollection {
    let userProgress: UserProgress?
    let learningRecords: [LearningRecord]
    let vocabularyProgress: LearningProgress
    let sessions: [LearningSession]
    let articleInteractions: [ArticleInteraction]
    let timeRange: DateInterval
}

struct AdaptiveRecommendation: Identifiable {
    let id: UUID
    let type: AdjustmentType
    let title: String
    let description: String
    let priority: AdjustmentPriority
    let expectedImpact: Double
    let confidence: Double
    let parameters: [String: Any]
    let createdDate: Date
    var isApplied: Bool
    var appliedDate: Date?
}

// MARK: - 扩展和辅助类型

enum AdaptiveLearningError: Error {
    case recommendationNotFound
    case insufficientData
    case analysisInProgress
    case configurationError
}