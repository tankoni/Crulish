//
//  UserProgressService.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData

@Observable
class UserProgressService {
    private var modelContext: ModelContext?
    private var userProgress: UserProgress?
    
    init() {
        initializeUserProgress()
    }
    
    // MARK: - 初始化
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        initializeUserProgress()
    }
    
    private func initializeUserProgress() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<UserProgress>()
            let existingProgress = try context.fetch(descriptor)
            
            if let progress = existingProgress.first {
                self.userProgress = progress
            } else {
                // 创建新的用户进度记录
                let newProgress = UserProgress()
                context.insert(newProgress)
                self.userProgress = newProgress
                try context.save()
            }
        } catch {
            print("初始化用户进度失败: \(error)")
        }
    }
    
    // MARK: - 获取用户进度
    
    func getUserProgress() -> UserProgress? {
        return userProgress
    }
    
    func getCurrentLevel() -> UserLevel {
        return userProgress?.level ?? .beginner
    }
    
    func getTotalExperience() -> Int {
        return userProgress?.experience ?? 0
    }
    
    func getConsecutiveDays() -> Int {
        return userProgress?.currentStreak ?? 0
    }
    
    // MARK: - 阅读统计
    
    func addReadingTime(_ minutes: Double) {
        guard let progress = userProgress else { return }
        
        progress.addReadingTime(minutes)
        updateDailyRecord(readingTime: minutes)
        saveProgress()
    }
    
    func incrementArticleRead() {
        guard let progress = userProgress else { return }
        
        progress.incrementArticlesRead()
        updateDailyRecord(articlesRead: 1)
        saveProgress()
    }
    
    func addWordLookup() {
        guard let progress = userProgress else { return }
        
        progress.incrementWordsLookedUp()
        updateDailyRecord(wordsLookedUp: 1)
        saveProgress()
    }
    
    func completeReview() {
        guard let progress = userProgress else { return }
        
        progress.completeReview()
        updateDailyRecord(reviewsCompleted: 1)
        saveProgress()
    }
    
    // MARK: - 每日记录管理
    
    private func updateDailyRecord(readingTime: Double = 0, articlesRead: Int = 0, wordsLookedUp: Int = 0, reviewsCompleted: Int = 0) {
        guard let progress = userProgress else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        if let todayRecord = progress.dailyRecords.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            todayRecord.readingTime += readingTime
            todayRecord.articlesRead += articlesRead
            todayRecord.wordsLookedUp += wordsLookedUp
            todayRecord.reviewsCompleted += reviewsCompleted
        } else {
            let newRecord = DailyStudyRecord(date: today)
            newRecord.readingTime = readingTime
            newRecord.articlesRead = articlesRead
            newRecord.wordsLookedUp = wordsLookedUp
            newRecord.reviewsCompleted = reviewsCompleted
            progress.dailyRecords.append(newRecord)
        }
    }
    
    func getTodayRecord() -> DailyStudyRecord? {
        guard let progress = userProgress else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        return progress.dailyRecords.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })
    }
    
    func getWeeklyRecords() -> [DailyStudyRecord] {
        guard let progress = userProgress else { return [] }
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        return progress.dailyRecords.filter { record in
            record.date >= weekAgo
        }.sorted { $0.date < $1.date }
    }
    
    func getMonthlyRecords() -> [DailyStudyRecord] {
        guard let progress = userProgress else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return progress.dailyRecords.filter { record in
            record.date >= startOfMonth
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - 经验值和等级
    
    func addExperience(_ points: Int, for action: ExperienceAction) {
        guard let progress = userProgress else { return }
        
        let actualPoints = calculateExperiencePoints(for: action)
        progress.experience += actualPoints
        
        // 检查是否升级
        checkLevelUp()
        
        // 检查成就
        checkAchievements(for: action, points: actualPoints)
        
        saveProgress()
    }
    
    private func calculateExperiencePoints(for action: ExperienceAction) -> Int {
        switch action {
        case .readArticle:
            return 10
        case .lookupWord:
            return 2
        case .completeReview:
            return 5
        case .consecutiveDay:
            return 20
        case .achievementUnlocked:
            return 50
        case .levelUp:
            return 100
        case .bookmarkArticle:
            return 2
        }
    }
    
    private func checkLevelUp() {
        guard let progress = userProgress else { return }
        
        let oldLevel = progress.level
        
        // 检查是否可以升级
        while let nextLevel = progress.level.nextLevel, progress.experience >= nextLevel.requiredExperience {
            progress.level = nextLevel
        }
        
        if progress.level != oldLevel {
            // 升级了，添加升级奖励经验
            addExperience(0, for: .levelUp)
        }
    }
    
    func getExperienceToNextLevel() -> Int {
        guard let progress = userProgress else { return 0 }
        
        if let nextLevel = progress.level.nextLevel {
            return max(0, nextLevel.requiredExperience - progress.experience)
        }
        return 0
    }
    
    func getLevelProgress() -> Double {
        guard let progress = userProgress else { return 0.0 }
        
        let currentLevelExp = progress.level.requiredExperience
        
        if let nextLevel = progress.level.nextLevel {
            let nextLevelExp = nextLevel.requiredExperience
            let progressInLevel = progress.experience - currentLevelExp
            let totalExpForLevel = nextLevelExp - currentLevelExp
            
            return Double(progressInLevel) / Double(totalExpForLevel)
        }
        
        return 1.0 // 已达到最高等级
    }
    
    // MARK: - 成就系统
    
    func unlockAchievement(_ type: AchievementType) {
        guard let progress = userProgress else { return }
        
        let achievement = Achievement(type: type)
        
        // 检查是否已经解锁
        let alreadyUnlocked = progress.achievements.contains { existingAchievement in
            existingAchievement.type == achievement.type
        }
        
        if !alreadyUnlocked {
            progress.achievements.append(achievement)
            addExperience(0, for: .achievementUnlocked)
            saveProgress()
        }
    }
    
    private func checkAchievements(for action: ExperienceAction, points: Int) {
        guard let progress = userProgress else { return }
        
        // 检查阅读相关成就
        if action == .readArticle {
            checkReadingAchievements(progress)
        }
        
        // 检查查词相关成就
        if action == .lookupWord {
            checkWordLookupAchievements(progress)
        }
        
        // 检查连续学习成就
        if action == .consecutiveDay {
            checkConsecutiveStudyAchievements(progress)
        }
        
        // 检查经验值成就
        checkExperienceAchievements(progress)
    }
    
    private func checkReadingAchievements(_ progress: UserProgress) {
        let articlesRead = progress.totalArticlesRead
        
        if articlesRead >= 1 {
            unlockAchievement(.firstArticle)
        }
        if articlesRead >= 10 {
            unlockAchievement(.read10Articles)
        }
        if articlesRead >= 50 {
            unlockAchievement(.read50Articles)
        }
        if articlesRead >= 100 {
            unlockAchievement(.read100Articles)
        }
    }
    
    private func checkWordLookupAchievements(_ progress: UserProgress) {
        let wordsLookedUp = progress.totalWordsLookedUp
        
        if wordsLookedUp >= 1 {
            unlockAchievement(.firstWord)
        }
        if wordsLookedUp >= 100 {
            unlockAchievement(.lookup100Words)
        }
        if wordsLookedUp >= 500 {
            unlockAchievement(.lookup500Words)
        }
        if wordsLookedUp >= 1000 {
            unlockAchievement(.lookup1000Words)
        }
    }
    
    private func checkConsecutiveStudyAchievements(_ progress: UserProgress) {
        let consecutiveDays = progress.currentStreak
        
        if consecutiveDays >= 3 {
            unlockAchievement(.streak3Days)
        }
        if consecutiveDays >= 7 {
            unlockAchievement(.streak7Days)
        }
        if consecutiveDays >= 30 {
            unlockAchievement(.streak30Days)
        }
        if consecutiveDays >= 100 {
            unlockAchievement(.streak100Days)
        }
    }
    
    private func checkExperienceAchievements(_ progress: UserProgress) {
        let totalTime = progress.totalReadingTime / 3600 // 转换为小时
        
        if totalTime >= 1 {
            unlockAchievement(.study1Hour)
        }
        if totalTime >= 10 {
            unlockAchievement(.study10Hours)
        }
        if totalTime >= 50 {
            unlockAchievement(.study50Hours)
        }
        if totalTime >= 100 {
            unlockAchievement(.study100Hours)
        }
    }
    
    func getUnlockedAchievements() -> [Achievement] {
        return userProgress?.achievements ?? []
    }
    
    func getAvailableAchievements() -> [AchievementType] {
        return AchievementType.allCases
    }
    
    // MARK: - 统计分析
    
    func getStudyStatistics() -> StudyStatistics {
        guard let progress = userProgress else {
            return StudyStatistics()
        }
        
        let weeklyRecords = getWeeklyRecords()
        let monthlyRecords = getMonthlyRecords()
        
        let weeklyReadingTime = weeklyRecords.reduce(0) { $0 + $1.readingTime }
        let monthlyReadingTime = monthlyRecords.reduce(0) { $0 + $1.readingTime }
        
        let weeklyArticles = weeklyRecords.reduce(0) { $0 + $1.articlesRead }
        let monthlyArticles = monthlyRecords.reduce(0) { $0 + $1.articlesRead }
        
        let weeklyWords = weeklyRecords.reduce(0) { $0 + $1.wordsLookedUp }
        let monthlyWords = monthlyRecords.reduce(0) { $0 + $1.wordsLookedUp }
        
        return StudyStatistics(
            totalReadingTime: progress.totalReadingTime,
            totalArticlesRead: progress.totalArticlesRead,
            totalWordsLookedUp: progress.totalWordsLookedUp,
            totalReviewsCompleted: 0, // 需要从dailyRecords计算
            consecutiveStudyDays: progress.currentStreak,
            currentLevel: progress.level,
            experiencePoints: progress.experience,
            achievementsUnlocked: progress.achievements.count,
            weeklyReadingTime: weeklyReadingTime,
            weeklyArticlesRead: weeklyArticles,
            weeklyWordsLookedUp: weeklyWords,
            monthlyReadingTime: monthlyReadingTime,
            monthlyArticlesRead: monthlyArticles,
            monthlyWordsLookedUp: monthlyWords,
            averageDailyReadingTime: progress.totalReadingTime / Double(max(1, progress.dailyRecords.count)),
            studyDaysCount: progress.dailyRecords.count
        )
    }
    
    func getReadingTrend(days: Int = 7) -> [DailyStudyRecord] {
        guard let progress = userProgress else { return [] }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        return progress.dailyRecords.filter { record in
            record.date >= startDate && record.date <= endDate
        }.sorted { $0.date < $1.date }
    }
    
    func getWeeklyComparison() -> WeeklyComparison {
        let calendar = Calendar.current
        let now = Date()
        
        // 本周
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let thisWeekRecords = userProgress?.dailyRecords.filter { record in
            record.date >= thisWeekStart
        } ?? []
        
        // 上周
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart
        let lastWeekEnd = calendar.date(byAdding: .day, value: -1, to: thisWeekStart) ?? thisWeekStart
        let lastWeekRecords = userProgress?.dailyRecords.filter { record in
            record.date >= lastWeekStart && record.date <= lastWeekEnd
        } ?? []
        
        let thisWeekTime = thisWeekRecords.reduce(0) { $0 + $1.readingTime }
        let lastWeekTime = lastWeekRecords.reduce(0) { $0 + $1.readingTime }
        
        let thisWeekArticles = thisWeekRecords.reduce(0) { $0 + $1.articlesRead }
        let lastWeekArticles = lastWeekRecords.reduce(0) { $0 + $1.articlesRead }
        
        let thisWeekWords = thisWeekRecords.reduce(0) { $0 + $1.wordsLookedUp }
        let lastWeekWords = lastWeekRecords.reduce(0) { $0 + $1.wordsLookedUp }
        
        return WeeklyComparison(
            thisWeekReadingTime: thisWeekTime,
            lastWeekReadingTime: lastWeekTime,
            thisWeekArticles: thisWeekArticles,
            lastWeekArticles: lastWeekArticles,
            thisWeekWords: thisWeekWords,
            lastWeekWords: lastWeekWords
        )
    }
    
    // MARK: - 数据管理
    
    private func saveProgress() {
        guard let context = modelContext else { return }
        
        do {
            try context.save()
        } catch {
            print("保存用户进度失败: \(error)")
        }
    }
    
    func resetProgress() {
        guard let context = modelContext, let progress = userProgress else { return }
        
        context.delete(progress)
        
        do {
            try context.save()
            initializeUserProgress()
        } catch {
            print("重置用户进度失败: \(error)")
        }
    }
    
    func exportProgressData() -> Data? {
        guard let progress = userProgress else { return nil }
        
        let exportData = ProgressExportData(
            totalReadingTime: progress.totalReadingTime,
            articlesRead: progress.totalArticlesRead,
            totalWordLookups: progress.totalWordsLookedUp,
            reviewsCompleted: 0, // 需要从dailyRecords计算
            consecutiveStudyDays: progress.currentStreak,
            experiencePoints: progress.experience,
            currentLevel: progress.level,
            achievements: progress.achievements,
            dailyRecords: progress.dailyRecords.map { DailyRecordData(from: $0) },
            exportDate: Date()
        )
        
        do {
            return try JSONEncoder().encode(exportData)
        } catch {
            print("导出进度数据失败: \(error)")
            return nil
        }
    }
    
    func importProgressData(_ data: Data) -> Bool {
        do {
            let importData = try JSONDecoder().decode(ProgressExportData.self, from: data)
            
            guard let context = modelContext else { return false }
            
            // 创建新的用户进度
            let newProgress = UserProgress()
            newProgress.totalReadingTime = importData.totalReadingTime
            newProgress.totalArticlesRead = importData.articlesRead
            newProgress.totalWordsLookedUp = importData.totalWordLookups
            newProgress.currentStreak = importData.consecutiveStudyDays
            newProgress.experience = importData.experiencePoints
            newProgress.level = importData.currentLevel
            newProgress.achievements = importData.achievements
            newProgress.dailyRecords = importData.dailyRecords.map { $0.toDailyStudyRecord() }
            
            // 删除旧的进度记录
            if let oldProgress = userProgress {
                context.delete(oldProgress)
            }
            
            context.insert(newProgress)
            self.userProgress = newProgress
            
            try context.save()
            return true
        } catch {
            print("导入进度数据失败: \(error)")
            return false
        }
    }
}

// MARK: - 数据结构

// 经验值动作类型
enum ExperienceAction {
    case readArticle
    case lookupWord
    case completeReview
    case consecutiveDay
    case achievementUnlocked
    case levelUp
    case bookmarkArticle
}

// 学习统计信息
struct StudyStatistics {
    let totalReadingTime: Double
    let totalArticlesRead: Int
    let totalWordsLookedUp: Int
    let totalReviewsCompleted: Int
    let consecutiveStudyDays: Int
    let currentLevel: UserLevel
    let experiencePoints: Int
    let achievementsUnlocked: Int
    let weeklyReadingTime: Double
    let weeklyArticlesRead: Int
    let weeklyWordsLookedUp: Int
    let monthlyReadingTime: Double
    let monthlyArticlesRead: Int
    let monthlyWordsLookedUp: Int
    let averageDailyReadingTime: Double
    let studyDaysCount: Int
    
    init() {
        self.totalReadingTime = 0
        self.totalArticlesRead = 0
        self.totalWordsLookedUp = 0
        self.totalReviewsCompleted = 0
        self.consecutiveStudyDays = 0
        self.currentLevel = .beginner
        self.experiencePoints = 0
        self.achievementsUnlocked = 0
        self.weeklyReadingTime = 0
        self.weeklyArticlesRead = 0
        self.weeklyWordsLookedUp = 0
        self.monthlyReadingTime = 0
        self.monthlyArticlesRead = 0
        self.monthlyWordsLookedUp = 0
        self.averageDailyReadingTime = 0
        self.studyDaysCount = 0
    }
    
    init(totalReadingTime: Double, totalArticlesRead: Int, totalWordsLookedUp: Int, totalReviewsCompleted: Int, consecutiveStudyDays: Int, currentLevel: UserLevel, experiencePoints: Int, achievementsUnlocked: Int, weeklyReadingTime: Double, weeklyArticlesRead: Int, weeklyWordsLookedUp: Int, monthlyReadingTime: Double, monthlyArticlesRead: Int, monthlyWordsLookedUp: Int, averageDailyReadingTime: Double, studyDaysCount: Int) {
        self.totalReadingTime = totalReadingTime
        self.totalArticlesRead = totalArticlesRead
        self.totalWordsLookedUp = totalWordsLookedUp
        self.totalReviewsCompleted = totalReviewsCompleted
        self.consecutiveStudyDays = consecutiveStudyDays
        self.currentLevel = currentLevel
        self.experiencePoints = experiencePoints
        self.achievementsUnlocked = achievementsUnlocked
        self.weeklyReadingTime = weeklyReadingTime
        self.weeklyArticlesRead = weeklyArticlesRead
        self.weeklyWordsLookedUp = weeklyWordsLookedUp
        self.monthlyReadingTime = monthlyReadingTime
        self.monthlyArticlesRead = monthlyArticlesRead
        self.monthlyWordsLookedUp = monthlyWordsLookedUp
        self.averageDailyReadingTime = averageDailyReadingTime
        self.studyDaysCount = studyDaysCount
    }
    
    var formattedTotalReadingTime: String {
        let hours = Int(totalReadingTime / 60)
        let minutes = Int(totalReadingTime.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    var formattedWeeklyReadingTime: String {
        let hours = Int(weeklyReadingTime / 60)
        let minutes = Int(weeklyReadingTime.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    var formattedMonthlyReadingTime: String {
        let hours = Int(monthlyReadingTime / 60)
        let minutes = Int(monthlyReadingTime.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// 周对比数据
struct WeeklyComparison {
    let thisWeekReadingTime: Double
    let lastWeekReadingTime: Double
    let thisWeekArticles: Int
    let lastWeekArticles: Int
    let thisWeekWords: Int
    let lastWeekWords: Int
    
    var readingTimeChange: Double {
        guard lastWeekReadingTime > 0 else { return 0 }
        return (thisWeekReadingTime - lastWeekReadingTime) / lastWeekReadingTime
    }
    
    var articlesChange: Double {
        guard lastWeekArticles > 0 else { return 0 }
        return Double(thisWeekArticles - lastWeekArticles) / Double(lastWeekArticles)
    }
    
    var wordsChange: Double {
        guard lastWeekWords > 0 else { return 0 }
        return Double(thisWeekWords - lastWeekWords) / Double(lastWeekWords)
    }
}

// 进度导出数据
struct ProgressExportData: Codable {
    let totalReadingTime: Double
    let articlesRead: Int
    let totalWordLookups: Int
    let reviewsCompleted: Int
    let consecutiveStudyDays: Int
    let experiencePoints: Int
    let currentLevel: UserLevel
    let achievements: [Achievement]
    let dailyRecords: [DailyRecordData]
    let exportDate: Date
}

// 用于导出的每日记录数据
struct DailyRecordData: Codable {
    let id: UUID
    let date: Date
    let readingTime: TimeInterval
    let articlesRead: Int
    let wordsLookedUp: Int
    let newWordsLearned: Int
    let reviewsCompleted: Int
    let experienceGained: Int
    
    init(from record: DailyStudyRecord) {
        self.id = record.id
        self.date = record.date
        self.readingTime = record.readingTime
        self.articlesRead = record.articlesRead
        self.wordsLookedUp = record.wordsLookedUp
        self.newWordsLearned = record.newWordsLearned
        self.reviewsCompleted = record.reviewsCompleted
        self.experienceGained = record.experienceGained
    }
    
    func toDailyStudyRecord() -> DailyStudyRecord {
        let record = DailyStudyRecord(date: date)
        record.id = id
        record.readingTime = readingTime
        record.articlesRead = articlesRead
        record.wordsLookedUp = wordsLookedUp
        record.newWordsLearned = newWordsLearned
        record.reviewsCompleted = reviewsCompleted
        record.experienceGained = experienceGained
        return record
    }
}

// MARK: - 扩展

extension UserProgressService {
    // 获取学习建议
    func getStudyRecommendations() -> [StudyRecommendation] {
        guard let progress = userProgress else { return [] }
        
        var recommendations: [StudyRecommendation] = []
        
        // 基于连续学习天数的建议
        if progress.currentStreak == 0 {
            recommendations.append(StudyRecommendation(
                type: .startLearning,
                title: "开始学习之旅",
                description: "今天开始阅读第一篇文章，建立学习习惯！",
                priority: .high
            ))
        } else if progress.currentStreak < 7 {
            recommendations.append(StudyRecommendation(
                type: .maintainStreak,
                title: "保持学习连续性",
                description: "已连续学习\(progress.currentStreak)天，继续保持！",
                priority: .medium
            ))
        }
        
        // 基于阅读时间的建议
        let todayRecord = getTodayRecord()
        if todayRecord?.readingTime ?? 0 < 30 {
            recommendations.append(StudyRecommendation(
                type: .increaseReadingTime,
                title: "增加阅读时间",
                description: "建议每天至少阅读30分钟以获得更好的学习效果",
                priority: .medium
            ))
        }
        
        // 基于词汇量的建议
        if progress.totalWordsLookedUp < 100 {
            recommendations.append(StudyRecommendation(
                type: .expandVocabulary,
                title: "扩展词汇量",
                description: "多查询生词，建立个人词汇宝典",
                priority: .low
            ))
        }
        
        // 基于复习的建议
        let reviewsCompleted = 0 // 需要从dailyRecords计算
        if reviewsCompleted < progress.totalWordsLookedUp / 5 {
            recommendations.append(StudyRecommendation(
                type: .reviewWords,
                title: "复习生词",
                description: "定期复习已查询的单词，巩固记忆",
                priority: .high
            ))
        }
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    // 获取学习目标完成情况
    func getGoalProgress() -> GoalProgress {
        guard let _ = userProgress else {
            return GoalProgress()
        }
        
        let todayRecord = getTodayRecord()
        let weeklyRecords = getWeeklyRecords()
        
        let dailyReadingGoal: Double = 30 // 30分钟
        let weeklyArticleGoal = 5 // 5篇文章
        let weeklyWordGoal = 50 // 50个单词
        
        let dailyReadingProgress = min(1.0, (todayRecord?.readingTime ?? 0) / dailyReadingGoal)
        let weeklyArticleProgress = min(1.0, Double(weeklyRecords.reduce(0) { $0 + $1.articlesRead }) / Double(weeklyArticleGoal))
        let weeklyWordProgress = min(1.0, Double(weeklyRecords.reduce(0) { $0 + $1.wordsLookedUp }) / Double(weeklyWordGoal))
        
        return GoalProgress(
            dailyReadingProgress: dailyReadingProgress,
            weeklyArticleProgress: weeklyArticleProgress,
            weeklyWordProgress: weeklyWordProgress,
            dailyReadingGoal: dailyReadingGoal,
            weeklyArticleGoal: weeklyArticleGoal,
            weeklyWordGoal: weeklyWordGoal
        )
    }
}

// 学习建议
struct StudyRecommendation {
    let type: RecommendationType
    let title: String
    let description: String
    let priority: Priority
    
    enum RecommendationType {
        case startLearning
        case maintainStreak
        case increaseReadingTime
        case expandVocabulary
        case reviewWords
    }
    
    enum Priority: Int {
        case low = 1
        case medium = 2
        case high = 3
    }
}

// 目标进度
struct GoalProgress {
    let dailyReadingProgress: Double
    let weeklyArticleProgress: Double
    let weeklyWordProgress: Double
    let dailyReadingGoal: Double
    let weeklyArticleGoal: Int
    let weeklyWordGoal: Int
    
    init() {
        self.dailyReadingProgress = 0
        self.weeklyArticleProgress = 0
        self.weeklyWordProgress = 0
        self.dailyReadingGoal = 30
        self.weeklyArticleGoal = 5
        self.weeklyWordGoal = 50
    }
    
    init(dailyReadingProgress: Double, weeklyArticleProgress: Double, weeklyWordProgress: Double, dailyReadingGoal: Double, weeklyArticleGoal: Int, weeklyWordGoal: Int) {
        self.dailyReadingProgress = dailyReadingProgress
        self.weeklyArticleProgress = weeklyArticleProgress
        self.weeklyWordProgress = weeklyWordProgress
        self.dailyReadingGoal = dailyReadingGoal
        self.weeklyArticleGoal = weeklyArticleGoal
        self.weeklyWordGoal = weeklyWordGoal
    }
}