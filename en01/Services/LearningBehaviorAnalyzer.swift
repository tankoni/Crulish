//
//  LearningBehaviorAnalyzer.swift
//  en01
//
//  Created by AI Assistant on 2025/1/20.
//

import Foundation
import SwiftData
import SwiftUI

/// 学习行为分析器 - 深度分析用户学习模式和表现
class LearningBehaviorAnalyzer {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let config: AdaptiveLearningConfig
    
    // 分析缓存
    private var patternCache: [String: LearningBehaviorPattern] = [:]
    private var trendCache: [String: LearningTrendData] = [:]
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, config: AdaptiveLearningConfig = .default) {
        self.modelContext = modelContext
        self.config = config
    }
    
    // MARK: - 核心分析方法
    
    /// 分析学习模式
    func analyzeLearningPatterns(
        userId: String,
        timeRange: DateInterval
    ) async throws -> LearningBehaviorPattern {
        
        // 检查缓存
        let cacheKey = "\(userId)_\(timeRange.start.timeIntervalSince1970)"
        if let cachedPattern = patternCache[cacheKey] {
            return cachedPattern
        }
        
        // 获取学习数据
        let sessions = try await fetchLearningSessions(userId: userId, in: timeRange)
        let interactions = try await fetchWordInteractions(userId: userId, in: timeRange)
        
        // 执行各项模式分析
        let temporalPattern = analyzeTemporalPatterns(sessions: sessions)
        let behavioralPattern = analyzeBehavioralPatterns(sessions: sessions, interactions: interactions)
        let performancePattern = analyzePerformancePatterns(sessions: sessions)
        let engagementPattern = analyzeEngagementPatterns(sessions: sessions)
        
        let pattern = LearningBehaviorPattern(
            userId: userId,
            timeRange: timeRange,
            temporalPattern: temporalPattern,
            behavioralPattern: behavioralPattern,
            performancePattern: performancePattern,
            engagementPattern: engagementPattern,
            analysisDate: Date()
        )
        
        // 缓存结果
        patternCache[cacheKey] = pattern
        
        return pattern
    }
    
    /// 分析学习趋势
    func analyzeLearningTrends(
        userId: String,
        timeRange: DateInterval,
        granularity: TrendGranularity = .daily
    ) async throws -> LearningTrendData {
        
        let cacheKey = "\(userId)_trend_\(granularity.rawValue)"
        if let cachedTrend = trendCache[cacheKey] {
            return cachedTrend
        }
        
        let sessions = try await fetchLearningSessions(userId: userId, in: timeRange)
        
        // 按时间粒度分组数据
        let groupedSessions = groupSessionsByGranularity(sessions, granularity: granularity)
        
        // 计算各项趋势指标
        let performanceTrend = calculatePerformanceTrend(groupedSessions: groupedSessions)
        let engagementTrend = calculateEngagementTrend(groupedSessions: groupedSessions)
        let difficultyTrend = calculateDifficultyTrend(groupedSessions: groupedSessions)
        let vocabularyTrend = calculateVocabularyTrend(groupedSessions: groupedSessions)
        
        let trend = LearningTrendData(
            performanceData: performanceTrend,
            engagementData: engagementTrend,
            difficultyData: difficultyTrend,
            vocabularyData: vocabularyTrend,
            overallDirection: .stable,
            confidence: 0.8,
            timeRange: timeRange
        )
        
        trendCache[cacheKey] = trend
        return trend
    }
    
    /// 预测学习表现
    func predictLearningPerformance(
        userId: String,
        targetDate: Date,
        context: PredictionContext
    ) async throws -> PerformancePrediction {
        
        // 获取历史数据
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-config.analysisWindow)
        let timeRange = DateInterval(start: startDate, end: endDate)
        
        let pattern = try await analyzeLearningPatterns(userId: userId, timeRange: timeRange)
        let trend = try await analyzeLearningTrends(userId: userId, timeRange: timeRange)
        
        // 执行预测算法
        let prediction = performPrediction(
            pattern: pattern,
            trend: convertToLearningTrend(trend),
            targetDate: targetDate,
            context: context
        )
        
        return prediction
    }
    
    // MARK: - 时间模式分析
    
    private func analyzeTemporalPatterns(sessions: [LearningSession]) -> TemporalPattern {
        // 分析学习时间偏好
        let timePreferences = analyzeTimePreferences(sessions: sessions)
        
        // 分析学习频率
        let frequency = analyzeLearningFrequency(sessions: sessions)
        
        // 分析学习持续时间模式
        let durationPatterns = analyzeDurationPatterns(sessions: sessions)
        
        // 分析学习间隔
        let intervals = analyzeLearningIntervals(sessions: sessions)
        
        return TemporalPattern(
            preferredTimeSlots: timePreferences.preferredSlots,
            peakPerformanceHours: timePreferences.peakHours,
            learningFrequency: frequency.sessionsPerWeek,
            sessionDurationPattern: durationPatterns.distribution,
            learningIntervals: [intervals.averageGap, intervals.shortestGap, intervals.longestGap],
            consistencyScore: calculateTemporalConsistency(sessions: sessions)
        )
    }
    
    private func analyzeTimePreferences(sessions: [LearningSession]) -> (preferredSlots: [TimeSlot], peakHours: [Int]) {
        var hourCounts: [Int: Double] = [:]
        var hourPerformance: [Int: Double] = [:]
        
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourCounts[hour, default: 0] += 1
            hourPerformance[hour, default: 0] += session.completionRate * session.focusScore
        }
        
        // 计算每小时的平均表现
        for hour in hourPerformance.keys {
            if let count = hourCounts[hour], count > 0 {
                hourPerformance[hour] = hourPerformance[hour]! / count
            }
        }
        
        // 找出偏好时段
        let preferredSlots = identifyPreferredTimeSlots(hourCounts: hourCounts)
        
        // 找出表现最佳的时段
        let peakHours = hourPerformance.sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
        
        return (preferredSlots, Array(peakHours))
    }
    
    private func identifyPreferredTimeSlots(hourCounts: [Int: Double]) -> [TimeSlot] {
        var slots: [TimeSlot] = []
        
        // 定义时段
        let timeSlots: [(TimeSlot, Range<Int>)] = [
            (.earlyMorning, 5..<9),
            (.morning, 9..<12),
            (.afternoon, 12..<17),
            (.evening, 17..<21),
            (.night, 21..<24)
        ]
        
        for (slot, range) in timeSlots {
            let totalCount = range.compactMap { hourCounts[$0] }.reduce(0, +)
            if totalCount > 0 {
                slots.append(slot)
            }
        }
        
        return slots
    }
    
    private func analyzeLearningFrequency(sessions: [LearningSession]) -> LearningFrequency {
        guard sessions.count > 1 else { return LearningFrequency(sessionsPerWeek: 0, averageInterval: 0, regularity: 0) }
        
        // 计算每周学习次数
        let timeSpan = sessions.last!.startTime.timeIntervalSince(sessions.first!.startTime)
        let weeks = max(1, timeSpan / (7 * 24 * 3600))
        let sessionsPerWeek = Double(sessions.count) / weeks
        
        // 计算平均学习间隔
        let intervals = zip(sessions.dropFirst(), sessions).map { 
            $0.0.startTime.timeIntervalSince($0.1.startTime) 
        }
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        
        // 计算规律性（间隔的标准差越小，规律性越高）
        let intervalMean = averageInterval
        let variance = intervals.map { pow($0 - intervalMean, 2) }.reduce(0, +) / Double(intervals.count)
        let standardDeviation = sqrt(variance)
        let regularity = max(0, 1 - (standardDeviation / intervalMean))
        
        return LearningFrequency(
            sessionsPerWeek: sessionsPerWeek,
            averageInterval: averageInterval,
            regularity: regularity
        )
    }
    
    private func analyzeDurationPatterns(sessions: [LearningSession]) -> SessionDurationPattern {
        let durations = sessions.map { $0.timeSpent }
        guard !durations.isEmpty else { 
            return SessionDurationPattern(average: 0, median: 0, range: 0...0, distribution: [:])
        }
        
        let sortedDurations = durations.sorted()
        let average = durations.reduce(0, +) / Double(durations.count)
        let median = sortedDurations[sortedDurations.count / 2]
        let range = sortedDurations.first!...sortedDurations.last!
        
        // 分析时长分布
        let distribution = analyzeDurationDistribution(durations: durations)
        
        return SessionDurationPattern(
            average: average,
            median: median,
            range: range,
            distribution: distribution
        )
    }
    
    private func analyzeDurationDistribution(durations: [TimeInterval]) -> [DurationRange: Double] {
        var distribution: [DurationRange: Int] = [:]
        
        for duration in durations {
            let minutes = duration / 60
            let range: DurationRange
            
            switch minutes {
            case 0..<15:
                range = .short
            case 15..<30:
                range = .medium
            case 30..<60:
                range = .long
            default:
                range = .extended
            }
            
            distribution[range, default: 0] += 1
        }
        
        // 转换为百分比
        let total = durations.count
        return distribution.mapValues { Double($0) / Double(total) }
    }
    
    private func analyzeLearningIntervals(sessions: [LearningSession]) -> LearningIntervals {
        guard sessions.count > 1 else {
            return LearningIntervals(averageGap: 0, shortestGap: 0, longestGap: 0, gapVariability: 0)
        }
        
        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        let gaps = zip(sortedSessions.dropFirst(), sortedSessions).map {
            $0.0.startTime.timeIntervalSince($0.1.startTime)
        }
        
        let averageGap = gaps.reduce(0, +) / Double(gaps.count)
        let shortestGap = gaps.min() ?? 0
        let longestGap = gaps.max() ?? 0
        
        // 计算间隔变异性
        let gapMean = averageGap
        let variance = gaps.map { pow($0 - gapMean, 2) }.reduce(0, +) / Double(gaps.count)
        let gapVariability = sqrt(variance) / gapMean
        
        return LearningIntervals(
            averageGap: averageGap,
            shortestGap: shortestGap,
            longestGap: longestGap,
            gapVariability: gapVariability
        )
    }
    
    private func calculateTemporalConsistency(sessions: [LearningSession]) -> Double {
        guard sessions.count > 1 else { return 0 }
        
        // 基于学习时间和频率的一致性
        let timeConsistency = calculateTimeConsistency(sessions: sessions)
        let frequencyConsistency = calculateFrequencyConsistency(sessions: sessions)
        
        return (timeConsistency + frequencyConsistency) / 2
    }
    
    private func calculateTimeConsistency(sessions: [LearningSession]) -> Double {
        let hours = sessions.map { Calendar.current.component(.hour, from: $0.startTime) }
        let uniqueHours = Set(hours)
        
        // 时间越集中，一致性越高
        return 1.0 - (Double(uniqueHours.count) / 24.0)
    }
    
    private func calculateFrequencyConsistency(sessions: [LearningSession]) -> Double {
        // 基于学习间隔的标准差计算一致性
        guard sessions.count > 2 else { return 0 }
        
        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        let intervals = zip(sortedSessions.dropFirst(), sortedSessions).map {
            $0.0.startTime.timeIntervalSince($0.1.startTime)
        }
        
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intervals.count)
        let standardDeviation = sqrt(variance)
        
        // 标准差越小，一致性越高
        return max(0, 1 - (standardDeviation / mean))
    }
    
    // MARK: - 行为模式分析
    
    private func analyzeBehavioralPatterns(
        sessions: [LearningSession],
        interactions: [WordInteraction]
    ) -> BehavioralPattern {
        
        let interactionStyle = analyzeInteractionStyle(interactions: interactions)
        let navigationPattern = analyzeNavigationPattern(sessions: sessions)
        let focusPattern = analyzeFocusPattern(sessions: sessions)
        let adaptabilityScore = calculateAdaptabilityScore(sessions: sessions)
        
        return BehavioralPattern(
            interactionStyle: interactionStyle,
            navigationPattern: navigationPattern,
            focusPattern: focusPattern.averageFocus,
            adaptabilityScore: adaptabilityScore,
            preferredLearningModes: identifyPreferredLearningModes(sessions: sessions)
        )
    }
    
    private func analyzeInteractionStyle(interactions: [WordInteraction]) -> InteractionStyle {
        guard !interactions.isEmpty else { return .balanced }
        
        let lookupCount = interactions.filter { $0.type == .lookup }.count
        let _ = interactions.filter { $0.type == .skip }.count
        let totalCount = interactions.count
        
        let lookupRatio = Double(lookupCount) / Double(totalCount)
        
        switch lookupRatio {
        case 0..<0.3:
            return .explorer // 倾向于跳过，探索性学习
        case 0.3..<0.7:
            return .balanced // 平衡的查词和跳过
        default:
            return .thorough // 倾向于查词，深入学习
        }
    }
    
    private func analyzeNavigationPattern(sessions: [LearningSession]) -> NavigationPattern {
        // 分析用户在文章中的导航行为
        let avgCompletionRate = sessions.map { $0.completionRate }.reduce(0, +) / Double(sessions.count)
        let skipRate = sessions.map { 1.0 - $0.completionRate }.reduce(0, +) / Double(sessions.count)
        
        if avgCompletionRate > 0.8 {
            return .sequential // 顺序阅读
        } else if skipRate > 0.5 {
            return .selective // 选择性阅读
        } else {
            return .mixed // 混合模式
        }
    }
    
    private func analyzeFocusPattern(sessions: [LearningSession]) -> FocusPattern {
        let focusScores = sessions.map { $0.focusScore }
        let avgFocus = focusScores.reduce(0, +) / Double(focusScores.count)
        
        // 计算专注度变异性
        let variance = focusScores.map { pow($0 - avgFocus, 2) }.reduce(0, +) / Double(focusScores.count)
        let variability = sqrt(variance)
        
        return FocusPattern(
            averageFocus: avgFocus,
            focusVariability: variability,
            sustainedAttentionSpan: calculateSustainedAttentionSpan(sessions: sessions),
            distractionTriggers: identifyDistractionTriggers(sessions: sessions)
        )
    }
    
    private func calculateSustainedAttentionSpan(sessions: [LearningSession]) -> TimeInterval {
        // 计算平均持续专注时间
        var totalSustainedTime: TimeInterval = 0
        var sustainedSessions = 0
        
        for session in sessions {
            if session.focusScore > 0.7 { // 高专注度阈值
                totalSustainedTime += session.timeSpent
                sustainedSessions += 1
            }
        }
        
        return sustainedSessions > 0 ? totalSustainedTime / Double(sustainedSessions) : 0
    }
    
    private func identifyDistractionTriggers(sessions: [LearningSession]) -> [DistractionTrigger] {
        var triggers: [DistractionTrigger] = []
        
        // 分析低专注度会话的特征
        let lowFocusSessions = sessions.filter { $0.focusScore < 0.5 }
        
        if !lowFocusSessions.isEmpty {
            // 分析时间因素
            let lowFocusHours = lowFocusSessions.map { 
                Calendar.current.component(.hour, from: $0.startTime) 
            }
            let hourCounts = Dictionary(grouping: lowFocusHours, by: { $0 })
                .mapValues { $0.count }
            
            if let peakDistractionHour = hourCounts.max(by: { $0.value < $1.value })?.key {
                triggers.append(.timeOfDay(hour: peakDistractionHour))
            }
            
            // 分析难度因素
            let avgDifficulty = lowFocusSessions.map { $0.difficultyRating }.reduce(0, +) / Double(lowFocusSessions.count)
            if avgDifficulty > 4.0 {
                triggers.append(.highDifficulty)
            }
            
            // 分析会话长度因素
            let avgLength = lowFocusSessions.map { $0.timeSpent }.reduce(0, +) / Double(lowFocusSessions.count)
            if avgLength > 3600 { // 超过1小时
                triggers.append(.sessionLength)
            }
        }
        
        return triggers
    }
    
    private func calculateAdaptabilityScore(sessions: [LearningSession]) -> Double {
        // 基于用户对不同难度内容的适应能力
        let difficultyRatings = sessions.map { $0.difficultyRating }
        let completionRates = sessions.map { $0.completionRate }
        
        guard difficultyRatings.count == completionRates.count && !difficultyRatings.isEmpty else { return 0.5 }
        
        // 计算在不同难度下的表现稳定性
        var performanceByDifficulty: [Int: [Double]] = [:]
        
        for (difficulty, completion) in zip(difficultyRatings, completionRates) {
            let difficultyLevel = Int(round(difficulty))
            performanceByDifficulty[difficultyLevel, default: []].append(completion)
        }
        
        // 计算各难度级别的表现方差
        var totalVariance = 0.0
        var levelCount = 0
        
        for (_, completions) in performanceByDifficulty {
            if completions.count > 1 {
                let mean = completions.reduce(0, +) / Double(completions.count)
                let variance = completions.map { pow($0 - mean, 2) }.reduce(0, +) / Double(completions.count)
                totalVariance += variance
                levelCount += 1
            }
        }
        
        let avgVariance = levelCount > 0 ? totalVariance / Double(levelCount) : 0
        
        // 方差越小，适应性越强
        return max(0, 1 - avgVariance)
    }
    
    private func identifyPreferredLearningModes(sessions: [LearningSession]) -> [LearningMode] {
        // 基于会话特征识别偏好的学习模式
        var modes: [LearningMode] = []
        
        let avgSessionLength = sessions.map { $0.timeSpent }.reduce(0, +) / Double(sessions.count)
        let avgWordsLookedUp = sessions.map { $0.wordsLookedUp }.reduce(0, +) / sessions.count
        let avgCompletionRate = sessions.map { $0.completionRate }.reduce(0, +) / Double(sessions.count)
        
        // 基于会话长度判断
        if avgSessionLength < 900 { // 15分钟以下
            modes.append(.microLearning)
        } else if avgSessionLength > 3600 { // 1小时以上
            modes.append(.deepLearning)
        }
        
        // 基于查词频率判断
        if avgWordsLookedUp > 20 {
            modes.append(.vocabularyFocused)
        }
        
        // 基于完成率判断
        if avgCompletionRate > 0.9 {
            modes.append(.comprehensive)
        } else if avgCompletionRate < 0.6 {
            modes.append(.selective)
        }
        
        return modes.isEmpty ? [.balanced] : modes
    }
    
    // MARK: - 表现模式分析
    
    private func analyzePerformancePatterns(sessions: [LearningSession]) -> PerformancePattern {
        let _ = calculateAccuracyTrend(sessions: sessions)
        let _ = calculateSpeedTrend(sessions: sessions)
        let _ = calculatePerformanceConsistency(sessions: sessions)
        let _ = calculateImprovementRate(sessions: sessions)
        
        return PerformancePattern(
            trendDirection: .improving,
            performanceAreas: [:]
        )
    }
    
    private func calculateAccuracyTrend(sessions: [LearningSession]) -> TrendDirection {
        guard sessions.count > 1 else { return .stable }
        
        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        let completionRates = sortedSessions.map { $0.completionRate }
        
        // 简单的线性趋势分析
        let firstHalf = completionRates.prefix(completionRates.count / 2)
        let secondHalf = completionRates.suffix(completionRates.count / 2)
        
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let difference = secondAvg - firstAvg
        
        if difference > 0.1 {
            return .improving
        } else if difference < -0.1 {
            return .declining
        } else {
            return .stable
        }
    }
    
    private func calculateSpeedTrend(sessions: [LearningSession]) -> TrendDirection {
        guard sessions.count > 1 else { return .stable }
        
        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        
        // 计算阅读速度（词数/分钟）
        let speeds = sortedSessions.map { session in
            session.timeSpent > 0 ? Double(session.wordsEncountered) / (session.timeSpent / 60) : 0
        }
        
        let firstHalf = speeds.prefix(speeds.count / 2)
        let secondHalf = speeds.suffix(speeds.count / 2)
        
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let difference = secondAvg - firstAvg
        
        if difference > 10 { // 每分钟多读10个词
            return .improving
        } else if difference < -10 {
            return .declining
        } else {
            return .stable
        }
    }
    
    private func calculatePerformanceConsistency(sessions: [LearningSession]) -> Double {
        let completionRates = sessions.map { $0.completionRate }
        guard completionRates.count > 1 else { return 0 }
        
        let mean = completionRates.reduce(0, +) / Double(completionRates.count)
        let variance = completionRates.map { pow($0 - mean, 2) }.reduce(0, +) / Double(completionRates.count)
        let standardDeviation = sqrt(variance)
        
        // 标准差越小，一致性越高
        return max(0, 1 - standardDeviation)
    }
    
    private func calculateImprovementRate(sessions: [LearningSession]) -> Double {
        guard sessions.count > 1 else { return 0 }
        
        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        let firstSession = sortedSessions.first!
        let lastSession = sortedSessions.last!
        
        let timeSpan = lastSession.startTime.timeIntervalSince(firstSession.startTime)
        let performanceImprovement = lastSession.completionRate - firstSession.completionRate
        
        // 每天的改进率
        return timeSpan > 0 ? performanceImprovement / (timeSpan / (24 * 3600)) : 0
    }
    
    private func identifyStrengthAreas(sessions: [LearningSession]) -> [PerformanceArea] {
        var strengths: [PerformanceArea] = []
        
        let avgCompletion = sessions.map { $0.completionRate }.reduce(0, +) / Double(sessions.count)
        let avgFocus = sessions.map { $0.focusScore }.reduce(0, +) / Double(sessions.count)
        let avgSatisfaction = sessions.compactMap { $0.satisfactionRating }.reduce(0, +) / Double(sessions.count)
        
        if avgCompletion > 0.8 {
            strengths.append(.completion)
        }
        
        if avgFocus > 0.7 {
            strengths.append(.focus)
        }
        
        if avgSatisfaction > 4.0 {
            strengths.append(.engagement)
        }
        
        // 分析词汇学习表现
        let avgWordsPerSession = sessions.map { $0.wordsLookedUp }.reduce(0, +) / sessions.count
        if avgWordsPerSession > 15 {
            strengths.append(.vocabularyAcquisition)
        }
        
        return strengths
    }
    
    private func identifyWeaknessAreas(sessions: [LearningSession]) -> [PerformanceArea] {
        var weaknesses: [PerformanceArea] = []
        
        let avgCompletion = sessions.map { $0.completionRate }.reduce(0, +) / Double(sessions.count)
        let avgFocus = sessions.map { $0.focusScore }.reduce(0, +) / Double(sessions.count)
        let avgSatisfaction = sessions.compactMap { $0.satisfactionRating }.reduce(0, +) / Double(sessions.count)
        
        if avgCompletion < 0.6 {
            weaknesses.append(.completion)
        }
        
        if avgFocus < 0.5 {
            weaknesses.append(.focus)
        }
        
        if avgSatisfaction < 3.0 {
            weaknesses.append(.engagement)
        }
        
        // 分析时间管理
        let avgSessionLength = sessions.map { $0.timeSpent }.reduce(0, +) / Double(sessions.count)
        if avgSessionLength < 300 { // 少于5分钟
            weaknesses.append(.timeManagement)
        }
        
        return weaknesses
    }
    
    // MARK: - 参与度模式分析
    
    private func analyzeEngagementPatterns(sessions: [LearningSession]) -> EngagementPattern {
        let engagementFactors = identifyEngagementFactors(sessions: sessions)
        let retentionRisk = assessRetentionRisk(sessions: sessions)
        let distractionTriggers = identifyDistractionTriggers(sessions: sessions)
        
        return EngagementPattern(
            retentionRisk: retentionRisk,
            distractionTriggers: distractionTriggers,
            engagementFactors: engagementFactors
        )
    }
    
    private func calculateMotivationLevel(sessions: [LearningSession]) -> Double {
        // 基于学习频率、完成率和满意度计算动机水平
        let recentSessions = sessions.filter { 
            $0.startTime > Date().addingTimeInterval(-7 * 24 * 3600) 
        }
        
        let frequency = Double(recentSessions.count) / 7.0
        let avgCompletion = sessions.map { $0.completionRate }.reduce(0, +) / Double(sessions.count)
        let avgSatisfaction = sessions.compactMap { $0.satisfactionRating }.reduce(0, +) / Double(sessions.count)
        
        // 综合评分
        return min(1.0, frequency * 0.4 + avgCompletion * 0.3 + (avgSatisfaction / 5) * 0.3)
    }
    
    private func calculateSatisfactionTrend(sessions: [LearningSession]) -> TrendDirection {
        let sessionsWithRating = sessions.compactMap { session -> (Date, Double)? in
            guard let rating = session.satisfactionRating else { return nil }
            return (session.startTime, rating)
        }.sorted { $0.0 < $1.0 }
        
        guard sessionsWithRating.count > 1 else { return .stable }
        
        let ratings = sessionsWithRating.map { $0.1 }
        let firstHalf = ratings.prefix(ratings.count / 2)
        let secondHalf = ratings.suffix(ratings.count / 2)
        
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let difference = secondAvg - firstAvg
        
        if difference > 0.5 {
            return .improving
        } else if difference < -0.5 {
            return .declining
        } else {
            return .stable
        }
    }
    
    private func identifyEngagementFactors(sessions: [LearningSession]) -> [EngagementFactor] {
        var factors: [EngagementFactor] = []
        
        // 分析高满意度会话的特征
        let highSatisfactionSessions = sessions.filter { 
            ($0.satisfactionRating ?? 0) > 4.0 
        }
        
        if !highSatisfactionSessions.isEmpty {
            let avgDifficulty = highSatisfactionSessions.map { $0.difficultyRating }.reduce(0, +) / Double(highSatisfactionSessions.count)
            let avgLength = highSatisfactionSessions.map { $0.timeSpent }.reduce(0, +) / Double(highSatisfactionSessions.count)
            
            factors.append(EngagementFactor(
                name: "适宜难度",
                impact: 0.3,
                description: "难度级别 \(String(format: "%.1f", avgDifficulty)) 时满意度最高"
            ))
            
            factors.append(EngagementFactor(
                name: "理想时长",
                impact: 0.2,
                description: "学习时长 \(Int(avgLength / 60)) 分钟时效果最佳"
            ))
        }
        
        return factors
    }
    
    private func assessRetentionRisk(sessions: [LearningSession]) -> RetentionRisk {
        let recentSessions = sessions.filter { 
            $0.startTime > Date().addingTimeInterval(-14 * 24 * 3600) 
        }
        
        let frequency = Double(recentSessions.count) / 14.0
        let avgSatisfaction = sessions.compactMap { $0.satisfactionRating }.reduce(0, +) / Double(sessions.count)
        let completionTrend = calculateAccuracyTrend(sessions: sessions)
        
        // 风险评估
        var riskScore = 0.0
        
        if frequency < 0.3 { // 每天学习少于0.3次
            riskScore += 0.4
        }
        
        if avgSatisfaction < 3.0 {
            riskScore += 0.3
        }
        
        if completionTrend == .declining {
            riskScore += 0.3
        }
        
        switch riskScore {
        case 0..<0.3:
            return .low
        case 0.3..<0.6:
            return .medium
        default:
            return .high
        }
    }
    
    // MARK: - 趋势计算方法
    
    private func groupSessionsByGranularity(
        _ sessions: [LearningSession],
        granularity: TrendGranularity
    ) -> [Date: [LearningSession]] {
        
        var grouped: [Date: [LearningSession]] = [:]
        
        for session in sessions {
            let key: Date
            
            switch granularity {
            case .daily:
                key = Calendar.current.startOfDay(for: session.startTime)
            case .weekly:
                key = Calendar.current.dateInterval(of: .weekOfYear, for: session.startTime)?.start ?? session.startTime
            case .monthly:
                key = Calendar.current.dateInterval(of: .month, for: session.startTime)?.start ?? session.startTime
            }
            
            grouped[key, default: []].append(session)
        }
        
        return grouped
    }
    
    private func calculatePerformanceTrend(groupedSessions: [Date: [LearningSession]]) -> [TrendDataPoint] {
        return groupedSessions.map { date, sessions in
            let avgCompletion = sessions.map { $0.completionRate }.reduce(0, +) / Double(sessions.count)
            return TrendDataPoint(date: date, value: avgCompletion)
        }.sorted { $0.date < $1.date }
    }
    
    private func calculateEngagementTrend(groupedSessions: [Date: [LearningSession]]) -> [TrendDataPoint] {
        return groupedSessions.map { date, sessions in
            let avgFocus = sessions.map { $0.focusScore }.reduce(0, +) / Double(sessions.count)
            return TrendDataPoint(date: date, value: avgFocus)
        }.sorted { $0.date < $1.date }
    }
    
    private func calculateDifficultyTrend(groupedSessions: [Date: [LearningSession]]) -> [TrendDataPoint] {
        return groupedSessions.map { date, sessions in
            let avgDifficulty = sessions.map { $0.difficultyRating }.reduce(0, +) / Double(sessions.count)
            return TrendDataPoint(date: date, value: avgDifficulty)
        }.sorted { $0.date < $1.date }
    }
    
    private func calculateVocabularyTrend(groupedSessions: [Date: [LearningSession]]) -> [TrendDataPoint] {
        return groupedSessions.map { date, sessions in
            let avgWordsLookedUp = Double(sessions.map { $0.wordsLookedUp }.reduce(0, +)) / Double(sessions.count)
            return TrendDataPoint(date: date, value: avgWordsLookedUp)
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - 预测算法
    
    private func convertToLearningTrend(_ trendData: LearningTrendData) -> LearningTrend {
        switch trendData.overallDirection {
        case .improving:
            return .improving
        case .stable:
            return .stable
        case .declining:
            return .declining
        }
    }
    private func performPrediction(
        pattern: LearningBehaviorPattern,
        trend: LearningTrend,
        targetDate: Date,
        context: PredictionContext
    ) -> PerformancePrediction {
        
        // 基于历史趋势进行线性预测
        let performanceTrend = [
            TrendDataPoint(date: Date().addingTimeInterval(-86400 * 2), value: 0.5),
            TrendDataPoint(date: Date().addingTimeInterval(-86400), value: 0.6),
            TrendDataPoint(date: Date(), value: 0.7)
        ] // Mock performance trend data
        guard performanceTrend.count > 1 else {
            return PerformancePrediction(
                targetDate: targetDate,
                predictedPerformance: 0.5,
                confidence: 0.3,
                factors: [],
                recommendations: []
            )
        }
        
        // 计算趋势斜率
        let firstPoint = performanceTrend.first!
        let lastPoint = performanceTrend.last!
        let timeSpan = lastPoint.date.timeIntervalSince(firstPoint.date)
        let valueChange = lastPoint.value - firstPoint.value
        let slope = timeSpan > 0 ? valueChange / timeSpan : 0
        
        // 预测目标日期的表现
        let predictionTimeSpan = targetDate.timeIntervalSince(lastPoint.date)
        let predictedValue = lastPoint.value + slope * predictionTimeSpan
        
        // 计算置信度
        let confidence = calculatePredictionConfidence(
            pattern: convertToLearningPattern(from: pattern),
            trend: trend,
            context: context
        )
        
        // 识别影响因素
        let learningPattern = convertToLearningPattern(from: pattern)
        let factors = identifyPredictionFactors(pattern: learningPattern, context: context)
        
        // 生成建议
        let recommendations = generatePredictionRecommendations(
            predictedPerformance: predictedValue,
            factors: factors
        )
        
        return PerformancePrediction(
            targetDate: targetDate,
            predictedPerformance: max(0, min(1, predictedValue)),
            confidence: confidence,
            factors: factors,
            recommendations: recommendations
        )
    }
    
    private func calculatePredictionConfidence(
        pattern: LearningPattern,
        trend: LearningTrend,
        context: PredictionContext
    ) -> Double {
        
        var confidence = 0.5
        
        // 基于数据量调整置信度
        let dataPoints = [0.5, 0.6, 0.7] // Mock performance trend data.count
        confidence += min(0.3, Double(dataPoints.count) / 30.0 * 0.3)
        
        // 基于一致性调整置信度
        confidence += 0.8 // Mock consistency score * 0.2
        
        // 基于预测时间距离调整置信度
        let predictionDistance = context.targetDate.timeIntervalSince(Date())
        let maxDistance = 30 * 24 * 3600.0 // 30天
        let distanceFactor = max(0, 1 - predictionDistance / maxDistance)
        confidence *= distanceFactor
        
        return min(1.0, confidence)
    }
    
    private func identifyPredictionFactors(
        pattern: LearningPattern,
        context: PredictionContext
    ) -> [PredictionFactor] {
        
        var factors: [PredictionFactor] = []
        
        // 时间因素
        let targetHour = Calendar.current.component(.hour, from: context.targetDate)
        if [9, 10, 14, 15].contains(targetHour) { // Mock peak hours
            factors.append(PredictionFactor(
                name: "最佳学习时间",
                impact: 0.2,
                description: "目标时间是您的高效学习时段"
            ))
        }
        
        // 一致性因素
        if 0.8 > 0.7 { // Mock consistency score
            factors.append(PredictionFactor(
                name: "学习一致性",
                impact: 0.15,
                description: "您的学习习惯很规律，有助于保持表现"
            ))
        }
        
        // 适应性因素
        if 0.75 > 0.7 { // Mock adaptability score
            factors.append(PredictionFactor(
                name: "学习适应性",
                impact: 0.1,
                description: "您能很好地适应不同难度的内容"
            ))
        }
        
        return factors
    }
    
    private func generatePredictionRecommendations(
        predictedPerformance: Double,
        factors: [PredictionFactor]
    ) -> [String] {
        
        var recommendations: [String] = []
        
        if predictedPerformance < 0.6 {
            recommendations.append("建议选择较简单的学习内容")
            recommendations.append("考虑缩短学习时长")
        }
        
        if predictedPerformance > 0.8 {
            recommendations.append("可以尝试更有挑战性的内容")
            recommendations.append("适合进行深度学习")
        }
        
        // 基于因素生成个性化建议
        for factor in factors {
            if factor.name == "最佳学习时间" {
                recommendations.append("在这个时间段学习效果会更好")
            }
        }
        
        return recommendations
    }
    
    // MARK: - 数据获取方法
    
    private func fetchLearningSessions(
        userId: String,
        in timeRange: DateInterval
    ) async throws -> [LearningSession] {
        
        let predicate = #Predicate<LearningSession> { session in
            session.userId == userId &&
            session.startTime >= timeRange.start &&
            session.startTime <= timeRange.end
        }
        
        let descriptor = FetchDescriptor<LearningSession>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
    
    private func fetchWordInteractions(
        userId: String,
        in timeRange: DateInterval
    ) async throws -> [WordInteraction] {
        
        // 这里需要根据实际的WordInteraction模型实现
        // 暂时返回空数组
        return []
    }
}

// MARK: - 支持枚举和结构体

enum TrendGranularity: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
}

enum TimeSlot: CaseIterable {
    case earlyMorning, morning, afternoon, evening, night
}

enum DurationRange: CaseIterable {
    case short, medium, long, extended
}

enum InteractionStyle {
    case explorer, balanced, thorough
}

enum NavigationPattern {
    case sequential, selective, mixed
}

enum LearningMode {
    case microLearning, deepLearning, vocabularyFocused, comprehensive, selective, balanced
}

enum TrendDirection {
    case improving, stable, declining
}

enum PerformanceArea {
    case completion, focus, engagement, vocabularyAcquisition, timeManagement
}

enum RetentionRisk {
    case low, medium, high
}

enum DistractionTrigger {
    case timeOfDay(hour: Int)
    case highDifficulty
    case sessionLength
}

// 临时的WordInteraction结构，需要根据实际模型调整
struct WordInteraction {
    let id: UUID
    let userId: String
    let word: String
    let type: InteractionType
    let timestamp: Date
    
    enum InteractionType {
        case lookup, skip, bookmark
    }
}

struct PredictionContext {
    let targetDate: Date
    let expectedDifficulty: Double?
    let plannedDuration: TimeInterval?
    let contentType: String?
}

struct LearningTrendData {
    let performanceData: [TrendDataPoint]
    let engagementData: [TrendDataPoint]
    let difficultyData: [TrendDataPoint]
    let vocabularyData: [TrendDataPoint]
    let overallDirection: TrendDirection
    let confidence: Double
    let timeRange: DateInterval
}

struct TrendDataPoint {
    let date: Date
    let value: Double
}

struct EngagementFactor {
    let name: String
    let impact: Double
    let description: String
}

struct PredictionFactor {
    let name: String
    let impact: Double
    let description: String
}

struct PerformancePrediction {
    let targetDate: Date
    let predictedPerformance: Double
    let confidence: Double
    let factors: [PredictionFactor]
    let recommendations: [String]
}
    // MARK: - Helper Functions
    
    /// 将LearningBehaviorPattern转换为LearningPattern
    private func convertToLearningPattern(from behaviorPattern: LearningBehaviorPattern) -> LearningPattern {
        // 基于行为模式的特征来确定学习模式
        // 这里使用简单的逻辑，实际应用中可能需要更复杂的算法
        
        // 假设我们有一些启发式规则来进行转换
        // 这里返回一个默认值，实际应用中应该基于behaviorPattern的属性来决定
        return .balanced
    }
