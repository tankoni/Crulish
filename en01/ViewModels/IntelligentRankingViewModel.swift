//
//  IntelligentRankingViewModel.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation
import SwiftUI
import Combine

@MainActor
class IntelligentRankingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var rankedArticles: [ArticleMatchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSortOption: RankingSortOption = .matchScore
    @Published var selectedReadingMode: ReadingMode = .yearlyExams
    
    // 新增：自适应推荐相关属性
    @Published var adaptiveRecommendations: [AdaptiveArticleRecommendation] = []
    @Published var isAdaptiveMode = false
    @Published var adaptiveWeight: Double = 0.7
    @Published var showAdaptiveInsights = false
    @Published var adaptiveWeights: AdaptiveWeights = .default
    @Published var adaptiveMode: AdaptiveMode = .balanced
    @Published var currentLearningInsights: LearningInsights?
    
    // MARK: - Dependencies
    private let rankingService: IntelligentRankingService
    private let articleService: ArticleServiceProtocol
    private let dictionaryService: DictionaryServiceProtocol
    private let userProgressService: UserProgressServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    private let soloArticleService: SoloArticleService
    
    // 新增：自适应学习服务
    private var adaptiveLearningService: AdaptiveLearningService?
    private var adaptiveRecommendationEngine: AdaptiveRecommendationEngine?
    
    private var cancellables = Set<AnyCancellable>()
    private var allRankedResults: [ArticleMatchResult] = []
    
    // 缓存相关
    private var lastRankingTimestamp: Date?
    private let rankingCacheValidityDuration: TimeInterval = 86400 // 24小时
    
    // 新增：自适应推荐缓存
    private var lastAdaptiveRecommendationTimestamp: Date?
    private let adaptiveCacheValidityDuration: TimeInterval = 3600 // 1小时
    
    // MARK: - Initialization
    init(
        articleService: ArticleServiceProtocol,
        dictionaryService: DictionaryServiceProtocol,
        userProgressService: UserProgressServiceProtocol,
        errorHandler: ErrorHandlerProtocol,
        soloArticleService: SoloArticleService
    ) {
        self.articleService = articleService
        self.dictionaryService = dictionaryService
        self.userProgressService = userProgressService
        self.errorHandler = errorHandler
        self.soloArticleService = soloArticleService
        self.rankingService = IntelligentRankingService(
            dictionaryService: dictionaryService
        )
        
        setupNotificationListeners()
        setupAdaptiveLearning()
    }
    
    // 新增：设置自适应学习服务
    private func setupAdaptiveLearning() {
        // 从ServiceContainer获取自适应学习服务
        self.adaptiveLearningService = ServiceContainer.shared.getAdaptiveLearningService()
        
        // 从ServiceContainer获取自适应推荐引擎
        self.adaptiveRecommendationEngine = ServiceContainer.shared.getAdaptiveRecommendationEngine()
        
        // 配置推荐引擎到排序服务
        if let engine = adaptiveRecommendationEngine {
            rankingService.setAdaptiveRecommendationEngine(engine)
        }
    }
    
    // MARK: - Public Methods
    
    func loadRankedArticles() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let articles = try await loadArticles()
            let userVocabulary = try await loadUserVocabulary()
            
            if isAdaptiveMode {
                // 使用混合推荐
                let results = try await rankingService.getHybridRecommendations(
                    articles: articles,
                    userVocabulary: userVocabulary,
                    adaptiveWeight: adaptiveWeight
                )
                allRankedResults = results
                
                // 同时获取纯自适应推荐用于展示洞察
                adaptiveRecommendations = try await rankingService.getAdaptiveRecommendations(
                    articles: articles,
                    userVocabulary: userVocabulary
                )
                lastAdaptiveRecommendationTimestamp = Date()
            } else {
                // 使用传统推荐
                let results = await rankingService.rankArticles(articles, userVocabulary: userVocabulary)
                allRankedResults = results
            }
            
            sortArticles(by: selectedSortOption)
            lastRankingTimestamp = Date()
            
            // 记录用户体验
            userProgressService.addExperience(5, for: .readArticle)
            
        } catch {
            errorMessage = "加载文章失败: \(error.localizedDescription)"
            errorHandler.handle(AppError.unknown(error), context: "IntelligentRankingViewModel.loadRankedArticles")
        }
        
        isLoading = false
    }
    
    // 新增：切换自适应模式
    func toggleAdaptiveMode() async {
        isAdaptiveMode.toggle()
        await loadRankedArticles()
    }
    
    // 新增：调整自适应权重
    func updateAdaptiveWeight(_ weight: Double) async {
        adaptiveWeight = max(0.0, min(1.0, weight))
        if isAdaptiveMode {
            await loadRankedArticles()
        }
    }
    
    // 新增：获取自适应学习洞察
    func getAdaptiveLearningInsights() async -> LearningInsights? {
        guard let adaptiveService = adaptiveLearningService else { return nil }
        
        do {
            let analysis = try await adaptiveService.performLearningAnalysis(userId: "default")
            
            // 将分析结果转换为LearningInsights
            let insights = LearningInsights(
                learningPattern: .balanced,
                recommendationConfidence: analysis.difficultyPreference.confidenceLevel,
                adaptabilityScore: analysis.learningEfficiency.overallEfficiency * 10,
                vocabularyTrend: .stable,
                readingSpeedTrend: .stable,
                comprehensionTrend: .stable,
                vocabularyMasteryRate: Int(analysis.vocabularyLearning.masteryRate * 100),
                averageReadingSpeed: Int(analysis.readingPatterns.averageReadingSpeed),
                comprehensionAccuracy: 85,
                recommendationReasons: analysis.recommendedAdjustments.prefix(3).map { $0.description },
                learningRecommendations: analysis.learningEfficiency.optimizationSuggestions.prefix(2).map { $0.description }
            )
            
            return insights
        } catch {
            errorHandler.handle(AppError.unknown(error), context: "IntelligentRankingViewModel.getAdaptiveLearningInsights")
            return nil
        }
    }
    
    // 新增：获取推荐理由
    func getRecommendationReason(for articleId: UUID) -> String? {
        guard let recommendation = adaptiveRecommendations.first(where: { $0.article.id == articleId }) else {
            return nil
        }
        // 返回第一个推荐理由的描述，如果没有则返回nil
        return recommendation.recommendationReasons.first?.description
    }
    
    // 新增：记录文章交互
    func recordArticleInteraction(_ interaction: ArticleInteraction) async {
        guard let adaptiveService = adaptiveLearningService else { return }
        
        do {
            try await adaptiveService.recordLearningBehavior(
                userId: "default",
                behavior: LearningBehavior(
                    timestamp: Date(),
                    behaviorType: LearningBehaviorType.articleRead,
                    context: ["articleId": interaction.articleId.uuidString],
                    outcome: interaction.completed ? LearningOutcome.success : LearningOutcome.partial,
                    duration: interaction.duration
                )
            )
        } catch {
            errorHandler.handle(AppError.unknown(error), context: "IntelligentRankingViewModel.recordArticleInteraction")
        }
    }
    
    /// 切换阅读模式
    func switchReadingMode(to mode: ReadingMode) async {
        selectedReadingMode = mode
        await loadRankedArticles()
    }
    
    func getRankingStatistics() -> RankingStatistics {
        let totalArticles = allRankedResults.count
        let averageScore = allRankedResults.isEmpty ? 0.0 : 
            allRankedResults.map { $0.matchScore }.reduce(0, +) / Double(totalArticles)
        
        var difficultyDistribution: [IntelligentRankingDifficultyLevel: Int] = [:]
        var recommendationDistribution: [RecommendationLevel: Int] = [:]
        
        for result in allRankedResults {
            difficultyDistribution[result.difficulty, default: 0] += 1
            recommendationDistribution[result.recommendation, default: 0] += 1
        }
        
        return RankingStatistics(
            totalArticles: totalArticles,
            averageMatchScore: averageScore,
            difficultyDistribution: difficultyDistribution,
            recommendationDistribution: recommendationDistribution
        )
    }
    
    func getStatisticsForCurrentMode() -> (totalArticles: Int, averageMatchScore: Double, difficultyDistribution: [IntelligentRankingDifficultyLevel: Int]) {
        switch selectedReadingMode {
        case .yearlyExams:
            let stats = getRankingStatistics()
            return (stats.totalArticles, stats.averageMatchScore, stats.difficultyDistribution)
        case .soloArticles:
            return getSoloStatistics()
        }
    }
    
    /// 按指定选项排序文章
    @MainActor
    func sortArticles(by option: RankingSortOption) {
        selectedSortOption = option
        rankedArticles = rankingService.sortResults(allRankedResults, by: option)
    }
    
    /// 刷新排序结果
    func refreshRanking() async {
        clearCache()
        lastRankingTimestamp = nil
        await loadRankedArticles()
        // 记录用户刷新排序的行为，给予阅读相关经验奖励
        userProgressService.addExperience(5, for: .readArticle)
    }
    

    
    /// 获取推荐文章（匹配度最高的前N篇）
    func getRecommendedArticles(limit: Int = 5) -> [ArticleMatchResult] {
        return Array(rankedArticles.prefix(limit))
    }
    
    /// 根据难度筛选文章
    func filterArticlesByDifficulty(_ difficulty: IntelligentRankingDifficultyLevel) -> [ArticleMatchResult] {
        return rankedArticles.filter { $0.difficulty == difficulty }
    }
    
    /// 根据推荐等级筛选文章
    func filterArticlesByRecommendation(_ recommendation: RecommendationLevel) -> [ArticleMatchResult] {
        return rankedArticles.filter { $0.recommendation == recommendation }
    }
    
    // MARK: - Private Methods
    
    // MARK: - Solo文章相关方法
    
    /// 加载solo文章的匹配度结果
    private func loadSoloArticles() async {
        do {
            let userVocabulary = await dictionaryService.getUserWordRecords()
            let matchResults = await soloArticleService.getRankedSoloArticles(userVocabulary: userVocabulary)
            
            await MainActor.run {
                self.rankedArticles = matchResults
                print("✅ 成功加载solo文章匹配结果，共\(matchResults.count)篇")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "加载solo文章失败: \(error.localizedDescription)"
                print("❌ 加载solo文章失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 获取solo文章的统计信息
    func getSoloStatistics() -> (totalArticles: Int, averageMatchScore: Double, difficultyDistribution: [IntelligentRankingDifficultyLevel: Int]) {
        return soloArticleService.getSoloArticleStatistics(matchResults: rankedArticles)
    }
    
    // 移除重复的排序方法，使用 IntelligentRankingService 的排序方法
    
    /// 清除缓存
    private func clearCache() {
        allRankedResults.removeAll()
        lastRankingTimestamp = nil
    }
    
    private func loadArticles() async throws -> [Article] {
        switch selectedReadingMode {
        case .yearlyExams:
            return articleService.getAllArticles()
        case .soloArticles:
            return await soloArticleService.getAllSoloArticles()
        }
    }
    
    private func loadUserVocabulary() async throws -> [UserWord] {
        // 从词典服务获取用户词汇数据
        return await MainActor.run {
            dictionaryService.getUserWordRecords()
        }
    }
    
    private func setupNotificationListeners() {
        // 监听词汇测试完成通知
        NotificationCenter.default.publisher(for: .init("VocabularyTestCompleted"))
            .sink { [weak self] _ in
                Task {
                    await self?.refreshRanking()
                }
            }
            .store(in: &cancellables)
        
        // 监听文章更新通知
        NotificationCenter.default.publisher(for: .init("ArticlesUpdated"))
            .sink { [weak self] _ in
                Task {
                    await self?.refreshRanking()
                }
            }
            .store(in: &cancellables)
        
        // 监听词汇更新通知
        NotificationCenter.default.publisher(for: .init("VocabularyUpdated"))
            .sink { [weak self] _ in
                Task {
                    await self?.refreshRanking()
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - 排序统计信息
struct RankingStatistics {
    let totalArticles: Int
    let averageMatchScore: Double
    let difficultyDistribution: [IntelligentRankingDifficultyLevel: Int]
    let recommendationDistribution: [RecommendationLevel: Int]
    
    var formattedAverageScore: String {
        return String(format: "%.1f", averageMatchScore)
    }
    
    var mostCommonDifficulty: IntelligentRankingDifficultyLevel? {
        return difficultyDistribution.max { $0.value < $1.value }?.key
    }
    
    var mostCommonRecommendation: RecommendationLevel? {
        return recommendationDistribution.max { $0.value < $1.value }?.key
    }
}

// MARK: - 扩展：便利方法
extension IntelligentRankingViewModel {
    
    /// 获取特定文章的详细分析
    func getArticleAnalysis(for articleId: UUID) -> ArticleMatchResult? {
        return rankedArticles.first { $0.article.id == articleId }
    }
    
    /// 检查是否需要更新排序
    var needsRankingUpdate: Bool {
        guard let lastTimestamp = lastRankingTimestamp else { return true }
        return Date().timeIntervalSince(lastTimestamp) > rankingCacheValidityDuration
    }
    
    /// 获取排序性能指标
    func getPerformanceMetrics() -> (cacheHitRate: Double, lastUpdateTime: Date?) {
        let cacheHitRate = lastRankingTimestamp != nil && !needsRankingUpdate ? 1.0 : 0.0
        return (cacheHitRate, lastRankingTimestamp)
    }
}