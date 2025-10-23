#!/usr/bin/env swift

import Foundation

// MARK: - 测试数据结构

struct TestLearningSession {
    let userId: String
    let startTime: Date
    let timeSpent: Double // 分钟
    let wordsEncountered: Int
    let focusScore: Double // 0-1
    let difficultyLevel: Double // 0-1
    let completionRate: Double // 0-1
}

struct TestUserProgress {
    let totalWordsLearned: Int
    let averageAccuracy: Double
    let streakDays: Int
    let totalStudyTime: Double // 小时
}

struct TestVocabularyProgress {
    let masteryRate: Double
    let retentionRate: Double
    let newWordsPerSession: Double
}

struct TestArticle {
    let id: String
    let title: String
    let content: String
    let difficulty: Double
    let wordCount: Int
    let topics: [String]
}

// MARK: - 自适应学习算法测试

class AdaptiveLearningTester {
    
    // MARK: - 测试数据
    
    private let testSessions: [TestLearningSession] = [
        TestLearningSession(userId: "user1", startTime: Date().addingTimeInterval(-86400 * 7), timeSpent: 25, wordsEncountered: 150, focusScore: 0.8, difficultyLevel: 0.6, completionRate: 0.9),
        TestLearningSession(userId: "user1", startTime: Date().addingTimeInterval(-86400 * 6), timeSpent: 30, wordsEncountered: 180, focusScore: 0.7, difficultyLevel: 0.7, completionRate: 0.8),
        TestLearningSession(userId: "user1", startTime: Date().addingTimeInterval(-86400 * 5), timeSpent: 20, wordsEncountered: 120, focusScore: 0.9, difficultyLevel: 0.5, completionRate: 0.95),
        TestLearningSession(userId: "user1", startTime: Date().addingTimeInterval(-86400 * 4), timeSpent: 35, wordsEncountered: 200, focusScore: 0.6, difficultyLevel: 0.8, completionRate: 0.7),
        TestLearningSession(userId: "user1", startTime: Date().addingTimeInterval(-86400 * 3), timeSpent: 28, wordsEncountered: 165, focusScore: 0.8, difficultyLevel: 0.6, completionRate: 0.85),
        TestLearningSession(userId: "user1", startTime: Date().addingTimeInterval(-86400 * 2), timeSpent: 22, wordsEncountered: 140, focusScore: 0.9, difficultyLevel: 0.5, completionRate: 0.9),
        TestLearningSession(userId: "user1", startTime: Date().addingTimeInterval(-86400 * 1), timeSpent: 32, wordsEncountered: 190, focusScore: 0.7, difficultyLevel: 0.7, completionRate: 0.8)
    ]
    
    private let testUserProgress = TestUserProgress(
        totalWordsLearned: 1200,
        averageAccuracy: 0.82,
        streakDays: 15,
        totalStudyTime: 45.5
    )
    
    private let testVocabularyProgress = TestVocabularyProgress(
        masteryRate: 0.75,
        retentionRate: 0.88,
        newWordsPerSession: 12.5
    )
    
    private let testArticles: [TestArticle] = [
        TestArticle(id: "1", title: "Climate Change", content: "Climate change refers to long-term shifts...", difficulty: 0.8, wordCount: 500, topics: ["science", "environment"]),
        TestArticle(id: "2", title: "Daily Life", content: "Every morning, I wake up at seven...", difficulty: 0.3, wordCount: 200, topics: ["lifestyle", "routine"]),
        TestArticle(id: "3", title: "Technology Trends", content: "Artificial intelligence is transforming...", difficulty: 0.7, wordCount: 400, topics: ["technology", "AI"]),
        TestArticle(id: "4", title: "Cooking Basics", content: "Learning to cook is an essential skill...", difficulty: 0.4, wordCount: 300, topics: ["cooking", "lifestyle"]),
        TestArticle(id: "5", title: "Economic Theory", content: "Macroeconomic principles govern...", difficulty: 0.9, wordCount: 600, topics: ["economics", "theory"])
    ]
    
    // MARK: - 测试方法
    
    func runAllTests() {
        print("🧠 开始自适应学习功能测试")
        print(String(repeating: "=", count: 50))
        
        testReadingPatternAnalysis()
        testVocabularyLearningAnalysis()
        testDifficultyPreferenceAnalysis()
        testLearningEfficiencyAnalysis()
        testAdaptiveRecommendationGeneration()
        testRecommendationRanking()
        testPerformanceMetrics()
        
        print("\n✅ 所有自适应学习测试完成")
    }
    
    // MARK: - 阅读模式分析测试
    
    private func testReadingPatternAnalysis() {
        print("\n📖 测试阅读模式分析")
        print(String(repeating: "-", count: 30))
        
        let patterns = analyzeReadingPatterns(sessions: testSessions)
        
        print("平均阅读速度: \(String(format: "%.1f", patterns.averageSpeed)) 词/分钟")
        print("偏好会话长度: \(String(format: "%.1f", patterns.preferredLength)) 分钟")
        print("一致性评分: \(String(format: "%.2f", patterns.consistencyScore))")
        print("专注度评分: \(String(format: "%.2f", patterns.focusScore))")
        print("跳过率: \(String(format: "%.1f", patterns.skipRate * 100))%")
        
        // 验证结果合理性
        assert(patterns.averageSpeed > 0, "阅读速度应大于0")
        assert(patterns.consistencyScore >= 0 && patterns.consistencyScore <= 1, "一致性评分应在0-1之间")
        assert(patterns.focusScore >= 0 && patterns.focusScore <= 1, "专注度评分应在0-1之间")
        
        print("✅ 阅读模式分析测试通过")
    }
    
    // MARK: - 词汇学习分析测试
    
    private func testVocabularyLearningAnalysis() {
        print("\n📚 测试词汇学习分析")
        print(String(repeating: "-", count: 30))
        
        let analysis = analyzeVocabularyLearning(
            sessions: testSessions,
            progress: testVocabularyProgress
        )
        
        print("掌握率: \(String(format: "%.1f", analysis.masteryRate * 100))%")
        print("保持率: \(String(format: "%.1f", analysis.retentionRate * 100))%")
        print("学习速度: \(String(format: "%.1f", analysis.learningVelocity)) 词/天")
        print("最优新词数: \(analysis.optimalNewWordCount) 词/篇")
        print("词汇难度偏好: \(String(format: "%.2f", analysis.difficultyPreference))")
        
        // 验证结果合理性
        assert(analysis.masteryRate >= 0 && analysis.masteryRate <= 1, "掌握率应在0-1之间")
        assert(analysis.retentionRate >= 0 && analysis.retentionRate <= 1, "保持率应在0-1之间")
        assert(analysis.optimalNewWordCount > 0, "最优新词数应大于0")
        
        print("✅ 词汇学习分析测试通过")
    }
    
    // MARK: - 难度偏好分析测试
    
    private func testDifficultyPreferenceAnalysis() {
        print("\n🎯 测试难度偏好分析")
        print(String(repeating: "-", count: 30))
        
        let analysis = analyzeDifficultyPreference(sessions: testSessions)
        
        print("舒适区间: \(String(format: "%.2f", analysis.comfortZone.lowerBound)) - \(String(format: "%.2f", analysis.comfortZone.upperBound))")
        print("最优难度: \(String(format: "%.2f", analysis.optimalDifficulty))")
        print("难度容忍度: \(String(format: "%.2f", analysis.tolerance))")
        print("建议调整: \(String(format: "%.2f", analysis.suggestedAdjustment))")
        print("置信度: \(String(format: "%.2f", analysis.confidenceLevel))")
        
        // 验证结果合理性
        assert(analysis.comfortZone.lowerBound >= 0 && analysis.comfortZone.upperBound <= 1, "舒适区间应在0-1之间")
        assert(analysis.optimalDifficulty >= 0 && analysis.optimalDifficulty <= 1, "最优难度应在0-1之间")
        assert(analysis.confidenceLevel >= 0 && analysis.confidenceLevel <= 1, "置信度应在0-1之间")
        
        print("✅ 难度偏好分析测试通过")
    }
    
    // MARK: - 学习效率分析测试
    
    private func testLearningEfficiencyAnalysis() {
        print("\n⚡ 测试学习效率分析")
        print(String(repeating: "-", count: 30))
        
        let analysis = analyzeLearningEfficiency(
            sessions: testSessions,
            progress: testUserProgress
        )
        
        print("整体效率: \(String(format: "%.1f", analysis.overallEfficiency * 100))%")
        print("时间利用率: \(String(format: "%.1f", analysis.timeUtilization * 100))%")
        print("认知负荷: \(String(format: "%.2f", analysis.cognitiveLoad))")
        print("动机水平: \(String(format: "%.1f", analysis.motivationLevel * 100))%")
        print("效率因子数量: \(analysis.efficiencyFactors.count)")
        print("优化建议数量: \(analysis.optimizationSuggestions.count)")
        
        // 验证结果合理性
        assert(analysis.overallEfficiency >= 0 && analysis.overallEfficiency <= 1, "整体效率应在0-1之间")
        assert(analysis.timeUtilization >= 0 && analysis.timeUtilization <= 1, "时间利用率应在0-1之间")
        assert(analysis.motivationLevel >= 0 && analysis.motivationLevel <= 1, "动机水平应在0-1之间")
        
        print("✅ 学习效率分析测试通过")
    }
    
    // MARK: - 自适应推荐生成测试
    
    private func testAdaptiveRecommendationGeneration() {
        print("\n🎯 测试自适应推荐生成")
        print(String(repeating: "-", count: 30))
        
        let behaviorAnalysis = createMockBehaviorAnalysis()
        let recommendations = generateAdaptiveRecommendations(
            articles: testArticles,
            behaviorAnalysis: behaviorAnalysis
        )
        
        print("生成推荐数量: \(recommendations.count)")
        
        for (index, rec) in recommendations.enumerated() {
            print("\n推荐 \(index + 1):")
            print("  文章: \(rec.article.title)")
            print("  自适应分数: \(String(format: "%.3f", rec.adaptiveScore))")
            print("  难度因子: \(String(format: "%.2f", rec.factors.difficulty))")
            print("  词汇因子: \(String(format: "%.2f", rec.factors.vocabulary))")
            print("  长度因子: \(String(format: "%.2f", rec.factors.length))")
            print("  推荐理由: \(rec.reasons.first?.description ?? "无")")
        }
        
        // 验证推荐质量
        assert(!recommendations.isEmpty, "应生成至少一个推荐")
        assert(recommendations.first!.adaptiveScore >= recommendations.last!.adaptiveScore, "推荐应按分数降序排列")
        
        print("✅ 自适应推荐生成测试通过")
    }
    
    // MARK: - 推荐排序测试
    
    private func testRecommendationRanking() {
        print("\n📊 测试推荐排序算法")
        print(String(repeating: "-", count: 30))
        
        let behaviorAnalysis = createMockBehaviorAnalysis()
        let recommendations = generateAdaptiveRecommendations(
            articles: testArticles,
            behaviorAnalysis: behaviorAnalysis
        )
        
        // 测试不同排序策略
        let difficultyRanked = recommendations.sorted { $0.factors.difficulty > $1.factors.difficulty }
        let vocabularyRanked = recommendations.sorted { $0.factors.vocabulary > $1.factors.vocabulary }
        let adaptiveRanked = recommendations.sorted { $0.adaptiveScore > $1.adaptiveScore }
        
        print("按难度排序前3:")
        for i in 0..<min(3, difficultyRanked.count) {
            print("  \(difficultyRanked[i].article.title) - 难度因子: \(String(format: "%.2f", difficultyRanked[i].factors.difficulty))")
        }
        
        print("\n按词汇排序前3:")
        for i in 0..<min(3, vocabularyRanked.count) {
            print("  \(vocabularyRanked[i].article.title) - 词汇因子: \(String(format: "%.2f", vocabularyRanked[i].factors.vocabulary))")
        }
        
        print("\n按自适应分数排序前3:")
        for i in 0..<min(3, adaptiveRanked.count) {
            print("  \(adaptiveRanked[i].article.title) - 自适应分数: \(String(format: "%.3f", adaptiveRanked[i].adaptiveScore))")
        }
        
        print("✅ 推荐排序测试通过")
    }
    
    // MARK: - 性能指标测试
    
    private func testPerformanceMetrics() {
        print("\n⏱️ 测试性能指标")
        print(String(repeating: "-", count: 30))
        
        let startTime = Date()
        
        // 执行多次分析以测试性能
        for _ in 0..<100 {
            let _ = analyzeReadingPatterns(sessions: testSessions)
            let _ = analyzeVocabularyLearning(sessions: testSessions, progress: testVocabularyProgress)
            let _ = analyzeDifficultyPreference(sessions: testSessions)
        }
        
        let analysisTime = Date().timeIntervalSince(startTime)
        
        let behaviorAnalysis = createMockBehaviorAnalysis()
        let recommendationStartTime = Date()
        
        for _ in 0..<50 {
            let _ = generateAdaptiveRecommendations(articles: testArticles, behaviorAnalysis: behaviorAnalysis)
        }
        
        let recommendationTime = Date().timeIntervalSince(recommendationStartTime)
        
        print("分析性能 (100次): \(String(format: "%.3f", analysisTime))秒")
        print("推荐性能 (50次): \(String(format: "%.3f", recommendationTime))秒")
        print("平均分析时间: \(String(format: "%.1f", analysisTime * 10))毫秒")
        print("平均推荐时间: \(String(format: "%.1f", recommendationTime * 20))毫秒")
        
        // 性能要求验证
        assert(analysisTime / 100 < 0.1, "单次分析应在100毫秒内完成")
        assert(recommendationTime / 50 < 0.05, "单次推荐应在50毫秒内完成")
        
        print("✅ 性能指标测试通过")
    }
}

// MARK: - 算法实现

extension AdaptiveLearningTester {
    
    private func analyzeReadingPatterns(sessions: [TestLearningSession]) -> (averageSpeed: Double, preferredLength: Double, consistencyScore: Double, focusScore: Double, skipRate: Double) {
        let totalWords = sessions.reduce(0) { $0 + $1.wordsEncountered }
        let totalTime = sessions.reduce(0) { $0 + $1.timeSpent }
        let averageSpeed = totalTime > 0 ? Double(totalWords) / totalTime : 0
        
        let sessionLengths = sessions.map { $0.timeSpent }
        let preferredLength = sessionLengths.isEmpty ? 0 : sessionLengths.reduce(0, +) / Double(sessionLengths.count)
        
        let avgLength = preferredLength
        let variance = sessionLengths.map { pow($0 - avgLength, 2) }.reduce(0, +) / Double(sessionLengths.count)
        let consistencyScore = max(0, 1 - sqrt(variance) / avgLength)
        
        let focusScore = sessions.map { $0.focusScore }.reduce(0, +) / Double(sessions.count)
        
        let completionRates = sessions.map { $0.completionRate }
        let skipRate = 1 - (completionRates.reduce(0, +) / Double(completionRates.count))
        
        return (averageSpeed, preferredLength, consistencyScore, focusScore, skipRate)
    }
    
    private func analyzeVocabularyLearning(sessions: [TestLearningSession], progress: TestVocabularyProgress) -> (masteryRate: Double, retentionRate: Double, learningVelocity: Double, optimalNewWordCount: Int, difficultyPreference: Double) {
        let masteryRate = progress.masteryRate
        let retentionRate = progress.retentionRate
        
        let totalWords = sessions.reduce(0) { $0 + $1.wordsEncountered }
        let totalDays = 7.0 // 测试数据跨度
        let learningVelocity = Double(totalWords) / totalDays
        
        let avgWordsPerSession = Double(totalWords) / Double(sessions.count)
        let optimalNewWordCount = Int(avgWordsPerSession * 0.1) // 假设10%为新词
        
        let avgDifficulty = sessions.map { $0.difficultyLevel }.reduce(0, +) / Double(sessions.count)
        let difficultyPreference = avgDifficulty
        
        return (masteryRate, retentionRate, learningVelocity, optimalNewWordCount, difficultyPreference)
    }
    
    private func analyzeDifficultyPreference(sessions: [TestLearningSession]) -> (comfortZone: ClosedRange<Double>, optimalDifficulty: Double, tolerance: Double, suggestedAdjustment: Double, confidenceLevel: Double) {
        let difficulties = sessions.map { $0.difficultyLevel }
        let completionRates = sessions.map { $0.completionRate }
        
        // 找到表现最好的难度区间
        let sortedByPerformance = zip(difficulties, completionRates).sorted { $0.1 > $1.1 }
        let topPerformances = Array(sortedByPerformance.prefix(3))
        
        let optimalDifficulties = topPerformances.map { $0.0 }
        let avgOptimal = optimalDifficulties.reduce(0, +) / Double(optimalDifficulties.count)
        
        let minDifficulty = difficulties.min() ?? 0
        let maxDifficulty = difficulties.max() ?? 1
        let comfortZone = minDifficulty...maxDifficulty
        
        let tolerance = maxDifficulty - minDifficulty
        
        let currentAvg = difficulties.reduce(0, +) / Double(difficulties.count)
        let suggestedAdjustment = avgOptimal - currentAvg
        
        let confidenceLevel = min(1.0, Double(sessions.count) / 10.0) // 基于数据量
        
        return (comfortZone, avgOptimal, tolerance, suggestedAdjustment, confidenceLevel)
    }
    
    private func analyzeLearningEfficiency(sessions: [TestLearningSession], progress: TestUserProgress) -> (overallEfficiency: Double, timeUtilization: Double, cognitiveLoad: Double, motivationLevel: Double, efficiencyFactors: [String], optimizationSuggestions: [String]) {
        let avgCompletion = sessions.map { $0.completionRate }.reduce(0, +) / Double(sessions.count)
        let avgFocus = sessions.map { $0.focusScore }.reduce(0, +) / Double(sessions.count)
        let overallEfficiency = (avgCompletion + avgFocus) / 2
        
        let totalTime = sessions.reduce(0) { $0 + $1.timeSpent }
        let effectiveTime = sessions.reduce(0) { $0 + ($1.timeSpent * $1.focusScore) }
        let timeUtilization = totalTime > 0 ? effectiveTime / totalTime : 0
        
        let avgDifficulty = sessions.map { $0.difficultyLevel }.reduce(0, +) / Double(sessions.count)
        let cognitiveLoad = avgDifficulty * (1 - avgFocus)
        
        let motivationLevel = min(1.0, progress.averageAccuracy * Double(progress.streakDays) / 30.0)
        
        let efficiencyFactors = ["focus", "difficulty_match", "time_management"]
        let optimizationSuggestions = overallEfficiency < 0.7 ? ["调整学习时间", "优化内容难度"] : ["保持当前节奏"]
        
        return (overallEfficiency, timeUtilization, cognitiveLoad, motivationLevel, efficiencyFactors, optimizationSuggestions)
    }
    
    private func createMockBehaviorAnalysis() -> MockBehaviorAnalysis {
        let patterns = analyzeReadingPatterns(sessions: testSessions)
        let vocabulary = analyzeVocabularyLearning(sessions: testSessions, progress: testVocabularyProgress)
        let difficulty = analyzeDifficultyPreference(sessions: testSessions)
        let efficiency = analyzeLearningEfficiency(sessions: testSessions, progress: testUserProgress)
        
        return MockBehaviorAnalysis(
            readingPatterns: patterns,
            vocabularyLearning: vocabulary,
            difficultyPreference: difficulty,
            learningEfficiency: efficiency
        )
    }
    
    private func generateAdaptiveRecommendations(articles: [TestArticle], behaviorAnalysis: MockBehaviorAnalysis) -> [MockRecommendation] {
        return articles.map { article in
            let difficultyFactor = calculateDifficultyFactor(
                articleDifficulty: article.difficulty,
                userPreference: behaviorAnalysis.difficultyPreference.optimalDifficulty
            )
            
            let vocabularyFactor = calculateVocabularyFactor(
                articleWordCount: article.wordCount,
                userPreference: behaviorAnalysis.vocabularyLearning.optimalNewWordCount
            )
            
            let lengthFactor = calculateLengthFactor(
                articleLength: Double(article.wordCount),
                userPreference: behaviorAnalysis.readingPatterns.preferredLength * 6 // 假设每分钟6词
            )
            
            let adaptiveScore = (difficultyFactor + vocabularyFactor + lengthFactor) / 3
            
            let reasons = generateReasons(
                difficultyFactor: difficultyFactor,
                vocabularyFactor: vocabularyFactor,
                lengthFactor: lengthFactor
            )
            
            return MockRecommendation(
                article: article,
                adaptiveScore: adaptiveScore,
                factors: (difficulty: difficultyFactor, vocabulary: vocabularyFactor, length: lengthFactor),
                reasons: reasons
            )
        }.sorted { $0.adaptiveScore > $1.adaptiveScore }
    }
    
    private func calculateDifficultyFactor(articleDifficulty: Double, userPreference: Double) -> Double {
        let difference = abs(articleDifficulty - userPreference)
        return max(0, 1 - difference * 2) // 差异越小，因子越高
    }
    
    private func calculateVocabularyFactor(articleWordCount: Int, userPreference: Int) -> Double {
        let estimatedNewWords = Double(articleWordCount) * 0.1 // 假设10%为新词
        let difference = abs(estimatedNewWords - Double(userPreference))
        return max(0, 1 - difference / Double(userPreference))
    }
    
    private func calculateLengthFactor(articleLength: Double, userPreference: Double) -> Double {
        let ratio = min(articleLength, userPreference) / max(articleLength, userPreference)
        return ratio
    }
    
    private func generateReasons(difficultyFactor: Double, vocabularyFactor: Double, lengthFactor: Double) -> [MockReason] {
        var reasons: [MockReason] = []
        
        if difficultyFactor > 0.8 {
            reasons.append(MockReason(description: "难度匹配度高"))
        }
        if vocabularyFactor > 0.8 {
            reasons.append(MockReason(description: "词汇量适中"))
        }
        if lengthFactor > 0.8 {
            reasons.append(MockReason(description: "长度符合偏好"))
        }
        
        return reasons
    }
}

// MARK: - 辅助数据结构

struct MockBehaviorAnalysis {
    let readingPatterns: (averageSpeed: Double, preferredLength: Double, consistencyScore: Double, focusScore: Double, skipRate: Double)
    let vocabularyLearning: (masteryRate: Double, retentionRate: Double, learningVelocity: Double, optimalNewWordCount: Int, difficultyPreference: Double)
    let difficultyPreference: (comfortZone: ClosedRange<Double>, optimalDifficulty: Double, tolerance: Double, suggestedAdjustment: Double, confidenceLevel: Double)
    let learningEfficiency: (overallEfficiency: Double, timeUtilization: Double, cognitiveLoad: Double, motivationLevel: Double, efficiencyFactors: [String], optimizationSuggestions: [String])
}

struct MockRecommendation {
    let article: TestArticle
    let adaptiveScore: Double
    let factors: (difficulty: Double, vocabulary: Double, length: Double)
    let reasons: [MockReason]
}

struct MockReason {
    let description: String
}

// MARK: - 主程序

let tester = AdaptiveLearningTester()
tester.runAllTests()