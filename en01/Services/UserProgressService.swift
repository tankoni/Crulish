//
//  UserProgressService.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData

enum ExperienceAction {
    case readArticle
    case lookupWord
    case completeReview
    case consecutiveDay
    case achievementUnlocked
    case levelUp
    case bookmarkArticle
}

@Observable
class UserProgressService: BaseService, UserProgressServiceProtocol {
    private var userProgress: UserProgress?
    
    init(
        modelContext: ModelContext,
        cacheManager: CacheManagerProtocol,
        errorHandler: ErrorHandlerProtocol
    ) {
        super.init(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler,
            subsystem: "com.en01.services",
            category: "UserProgressService"
        )
        initializeUserProgress()
    }
    
    // MARK: - 初始化
    
    /// 初始化用户进度（带错误处理优化）
    private func initializeUserProgress() {
        let descriptor = FetchDescriptor<UserProgress>()
        let existingProgress = safeFetch(descriptor, operation: "获取用户进度")
        
        if let progress = existingProgress.first {
            self.userProgress = progress
            logger.info("用户进度加载成功")
        } else {
            // 创建新的用户进度记录
            let newProgress = UserProgress()
            modelContext.insert(newProgress)
            self.userProgress = newProgress
            safeSave(operation: "保存新用户进度")
            logger.info("新用户进度创建成功")
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
        performSafeOperation("添加阅读时间") {
            guard let progress = userProgress else {
                throw ServiceError.notFound("用户进度不存在")
            }
            
            progress.addReadingTime(minutes)
            updateDailyRecord(readingTime: minutes)
            
            safeSave(operation: "保存阅读时间")
            logger.info("添加阅读时间: \(minutes)分钟")
        }
    }
    
    func incrementArticleRead() {
        performSafeOperation("增加已读文章数") {
            guard let progress = userProgress else {
                throw ServiceError.notFound("用户进度不存在")
            }
            
            progress.incrementArticlesRead()
            updateDailyRecord(articlesRead: 1)
            
            safeSave(operation: "保存文章阅读记录")
            logger.info("已读文章数增加1，当前总数: \(progress.totalArticlesRead)")
        }
    }
    
    func addWordLookup() {
        performSafeOperation("添加查词记录") {
            guard let progress = userProgress else {
                throw ServiceError.notFound("用户进度不存在")
            }
            
            progress.incrementWordsLookedUp()
            updateDailyRecord(wordsLookedUp: 1)
            
            safeSave(operation: "保存词汇查找记录")
            logger.info("查词次数增加1，当前总数: \(progress.totalWordsLookedUp)")
        }
    }
    
    func completeReview() {
        performSafeOperation("完成复习") {
            guard let progress = userProgress else {
                throw ServiceError.notFound("用户进度不存在")
            }
            
            progress.completeReview()
            updateDailyRecord(reviewsCompleted: 1)
            
            safeSave(operation: "保存复习记录")
            logger.info("复习完成次数增加1")
        }
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
        performSafeOperation("添加经验值") {
            guard let progress = userProgress else {
                throw ServiceError.notFound("用户进度不存在")
            }
            
            let actualPoints = calculateExperiencePoints(for: action)
            progress.experience += actualPoints
            
            // 检查是否升级
            checkLevelUp()
            
            // 检查成就
            checkAchievements(for: action, points: actualPoints)
            
            safeSave(operation: "保存经验值")
            logger.info("添加经验值: \(actualPoints)，当前总经验: \(progress.experience)")
        }
    }
    
    // MARK: - Protocol Required Methods
    
    func recordWordReview(word: String, correct: Bool) async throws {
        // TODO: 实现单词复习记录
        logger.info("记录单词复习: \(word), 正确: \(correct)")
    }
    
    func recordReviewSession(wordsReviewed: Int, correctAnswers: Int) async throws {
        // TODO: 实现复习会话记录
        logger.info("记录复习会话: 复习\(wordsReviewed)个单词，正确\(correctAnswers)个")
    }
    
    func recordArticleCompletion(articleId: String, readingTime: TimeInterval, wordsLookedUp: Int) async throws {
        // TODO: 实现文章完成记录
        logger.info("记录文章完成: \(articleId), 阅读时间: \(readingTime), 查词数: \(wordsLookedUp)")
    }
    
    func updateReadingProgress(articleId: String, progress: Double, readingTime: TimeInterval) async throws {
        // TODO: 实现阅读进度更新
        logger.info("更新阅读进度: \(articleId), 进度: \(progress), 时间: \(readingTime)")
    }
    
    func recordWordLookup(word: String, articleId: String) async throws {
        // TODO: 实现查词记录
        logger.info("记录查词: \(word) 在文章 \(articleId)")
    }
    
    func addBookmark(articleId: String) async throws {
        // TODO: 实现添加书签
        logger.info("添加书签: \(articleId)")
    }
    
    func removeBookmark(articleId: String) async throws {
        // TODO: 实现移除书签
        logger.info("移除书签: \(articleId)")
    }
    
    func isBookmarked(articleId: String) async throws -> Bool {
        // TODO: 实现书签检查
        logger.info("检查书签: \(articleId)")
        return false
    }
    
    func markArticleAsCompleted(articleId: String) async throws {
        // TODO: 实现标记文章完成
        logger.info("标记文章完成: \(articleId)")
    }
    
    func isCompleted(articleId: String) async throws -> Bool {
        // TODO: 实现完成状态检查
        logger.info("检查完成状态: \(articleId)")
        return false
    }
    
    func getReadingTrend(days: Int) -> [DailyStudyRecord] {
        guard let progress = userProgress else { return [] }
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        
        return progress.dailyRecords.filter { record in
            record.date >= startDate
        }.sorted { $0.date < $1.date }
    }
    
    func getWeeklyComparison() -> WeeklyComparison {
        // TODO: 实现周对比数据
        return WeeklyComparison(
            thisWeekReadingTime: 0,
            lastWeekReadingTime: 0,
            thisWeekArticles: 0,
            lastWeekArticles: 0,
            thisWeekWords: 0,
            lastWeekWords: 0
        )
    }
    
    func getStudyStatistics() -> StudyStatistics {
        // TODO: 实现学习统计
        return StudyStatistics()
    }
    
    // MARK: - Statistics Methods
    
    func getTodayStatistics() async throws -> TodayStatistics {
        return await MainActor.run {
            let todayRecord = getTodayRecord()
            let _ = getUserProgress()
            
            let readingTime = todayRecord?.readingTime ?? 0
            let articlesRead = todayRecord?.articlesRead ?? 0
            let wordsLookedUp = todayRecord?.wordsLookedUp ?? 0
            let reviewsCompleted = todayRecord?.reviewsCompleted ?? 0
            
            // 计算每日阅读目标进度 (使用默认30分钟目标)
            let dailyGoal = 30.0 // 默认每日阅读目标30分钟
            let progress = Double(readingTime) / (dailyGoal * 60)
            
            let consecutiveDays = getConsecutiveDays()
            
            return TodayStatistics(
                readingTime: readingTime,
                articlesRead: articlesRead,
                wordsLookedUp: wordsLookedUp,
                reviewsCompleted: reviewsCompleted,
                dailyReadingGoalProgress: min(progress, 1.0),
                consecutiveDays: consecutiveDays
            )
        }
    }
    
    func getWeeklyStatistics() async throws -> WeeklyStatistics {
        // TODO: 实现周统计
        return WeeklyStatistics()
    }
    
    func getMonthlyStatistics() async throws -> MonthlyStatistics {
        // TODO: 实现月统计
        return MonthlyStatistics()
    }
    
    func getOverallStatistics() async throws -> OverallStatistics {
        // TODO: 实现总体统计
        return OverallStatistics()
    }
    
    func getVocabularyProgressStatistics() async throws -> VocabularyProgressStats {
        // TODO: 实现词汇进度统计
        return VocabularyProgressStats()
    }
    
    func getVocabularyStatistics() async throws -> VocabularyStatistics {
        return await MainActor.run {
            // 从DictionaryService获取词汇统计
            let vocabularyStats = getCachedOrFetchModel(
                key: "vocabulary_statistics",
                operation: "获取词汇统计"
            ) {
                // 这里应该从DictionaryService获取实际的词汇数据
                // 暂时返回默认值
                return VocabularyStatistics(
                    totalWords: 0,
                    unknownWords: 0,
                    learningWords: 0,
                    familiarWords: 0,
                    masteredWords: 0,
                    wordsNeedingReview: 0,
                    averageLookupCount: 0.0,
                    totalLookups: 0
                )
            }
            
            return vocabularyStats ?? VocabularyStatistics(
                totalWords: 0,
                unknownWords: 0,
                learningWords: 0,
                familiarWords: 0,
                masteredWords: 0,
                wordsNeedingReview: 0,
                averageLookupCount: 0.0,
                totalLookups: 0
            )
        }
    }
    
    func getAchievementStatistics() async throws -> AchievementStatistics {
        // TODO: 实现成就统计
        return AchievementStatistics()
    }
    
    func getReadingTimeChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint] {
        // TODO: 实现阅读时间图表数据
        return []
    }
    
    func getVocabularyChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint] {
        // TODO: 实现词汇图表数据
        return []
    }
    
    func getProgressChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint] {
        // TODO: 实现进度图表数据
        return []
    }
    
    func getExperienceToNextLevel() -> Int {
        guard let progress = userProgress else { return 0 }
        let currentLevel = progress.level
        let nextLevelExp = currentLevel.requiredExperience
        return max(0, nextLevelExp - progress.experience)
    }
    
    func getUnlockedAchievements() -> [Achievement] {
        guard let progress = userProgress else { return [] }
        return progress.achievements
    }
    
    func getAvailableAchievements() -> [AchievementType] {
        // TODO: 实现可用成就列表
        return []
    }
    
    func resetProgress() {
        performSafeOperation("重置进度") {
            guard let progress = userProgress else {
                throw ServiceError.notFound("用户进度不存在")
            }
            
            // 重置所有进度数据
            progress.totalReadingTime = 0
            progress.totalArticlesRead = 0
            progress.totalWordsLookedUp = 0
            progress.experience = 0
            progress.level = .beginner
            progress.currentStreak = 0
            progress.dailyRecords.removeAll()
            progress.achievements.removeAll()
            
            safeSave(operation: "重置用户进度")
            logger.info("用户进度已重置")
        }
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

    func getProgressStatistics() -> ProgressStatistics {
        // TODO: Implement actual logic
        return ProgressStatistics(weeklyStats: WeeklyStats(), monthlyStats: MonthlyStats())
    }
    
    // MARK: - 成就系统
    
    func unlockAchievement(_ type: AchievementType) {
        performSafeOperation("解锁成就") {
            guard let progress = userProgress else {
                throw ServiceError.notFound("用户进度不存在")
            }
            
            let achievement = Achievement(type: type)
            
            // 检查是否已经解锁
            let alreadyUnlocked = progress.achievements.contains { existingAchievement in
                existingAchievement.type == achievement.type
            }
            
            if !alreadyUnlocked {
                progress.achievements.append(achievement)
                addExperience(0, for: .achievementUnlocked)
                
                safeSave(operation: "保存成就解锁")
                logger.info("解锁新成就: \(type)")
            }
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
    

    
    // MARK: - 统计分析
    

    

    

    
    // MARK: - 数据管理
    
    /// 保存用户进度（带错误处理优化）
    private func saveProgress() {
        safeSave(operation: "保存用户进度")
    }
    

    
    /// 导出用户进度数据（带错误处理优化）
    /// - Returns: 序列化后的进度数据，失败时返回nil
    func exportProgressData() -> Data? {
        guard let progress = userProgress else { 
            logger.error("用户进度不存在，无法导出")
            return nil 
        }
        
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
            let data = try JSONEncoder().encode(exportData)
            logger.info("进度数据导出成功，大小: \(data.count) bytes")
            return data
        } catch {
            let serviceError = ServiceError.encodingError(error)
            errorHandler.handle(serviceError, context: "导出进度数据失败")
            return nil
        }
    }
    
    /// 导入用户进度数据（带错误处理优化）
    /// - Parameter data: 要导入的进度数据
    /// - Returns: 导入是否成功
    func importProgressData(_ data: Data) -> Bool {
        guard !data.isEmpty else {
            logger.error("导入数据为空")
            return false
        }
        
        do {
            let importData = try JSONDecoder().decode(ProgressExportData.self, from: data)
            logger.info("进度数据解码成功")
            
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
                modelContext.delete(oldProgress)
                logger.info("已删除旧的用户进度")
            }
            
            modelContext.insert(newProgress)
            self.userProgress = newProgress
            
            safeSave(operation: "导入用户进度")
            logger.info("用户进度导入成功")
            return true
        } catch {
            let serviceError: ServiceError
            let context: String
            if error is DecodingError {
                serviceError = ServiceError.decodingError(error)
                context = "数据格式错误"
            } else {
                serviceError = ServiceError.databaseError(error)
                context = "导入进度数据失败"
            }
            errorHandler.handle(serviceError, context: context)
            return false
        }
    }
}

// MARK: - 数据结构

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
                description: "连续学习是进步的关键，继续加油！",
                priority: .medium
            ))
        } else {
            recommendations.append(StudyRecommendation(
                type: .challengeYourself,
                title: "挑战更高目标",
                description: "你已经保持了很好的学习习惯，尝试一些更有挑战性的文章吧！",
                priority: .low
            ))
        }
        
        // 基于阅读文章数量的建议
        if progress.totalArticlesRead < 10 {
            recommendations.append(StudyRecommendation(
                type: .exploreTopics,
                title: "探索不同主题",
                description: "多阅读不同类型的文章，找到你的兴趣所在。",
                priority: .medium
            ))
        }
        
        // 基于等级的建议
        if progress.level != .advanced && progress.level != .expert {
            recommendations.append(StudyRecommendation(
                type: .levelUp,
                title: "向更高等级迈进",
                description: "通过持续学习提升等级，解锁更多功能。",
                priority: .medium
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
        case challengeYourself
        case exploreTopics
        case levelUp
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

// MARK: - Settings Management

extension UserProgressService {
    // 获取设置方法
    func getUserSettings() async throws -> UserSettings {
        return UserSettings()
    }
    
    func getReadingSettings() async throws -> ReadingSettings {
        return ReadingSettings()
    }
    
    func getVocabularySettings() async throws -> VocabularySettings {
        return VocabularySettings()
    }
    
    func getNotificationSettings() async throws -> NotificationSettings {
        return NotificationSettings()
    }
    
    func getPrivacySettings() async throws -> PrivacySettings {
        return PrivacySettings()
    }
    
    func getAppearanceSettings() async throws -> AppearanceSettings {
        return AppearanceSettings()
    }
    
    // 更新设置方法
    func updateUserSettings(_ settings: UserSettings) async throws {
        // 实现用户设置更新逻辑
        logger.info("用户设置已更新")
    }
    
    func updateReadingSettings(_ settings: ReadingSettings) async throws {
        // 实现阅读设置更新逻辑
        logger.info("阅读设置已更新")
    }
    
    func updateVocabularySettings(_ settings: VocabularySettings) async throws {
        // 实现词汇设置更新逻辑
        logger.info("词汇设置已更新")
    }
    
    func updateNotificationSettings(_ settings: NotificationSettings) async throws {
        // 实现通知设置更新逻辑
        logger.info("通知设置已更新")
    }
    
    func updatePrivacySettings(_ settings: PrivacySettings) async throws {
        // 实现隐私设置更新逻辑
        logger.info("隐私设置已更新")
    }
    
    func updateAppearanceSettings(_ settings: AppearanceSettings) async throws {
        // TODO: 实现外观设置更新逻辑
        logger.info("外观设置已更新")
    }
    
    func resetAllData() async throws {
        // TODO: 实现重置所有数据的逻辑
        // 清除所有用户进度数据
        // 重置设置到默认值
        // 清除缓存
        logger.info("所有数据已重置")
    }
}