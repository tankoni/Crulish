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
    
    // MARK: - Dependencies
    private let rankingService: IntelligentRankingService
    private let articleService: ArticleServiceProtocol
    private let dictionaryService: DictionaryServiceProtocol
    private let userProgressService: UserProgressServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    
    private var cancellables = Set<AnyCancellable>()
    private var allRankedResults: [ArticleMatchResult] = []
    
    // 缓存相关
    private var lastRankingTimestamp: Date?
    private let rankingCacheValidityDuration: TimeInterval = 600 // 10分钟
    
    // MARK: - Initialization
    init(
        articleService: ArticleServiceProtocol,
        dictionaryService: DictionaryServiceProtocol,
        userProgressService: UserProgressServiceProtocol,
        errorHandler: ErrorHandlerProtocol
    ) {
        self.articleService = articleService
        self.dictionaryService = dictionaryService
        self.userProgressService = userProgressService
        self.errorHandler = errorHandler
        self.rankingService = IntelligentRankingService(
            dictionaryService: dictionaryService
        )
        
        setupNotificationListeners()
    }
    
    // MARK: - Public Methods
    
    /// 加载排序后的文章
    func loadRankedArticles() async {
        // 检查缓存是否有效
        if let lastTimestamp = lastRankingTimestamp,
           Date().timeIntervalSince(lastTimestamp) < rankingCacheValidityDuration,
           !allRankedResults.isEmpty {
            sortArticles(by: selectedSortOption)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 并行加载文章和词汇数据
            async let articlesTask = loadArticles()
            async let vocabularyTask = loadUserVocabulary()
            
            let (articles, vocabulary) = try await (articlesTask, vocabularyTask)
            
            // 执行智能排序
            let rankedResults = await rankingService.rankArticles(articles, userVocabulary: vocabulary)
            
            // 更新结果
            allRankedResults = rankedResults
            lastRankingTimestamp = Date()
            sortArticles(by: selectedSortOption)
            
            errorHandler.logSuccess("智能排序完成，共 \(rankedResults.count) 篇文章")
            
        } catch {
            errorMessage = "加载文章排序失败: \(error.localizedDescription)"
            errorHandler.handle(error, context: "智能排序失败")
        }
        
        isLoading = false
    }
    
    /// 按指定选项排序文章
    func sortArticles(by option: RankingSortOption) {
        selectedSortOption = option
        rankedArticles = rankingService.sortResults(allRankedResults, by: option)
    }
    
    /// 刷新排序结果
    func refreshRanking() async {
        clearCache()
        lastRankingTimestamp = nil
        await loadRankedArticles()
    }
    
    /// 获取排序统计信息
    func getRankingStatistics() -> RankingStatistics {
        let totalArticles = rankedArticles.count
        let averageMatchScore = rankedArticles.isEmpty ? 0 : rankedArticles.map { $0.matchScore }.reduce(0, +) / Double(totalArticles)
        
        let difficultyDistribution = Dictionary(grouping: rankedArticles) { $0.difficulty }
            .mapValues { $0.count }
        
        let recommendationDistribution = Dictionary(grouping: rankedArticles) { $0.recommendation }
            .mapValues { $0.count }
        
        return RankingStatistics(
            totalArticles: totalArticles,
            averageMatchScore: averageMatchScore,
            difficultyDistribution: difficultyDistribution,
            recommendationDistribution: recommendationDistribution
        )
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
    
    // 移除重复的排序方法，使用 IntelligentRankingService 的排序方法
    
    /// 清除缓存
    private func clearCache() {
        allRankedResults.removeAll()
        lastRankingTimestamp = nil
    }
    
    private func loadArticles() async throws -> [Article] {
        let articles = articleService.getAllArticles()
        return articles
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