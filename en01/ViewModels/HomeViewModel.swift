//
//  HomeViewModel.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI
import SwiftData
import Combine

/// 首页ViewModel，负责文章列表、推荐和搜索功能
@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var articles: [Article] = []
    @Published var filteredArticles: [Article] = []
    @Published var searchText: String = ""
    @Published var selectedYear: String = "全部"
    @Published var selectedDifficulty: String = "全部"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Home View Properties
    @Published var currentLevelInfo: LevelInfo = LevelInfo()
    @Published var todaySummary: TodaySummary? = nil
    @Published var streakStatus: StreakStatus? = nil
    @Published var recentArticles: [Article] = []
    @Published var recommendedArticles: [Article] = []
    @Published var recommendations: [StudyRecommendation] = []
    @Published var nextRecommendedArticle: Article? = nil
    @Published var wordsForReviewCount: Int = 0
    
    // MARK: - Cache Properties
    private var articlesCache: (articles: [Article], timestamp: Date)?
    private var recommendedCache: (articles: [Article], timestamp: Date)?
    private var recentCache: (articles: [Article], timestamp: Date)?
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟
    
    // MARK: - Services
    private let articleService: ArticleServiceProtocol
    private let userProgressService: UserProgressServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    
    // MARK: - Debounce
    private var searchCancellable: AnyCancellable?
    private var debounceTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init(
        articleService: ArticleServiceProtocol,
        userProgressService: UserProgressServiceProtocol,
        errorHandler: ErrorHandlerProtocol
    ) {
        self.articleService = articleService
        self.userProgressService = userProgressService
        self.errorHandler = errorHandler
        
        setupSearchDebounce()
        loadArticles()
    }
    
    // MARK: - Setup
    private func setupSearchDebounce() {
        searchCancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.filterArticles()
            }
    }
    
    // MARK: - Data Loading
    func loadArticles() {
        // 检查缓存
        if let cache = articlesCache,
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            self.articles = cache.articles
            self.filterArticles()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            let loadedArticles = articleService.getAllArticles()
            self.articles = loadedArticles
            self.articlesCache = (loadedArticles, Date())
            self.filterArticles()
            self.isLoading = false
            errorHandler.logSuccess("成功加载 \(loadedArticles.count) 篇文章")
        }
    }
    
    func getRecommendedArticles() -> [Article] {
        // 检查缓存
        if let cache = recommendedCache,
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            return cache.articles
        }
        
        let recommended = articleService.getRecommendedArticles(limit: 5)
        recommendedCache = (recommended, Date())
        return recommended
    }
    
    func getRecentArticles() -> [Article] {
        // 检查缓存
        if let cache = recentCache,
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            return cache.articles
        }
        
        let recent = articleService.getRecentArticles(limit: 10)
        recentCache = (recent, Date())
        return recent
    }
    
    // MARK: - Filtering
    private func filterArticles() {
        var filtered = articles
        
        // 年份筛选
        if selectedYear != "全部" {
            if let yearInt = Int(selectedYear) {
                filtered = filtered.filter { $0.year == yearInt }
            }
        }
        
        // 难度筛选
        if selectedDifficulty != "全部" {
            if let difficultyEnum = ArticleDifficulty.from(string: selectedDifficulty) {
                filtered = filtered.filter { $0.difficulty == difficultyEnum }
            }
        }
        
        // 搜索筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { article in
                article.title.localizedCaseInsensitiveContains(searchText) ||
                article.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        filteredArticles = filtered
    }
    
    // MARK: - Filter Actions
    func setYearFilter(_ year: String) {
        selectedYear = year
        filterArticles()
    }
    
    func setDifficultyFilter(_ difficulty: String) {
        selectedDifficulty = difficulty
        filterArticles()
    }
    
    func clearFilters() {
        selectedYear = "全部"
        selectedDifficulty = "全部"
        searchText = ""
        filterArticles()
    }
    
    // MARK: - Search
    func performSearch() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    self.filterArticles()
                }
            }
        }
    }
    
    // MARK: - Article Actions
    func getArticlesByYear(_ year: String) -> [Article] {
        if let yearInt = Int(year) {
            return articles.filter { $0.year == yearInt }
        }
        return []
    }
    
    func getArticlesByDifficulty(_ difficulty: String) -> [Article] {
        if let difficultyEnum = ArticleDifficulty.from(string: difficulty) {
            return articles.filter { $0.difficulty == difficultyEnum }
        }
        return []
    }
    
    func selectArticle(by articleId: String) {
        // 根据ID查找文章并进行相应操作
        if let article = articles.first(where: { $0.id.uuidString == articleId }) {
            // 可以在这里添加选择文章的逻辑，比如记录访问等
            errorHandler.logSuccess("选择文章: \(article.title)")
        }
    }
    
    // MARK: - Data Management
    func refreshData() {
        // 清除缓存并重新加载
        articlesCache = nil
        recommendedCache = nil
        recentCache = nil
        
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            // 先加载文章数据
            let loadedArticles = articleService.getAllArticles()
            self.articles = loadedArticles
            self.articlesCache = (loadedArticles, Date())
            self.filterArticles()
            
            // 然后加载HomeView所需的数据
            await loadHomeData()
            
            // 所有数据加载完成后更新状态
            self.isLoading = false
            errorHandler.logSuccess("首页数据刷新完成")
        }
    }
    
    @MainActor
    private func loadHomeData() async {
        // 加载今日总结
        todaySummary = await getTodaySummary()
        
        // 加载连续学习状态
        streakStatus = getStreakStatus()
        
        // 加载推荐文章
        recommendedArticles = getRecommendedArticles()
        nextRecommendedArticle = recommendedArticles.first
        
        // 加载最近文章
        recentArticles = getRecentArticles()
        
        // 加载学习建议
        recommendations = getStudyRecommendations()
        
        // 加载待复习词汇数量
        wordsForReviewCount = await getWordsForReviewCount()
    }
    
    private func getStudyRecommendations() -> [StudyRecommendation] {
        // 返回一些默认的学习建议
        return [
            StudyRecommendation(
                type: .startLearning,
                title: "开始今日学习",
                description: "完成每日阅读目标",
                priority: .high
            ),
            StudyRecommendation(
                type: .reviewWords,
                title: "复习词汇",
                description: "巩固已学词汇",
                priority: .medium
            )
        ]
    }
    
    @MainActor
    private func getWordsForReviewCount() async -> Int {
        // 从用户进度服务获取待复习词汇数量
        do {
            let vocabularyStats = try await userProgressService.getVocabularyStatistics()
            return vocabularyStats.wordsNeedingReview
        } catch {
            errorHandler.handle(error, context: "HomeViewModel.getWordsForReviewCount")
            return 0
        }
    }
    
    func clearCache() {
        articlesCache = nil
        recommendedCache = nil
        recentCache = nil
    }
    
    // MARK: - Today Summary (保持兼容性)
    @MainActor
    func getTodaySummary() async -> TodaySummary {
        // 从UserProgressService获取今日数据
        do {
            let todayStats = try await userProgressService.getTodayStatistics()
            return TodaySummary(
                readingTime: todayStats.readingTime,
                articlesRead: todayStats.articlesRead,
                wordsLookedUp: todayStats.wordsLookedUp,
                reviewsCompleted: todayStats.reviewsCompleted,
                dailyReadingGoalProgress: todayStats.dailyReadingGoalProgress,
                consecutiveDays: todayStats.consecutiveDays,
                isGoalAchieved: todayStats.dailyReadingGoalProgress >= 1.0
            )
        } catch {
            errorHandler.handle(error, context: "HomeViewModel.getTodaySummary")
            return TodaySummary(
                readingTime: 0,
                articlesRead: 0,
                wordsLookedUp: 0,
                reviewsCompleted: 0,
                dailyReadingGoalProgress: 0,
                consecutiveDays: 0,
                isGoalAchieved: false
            )
        }
    }
    
    // MARK: - Streak Status (保持兼容性)
    func getStreakStatus() -> StreakStatus {
        let consecutiveDays = userProgressService.getConsecutiveDays()
        let todayRecord = userProgressService.getTodayRecord()
        let hasStudiedToday = todayRecord != nil && (todayRecord!.readingTime > 0 || todayRecord!.articlesRead > 0)
        let isAtRisk = !hasStudiedToday && consecutiveDays > 0
        
        let statusMessage: String
        let statusColor: Color
        
        if hasStudiedToday {
            statusMessage = "今日已学习"
            statusColor = .green
        } else if isAtRisk {
            statusMessage = "连续记录有风险"
            statusColor = .orange
        } else {
            statusMessage = "继续保持"
            statusColor = .blue
        }
        
        return StreakStatus(
            consecutiveDays: consecutiveDays,
            hasStudiedToday: hasStudiedToday,
            isAtRisk: isAtRisk,
            statusMessage: statusMessage,
            statusColor: statusColor
        )
    }
    
    // MARK: - Navigation Methods
    
    func selectReadingTab() {
        // 切换到阅读标签页的逻辑
        // 这里可以通过通知或委托模式来实现标签页切换
        NotificationCenter.default.post(name: NSNotification.Name("SelectReadingTab"), object: nil)
    }
    
    func selectVocabularyTab() {
        NotificationCenter.default.post(name: NSNotification.Name("SelectVocabularyTab"), object: nil)
    }
    
    func selectProgressTab() {
        NotificationCenter.default.post(name: NSNotification.Name("SelectProgressTab"), object: nil)
    }
    
    // MARK: - Reading Actions
    
    func startReading(_ article: Article) {
        // 通过通知或委托模式启动阅读
        NotificationCenter.default.post(name: NSNotification.Name("StartReading"), object: article)
    }
    
    // MARK: - Computed Properties
    var availableYears: [String] {
        let years = Set(articles.map { $0.year })
        return ["全部"] + years.sorted().map { String($0) }
    }
    
    var availableDifficulties: [String] {
        let difficulties = Set(articles.map { $0.difficulty.rawValue })
        return ["全部"] + difficulties.sorted()
    }
    
    var hasArticles: Bool {
        !articles.isEmpty
    }
    
    var hasFilteredResults: Bool {
        !filteredArticles.isEmpty
    }
    
    var isSearching: Bool {
        !searchText.isEmpty
    }
    
    var isFiltering: Bool {
        selectedYear != "全部" || selectedDifficulty != "全部"
    }
}

// MARK: - Error Handling
extension HomeViewModel {
    func clearError() {
        errorMessage = nil
    }
    
    private func handleError(_ error: Error, context: String) {
        errorHandler.handle(error, context: context)
        errorMessage = "操作失败，请重试"
    }
}