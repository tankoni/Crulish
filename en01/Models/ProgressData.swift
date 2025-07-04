//
//  ProgressData.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation

// MARK: - 进度数据结构

/// 进度数据容器，用于ProgressView显示
struct ProgressData {
    let userProgress: UserProgress?
    let statistics: ProgressStatistics
    
    init(userProgress: UserProgress?, statistics: ProgressStatistics) {
        self.userProgress = userProgress
        self.statistics = statistics
    }
}

/// 进度统计数据
struct ProgressStatistics {
    let weeklyStats: WeeklyStats
    let monthlyStats: MonthlyStats
    let dailyRecords: [DailyStudyRecord]
    
    init(weeklyStats: WeeklyStats, monthlyStats: MonthlyStats, dailyRecords: [DailyStudyRecord] = []) {
        self.weeklyStats = weeklyStats
        self.monthlyStats = monthlyStats
        self.dailyRecords = dailyRecords
    }
}

/// 周统计数据
struct WeeklyStats {
    let thisWeekReadingTime: TimeInterval
    let thisWeekArticlesRead: Int
    let thisWeekWordsLookedUp: Int
    let averageDailyTime: TimeInterval
    let streakDays: Int
    
    init(readingTime: TimeInterval = 0, articlesRead: Int = 0, wordsLookedUp: Int = 0, averageDailyTime: TimeInterval = 0, streakDays: Int = 0) {
        self.thisWeekReadingTime = readingTime
        self.thisWeekArticlesRead = articlesRead
        self.thisWeekWordsLookedUp = wordsLookedUp
        self.averageDailyTime = averageDailyTime
        self.streakDays = streakDays
    }
}

/// 月统计数据
struct MonthlyStats {
    let thisMonthReadingTime: TimeInterval
    let thisMonthArticlesRead: Int
    let thisMonthWordsLookedUp: Int
    let averageDailyTime: TimeInterval
    let totalDays: Int
    
    init(readingTime: TimeInterval = 0, articlesRead: Int = 0, wordsLookedUp: Int = 0, averageDailyTime: TimeInterval = 0, totalDays: Int = 0) {
        self.thisMonthReadingTime = readingTime
        self.thisMonthArticlesRead = articlesRead
        self.thisMonthWordsLookedUp = wordsLookedUp
        self.averageDailyTime = averageDailyTime
        self.totalDays = totalDays
    }
}