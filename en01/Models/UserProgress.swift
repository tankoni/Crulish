//
//  UserProgress.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData
import SwiftUI

// 用户学习进度总览
@Model
final class UserProgress: @unchecked Sendable {
    var id: UUID
    var totalReadingTime: TimeInterval // 总阅读时间（秒）
    var totalArticlesRead: Int // 已读文章数
    var totalWordsLookedUp: Int // 总查词数
    var currentStreak: Int // 当前连续学习天数
    var longestStreak: Int // 最长连续学习天数
    var lastStudyDate: Date?
    var createdDate: Date
    var level: UserLevel
    var experience: Int // 经验值
    var experiencePoints: Int // 经验点数（别名）
    var streakDays: Int // 连续学习天数（别名）
    var maxStreakDays: Int // 最大连续学习天数（别名）
    var articlesRead: Int // 已读文章数（别名）
    var achievements: [AchievementData] // 成就列表
    
    // 新增字段
    var readingProgress: [ReadingProgressRecord] = [] // 阅读进度记录
    var bookmarkedArticles: [String] = [] // 收藏的文章ID列表
    var completedArticleIds: [String] = [] // 已完成的文章ID列表
    
    // 每日学习记录
    @Relationship(deleteRule: .cascade)
    var dailyRecords: [DailyStudyRecord] = []
    
    init() {
        self.id = UUID()
        self.totalReadingTime = 0
        self.totalArticlesRead = 0
        self.totalWordsLookedUp = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastStudyDate = nil
        self.createdDate = Date()
        self.level = .beginner
        self.experience = 0
        self.experiencePoints = 0
        self.streakDays = 0
        self.maxStreakDays = 0
        self.articlesRead = 0
        self.achievements = []
    }
    
    // MARK: - 计算属性
    var nextLevelExperience: Int {
        return level.nextLevel?.requiredExperience ?? level.requiredExperience
    }
    
    var levelProgress: Double {
        let currentLevelExp = level.requiredExperience
        let nextLevelExp = nextLevelExperience
        let progress = Double(experience - currentLevelExp) / Double(nextLevelExp - currentLevelExp)
        return max(0, min(1, progress))
    }
    
    var experienceToNextLevel: Int {
        return max(0, nextLevelExperience - experience)
    }
    
    var totalWordLookups: Int {
        return totalWordsLookedUp
    }
    
    var reviewsCompleted: Int {
        return dailyRecords.reduce(0) { $0 + $1.reviewsCompleted }
    }
    
    // 获取今日学习统计
    var todayStats: DailyStudyRecord? {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyRecords.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    
    // 获取本周学习统计
    var weeklyStats: (readingTime: TimeInterval, articlesRead: Int, wordsLookedUp: Int) {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let weeklyRecords = dailyRecords.filter { $0.date >= weekAgo }
        
        let totalTime = weeklyRecords.reduce(0) { $0 + $1.readingTime }
        let totalArticles = weeklyRecords.reduce(0) { $0 + $1.articlesRead }
        let totalWords = weeklyRecords.reduce(0) { $0 + $1.wordsLookedUp }
        
        return (totalTime, totalArticles, totalWords)
    }
    
    // 获取学习天数
    var studyDays: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: createdDate, to: Date()).day ?? 0
        return max(0, days + 1)
    }
    
    // MARK: - 学习进度方法
    
    // 添加阅读时间
    func addReadingTime(_ time: TimeInterval) {
        self.totalReadingTime += time
        updateTodayRecord { record in
            record.readingTime += time
        }
        addExperience(Int(time / 60)) // 每分钟1经验值
    }
    
    // 增加文章阅读数
    func incrementArticlesRead() {
        self.totalArticlesRead += 1
        updateTodayRecord { record in
            record.articlesRead += 1
        }
        addExperience(10) // 每篇文章10经验值
        checkAchievements()
    }
    
    // 增加查词数
    func incrementWordsLookedUp(isNewWord: Bool = false) {
        self.totalWordsLookedUp += 1
        updateTodayRecord { record in
            record.wordsLookedUp += 1
            if isNewWord {
                record.newWordsLearned += 1
            }
        }
        addExperience(isNewWord ? 5 : 2) // 新单词5经验值，重复单词2经验值
        checkAchievements()
    }
    
    // 完成复习
    func completeReview() {
        updateTodayRecord { record in
            record.reviewsCompleted += 1
        }
        addExperience(3) // 每次复习3经验值
    }
    
    // MARK: - 私有方法
    
    // 更新今日记录
    private func updateTodayRecord(update: (DailyStudyRecord) -> Void) {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let todayRecord = dailyRecords.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            update(todayRecord)
        } else {
            let newRecord = DailyStudyRecord(date: today)
            update(newRecord)
            dailyRecords.append(newRecord)
        }
        
        updateStreak()
    }
    
    // 更新连续学习天数
    private func updateStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastStudy = lastStudyDate {
            let daysDifference = Calendar.current.dateComponents([.day], from: lastStudy, to: today).day ?? 0
            
            if daysDifference == 1 {
                // 连续学习
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else if daysDifference > 1 {
                // 中断了
                currentStreak = 1
            }
            // daysDifference == 0 表示今天已经学习过了，不需要更新
        } else {
            // 第一次学习
            currentStreak = 1
            longestStreak = 1
        }
        
        lastStudyDate = today
        checkAchievements()
    }
    
    // 添加经验值
    private func addExperience(_ exp: Int) {
        self.experience += exp
        updateTodayRecord { record in
            record.experienceGained += exp
        }
        updateLevel()
    }
    
    // 更新等级
    private func updateLevel() {
        while let nextLevel = level.nextLevel, experience >= nextLevel.requiredExperience {
            self.level = nextLevel
        }
    }
    
    // 检查成就
    private func checkAchievements() {
        let newAchievements = AchievementType.allCases.filter { type in
            !achievements.contains { $0.type == type } && hasEarnedAchievement(type)
        }
        
        for achievementType in newAchievements {
            let achievement = AchievementData(type: achievementType)
            achievements.append(achievement)
            addExperience(achievementType.experienceReward)
        }
    }
    
    // 检查是否获得特定成就
    private func hasEarnedAchievement(_ type: AchievementType) -> Bool {
        switch type {
        case .firstArticle: return totalArticlesRead >= 1
        case .read10Articles: return totalArticlesRead >= 10
        case .read50Articles: return totalArticlesRead >= 50
        case .read100Articles: return totalArticlesRead >= 100
        case .firstWord: return totalWordsLookedUp >= 1
        case .lookup100Words: return totalWordsLookedUp >= 100
        case .lookup500Words: return totalWordsLookedUp >= 500
        case .lookup1000Words: return totalWordsLookedUp >= 1000
        case .master100Words: return false // 需要额外逻辑检查掌握的单词数
        case .study1Hour: return totalReadingTime >= 3600
        case .study10Hours: return totalReadingTime >= 36000
        case .study50Hours: return totalReadingTime >= 180000
        case .study100Hours: return totalReadingTime >= 360000
        case .streak3Days: return currentStreak >= 3
        case .streak7Days: return currentStreak >= 7
        case .streak30Days: return currentStreak >= 30
        case .streak100Days: return currentStreak >= 100
        }
    }
}

// MARK: - 用户等级
enum UserLevel: String, CaseIterable, Codable {
    case beginner = "初学者"
    case elementary = "入门"
    case intermediate = "中级"
    case upperIntermediate = "上中级"
    case advanced = "高级"
    case expert = "专家"
    
    var displayName: String {
        return self.rawValue
    }
    
    var requiredExperience: Int {
        switch self {
        case .beginner: return 0
        case .elementary: return 100
        case .intermediate: return 300
        case .upperIntermediate: return 500
        case .advanced: return 600
        case .expert: return 1000
        }
    }
    
    var nextLevel: UserLevel? {
        switch self {
        case .beginner: return .elementary
        case .elementary: return .intermediate
        case .intermediate: return .upperIntermediate
        case .upperIntermediate: return .advanced
        case .advanced: return .expert
        case .expert: return nil
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .gray
        case .elementary: return .green
        case .intermediate: return .blue
        case .upperIntermediate: return .orange
        case .advanced: return .purple
        case .expert: return .yellow
        }
    }
    
    var iconName: String {
        switch self {
        case .beginner: return "leaf"
        case .elementary: return "seedling"
        case .intermediate: return "tree"
        case .upperIntermediate: return "tree.fill"
        case .advanced: return "mountain"
        case .expert: return "crown"
        }
    }
}

// MARK: - 每日学习记录
@Model
final class DailyStudyRecord: @unchecked Sendable {
    var id: UUID
    var date: Date
    var readingTime: TimeInterval // 当日阅读时间
    var articlesRead: Int // 当日阅读文章数
    var wordsLookedUp: Int // 当日查词数
    var newWordsLearned: Int // 当日新学单词数
    var reviewsCompleted: Int // 当日完成的复习数
    var experienceGained: Int // 当日获得经验值
    
    init(date: Date = Date()) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.readingTime = 0
        self.articlesRead = 0
        self.wordsLookedUp = 0
        self.newWordsLearned = 0
        self.reviewsCompleted = 0
        self.experienceGained = 0
    }
}

// MARK: - 成就系统
struct AchievementData: Codable, Identifiable {
    var id = UUID()
    let type: AchievementType
    let unlockedDate: Date
    let progress: Double // 0.0 - 1.0
    
    init(type: AchievementType, progress: Double = 1.0) {
        self.type = type
        self.unlockedDate = Date()
        self.progress = progress
    }
    
    var iconName: String {
        return type.icon
    }
    
    var isUnlocked: Bool {
        return progress >= 1.0
    }
    
    var title: String {
        return type.title
    }
    
    var description: String {
        return type.description
    }
}

// MARK: - Codable Support
extension UserProgress: Codable {
    enum CodingKeys: CodingKey {
        case id, totalReadingTime, totalArticlesRead, totalWordsLookedUp, currentStreak, longestStreak, lastStudyDate, createdDate, level, experience, experiencePoints, streakDays, maxStreakDays, articlesRead, achievements, readingProgress, bookmarkedArticles, completedArticleIds, dailyRecords
    }

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        totalReadingTime = try container.decode(TimeInterval.self, forKey: .totalReadingTime)
        totalArticlesRead = try container.decode(Int.self, forKey: .totalArticlesRead)
        totalWordsLookedUp = try container.decode(Int.self, forKey: .totalWordsLookedUp)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        longestStreak = try container.decode(Int.self, forKey: .longestStreak)
        lastStudyDate = try container.decodeIfPresent(Date.self, forKey: .lastStudyDate)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        level = try container.decode(UserLevel.self, forKey: .level)
        experience = try container.decode(Int.self, forKey: .experience)
        experiencePoints = try container.decode(Int.self, forKey: .experiencePoints)
        streakDays = try container.decode(Int.self, forKey: .streakDays)
        maxStreakDays = try container.decode(Int.self, forKey: .maxStreakDays)
        articlesRead = try container.decode(Int.self, forKey: .articlesRead)
        achievements = try container.decode([AchievementData].self, forKey: .achievements)
        readingProgress = try container.decode([ReadingProgressRecord].self, forKey: .readingProgress)
        bookmarkedArticles = try container.decode([String].self, forKey: .bookmarkedArticles)
        completedArticleIds = try container.decode([String].self, forKey: .completedArticleIds)
        dailyRecords = try container.decode([DailyStudyRecord].self, forKey: .dailyRecords)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(totalReadingTime, forKey: .totalReadingTime)
        try container.encode(totalArticlesRead, forKey: .totalArticlesRead)
        try container.encode(totalWordsLookedUp, forKey: .totalWordsLookedUp)
        try container.encode(currentStreak, forKey: .currentStreak)
        try container.encode(longestStreak, forKey: .longestStreak)
        try container.encodeIfPresent(lastStudyDate, forKey: .lastStudyDate)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(level, forKey: .level)
        try container.encode(experience, forKey: .experience)
        try container.encode(experiencePoints, forKey: .experiencePoints)
        try container.encode(streakDays, forKey: .streakDays)
        try container.encode(maxStreakDays, forKey: .maxStreakDays)
        try container.encode(articlesRead, forKey: .articlesRead)
        try container.encode(achievements, forKey: .achievements)
        try container.encode(readingProgress, forKey: .readingProgress)
        try container.encode(bookmarkedArticles, forKey: .bookmarkedArticles)
        try container.encode(completedArticleIds, forKey: .completedArticleIds)
        try container.encode(dailyRecords, forKey: .dailyRecords)
    }
}

extension DailyStudyRecord: Codable {
    enum CodingKeys: CodingKey {
        case id, date, readingTime, articlesRead, wordsLookedUp, newWordsLearned, reviewsCompleted, experienceGained
    }

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        readingTime = try container.decode(TimeInterval.self, forKey: .readingTime)
        articlesRead = try container.decode(Int.self, forKey: .articlesRead)
        wordsLookedUp = try container.decode(Int.self, forKey: .wordsLookedUp)
        newWordsLearned = try container.decode(Int.self, forKey: .newWordsLearned)
        reviewsCompleted = try container.decode(Int.self, forKey: .reviewsCompleted)
        experienceGained = try container.decode(Int.self, forKey: .experienceGained)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(readingTime, forKey: .readingTime)
        try container.encode(articlesRead, forKey: .articlesRead)
        try container.encode(wordsLookedUp, forKey: .wordsLookedUp)
        try container.encode(newWordsLearned, forKey: .newWordsLearned)
        try container.encode(reviewsCompleted, forKey: .reviewsCompleted)
        try container.encode(experienceGained, forKey: .experienceGained)
    }
}