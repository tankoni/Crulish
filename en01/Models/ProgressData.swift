//
//  ProgressData.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftUI

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

// MARK: - Home View Data Structures

/// 用户等级信息
struct LevelInfo {
    let currentLevel: Int
    let currentExperience: Int
    let experienceToNextLevel: Int
    let levelTitle: String
    let progressPercentage: Double
    let level: UserLevel
    let progress: Double
    
    init(currentLevel: Int = 1, currentExperience: Int = 0, experienceToNextLevel: Int = 100, levelTitle: String = "初学者", progressPercentage: Double = 0.0, level: UserLevel = .beginner, progress: Double = 0.0) {
        self.currentLevel = currentLevel
        self.currentExperience = currentExperience
        self.experienceToNextLevel = experienceToNextLevel
        self.levelTitle = levelTitle
        self.progressPercentage = progressPercentage
        self.level = level
        self.progress = progress
    }
}

/// 今日学习总结
struct TodaySummary {
    let readingTime: TimeInterval
    let articlesRead: Int
    let wordsLookedUp: Int
    let reviewsCompleted: Int
    let dailyReadingGoalProgress: Double
    let consecutiveDays: Int
    let isGoalAchieved: Bool
    
    init(readingTime: TimeInterval = 0, articlesRead: Int = 0, wordsLookedUp: Int = 0, reviewsCompleted: Int = 0, dailyReadingGoalProgress: Double = 0.0, consecutiveDays: Int = 0, isGoalAchieved: Bool = false) {
        self.readingTime = readingTime
        self.articlesRead = articlesRead
        self.wordsLookedUp = wordsLookedUp
        self.reviewsCompleted = reviewsCompleted
        self.dailyReadingGoalProgress = dailyReadingGoalProgress
        self.consecutiveDays = consecutiveDays
        self.isGoalAchieved = isGoalAchieved
    }
}

/// 连续学习状态
struct StreakStatus {
    let consecutiveDays: Int
    let hasStudiedToday: Bool
    let isAtRisk: Bool
    let statusMessage: String
    let statusColor: Color
    
    init(consecutiveDays: Int = 0, hasStudiedToday: Bool = false, isAtRisk: Bool = false, statusMessage: String = "继续保持", statusColor: Color = .green) {
        self.consecutiveDays = consecutiveDays
        self.hasStudiedToday = hasStudiedToday
        self.isAtRisk = isAtRisk
        self.statusMessage = statusMessage
        self.statusColor = statusColor
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