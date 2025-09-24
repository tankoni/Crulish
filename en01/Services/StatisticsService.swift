//
//  StatisticsService.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation
import SwiftData
import Combine

/// 统计分析服务 - 提供全面的学习数据统计和分析功能
class StatisticsService: BaseService {
    
    // MARK: - Properties
    
    /// 统计数据缓存
    private var statisticsCache: [String: Any] = [:]
    
    /// 缓存有效期（10分钟）
    private let cacheValidityDuration: TimeInterval = 600
    
    /// 最后缓存更新时间
    private var lastCacheUpdate: Date?
    
    // MARK: - Initialization
    
    override init(
        modelContext: ModelContext,
        cacheManager: CacheManagerProtocol,
        errorHandler: ErrorHandlerProtocol,
        subsystem: String = "com.en01.services",
        category: String = "StatisticsService"
    ) {
        super.init(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler,
            subsystem: subsystem,
            category: category
        )
        
        logger.info("StatisticsService 初始化完成")
    }
    
    // MARK: - Public Methods
    
    /// 获取词汇掌握情况统计
    /// - Returns: 词汇掌握统计数据
    func getVocabularyMasteryStatistics() -> VocabularyMasteryStatistics {
        return getCachedOrCompute(key: "vocabulary_mastery") {
            return performSafeOperation("获取词汇掌握统计") {
                let descriptor = FetchDescriptor<UserWord>()
                let userWords = try modelContext.fetch(descriptor)
                
                let masteredCount = userWords.filter { $0.masteryLevel == .mastered }.count
                let familiarCount = userWords.filter { $0.masteryLevel == .familiar }.count
                let unfamiliarCount = userWords.filter { $0.masteryLevel == .unfamiliar }.count
                
                let totalWords = userWords.count
                let masteryRate = totalWords > 0 ? Double(masteredCount) / Double(totalWords) : 0
                
                // 按来源分类统计
                let testWords = userWords.filter { $0.isFromTest }.count
                let readingWords = userWords.filter { !$0.isFromTest }.count
                
                return VocabularyMasteryStatistics(
                    totalWords: totalWords,
                    masteredWords: masteredCount,
                    familiarWords: familiarCount,
                    unfamiliarWords: unfamiliarCount,
                    masteryRate: masteryRate,
                    wordsFromTest: testWords,
                    wordsFromReading: readingWords
                )
            } ?? VocabularyMasteryStatistics.empty
        }
    }
    
    /// 获取学习趋势数据
    /// - Parameter days: 统计天数
    /// - Returns: 学习趋势数据
    func getLearningTrend(days: Int = 30) -> StatisticsLearningTrendData {
        return getCachedOrCompute(key: "learning_trend_\(days)") {
            return performSafeOperation("获取学习趋势") {
                let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                
                // 获取学习记录
                let learningPredicate = #Predicate<LearningRecord> { record in
                    record.timestamp >= startDate
                }
                let learningDescriptor = FetchDescriptor<LearningRecord>(predicate: learningPredicate)
                let learningRecords = try modelContext.fetch(learningDescriptor)
                
                // 获取点击记录
                let clickPredicate = #Predicate<WordClickRecord> { record in
                    record.clickDate >= startDate
                }
                let clickDescriptor = FetchDescriptor<WordClickRecord>(predicate: clickPredicate)
                let clickRecords = try modelContext.fetch(clickDescriptor)
                
                // 按日期分组统计
                var dailyData: [DailyLearningData] = []
                let calendar = Calendar.current
                
                for i in 0..<days {
                    let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
                    let dayStart = calendar.startOfDay(for: date)
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? Date()
                    
                    let dayLearningRecords = learningRecords.filter {
                        $0.timestamp >= dayStart && $0.timestamp < dayEnd
                    }
                    
                    let dayClickRecords = clickRecords.filter {
                        $0.clickDate >= dayStart && $0.clickDate < dayEnd
                    }
                    
                    let wordsLearned = Set(dayLearningRecords.map { $0.word }).count
                    let wordsClicked = Set(dayClickRecords.map { $0.word }).count
                    let totalClicks = dayClickRecords.count
                    
                    let masteryChanges = dayLearningRecords.filter {
                        $0.newMastery.rawValue > $0.previousMastery.rawValue
                    }.count
                    
                    dailyData.append(DailyLearningData(
                        date: date,
                        wordsLearned: wordsLearned,
                        wordsClicked: wordsClicked,
                        totalClicks: totalClicks,
                        masteryImprovements: masteryChanges
                    ))
                }
                
                dailyData.reverse() // 按时间正序排列
                
                return StatisticsLearningTrendData(
                    dailyData: dailyData,
                    totalDays: days,
                    averageWordsPerDay: dailyData.map { $0.wordsLearned }.reduce(0, +) / days,
                    averageClicksPerDay: dailyData.map { $0.totalClicks }.reduce(0, +) / days
                )
            } ?? StatisticsLearningTrendData.empty(days: days)
        }
    }
    
    /// 获取测试历史统计
    /// - Returns: 测试历史统计数据
    func getTestHistoryStatistics() -> TestHistoryStatistics {
        return getCachedOrCompute(key: "test_history") {
            return performSafeOperation("获取测试历史统计") {
                let descriptor = FetchDescriptor<VocabularyTest>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
                let tests = try modelContext.fetch(descriptor)
                
                let completedTests = tests.filter { $0.isCompleted }
                let totalTests = tests.count
                
                let totalScore = completedTests.map { $0.accuracyPercentage }.reduce(0, +)
                let averageScore = completedTests.isEmpty ? 0 : totalScore / Double(completedTests.count)                
                let bestScore = completedTests.map { $0.accuracyPercentage }.max() ?? 0
                let latestScore = completedTests.first?.accuracyPercentage ?? 0
                
                // 按词典分类统计
                let testsByDictionary = Dictionary(grouping: completedTests) { $0.dictionaryName }
                let dictionaryStats = testsByDictionary.mapValues { tests in
                    DictionaryTestStats(
                        testCount: tests.count,
                        averageScore: tests.map { $0.accuracyPercentage }.reduce(0, +) / Double(tests.count),
                        bestScore: tests.map { $0.accuracyPercentage }.max() ?? 0,
                        latestTest: tests.first?.completedAt ?? Date()
                    )
                }
                
                return TestHistoryStatistics(
                    totalTests: totalTests,
                    completedTests: completedTests.count,
                    averageScore: averageScore,
                    bestScore: bestScore,
                    latestScore: latestScore,
                    dictionaryStats: dictionaryStats
                )
            } ?? TestHistoryStatistics.empty
        }
    }
    
    /// 获取阅读统计数据（已废弃，使用ArticleService.getReadingStatistics）
    /// - Returns: 阅读统计数据
    @available(*, deprecated, message: "使用ArticleService.getReadingStatistics代替")
    func getReadingStatistics() -> ReadingStatisticsDomain {
        return getCachedOrCompute(key: "reading_statistics") {
            return performSafeOperation("获取阅读统计") {
                // 获取文章点击记录
                let clickDescriptor = FetchDescriptor<WordClickRecord>()
                let clickRecords = try modelContext.fetch(clickDescriptor)
                
                // 按文章分组统计
                let articleClicks = Dictionary(grouping: clickRecords) { $0.articleID }
                let articlesRead = articleClicks.count
                
                let totalClicks = clickRecords.count
                
                // 计算平均阅读速度（假设每次点击代表阅读了一定数量的单词）
                let averageReadingSpeed = articlesRead > 0 ? Double(totalClicks * 50) / Double(articlesRead) : 200.0
                
                // 计算完成率（基于点击记录的文章数量）
                let completionRate = articlesRead > 0 ? min(1.0, Double(articlesRead) / 100.0) : 0.0
                
                return ReadingStatisticsDomain(
                    totalArticlesRead: articlesRead,
                    totalReadingTime: TimeInterval(articlesRead * 600), // 假设每篇文章平均10分钟
                    averageReadingSpeed: averageReadingSpeed,
                    completionRate: completionRate,
                    favoriteCategories: []
                )
            } ?? ReadingStatisticsDomain.empty
        }
    }
    
    /// 获取学习效率分析
    /// - Returns: 学习效率数据
    func getLearningEfficiencyAnalysis() -> LearningEfficiencyData {
        return getCachedOrCompute(key: "learning_efficiency") {
            return performSafeOperation("获取学习效率分析") {
                let descriptor = FetchDescriptor<LearningRecord>(
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
                let records = try modelContext.fetch(descriptor)
                
                // 计算掌握程度提升效率
                let improvements = records.filter {
                    $0.newMastery.rawValue > $0.previousMastery.rawValue
                }
                
                let totalLearningActions = records.count
                let improvementRate = totalLearningActions > 0 ?
                    Double(improvements.count) / Double(totalLearningActions) : 0
                
                // 按来源分析效率
                let testLearning = records.filter { $0.source == "test" }
                let readingLearning = records.filter { $0.source == "reading" }
                
                let testEfficiency = calculateSourceEfficiency(testLearning)
                let readingEfficiency = calculateSourceEfficiency(readingLearning)
                
                // 学习速度分析（每天的学习量）
                let recentDays = 7
                let recentDate = Calendar.current.date(byAdding: .day, value: -recentDays, to: Date()) ?? Date()
                let recentRecords = records.filter { $0.timestamp >= recentDate }
                
                let dailyLearningRate = Double(recentRecords.count) / Double(recentDays)
                
                return LearningEfficiencyData(
                    totalLearningActions: totalLearningActions,
                    improvementRate: improvementRate,
                    testLearningEfficiency: testEfficiency,
                    readingLearningEfficiency: readingEfficiency,
                    dailyLearningRate: dailyLearningRate,
                    recommendedDailyGoal: calculateRecommendedDailyGoal(dailyLearningRate)
                )
            } ?? LearningEfficiencyData.empty
        }
    }
    
    /// 清除统计缓存
    func clearStatisticsCache() {
        statisticsCache.removeAll()
        lastCacheUpdate = nil
        logger.info("统计缓存已清除")
    }
    
    // MARK: - Private Methods
    
    private func getCachedOrCompute<T>(key: String, computation: () -> T) -> T {
        // 检查缓存是否有效
        if let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheValidityDuration,
           let cached = statisticsCache[key] as? T {
            return cached
        }
        
        // 计算新值
        let result = computation()
        
        // 更新缓存
        statisticsCache[key] = result
        lastCacheUpdate = Date()
        
        return result
    }
    
    private func calculateSourceEfficiency(_ records: [LearningRecord]) -> Double {
        guard !records.isEmpty else { return 0 }
        
        let improvements = records.filter {
            $0.newMastery.rawValue > $0.previousMastery.rawValue
        }
        
        return Double(improvements.count) / Double(records.count)
    }
    
    private func calculateRecommendedDailyGoal(_ currentRate: Double) -> Int {
        // 基于当前学习速度推荐每日目标
        let baseGoal = max(5, Int(currentRate * 1.2)) // 比当前速度高20%
        return min(baseGoal, 50) // 最多不超过50个单词
    }
}

// MARK: - Data Models

/// 词汇掌握统计数据
struct VocabularyMasteryStatistics {
    let totalWords: Int
    let masteredWords: Int
    let familiarWords: Int
    let unfamiliarWords: Int
    let masteryRate: Double
    let wordsFromTest: Int
    let wordsFromReading: Int
    
    var masteredPercentage: Double {
        return totalWords > 0 ? Double(masteredWords) / Double(totalWords) * 100 : 0
    }
    
    var familiarPercentage: Double {
        return totalWords > 0 ? Double(familiarWords) / Double(totalWords) * 100 : 0
    }
    
    var unfamiliarPercentage: Double {
        return totalWords > 0 ? Double(unfamiliarWords) / Double(totalWords) * 100 : 0
    }
    
    static let empty = VocabularyMasteryStatistics(
        totalWords: 0, masteredWords: 0, familiarWords: 0, unfamiliarWords: 0,
        masteryRate: 0, wordsFromTest: 0, wordsFromReading: 0
    )
}

/// 每日学习数据
struct DailyLearningData {
    let date: Date
    let wordsLearned: Int
    let wordsClicked: Int
    let totalClicks: Int
    let masteryImprovements: Int
}

/// 学习趋势数据
struct StatisticsLearningTrendData {
    let dailyData: [DailyLearningData]
    let totalDays: Int
    let averageWordsPerDay: Int
    let averageClicksPerDay: Int
    
    static func empty(days: Int) -> StatisticsLearningTrendData {
        return StatisticsLearningTrendData(
            dailyData: [],
            totalDays: days,
            averageWordsPerDay: 0,
            averageClicksPerDay: 0
        )
    }
}

/// 词典测试统计
struct DictionaryTestStats {
    let testCount: Int
    let averageScore: Double
    let bestScore: Double
    let latestTest: Date
}

/// 测试历史统计
struct TestHistoryStatistics {
    let totalTests: Int
    let completedTests: Int
    let averageScore: Double
    let bestScore: Double
    let latestScore: Double
    let dictionaryStats: [String: DictionaryTestStats]
    
    static let empty = TestHistoryStatistics(
        totalTests: 0, completedTests: 0, averageScore: 0,
        bestScore: 0, latestScore: 0, dictionaryStats: [:]
    )
}

// ReadingStatisticsInternal已移除，请使用ArticleService.getReadingStatistics()获取ReadingStatisticsDomain

/// 学习效率数据
struct LearningEfficiencyData {
    let totalLearningActions: Int
    let improvementRate: Double
    let testLearningEfficiency: Double
    let readingLearningEfficiency: Double
    let dailyLearningRate: Double
    let recommendedDailyGoal: Int
    
    static let empty = LearningEfficiencyData(
        totalLearningActions: 0, improvementRate: 0, testLearningEfficiency: 0,
        readingLearningEfficiency: 0, dailyLearningRate: 0, recommendedDailyGoal: 5
    )
}
