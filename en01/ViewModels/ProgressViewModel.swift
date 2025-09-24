//
//  ProgressViewModel.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI
import SwiftData
import Combine

/// 进度ViewModel，负责学习进度统计和数据分析功能
@MainActor
class ProgressViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var todayStats: TodayStatistics = TodayStatistics()
    @Published var weeklyStats: WeeklyStatistics = WeeklyStatistics()
    @Published var monthlyStats: MonthlyStatistics = MonthlyStatistics()
    @Published var overallStats: OverallStatistics = OverallStatistics()
    @Published var readingStats: ReadingStatisticsUI = ReadingStatisticsUI()
    @Published var vocabularyStats: VocabularyProgressStats = VocabularyProgressStats()
    @Published var achievementStats: AchievementStatistics = AchievementStatistics()
    
    @Published var selectedTimeRange: String = "week"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Chart Data
    @Published var readingTimeChartData: [ChartDataPoint] = []
    @Published var vocabularyChartData: [ChartDataPoint] = []
    @Published var progressChartData: [ChartDataPoint] = []
    
    // MARK: - Cache Properties
    private var statsCache: [String: (stats: Any, timestamp: Date)] = [:]
    private var chartDataCache: [String: (data: [ChartDataPoint], timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟
    
    // MARK: - Services
    private let userProgressService: UserProgressServiceProtocol
    private let articleService: ArticleServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    
    // MARK: - Initialization
    init(
        userProgressService: UserProgressServiceProtocol,
        articleService: ArticleServiceProtocol,
        errorHandler: ErrorHandlerProtocol
    ) {
        self.userProgressService = userProgressService
        self.articleService = articleService
        self.errorHandler = errorHandler
        
        loadAllStatistics()
    }
    
    // MARK: - Data Loading
    func loadAllStatistics() {
        isLoading = true
        errorMessage = nil
        
        Task {
            await loadTodayStatistics()
            await loadWeeklyStatistics()
            await loadMonthlyStatistics()
            await loadOverallStatistics()
            await loadReadingStatistics()
            await loadVocabularyStatistics()
            await loadAchievementStatistics()
            await loadChartData()
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadTodayStatistics() async {
        do {
            let stats = try await userProgressService.getTodayStatistics()
            self.todayStats = stats
            errorHandler.logSuccess("加载今日统计成功")
        } catch {
            errorHandler.handle(error, context: "ProgressViewModel.loadTodayStatistics")
        }
    }
    
    private func loadWeeklyStatistics() async {
        // 检查缓存
        if let cache = statsCache["week"],
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            if let stats = cache.stats as? WeeklyStatistics {
                await MainActor.run {
                    self.weeklyStats = stats
                }
                return
            }
        }
        
        do {
            let stats = try await userProgressService.getWeeklyStatistics()
            self.weeklyStats = stats
            self.statsCache["week"] = (stats, Date())
            
            errorHandler.logSuccess("加载周统计成功")
        } catch {
            errorHandler.handle(error, context: "ProgressViewModel.loadWeeklyStatistics")
        }
    }
    
    private func loadMonthlyStatistics() async {
        // 检查缓存
        if let cache = statsCache["month"],
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            if let stats = cache.stats as? MonthlyStatistics {
                await MainActor.run {
                    self.monthlyStats = stats
                }
                return
            }
        }
        
        do {
            let stats = try await userProgressService.getMonthlyStatistics()
            self.monthlyStats = stats
            self.statsCache["month"] = (stats, Date())
            
            errorHandler.logSuccess("加载月统计成功")
        } catch {
            errorHandler.handle(error, context: "ProgressViewModel.loadMonthlyStatistics")
        }
    }
    
    private func loadOverallStatistics() async {
        do {
            let stats = try await userProgressService.getOverallStatistics()
            self.overallStats = stats
            errorHandler.logSuccess("加载总体统计成功")
        } catch {
            errorHandler.handle(error, context: "ProgressViewModel.loadOverallStatistics")
        }
    }
    
    private func loadReadingStatistics() async {
        do {
            let domainStats = try await articleService.getReadingStatistics()
            // 将领域模型映射到UI模型
            let uiStats = ReadingStatisticsUI(
                completedArticles: domainStats.totalArticlesRead,
                inProgressArticles: 0, // 领域模型中没有此字段，设为默认值
                bookmarkedArticles: 0, // 领域模型中没有此字段，设为默认值
                averageReadingTime: domainStats.totalReadingTime / max(1, TimeInterval(domainStats.totalArticlesRead)),
                favoriteTopics: domainStats.favoriteCategories,
                difficultyDistribution: [:], // 领域模型中没有此字段，设为默认值
                yearDistribution: [:] // 领域模型中没有此字段，设为默认值
            )
            self.readingStats = uiStats
            errorHandler.logSuccess("加载阅读统计成功")
        } catch {
            errorHandler.handle(error, context: "ProgressViewModel.loadReadingStatistics")
        }
    }
    
    private func loadVocabularyStatistics() async {
        do {
            let stats = try await userProgressService.getVocabularyProgressStatistics()
            await MainActor.run {
                self.vocabularyStats = VocabularyProgressStats(
                    totalWords: stats.totalWords,
                    masteredWords: stats.masteredWords,
                    learningWords: stats.learningWords,
                    reviewWords: stats.reviewWords,
                    masteryRate: stats.masteryRate,
                    weeklyNewWords: stats.weeklyNewWords,
                    monthlyNewWords: stats.monthlyNewWords,
                    averageReviewAccuracy: stats.averageReviewAccuracy
                )
            }
            errorHandler.logSuccess("加载词汇统计成功")
        } catch {
            errorHandler.handle(error, context: "ProgressViewModel.loadVocabularyStatistics")
        }
    }
    
    private func loadAchievementStatistics() async {
        do {
            let stats = try await userProgressService.getAchievementStatistics()
            await MainActor.run {
                self.achievementStats = AchievementStatistics(
                    totalAchievements: stats.totalAchievements,
                    unlockedAchievements: stats.unlockedAchievements,
                    recentAchievements: stats.recentAchievements,
                    nextMilestones: stats.nextMilestones
                )
            }
            errorHandler.logSuccess("加载成就统计成功")
        } catch {
            errorHandler.handle(error, context: "ProgressViewModel.loadAchievementStatistics")
        }
    }
    
    private func loadChartData() async {
        await loadReadingTimeChartData()
        await loadVocabularyChartData()
        await loadProgressChartData()
    }
    
    private func loadReadingTimeChartData() async {
        let cacheKey = "readingTime_\(selectedTimeRange)"
        
        // 检查缓存
        if let cache = chartDataCache[cacheKey],
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            await MainActor.run {
                self.readingTimeChartData = cache.data
            }
            return
        }
        
        do {
            let timeRange = TimeRange(rawValue: selectedTimeRange) ?? .week
            let data = try await userProgressService.getReadingTimeChartData(for: timeRange)
            let chartData = data.map { ChartDataPoint(date: $0.date, value: $0.value, label: $0.label) }
            
            await MainActor.run {
                self.readingTimeChartData = chartData
                self.chartDataCache[cacheKey] = (chartData, Date())
            }
        } catch {
            errorHandler.handle(error, context: "ProgressViewModel.loadReadingTimeChartData")
        }
    }
    
    private func loadVocabularyChartData() async {
        let cacheKey = "vocabulary_\(selectedTimeRange)"
        
        // 检查缓存
        if let cache = chartDataCache[cacheKey],
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            await MainActor.run {
                self.vocabularyChartData = cache.data
            }
            return
        }
        
        do {
            let timeRange = TimeRange(rawValue: selectedTimeRange) ?? .week
            let data = try await userProgressService.getVocabularyChartData(for: timeRange)
            let chartData = data.map { ChartDataPoint(date: $0.date, value: $0.value, label: $0.label) }
            
            await MainActor.run {
                self.vocabularyChartData = chartData
                self.chartDataCache[cacheKey] = (chartData, Date())
            }
        } catch {
            errorHandler.handle(error, context: "ProgressViewModel.loadVocabularyChartData")
        }
    }
    
    private func loadProgressChartData() async {
        let cacheKey = "progress_\(selectedTimeRange)"
        
        // 检查缓存
        if let cache = chartDataCache[cacheKey],
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            await MainActor.run {
                self.progressChartData = cache.data
            }
            return
        }
        
        do {
            let timeRange = TimeRange(rawValue: selectedTimeRange) ?? .week
            let data = try await userProgressService.getProgressChartData(for: timeRange)
            let chartData = data.map { ChartDataPoint(date: $0.date, value: $0.value, label: $0.label) }
            
            await MainActor.run {
                self.progressChartData = chartData
                self.chartDataCache[cacheKey] = (chartData, Date())
            }
        } catch {
            errorHandler.handle(error, context: "ProgressViewModel.loadProgressChartData")
        }
    }
    
    // MARK: - Time Range Selection
    func setTimeRange(_ timeRange: String) {
        selectedTimeRange = timeRange
        
        Task {
            await loadChartData()
        }
    }
    
    // MARK: - Data Refresh
    func refreshData() {
        // 清除所有缓存
        statsCache.removeAll()
        chartDataCache.removeAll()
        
        // 重新加载数据
        loadAllStatistics()
    }
    
    func refreshReadingStats() {
        Task {
            await loadReadingStatistics()
            await loadReadingTimeChartData()
        }
    }
    
    func refreshVocabularyStats() {
        Task {
            await loadVocabularyStatistics()
            await loadVocabularyChartData()
        }
    }
    
    // MARK: - Cache Management
    func clearCache() {
        statsCache.removeAll()
        chartDataCache.removeAll()
    }
    
    // MARK: - Export
    func exportProgressData() -> Data? {
        let exportData: [String: Any] = [
            "todayStats": todayStats,
            "weeklyStats": weeklyStats,
            "monthlyStats": monthlyStats,
            "overallStats": overallStats,
            "readingStats": readingStats,
            "vocabularyStats": vocabularyStats,
            "achievementStats": achievementStats,
            "exportDate": Date()
        ]
        
        do {
            return try JSONSerialization.data(withJSONObject: exportData)
        } catch {
            errorHandler.handle(error, context: "ProgressViewModel.exportProgressData")
            return nil
        }
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Computed Properties
    var hasDataToShow: Bool {
        todayStats.readingTime > 0 || overallStats.totalArticlesRead > 0
    }
    
    var studyStreakStatus: String {
        if overallStats.currentStreak == 0 {
            return "今天开始新的学习旅程吧！"
        } else if overallStats.currentStreak == 1 {
            return "连续学习 1 天，继续保持！"
        } else {
            return "连续学习 \(overallStats.currentStreak) 天，太棒了！"
        }
    }
    
    var todayGoalProgress: Double {
        return todayStats.dailyReadingGoalProgress
    }
    
    var weeklyGoalProgress: Double {
        return weeklyStats.weeklyGoalProgress
    }
    
    var monthlyGoalProgress: Double {
        return monthlyStats.monthlyGoalProgress
    }
}

// MARK: - Supporting Types

struct ChartDataPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
    
    static func == (lhs: ChartDataPoint, rhs: ChartDataPoint) -> Bool {
        return lhs.date == rhs.date && lhs.value == rhs.value && lhs.label == rhs.label
    }
}

struct TodayStatistics {
    var readingTime: TimeInterval = 0
    var articlesRead: Int = 0
    var wordsLookedUp: Int = 0
    var reviewsCompleted: Int = 0
    var dailyReadingGoalProgress: Double = 0
    var consecutiveDays: Int = 0
}

struct WeeklyStatistics {
    var totalReadingTime: TimeInterval = 0
    var totalArticlesRead: Int = 0
    var totalWordsLookedUp: Int = 0
    var totalReviewsCompleted: Int = 0
    var dailyAverageReadingTime: TimeInterval = 0
    var studyDaysThisWeek: Int = 0
    var weeklyGoalProgress: Double = 0
}

struct MonthlyStatistics {
    var totalReadingTime: TimeInterval = 0
    var totalArticlesRead: Int = 0
    var totalWordsLookedUp: Int = 0
    var totalReviewsCompleted: Int = 0
    var dailyAverageReadingTime: TimeInterval = 0
    var studyDaysThisMonth: Int = 0
    var monthlyGoalProgress: Double = 0
    var bestWeekReadingTime: TimeInterval = 0
}

struct OverallStatistics {
    var totalReadingTime: TimeInterval = 0
    var totalArticlesRead: Int = 0
    var totalWordsLookedUp: Int = 0
    var totalReviewsCompleted: Int = 0
    var longestStreak: Int = 0
    var currentStreak: Int = 0
    var totalStudyDays: Int = 0
    var averageReadingSpeed: Double = 0
}

struct ReadingStatisticsUI {
    var completedArticles: Int = 0
    var inProgressArticles: Int = 0
    var bookmarkedArticles: Int = 0
    var averageReadingTime: TimeInterval = 0
    var favoriteTopics: [String] = []
    var difficultyDistribution: [String: Int] = [:]
    var yearDistribution: [String: Int] = [:]
}

struct VocabularyProgressStats {
    var totalWords: Int = 0
    var masteredWords: Int = 0
    var learningWords: Int = 0
    var reviewWords: Int = 0
    var masteryRate: Double = 0
    var weeklyNewWords: Int = 0
    var monthlyNewWords: Int = 0
    var averageReviewAccuracy: Double = 0
}

struct AchievementStatistics {
    var totalAchievements: Int = 0
    var unlockedAchievements: Int = 0
    var recentAchievements: [String] = []
    var nextMilestones: [String] = []
    var longestStreak: Int = 0
    var recentBadges: [AchievementBadgeUI] = []
}

struct AchievementBadgeUI: Identifiable, Codable {
    let id = UUID()
    let name: String
    let iconName: String
    let color: Color
    let unlockedDate: Date
    
    enum CodingKeys: String, CodingKey {
        case name, iconName, unlockedDate
    }
    
    init(name: String, iconName: String, color: Color, unlockedDate: Date = Date()) {
        self.name = name
        self.iconName = iconName
        self.color = color
        self.unlockedDate = unlockedDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        unlockedDate = try container.decode(Date.self, forKey: .unlockedDate)
        color = .blue // 默认颜色，实际应该根据成就类型设置
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(unlockedDate, forKey: .unlockedDate)
    }
}



// MARK: - Codable Extensions
extension TodayStatistics: Codable {}
extension WeeklyStatistics: Codable {}
extension MonthlyStatistics: Codable {}
extension OverallStatistics: Codable {}
extension ReadingStatisticsUI: Codable {}
extension VocabularyProgressStats: Codable {}
extension AchievementStatistics: Codable {}