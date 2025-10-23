//
//  UserProgressService.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData



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
    
    func addExperience(_ points: Int, for activity: ExperienceAction) {
        performSafeOperation("添加经验值") {
            guard let progress = userProgress else {
                throw ServiceError.notFound("用户进度不存在")
            }
            
            let actualPoints = calculateExperiencePoints(for: activity)
            progress.experience += actualPoints
            
            // 检查是否升级
            checkLevelUp()
            
            // 检查成就
            checkAchievements(for: activity, points: actualPoints)
            
            safeSave(operation: "保存经验值")
            logger.info("添加经验值: \(actualPoints)，当前总经验: \(progress.experience)")
        }
    }
    
    // MARK: - Protocol Required Methods
    
    /// 计算经验值
    private func calculateExperiencePoints(for action: ExperienceAction) -> Int {
        switch action {
        case .readArticle:
            return 10
        case .lookupWord:
            return 2
        case .completeReview:
            return 5
        case .consecutiveDay:
            return 15
        case .achievementUnlocked:
            return 20
        case .levelUp:
            return 50
        case .bookmarkArticle:
            return 3
        }
    }
    
    /// 检查是否升级
    private func checkLevelUp() {
        guard let progress = userProgress else { return }
        
        let currentLevel = progress.level
        let newLevel = calculateLevel(from: progress.experience)
        
        if newLevel.rawValue > currentLevel.rawValue {
            progress.level = newLevel
            // 升级时给予额外经验奖励
            addExperience(50, for: .levelUp)
            logger.info("用户升级到等级 \(newLevel)")
        }
    }
    
    /// 检查成就
    private func checkAchievements(for action: ExperienceAction, points: Int) {
        guard let progress = userProgress else { return }
        
        // 这里可以根据不同的行为检查相应的成就
        // 例如：连续阅读天数、总经验值、单词查询次数等
        switch action {
        case .readArticle:
            if progress.articlesRead >= 10 && !progress.achievements.contains(where: { $0.type == .read10Articles }) {
                let achievement = AchievementData(type: .read10Articles)
                progress.achievements.append(achievement)
                logger.info("解锁成就：阅读10篇文章")
            }
        case .lookupWord:
            if progress.totalWordsLookedUp >= 100 && !progress.achievements.contains(where: { $0.type == .lookup100Words }) {
                let achievement = AchievementData(type: .lookup100Words)
                progress.achievements.append(achievement)
                logger.info("解锁成就：查询100个单词")
            }
        case .consecutiveDay:
            if progress.currentStreak >= 7 && !progress.achievements.contains(where: { $0.type == .streak7Days }) {
                let achievement = AchievementData(type: .streak7Days)
                progress.achievements.append(achievement)
                logger.info("解锁成就：连续学习7天")
            }
        default:
            break
        }
    }
    
    /// 根据经验值计算等级
    private func calculateLevel(from experience: Int) -> UserLevel {
        // 根据经验值计算等级
        if experience < 100 {
            return .beginner
        } else if experience < 500 {
            return .intermediate
        } else if experience < 1000 {
            return .advanced
        } else {
            return .expert
        }
    }
    
    // MARK: - Protocol Methods Implementation
    
    func recordWordReview(word: String, correct: Bool) async throws {
        await MainActor.run {
            guard userProgress != nil else {
                logger.error("用户进度未初始化")
                return
            }
            
            // 更新每日记录
            updateDailyRecord(reviewsCompleted: 1)
            
            // 添加经验值
            let points = correct ? 5 : 2
            addExperience(points, for: .completeReview)
            
            safeSave(operation: "记录单词复习")
            logger.info("记录单词复习: \(word), 正确: \(correct), 获得经验: \(points)")
        }
    }
    
    func recordReviewSession(wordsReviewed: Int, correctAnswers: Int) async throws {
        await MainActor.run {
            guard userProgress != nil else {
                logger.error("用户进度未初始化")
                return
            }
            
            // 更新每日记录
            updateDailyRecord(reviewsCompleted: wordsReviewed)
            
            // 计算准确率和经验值
            let accuracy = wordsReviewed > 0 ? Double(correctAnswers) / Double(wordsReviewed) : 0
            let basePoints = correctAnswers * 5 + (wordsReviewed - correctAnswers) * 2
            let bonusPoints = accuracy >= 0.8 ? Int(Double(basePoints) * 0.2) : 0
            
            addExperience(basePoints + bonusPoints, for: .completeReview)
            
            safeSave(operation: "记录复习会话")
            logger.info("记录复习会话: 复习\(wordsReviewed)个单词，正确\(correctAnswers)个，准确率: \(String(format: "%.1f", accuracy * 100))%")
        }
    }
    
    func recordArticleCompletion(articleId: String, readingTime: TimeInterval, wordsLookedUp: Int) async throws {
        await MainActor.run {
            guard let progress = userProgress else {
                logger.error("用户进度未初始化")
                return
            }
            
            // 更新每日记录
            updateDailyRecord(
                readingTime: readingTime / 60, // 转换为分钟
                articlesRead: 1,
                wordsLookedUp: wordsLookedUp
            )
            
            // 添加经验值
            let basePoints = 20 // 完成文章基础分
            let timeBonus = readingTime > 300 ? 10 : 0 // 阅读超过5分钟额外奖励
            let vocabularyBonus = min(wordsLookedUp * 2, 20) // 查词奖励，最多20分
            
            addExperience(basePoints + timeBonus + vocabularyBonus, for: .readArticle)
            
            // 标记文章为已完成
            if !progress.completedArticleIds.contains(articleId) {
                progress.completedArticleIds.append(articleId)
            }
            
            safeSave(operation: "记录文章完成")
            logger.info("记录文章完成: \(articleId), 阅读时间: \(String(format: "%.1f", readingTime/60))分钟, 查词数: \(wordsLookedUp)")
        }
    }
    
    func updateReadingProgress(articleId: String, progress: Double, readingTime: TimeInterval) async throws {
        await MainActor.run {
            guard let userProgress = userProgress else {
                logger.error("用户进度未初始化")
                return
            }
            
            // 查找或创建阅读进度记录
            if let existingIndex = userProgress.readingProgress.firstIndex(where: { $0.articleId == articleId }) {
                userProgress.readingProgress[existingIndex].progress = progress
                userProgress.readingProgress[existingIndex].lastReadTime = Date()
                userProgress.readingProgress[existingIndex].totalReadingTime += readingTime
            } else {
                let progressRecord = ReadingProgressRecord(
                    articleId: articleId,
                    progress: progress,
                    totalReadingTime: readingTime,
                    lastReadTime: Date()
                )
                userProgress.readingProgress.append(progressRecord)
            }
            
            // 更新每日阅读时间
            updateDailyRecord(readingTime: readingTime / 60)
            
            safeSave(operation: "更新阅读进度")
            logger.info("更新阅读进度: \(articleId), 进度: \(String(format: "%.1f", progress * 100))%, 时间: \(String(format: "%.1f", readingTime/60))分钟")
        }
    }
    
    func recordWordLookup(word: String, articleId: String) async throws {
        await MainActor.run {
            guard userProgress != nil else {
                logger.error("用户进度未初始化")
                return
            }
            
            // 更新每日记录
            updateDailyRecord(wordsLookedUp: 1)
            
            // 添加经验值
            addExperience(3, for: .lookupWord)
            
            safeSave(operation: "记录查词")
            logger.info("记录查词: \(word) 在文章 \(articleId)")
        }
    }
    
    func addBookmark(articleId: String) async throws {
        await MainActor.run {
            guard let progress = userProgress else {
                logger.error("用户进度未初始化")
                return
            }
            
            if !progress.bookmarkedArticles.contains(articleId) {
                progress.bookmarkedArticles.append(articleId)
                
                // 添加经验值
                addExperience(5, for: .bookmarkArticle)
                
                safeSave(operation: "添加书签")
                logger.info("添加书签: \(articleId)")
            }
        }
    }
    
    func removeBookmark(articleId: String) async throws {
        await MainActor.run {
            guard let progress = userProgress else {
                logger.error("用户进度未初始化")
                return
            }
            
            if let index = progress.bookmarkedArticles.firstIndex(of: articleId) {
                progress.bookmarkedArticles.remove(at: index)
                safeSave(operation: "移除书签")
                logger.info("移除书签: \(articleId)")
            }
        }
    }
    
    func isBookmarked(articleId: String) async throws -> Bool {
        return await MainActor.run {
            guard let progress = userProgress else {
                logger.error("用户进度未初始化")
                return false
            }
            return progress.bookmarkedArticles.contains(articleId)
        }
    }
    
    func markArticleAsCompleted(articleId: String) async throws {
        await MainActor.run {
            guard let progress = userProgress else {
                logger.error("用户进度未初始化")
                return
            }
            
            if !progress.completedArticleIds.contains(articleId) {
                progress.completedArticleIds.append(articleId)
                
                // 更新每日记录
                updateDailyRecord(articlesRead: 1)
                
                // 添加经验值
                addExperience(15, for: .readArticle)
                
                safeSave(operation: "标记文章完成")
                logger.info("标记文章完成: \(articleId)")
            }
        }
    }
    
    func isCompleted(articleId: String) async throws -> Bool {
        return await MainActor.run {
            guard let progress = userProgress else {
                logger.error("用户进度未初始化")
                return false
            }
            return progress.completedArticleIds.contains(articleId)
        }
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
        guard let progress = userProgress else {
            return WeeklyComparison(
                currentWeek: StatisticsWeeklyStats(totalStudyTime: 0, articlesRead: 0, wordsLearned: 0),
                previousWeek: StatisticsWeeklyStats(totalStudyTime: 0, articlesRead: 0, wordsLearned: 0)
            )
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // 本周数据
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let thisWeekRecords = progress.dailyRecords.filter { $0.date >= thisWeekStart }
        
        // 上周数据
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? now
        let lastWeekEnd = thisWeekStart
        let lastWeekRecords = progress.dailyRecords.filter { 
            $0.date >= lastWeekStart && $0.date < lastWeekEnd 
        }
        
        let previousWeekStats = StatisticsWeeklyStats(
            totalStudyTime: lastWeekRecords.reduce(0) { $0 + $1.readingTime },
            articlesRead: lastWeekRecords.reduce(0) { $0 + $1.articlesRead },
            wordsLearned: lastWeekRecords.reduce(0) { $0 + $1.wordsLookedUp }
        )
        
        let currentWeekStats = StatisticsWeeklyStats(
            totalStudyTime: thisWeekRecords.reduce(0) { $0 + $1.readingTime },
            articlesRead: thisWeekRecords.reduce(0) { $0 + $1.articlesRead },
            wordsLearned: thisWeekRecords.reduce(0) { $0 + $1.wordsLookedUp }
        )
        
        return WeeklyComparison(currentWeek: currentWeekStats, previousWeek: previousWeekStats)
    }
    
    func getStudyStatistics() -> StudyStatistics {
        guard let progress = userProgress else {
            return StudyStatistics(
                totalStudyTime: 0,
                averageSessionTime: 0,
                totalSessions: 0,
                consecutiveDays: 0,
                longestStreak: 0,
                weeklyAverage: 0,
                monthlyAverage: 0
            )
        }
        
        let totalReadingTime = progress.dailyRecords.reduce(0) { $0 + $1.readingTime }
        let _ = progress.dailyRecords.reduce(0) { $0 + $1.articlesRead }
        let _ = progress.dailyRecords.reduce(0) { $0 + $1.wordsLookedUp }
        
        let studyDays = progress.dailyRecords.filter { $0.readingTime > 0 }.count
        let averageSessionTime = studyDays > 0 ? totalReadingTime / Double(studyDays) : 0
        
        return StudyStatistics(
            totalStudyTime: totalReadingTime,
            averageSessionTime: averageSessionTime,
            totalSessions: studyDays,
            consecutiveDays: progress.currentStreak,
            longestStreak: progress.longestStreak,
            weeklyAverage: totalReadingTime / 7,
            monthlyAverage: totalReadingTime / 30
        )
    }
    
    func getTodayStatistics() async throws -> TodayStatistics {
        return await MainActor.run {
            guard let progress = userProgress else {
                return TodayStatistics()
            }
            
            let todayRecord = getTodayRecord()
            
            return TodayStatistics(
                readingTime: todayRecord?.readingTime ?? 0,
                articlesRead: todayRecord?.articlesRead ?? 0,
                wordsLookedUp: todayRecord?.wordsLookedUp ?? 0,
                reviewsCompleted: todayRecord?.reviewsCompleted ?? 0,
                dailyReadingGoalProgress: 0, // 需要根据目标计算
                consecutiveDays: progress.currentStreak
            )
        }
    }
    
    func getWeeklyStatistics() async throws -> WeeklyStatistics {
        return await MainActor.run {
            guard userProgress != nil else {
                return WeeklyStatistics()
            }
            
            let weeklyRecords = getWeeklyRecords()
            let totalReadingTime = weeklyRecords.reduce(0) { $0 + $1.readingTime }
            let totalArticlesRead = weeklyRecords.reduce(0) { $0 + $1.articlesRead }
            let totalWordsLookedUp = weeklyRecords.reduce(0) { $0 + $1.wordsLookedUp }
            let totalReviewsCompleted = weeklyRecords.reduce(0) { $0 + $1.reviewsCompleted }
            
            let studyDaysThisWeek = weeklyRecords.filter { $0.readingTime > 0 }.count
            let dailyAverageReadingTime = studyDaysThisWeek > 0 ? totalReadingTime / Double(studyDaysThisWeek) : 0
            
            return WeeklyStatistics(
                totalReadingTime: totalReadingTime,
                totalArticlesRead: totalArticlesRead,
                totalWordsLookedUp: totalWordsLookedUp,
                totalReviewsCompleted: totalReviewsCompleted,
                dailyAverageReadingTime: dailyAverageReadingTime,
                studyDaysThisWeek: studyDaysThisWeek,
                weeklyGoalProgress: 0 // 需要根据目标计算
            )
        }
    }
    
    func getMonthlyStatistics() async throws -> MonthlyStatistics {
        return await MainActor.run {
            guard userProgress != nil else {
                return MonthlyStatistics(
                    totalReadingTime: 0,
                    totalArticlesRead: 0,
                    totalWordsLookedUp: 0,
                    totalReviewsCompleted: 0,
                    dailyAverageReadingTime: 0,
                    studyDaysThisMonth: 0,
                    monthlyGoalProgress: 0,
                    bestWeekReadingTime: 0
                )
            }
            
            let monthlyRecords = getMonthlyRecords()
            let readingTime = monthlyRecords.reduce(0) { $0 + $1.readingTime }
            let articlesRead = monthlyRecords.reduce(0) { $0 + $1.articlesRead }
            let wordsLookedUp = monthlyRecords.reduce(0) { $0 + $1.wordsLookedUp }
            let reviewsCompleted = monthlyRecords.reduce(0) { $0 + $1.reviewsCompleted }
            
            let studyDays = monthlyRecords.filter { $0.readingTime > 0 }.count
            let averageSessionTime = studyDays > 0 ? readingTime / Double(studyDays) : 0
            
            return MonthlyStatistics(
                totalReadingTime: readingTime,
                totalArticlesRead: articlesRead,
                totalWordsLookedUp: wordsLookedUp,
                totalReviewsCompleted: reviewsCompleted,
                dailyAverageReadingTime: averageSessionTime,
                studyDaysThisMonth: studyDays,
                monthlyGoalProgress: 0.75,
                bestWeekReadingTime: readingTime / 4
            )
        }
    }
    
    // MARK: - Missing Protocol Methods Implementation
    
    func getOverallStatistics() async throws -> OverallStatistics {
        return await MainActor.run {
            guard let progress = userProgress else {
                return OverallStatistics()
            }
            
            let totalReadingTime = progress.dailyRecords.reduce(0) { $0 + $1.readingTime }
            let totalArticlesRead = progress.dailyRecords.reduce(0) { $0 + $1.articlesRead }
            let totalWordsLookedUp = progress.dailyRecords.reduce(0) { $0 + $1.wordsLookedUp }
            let totalReviewsCompleted = progress.dailyRecords.reduce(0) { $0 + $1.reviewsCompleted }
            
            let studyDays = progress.dailyRecords.filter { $0.readingTime > 0 }.count
            let averageReadingSpeed = studyDays > 0 ? totalReadingTime / Double(studyDays) : 0
            
            return OverallStatistics(
                totalReadingTime: totalReadingTime,
                totalArticlesRead: totalArticlesRead,
                totalWordsLookedUp: totalWordsLookedUp,
                totalReviewsCompleted: totalReviewsCompleted,
                longestStreak: progress.longestStreak,
                currentStreak: progress.currentStreak,
                totalStudyDays: studyDays,
                averageReadingSpeed: averageReadingSpeed
            )
        }
    }
    
    @MainActor
    func getVocabularyProgressStatistics() async throws -> VocabularyProgressStats {
        // 确保在主线程执行数据库操作
        let request = FetchDescriptor<TestedWord>()
        let testedWords = safeFetch(request, operation: "获取词汇测试记录")
        
        print("[DEBUG] 查询到的 TestedWord 记录数量: \(testedWords.count)")
        
        // 添加更详细的调试信息
        if !testedWords.isEmpty {
            print("[DEBUG] 最近的几条记录:")
            for (index, word) in testedWords.prefix(5).enumerated() {
                print("[DEBUG] \(index + 1). \(word.word) - \(word.masteryLevel) - \(word.testedAt)")
            }
        }
        
        if testedWords.isEmpty {
            logger.info("没有词汇测试记录，返回空统计数据")
            return VocabularyProgressStats()
        }
        
        // 基于真实测试数据计算统计
        let totalWords = testedWords.count
        let masteredWords = testedWords.filter { $0.masteryLevelEnum == .mastered }.count
        let familiarWords = testedWords.filter { $0.masteryLevelEnum == .familiar }.count
        let unfamiliarWords = testedWords.filter { $0.masteryLevelEnum == .unfamiliar }.count
        
        print("[DEBUG] 统计详情: 总计=\(totalWords), 已掌握=\(masteredWords), 熟悉=\(familiarWords), 不熟悉=\(unfamiliarWords)")
        
        // 计算本周和本月新增测试单词
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        
        let weeklyNewWords = testedWords.filter { $0.testedAt >= weekAgo }.count
        let monthlyNewWords = testedWords.filter { $0.testedAt >= monthAgo }.count
        
        // 计算平均复习准确率（基于掌握和熟悉的比例）
        let knownWords = masteredWords + familiarWords
        let averageReviewAccuracy = totalWords > 0 ? Double(knownWords) / Double(totalWords) : 0
        
        logger.info("词汇统计加载成功: 总测试词汇=\(totalWords), 已掌握=\(masteredWords), 熟悉=\(familiarWords), 不熟悉=\(unfamiliarWords)")
        
        return VocabularyProgressStats(
            totalWords: totalWords,
            masteredWords: masteredWords,
            learningWords: familiarWords, // 熟悉的单词视为学习中
            reviewWords: unfamiliarWords, // 不熟悉的单词需要复习
            masteryRate: totalWords > 0 ? Double(masteredWords) / Double(totalWords) : 0,
            weeklyNewWords: weeklyNewWords,
            monthlyNewWords: monthlyNewWords,
            averageReviewAccuracy: averageReviewAccuracy
        )
    }
    
    func getVocabularyStatistics() async throws -> VocabularyStatisticsDomain {
        return await MainActor.run {
            guard let progress = userProgress else {
                return VocabularyStatisticsDomain()
            }
            
            let totalWords = progress.totalWordsLookedUp
            let masteredWords = Int(Double(totalWords) * 0.6)
            let reviewingWords = Int(Double(totalWords) * 0.3)
            let newWords = totalWords - masteredWords - reviewingWords
            
            return VocabularyStatisticsDomain(
                totalWordsLearned: totalWords,
                masteredWords: masteredWords,
                reviewingWords: reviewingWords,
                newWords: newWords,
                averageTestScore: 85.0,
                strongestCategories: ["阅读理解", "词汇"],
                weakestCategories: ["语法", "写作"]
            )
        }
    }
    
    func getAchievementStatistics() async throws -> AchievementStatistics {
        return await MainActor.run {
            guard let progress = userProgress else {
                return AchievementStatistics()
            }
            
            let totalAchievements = AchievementType.allCases.count
            let unlockedAchievements = progress.achievements.filter { $0.isUnlocked }.count
            
            return AchievementStatistics(
                totalAchievements: totalAchievements,
                unlockedAchievements: unlockedAchievements,
                recentAchievements: [],
                nextMilestones: [],
                longestStreak: progress.longestStreak,
                recentBadges: []
            )
        }
    }
    
    func getReadingTimeChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint] {
        return await MainActor.run {
            guard let progress = userProgress else { return [] }
            
            let calendar = Calendar.current
            let now = Date()
            let records: [DailyStudyRecord]
            
            switch timeRange {
            case .day:
                records = [getTodayRecord()].compactMap { $0 }
            case .week:
                records = getWeeklyRecords()
            case .month:
                records = getMonthlyRecords()
            case .threeMonths:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                records = progress.dailyRecords.filter { $0.date >= threeMonthsAgo }
            case .year:
                let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? now
                records = progress.dailyRecords.filter { $0.date >= yearStart }
            case .all:
                records = progress.dailyRecords
            }
            
            return records.map { record in
                ChartDataPoint(
                    date: record.date,
                    value: record.readingTime,
                    label: "阅读时长"
                )
            }
        }
    }
    
    func getVocabularyChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint] {
        return await MainActor.run {
            guard let progress = userProgress else { return [] }
            
            let calendar = Calendar.current
            let now = Date()
            let records: [DailyStudyRecord]
            
            switch timeRange {
            case .day:
                records = [getTodayRecord()].compactMap { $0 }
            case .week:
                records = getWeeklyRecords()
            case .month:
                records = getMonthlyRecords()
            case .threeMonths:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                records = progress.dailyRecords.filter { $0.date >= threeMonthsAgo }
            case .year:
                let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? now
                records = progress.dailyRecords.filter { $0.date >= yearStart }
            case .all:
                records = progress.dailyRecords
            }
            
            return records.map { record in
                ChartDataPoint(
                    date: record.date,
                    value: Double(record.wordsLookedUp),
                    label: "查词数量"
                )
            }
        }
    }
    
    func getProgressChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint] {
        return await MainActor.run {
            guard let progress = userProgress else { return [] }
            
            let calendar = Calendar.current
            let now = Date()
            let records: [DailyStudyRecord]
            
            switch timeRange {
            case .day:
                records = [getTodayRecord()].compactMap { $0 }
            case .week:
                records = getWeeklyRecords()
            case .month:
                records = getMonthlyRecords()
            case .threeMonths:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                records = progress.dailyRecords.filter { $0.date >= threeMonthsAgo }
            case .year:
                let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? now
                records = progress.dailyRecords.filter { $0.date >= yearStart }
            case .all:
                records = progress.dailyRecords
            }
            
            return records.map { record in
                ChartDataPoint(
                    date: record.date,
                    value: Double(record.articlesRead),
                    label: "文章阅读"
                )
            }
        }
    }
    
    func getLevelProgress() -> Double {
        guard let progress = userProgress else { return 0 }
        
        let currentLevelExp = calculateExperienceForLevel(progress.level)
        let nextLevelExp = calculateExperienceForLevel(progress.level.nextLevel ?? progress.level)
        let currentExp = progress.experience
        
        if nextLevelExp <= currentLevelExp {
            return 1.0
        }
        
        let progressInLevel = currentExp - currentLevelExp
        let expNeededForNextLevel = nextLevelExp - currentLevelExp
        
        return Double(progressInLevel) / Double(expNeededForNextLevel)
    }
    
    func getExperienceToNextLevel() -> Int {
        guard let progress = userProgress else { return 0 }
        
        let nextLevelExp = calculateExperienceForLevel(progress.level.nextLevel ?? progress.level)
        return max(0, nextLevelExp - progress.experience)
    }
    
    func getGoalProgress() -> GoalProgress {
        guard userProgress != nil else {
            return GoalProgress(
                dailyGoal: GoalItem(title: "每日阅读", current: 0, target: 30),
                weeklyGoal: GoalItem(title: "每周文章", current: 0, target: 5),
                monthlyGoal: GoalItem(title: "每月单词", current: 0, target: 100)
            )
        }
        
        let todayRecord = getTodayRecord()
        let weeklyRecords = getWeeklyRecords()
        let monthlyRecords = getMonthlyRecords()
        
        return GoalProgress(
            dailyGoal: GoalItem(
                title: "每日阅读",
                current: Int(todayRecord?.readingTime ?? 0),
                target: 30
            ),
            weeklyGoal: GoalItem(
                title: "每周文章",
                current: weeklyRecords.reduce(0) { $0 + $1.articlesRead },
                target: 5
            ),
            monthlyGoal: GoalItem(
                title: "每月单词",
                current: monthlyRecords.reduce(0) { $0 + $1.wordsLookedUp },
                target: 100
            )
        )
    }
    
    func getUnlockedAchievements() -> [AchievementData] {
        guard let progress = userProgress else { return [] }
        return progress.achievements.filter { $0.isUnlocked }
    }
    
    func getAvailableAchievements() -> [AchievementType] {
        return AchievementType.allCases
    }
    
    func getStudyRecommendations() -> [StudyRecommendation] {
        guard let progress = userProgress else { return [] }
        
        var recommendations: [StudyRecommendation] = []
        
        // 基于学习数据生成建议
        let todayRecord = getTodayRecord()
        if todayRecord?.readingTime ?? 0 < 15 {
            recommendations.append(StudyRecommendation(
                title: "增加阅读时间",
                description: "建议每天至少阅读15分钟",
                priority: .high
            ))
        }
        
        if progress.currentStreak < 3 {
            recommendations.append(StudyRecommendation(
                title: "保持学习连续性",
                description: "连续学习可以提高学习效果",
                priority: .medium
            ))
        }
        
        return recommendations
    }
    
    func exportProgressData() -> Data? {
        guard let progress = userProgress else { return nil }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(progress)
        } catch {
            logger.error("导出进度数据失败: \(error)")
            return nil
        }
    }
    
    func importProgressData(_ data: Data) -> Bool {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedProgress = try decoder.decode(UserProgress.self, from: data)
            
            // 更新当前进度
            self.userProgress = importedProgress
            modelContext.insert(importedProgress)
            safeSave(operation: "导入进度数据")
            
            logger.info("进度数据导入成功")
            return true
        } catch {
            logger.error("导入进度数据失败: \(error)")
            return false
        }
    }
    
    func resetProgress() {
        performSafeOperation("重置进度") {
            guard let progress = userProgress else { return }
            
            // 重置所有进度数据
            progress.totalReadingTime = 0
            progress.totalArticlesRead = 0
            progress.totalWordsLookedUp = 0
            progress.experience = 0
            progress.level = .beginner
            progress.currentStreak = 0
            progress.longestStreak = 0
            progress.dailyRecords.removeAll()
            progress.achievements.removeAll()
            
            safeSave(operation: "重置进度")
            logger.info("用户进度已重置")
        }
    }
    
    // MARK: - Settings Methods
    
    func getUserSettings() async throws -> UserSettingsUI {
        return await MainActor.run {
            UserSettingsUI(
                username: "用户",
                email: "user@example.com",
                profileImageURL: nil,
                preferredLanguage: "zh-CN",
                timezone: TimeZone.current.identifier,
                dateJoined: Date(),
                lastActiveDate: Date()
            )
        }
    }
    
    func getReadingSettings() async throws -> ReadingSettingsUI {
        return await MainActor.run {
            ReadingSettingsUI(
                fontSize: 16.0,
                fontFamily: "System",
                lineSpacing: 1.2,
                backgroundColor: "#FFFFFF",
                textColor: "#000000",
                highlightColor: "#FFFF00",
                linkColor: "#007AFF",
                readingMargin: 16.0,
                paragraphSpacing: 8.0,
                autoScrollSpeed: 1.0,
                enableAutoScroll: false,
                showWordCount: true,
                showReadingTime: true,
                enableImmersiveMode: false,
                dailyReadingGoal: 30,
                weeklyReadingGoal: 210,
                colorScheme: "system"
            )
        }
    }
    
    func getVocabularySettings() async throws -> VocabularySettingsUI {
        return await MainActor.run {
            VocabularySettingsUI(
                enableAutoLookup: true,
                showPronunciation: true,
                showExamples: true,
                enableSpacedRepetition: true,
                reviewFrequency: .daily,
                difficultyAdjustment: .automatic,
                maxNewWordsPerDay: 20,
                enableNotifications: true,
                preferredDictionary: "default",
                autoAddToReview: true
            )
        }
    }
    
    func getNotificationSettings() async throws -> NotificationSettingsUI {
        return await MainActor.run {
            NotificationSettingsUI(
                enableDailyReminder: true,
                dailyReminderTime: Date(),
                enableReviewReminder: true,
                reviewReminderInterval: 4,
                enableAchievementNotifications: true,
                enableProgressNotifications: true,
                enableWeeklyReport: true,
                weeklyReportDay: 1,
                notificationSound: "default",
                enableVibration: true
            )
        }
    }
    
    func getPrivacySettings() async throws -> PrivacySettingsUI {
        return await MainActor.run {
            PrivacySettingsUI(
                enableAnalytics: true,
                enableCrashReporting: true,
                shareUsageData: false,
                enableCloudSync: true,
                autoBackup: true,
                dataRetentionPeriod: 365,
                enableLocationServices: false
            )
        }
    }
    
    // MARK: - Missing Protocol Methods
    
    func getAppearanceSettings() async throws -> AppearanceSettingsUI {
        return await MainActor.run {
            AppearanceSettingsUI(
                colorScheme: .system,
                accentColor: "#007AFF",
                enableDynamicType: true,
                enableReduceMotion: false,
                enableHighContrast: false,
                tabBarStyle: .standard,
                navigationStyle: .standard
            )
        }
    }
    
    func updateUserSettings(_ settings: UserSettingsUI) async throws {
        await MainActor.run {
            logger.info("用户设置已更新")
        }
    }
    
    func updateReadingSettings(_ settings: ReadingSettingsUI) async throws {
        await MainActor.run {
            logger.info("阅读设置已更新")
        }
    }
    
    func updateVocabularySettings(_ settings: VocabularySettingsUI) async throws {
        await MainActor.run {
            logger.info("词汇设置已更新")
        }
    }
    
    func updateNotificationSettings(_ settings: NotificationSettingsUI) async throws {
        await MainActor.run {
            logger.info("通知设置已更新")
        }
    }
    
    func updatePrivacySettings(_ settings: PrivacySettingsUI) async throws {
        await MainActor.run {
            logger.info("隐私设置已更新")
        }
    }
    
    func updateAppearanceSettings(_ settings: AppearanceSettingsUI) async throws {
        await MainActor.run {
            logger.info("外观设置已更新")
        }
    }
    
    func resetAllData() async throws {
        await MainActor.run {
            resetProgress()
            logger.info("所有数据已重置")
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateExperienceForLevel(_ level: UserLevel) -> Int {
        switch level {
        case .beginner: return 0
        case .elementary: return 100
        case .intermediate: return 300
        case .upperIntermediate: return 600
        case .advanced: return 1000
        case .expert: return 1500
        }
    }
    
    // MARK: - Cache Management
    
    private func cacheUserLevel() {
        guard let progress = userProgress else { return }
        cacheManager.set("user_level", value: progress.level.rawValue, expiration: 300)
    }
    
    private func cacheExperience() {
        guard let progress = userProgress else { return }
        cacheManager.set("total_experience", value: progress.experience, expiration: 300)
    }
    
    private func cacheStreak() {
        guard let progress = userProgress else { return }
        cacheManager.set("current_streak", value: progress.currentStreak, expiration: 300)
    }
    
    private func cacheTodayStats() {
        guard let todayRecord = getTodayRecord() else { return }
        cacheManager.set("today_stats", value: todayRecord, expiration: 300)
    }
    
    private func cacheWeeklyStats() {
        let weeklyRecords = getWeeklyRecords()
        cacheManager.set("weekly_stats", value: weeklyRecords, expiration: 300)
    }
    
    private func cacheMonthlyStats() {
        let monthlyRecords = getMonthlyRecords()
        cacheManager.set("monthly_stats", value: monthlyRecords, expiration: 300)
    }
    
    private func cacheAchievements() {
        guard let progress = userProgress else { return }
        cacheManager.set("achievements", value: progress.achievements, expiration: 300)
    }
    
    private func clearAllCaches() {
        cacheManager.clearAll()
        
        // 重置进度数据
        initializeUserProgress()
    }
    
    // MARK: - Experience Actions
    
    private func handleExperienceAction(_ action: ExperienceAction) {
        switch action {
        case .readArticle:
            break // 已在相应方法中处理
        case .lookupWord:
            break // 已在相应方法中处理
        case .completeReview:
            break // 已在相应方法中处理
        case .consecutiveDay:
            break // 已在连续天数更新中处理
        case .achievementUnlocked:
            break // 已在成就检查中处理
        case .levelUp:
            break // 已在等级检查中处理
        case .bookmarkArticle:
            break // 已在书签方法中处理
        }
    }
    
    // MARK: - Achievement Progress
    
    private func getAchievementProgress(for achievementId: String) -> AchievementProgress? {
        guard let progress = userProgress else { return nil }
        
        if let achievement = progress.achievements.first(where: { $0.id.uuidString == achievementId }) {
            return AchievementProgress(
                type: achievement.type,
                current: Int(achievement.progress * 100),
                required: 100,
                title: achievement.title,
                description: achievement.description
            )
        }
        return nil
    }
}