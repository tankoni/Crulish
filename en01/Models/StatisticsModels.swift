import Foundation
import SwiftData

// MARK: - 学习统计数据模型

/// 学习统计数据
@Model
class LearningStatistics {
    var id: UUID
    var userId: String
    var date: Date
    var wordsLearned: Int
    var articlesRead: Int
    var studyTimeMinutes: Int
    var testScore: Double
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String, date: Date = Date(), wordsLearned: Int = 0, articlesRead: Int = 0, studyTimeMinutes: Int = 0, testScore: Double = 0.0) {
        self.id = UUID()
        self.userId = userId
        self.date = date
        self.wordsLearned = wordsLearned
        self.articlesRead = articlesRead
        self.studyTimeMinutes = studyTimeMinutes
        self.testScore = testScore
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// 阅读统计数据 - 领域层模型
struct ReadingStatisticsDomain: Codable {
    let totalArticlesRead: Int
    let totalReadingTime: TimeInterval
    let averageReadingSpeed: Double // 每分钟字数
    let completionRate: Double // 完成率
    let favoriteCategories: [String]
    
    init(totalArticlesRead: Int = 0, totalReadingTime: TimeInterval = 0, averageReadingSpeed: Double = 0, completionRate: Double = 0, favoriteCategories: [String] = []) {
        self.totalArticlesRead = totalArticlesRead
        self.totalReadingTime = totalReadingTime
        self.averageReadingSpeed = averageReadingSpeed
        self.completionRate = completionRate
        self.favoriteCategories = favoriteCategories
    }
    
    static let empty = ReadingStatisticsDomain()
}

/// 阅读统计数据 - UI层模型（保持向后兼容）
typealias ReadingStatistics = ReadingStatisticsDomain

/// 词汇统计数据
struct VocabularyStatisticsDomain: Codable {
    let totalWordsLearned: Int
    let masteredWords: Int
    let reviewingWords: Int
    let newWords: Int
    let averageTestScore: Double
    let strongestCategories: [String]
    let weakestCategories: [String]
    
    init(totalWordsLearned: Int = 0, masteredWords: Int = 0, reviewingWords: Int = 0, newWords: Int = 0, averageTestScore: Double = 0, strongestCategories: [String] = [], weakestCategories: [String] = []) {
        self.totalWordsLearned = totalWordsLearned
        self.masteredWords = masteredWords
        self.reviewingWords = reviewingWords
        self.newWords = newWords
        self.averageTestScore = averageTestScore
        self.strongestCategories = strongestCategories
        self.weakestCategories = weakestCategories
    }
}

/// 学习目标数据
@Model
class LearningGoal {
    var id: UUID
    var userId: String
    var type: GoalType
    var targetValue: Int
    var currentValue: Int
    var deadline: Date
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String, type: GoalType, targetValue: Int, deadline: Date) {
        self.id = UUID()
        self.userId = userId
        self.type = type
        self.targetValue = targetValue
        self.currentValue = 0
        self.deadline = deadline
        self.isCompleted = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1.0)
    }
}

/// 目标类型
enum GoalType: String, Codable, CaseIterable {
    case dailyWords = "daily_words"
    case weeklyArticles = "weekly_articles"
    case monthlyStudyTime = "monthly_study_time"
    case vocabularyTest = "vocabulary_test"
    
    var displayName: String {
        switch self {
        case .dailyWords: return "每日单词"
        case .weeklyArticles: return "每周文章"
        case .monthlyStudyTime: return "每月学习时间"
        case .vocabularyTest: return "词汇测试"
        }
    }
}

/// 成就数据
@Model
class AchievementEntity {
    var id: UUID
    var userId: String
    var type: AchievementType
    var title: String
    var descriptionText: String
    var isUnlocked: Bool
    var unlockedAt: Date?
    var progress: Double
    var createdAt: Date
    
    init(userId: String, type: AchievementType, title: String, description: String) {
        self.id = UUID()
        self.userId = userId
        self.type = type
        self.title = title
        self.descriptionText = description
        self.isUnlocked = false
        self.unlockedAt = nil
        self.progress = 0.0
        self.createdAt = Date()
    }
}

/// 书签数据
@Model
class Bookmark {
    var id: UUID
    var userId: String
    var articleId: String
    var position: Double // 阅读位置百分比
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String, articleId: String, position: Double, note: String? = nil) {
        self.id = UUID()
        self.userId = userId
        self.articleId = articleId
        self.position = position
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// 阅读会话数据
@Model
class ReadingSession {
    var id: UUID
    var userId: String
    var articleId: String
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var wordsRead: Int
    var completionPercentage: Double
    var createdAt: Date
    
    init(userId: String, articleId: String, startTime: Date = Date()) {
        self.id = UUID()
        self.userId = userId
        self.articleId = articleId
        self.startTime = startTime
        self.endTime = nil
        self.duration = 0
        self.wordsRead = 0
        self.completionPercentage = 0
        self.createdAt = Date()
    }
    
    func endSession(wordsRead: Int, completionPercentage: Double) {
        self.endTime = Date()
        self.duration = endTime?.timeIntervalSince(startTime) ?? 0
        self.wordsRead = wordsRead
        self.completionPercentage = completionPercentage
    }
}


/// 周对比数据
struct WeeklyComparison: Codable {
    let currentWeek: StatisticsWeeklyStats
    let previousWeek: StatisticsWeeklyStats
    let improvement: Double // 改进百分比
    
    init(currentWeek: StatisticsWeeklyStats, previousWeek: StatisticsWeeklyStats) {
        self.currentWeek = currentWeek
        self.previousWeek = previousWeek
        
        // 计算改进百分比
        let currentTotal = currentWeek.totalStudyTime + Double(currentWeek.articlesRead) + Double(currentWeek.wordsLearned)
        let previousTotal = previousWeek.totalStudyTime + Double(previousWeek.articlesRead) + Double(previousWeek.wordsLearned)
        
        if previousTotal > 0 {
            self.improvement = ((currentTotal - previousTotal) / previousTotal) * 100
        } else {
            self.improvement = currentTotal > 0 ? 100 : 0
        }
    }
}

// 重命名以避免与ProgressData.swift中的WeeklyStats冲突
struct StatisticsWeeklyStats: Codable {
    let totalStudyTime: Double
    let articlesRead: Int
    let wordsLearned: Int
    let averageScore: Double
    
    init(totalStudyTime: Double = 0, articlesRead: Int = 0, wordsLearned: Int = 0, averageScore: Double = 0) {
        self.totalStudyTime = totalStudyTime
        self.articlesRead = articlesRead
        self.wordsLearned = wordsLearned
        self.averageScore = averageScore
    }
}

/// 学习统计数据
struct StudyStatistics: Codable {
    let totalStudyTime: TimeInterval
    let averageSessionTime: TimeInterval
    let totalSessions: Int
    let consecutiveDays: Int
    let longestStreak: Int
    let weeklyAverage: Double
    let monthlyAverage: Double
    
    init(totalStudyTime: TimeInterval = 0, averageSessionTime: TimeInterval = 0, totalSessions: Int = 0, consecutiveDays: Int = 0, longestStreak: Int = 0, weeklyAverage: Double = 0, monthlyAverage: Double = 0) {
        self.totalStudyTime = totalStudyTime
        self.averageSessionTime = averageSessionTime
        self.totalSessions = totalSessions
        self.consecutiveDays = consecutiveDays
        self.longestStreak = longestStreak
        self.weeklyAverage = weeklyAverage
        self.monthlyAverage = monthlyAverage
    }
}

/// 目标进度数据
struct GoalProgress: Codable {
    let dailyGoal: GoalItem
    let weeklyGoal: GoalItem
    let monthlyGoal: GoalItem
    let overallProgress: Double
    
    init(dailyGoal: GoalItem, weeklyGoal: GoalItem, monthlyGoal: GoalItem) {
        self.dailyGoal = dailyGoal
        self.weeklyGoal = weeklyGoal
        self.monthlyGoal = monthlyGoal
        
        // 计算总体进度
        self.overallProgress = (dailyGoal.progress + weeklyGoal.progress + monthlyGoal.progress) / 3.0
    }
}

/// 目标项目
struct GoalItem: Codable {
    let title: String
    let current: Int
    let target: Int
    let progress: Double
    let isCompleted: Bool
    
    init(title: String, current: Int, target: Int) {
        self.title = title
        self.current = current
        self.target = target
        self.progress = target > 0 ? min(Double(current) / Double(target), 1.0) : 0
        self.isCompleted = current >= target
    }
}