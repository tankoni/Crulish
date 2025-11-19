//
//  MockServices.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import Foundation
import SwiftData
import Combine

// MARK: - Type Aliases
typealias Word = DictionaryWord

// MARK: - Mock Error Handler

class MockErrorHandler: ErrorHandlerProtocol {
    var currentError: AppError?
    var isShowingError: Bool = false
    
    func handle(_ error: Error, context: String) {
        print("MockErrorHandler: \(error.localizedDescription) in \(context)")
    }
    
    func handle(_ appError: AppError) {
        currentError = appError
        isShowingError = true
        print("MockErrorHandler: \(appError)")
    }
    
    func logSuccess(_ message: String) {
        print("MockErrorHandler Success: \(message)")
    }
    
    func dismissError() {
        currentError = nil
        isShowingError = false
    }
    
    func clearAllErrors() {
        currentError = nil
        isShowingError = false
    }
}

// MARK: - Mock Statistics Export Service

class MockStatisticsExportService: StatisticsExportServiceProtocol {
    func getCompletedTestResults() async throws -> [VocabularyTest] {
        return []
    }
    
    func getTestWordDetails(for test: VocabularyTest) async throws -> [TestedWord] {
        return []
    }
    
    func generateMarkdownContent(for tests: [VocabularyTest]) async throws -> String {
        return "# Mock Export Content\n\nNo tests available."
    }
    
    func generateTestDetailReport(for test: VocabularyTest) async throws -> String {
        return "# Mock Test Report\n\nTest ID: \(test.id)"
    }
}

// MARK: - Mock Cache Manager

// MARK: - Mock CacheManager
class MockCacheManager: CacheManagerProtocol {
    private var cache: [String: CacheItem] = [:]
    private let maxCacheSize = 1000 // 限制缓存大小
    private let queue = DispatchQueue(label: "MockCacheManager", qos: .utility)
    
    private struct CacheItem {
        let value: Any
        let expirationDate: Date?
        let createdAt: Date
        
        init(value: Any, expiration: TimeInterval?) {
            self.value = value
            self.createdAt = Date()
            if let expiration = expiration {
                self.expirationDate = Date().addingTimeInterval(expiration)
            } else {
                self.expirationDate = nil
            }
        }
        
        var isExpired: Bool {
            guard let expirationDate = expirationDate else { return false }
            return Date() > expirationDate
        }
    }
    
    func get<T: Codable>(_ key: String, type: T.Type) -> T? {
        return queue.sync {
            guard let item = cache[key], !item.isExpired else {
                cache.removeValue(forKey: key)
                return nil
            }
            return item.value as? T
        }
    }
    
    func set<T: Codable>(_ key: String, value: T, expiration: TimeInterval?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查缓存大小限制
            if self.cache.count >= self.maxCacheSize {
                self.evictOldestItems()
            }
            
            self.cache[key] = CacheItem(value: value, expiration: expiration)
        }
    }
    
    func invalidate(_ key: String) {
        queue.async { [weak self] in
            self?.cache.removeValue(forKey: key)
        }
    }
    
    func invalidateAll() {
        queue.async { [weak self] in
            self?.cache.removeAll()
        }
    }
    
    func clearAll() {
        queue.async { [weak self] in
            self?.cache.removeAll()
        }
    }
    
    func clearExpiredItems() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let expiredKeys = self.cache.compactMap { key, item in
                item.isExpired ? key : nil
            }
            for key in expiredKeys {
                self.cache.removeValue(forKey: key)
            }
        }
    }
    
    func getCacheSize() -> Int {
        return queue.sync {
            return cache.count
        }
    }
    
    func getCacheInfo() -> CacheInfo {
        return queue.sync {
            let totalItems = cache.count
            return CacheInfo(
                itemCount: totalItems,
                totalSize: totalItems * 100,
                hitRate: 0.85,
                missRate: 0.15
            )
        }
    }
    
    func remove(_ key: String) {
        queue.async { [weak self] in
            self?.cache.removeValue(forKey: key)
        }
    }
    
    func removeByPrefix(_ prefix: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let keysToRemove = self.cache.keys.filter { $0.hasPrefix(prefix) }
            for key in keysToRemove {
                self.cache.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Private Methods
    private func evictOldestItems() {
        // 移除最旧的 20% 缓存项
        let itemsToRemove = Int(Double(cache.count) * 0.2)
        let sortedItems = cache.sorted { $0.value.createdAt < $1.value.createdAt }
        
        for i in 0..<min(itemsToRemove, sortedItems.count) {
            cache.removeValue(forKey: sortedItems[i].key)
        }
    }
}

// MARK: - Mock ArticleService
class MockArticleService: ArticleServiceProtocol {
    private var articles: [Article] = [
        Article(
            title: "Test Article 1",
            content: "This is test content for article 1",
            year: 2023,
            examType: "考研英语一",
            difficulty: .medium,
            topic: "Technology",
            imageName: "test1"
        ),
        Article(
            title: "Sample Article 2",
            content: "This is test content for article 2",
            year: 2023,
            examType: "考研英语二",
            difficulty: .hard,
            topic: "Science",
            imageName: "test2"
        )
    ]
    
    // MARK: - ArticleServiceProtocol Methods
    
    func getAllArticles() -> [Article] {
        return articles
    }
    
    func getArticlesByYear(_ year: Int) -> [Article] {
        return articles.filter { $0.year == year }
    }
    
    func getArticlesByDifficulty(_ difficulty: ArticleDifficulty) -> [Article] {
        return articles.filter { $0.difficulty == difficulty }
    }
    
    func getArticlesByExamType(_ examType: String) -> [Article] {
        return articles.filter { $0.examType == examType }
    }
    
    func getRecentArticles(limit: Int) -> [Article] {
        return Array(articles.suffix(limit))
    }
    
    func getRecommendedArticles(limit: Int) -> [Article] {
        return Array(articles.prefix(limit))
    }
    
    func searchArticles(_ query: String) -> [Article] {
        return articles.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
    
    func updateArticle(_ article: Article) {
        // Mock implementation
    }
    
    func markArticleAsCompleted(_ article: Article) {
        // Mock implementation
    }
    
    func updateArticleProgress(_ article: Article, progress: Double) {
        // Mock implementation
    }
    
    func addReadingTime(to article: Article, time: Double) {
        // Mock implementation
    }
    
    func clearAllArticles() {
        articles.removeAll()
    }
    
    func importArticlesFromJSON() async throws {
        // Mock implementation
    }
    
    func importArticlesFromPDFs() {
        // Mock implementation
    }
    
    func initializeSampleData() {
        // Mock implementation
    }
    
    func getArticleStats() -> ArticleStats {
        return ArticleStats(
            totalArticles: articles.count,
            completedArticles: 0,
            inProgressArticles: 0,
            unreadArticles: articles.count,
            totalReadingTime: 0,
            averageProgress: 0,
            yearStats: [:],
            difficultyStats: [:],
            topicStats: [:]
        )
    }
    
    func getAvailableYears() -> [Int] {
        return Array(Set(articles.map { $0.year })).sorted()
    }
    
    func getAvailableTopics() -> [String] {
        return Array(Set(articles.map { $0.topic })).sorted()
    }
    
    func getAvailableExamTypes() -> [String] {
        return Array(Set(articles.map { $0.examType })).sorted()
    }
    
    func getReadingStatistics() async throws -> ReadingStatisticsDomain {
        return ReadingStatisticsDomain(
            totalArticlesRead: articles.count,
            totalReadingTime: 0,
            averageReadingSpeed: 200.0,
            completionRate: 0.0,
            favoriteCategories: getAvailableTopics()
        )
    }
}

// MARK: - Mock DictionaryService
class MockDictionaryService: DictionaryServiceProtocol, @unchecked Sendable {
    private var mockWords: [DictionaryWord] = []
    private var vocabulary: [UserWord] = []
    private let maxVocabularySize = 10000 // 限制词汇表大小
    private let queue = DispatchQueue(label: "MockDictionaryService", qos: .utility)
    
    deinit {
        clearAllData()
    }
    
    // MARK: - Protocol Requirements
    func setModelContext(_ context: ModelContext) {
        // Mock implementation - no actual context needed for mock service
        print("MockDictionaryService: setModelContext called")
    }
    
    func setupMockWords(count: Int = 1000) {
        queue.async { [weak self] in
            self?.mockWords = self?.createMockWords(count: min(count, 5000)) ?? [] // 限制最大数量
        }
    }
    
    func createMockWords(count: Int) -> [DictionaryWord] {
        var words: [DictionaryWord] = []
        words.reserveCapacity(count) // 预分配内存
        
        for i in 0..<count {
            let difficulty = WordDifficulty.allCases[i % WordDifficulty.allCases.count]
            let partOfSpeech = PartOfSpeech.allCases[i % PartOfSpeech.allCases.count]
            
            let definition = WordDefinition(
                partOfSpeech: partOfSpeech,
                meaning: "中文释义\(i)",
                englishMeaning: "English definition \(i)",
                examples: ["Example sentence \(i)"],
                contextKeywords: ["keyword\(i)"]
            )
            
            let word = DictionaryWord(
                word: "word\(i)",
                phonetic: "/wɜːrd\(i)/",
                definitions: [definition],
                frequency: i % 100,
                difficulty: difficulty,
                tags: ["tag\(i % 10)"]
            )
            
            words.append(word)
        }
        
        return words
    }
    
    func getAllWords() -> [DictionaryWord] {
        return queue.sync {
            return mockWords
        }
    }
    
    func getRandomWords(count: Int) -> [DictionaryWord] {
        return queue.sync {
            return Array(mockWords.shuffled().prefix(min(count, mockWords.count)))
        }
    }
    
    // MARK: - Dictionary Management
    func getAvailableDictionaries() -> AnyPublisher<[DictionaryInfo], Error> {
        let mockDictionaries = [
            DictionaryInfo(
                name: "kaoyan_core",
                displayName: "考研核心词汇",
                fileName: "KaoYan_1.json",
                filePath: "/mock/path/KaoYan_1.json",
                version: "1.0",
                description: "考研必备核心词汇，包含高频词汇和重点词汇",
                language: "en",
                totalWords: 3000,
                difficultyLevels: [1, 2, 3, 4],
                categories: ["考研", "核心词汇"]
            )
        ]
        
        return Just(mockDictionaries)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func loadDictionary(fileName: String) -> AnyPublisher<[DictionaryWord], Error> {
        let mockWords = [
            DictionaryWord(
                word: "test",
                phonetic: "/test/",
                definitions: [
                    WordDefinition(
                        partOfSpeech: .noun,
                        meaning: "测试；考试",
                        englishMeaning: "a procedure intended to establish the quality, performance, or reliability of something",
                        examples: ["This is a test."],
                        contextKeywords: ["exam", "evaluation"]
                    )
                ],
                frequency: 1000,
                difficulty: .medium,
                tags: ["academic", "common"]
            )
        ]
        
        return Just(mockWords)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func lookupWord(_ word: String) async throws -> UserWord {
        return vocabulary.first { $0.word == word } ?? UserWord(
            word: word,
            context: "Mock context for \(word)",
            sentence: "Mock sentence for \(word)",
            selectedDefinition: WordDefinition(partOfSpeech: .noun, meaning: "Mock definition for \(word)")
        )
    }
    
    func lookupWord(_ word: String, context: String) -> DictionaryWord? {
        return DictionaryWord(
            word: word,
            phonetic: "/mock/",
            definitions: [WordDefinition(partOfSpeech: .noun, meaning: "Mock definition")],
            frequency: 100,
            difficulty: .medium,
            tags: ["mock"]
        )
    }
    
    func searchWords(_ query: String) -> [DictionaryWord] {
        return []
    }
    
    func addUnknownWord(_ word: UserWord) async throws {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                // 检查词汇表大小限制
                if self.vocabulary.count >= self.maxVocabularySize {
                    self.evictOldestVocabulary()
                }
                
                self.vocabulary.append(word)
                continuation.resume()
            }
        }
    }
    
    func getUserVocabulary() async throws -> [UserWord] {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                continuation.resume(returning: self?.vocabulary ?? [])
            }
        }
    }
    
    func addWord(_ word: UserWord) async throws {
        try await addUnknownWord(word)
    }
    
    func getUserWordRecords() -> [UserWord] {
        return queue.sync {
            return vocabulary
        }
    }

    // 获取总记录（非词典专属）的用户词汇记录（Mock：直接返回所有记录）
    func getGeneralUserWordRecords() -> [UserWord] {
        return queue.sync {
            return vocabulary
        }
    }

    // 获取词典专属的用户词汇记录（Mock：未区分词典，返回所有记录）
    func getDictionarySpecificUserWordRecords(for dictionaryId: UUID) -> [UserWord] {
        return queue.sync {
            return vocabulary
        }
    }
    
    func getWordsByMastery(_ mastery: MasteryLevel) -> [UserWord] {
        return queue.sync {
            return vocabulary.filter { $0.masteryLevel == mastery }
        }
    }
    
    func getWordsForReview() -> [UserWord] {
        return queue.sync {
            return vocabulary.filter { $0.isMarkedForReview }
        }
    }
    
    func initializeDictionary() async throws {
        // Mock implementation
    }
    
    func initializeKaoyanDictionary() async {
        // Mock implementation
    }
    
    func getKaoyanWordDetails(_ word: String) -> KaoyanWordDetails? {
        return nil
    }
    
    func updateWord(_ word: UserWord) async throws {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                if let index = self.vocabulary.firstIndex(where: { $0.word == word.word }) {
                    self.vocabulary[index] = word
                }
                continuation.resume()
            }
        }
    }
    
    func recordWordLookup(_ word: String) async throws {
        // Mock implementation
    }
    
    func recordWordLookup(word: String, context: String, sentence: String, article: Article) -> UserWord {
        let userWord = UserWord(
            word: word,
            context: context,
            sentence: sentence,
            selectedDefinition: WordDefinition(partOfSpeech: .noun, meaning: "Mock definition for \(word)")
        )
        vocabulary.append(userWord)
        return userWord
    }
    
    func updateWordMastery(_ record: UserWord, level: MasteryLevel) {
        // Mock implementation
    }
    
    func updateMasteryLevel(_ record: UserWord, level: MasteryLevel) {
        // Mock implementation
    }
    
    func markForReview(_ record: UserWord) {
        // Mock implementation
    }
    
    func addNote(_ record: UserWord, note: String) {
        // Mock implementation
    }
    
    func toggleReviewFlag(for record: UserWord) {
        // Mock implementation
    }
    
    func deleteWordRecord(_ record: UserWord) {
        // Mock implementation
    }
    
    func clearAllRecords() {
        queue.async { [weak self] in
            self?.vocabulary.removeAll()
        }
    }
    
    func getVocabularyStats() -> VocabularyStats {
        return queue.sync { [weak self] in
            guard let self = self else {
                return VocabularyStats(
                    totalWords: 0,
                    unfamiliarWords: 0,
                    familiarWords: 0,
                    masteredWords: 0,
                    todayLookups: 0,
                    weeklyLookups: 0,
                    averageLookupPerDay: 0,
                    mostLookedUpWords: []
                )
            }
            
            let totalWords = vocabulary.count
            let unfamiliarWords = vocabulary.filter { $0.masteryLevel == .unfamiliar }.count
            let familiarWords = vocabulary.filter { $0.masteryLevel == .familiar }.count
            let masteredWords = vocabulary.filter { $0.masteryLevel == .mastered }.count
            
            return VocabularyStats(
                totalWords: totalWords,
                unfamiliarWords: unfamiliarWords,
                familiarWords: familiarWords,
                masteredWords: masteredWords,
                todayLookups: 0,
                weeklyLookups: 0,
                averageLookupPerDay: 0,
                mostLookedUpWords: []
            )
        }
    }
    
    func clearGeneralUserWordsCache() {
        // no-op for mock
    }
    
    // MARK: - Private Methods
    private func clearAllData() {
        mockWords.removeAll()
        vocabulary.removeAll()
    }
    
    private func evictOldestVocabulary() {
        // 移除最旧的 20% 词汇
        let itemsToRemove = Int(Double(vocabulary.count) * 0.2)
        vocabulary.removeFirst(min(itemsToRemove, vocabulary.count))
    }
}

// MARK: - Mock UserProgressService
class MockUserProgressService: UserProgressServiceProtocol {
    private var userProgress = UserProgress()
    
    func getUserProgress() async throws -> UserProgress {
        return userProgress
    }
    
    func updateUserProgress(_ progress: UserProgress) async throws {
        self.userProgress = progress
    }
    
    func incrementWordsLearned() {
        userProgress.totalWordsLookedUp += 1
    }
    
    func incrementArticleRead() {
        userProgress.articlesRead += 1
    }
    
    func completeReview() {
        // Mock implementation
    }
    
    func markArticleAsCompleted(articleId: String) async throws {
        userProgress.articlesRead += 1
    }
    
    func recordWordReview(word: String, correct: Bool) async throws {
        // Mock implementation
    }
    
    func recordReviewSession(wordsReviewed: Int, correctAnswers: Int) async throws {
        // Mock implementation
    }
    
    func recordArticleCompletion(articleId: String, readingTime: TimeInterval, wordsLookedUp: Int) async throws {
        userProgress.articlesRead += 1
        userProgress.totalReadingTime += readingTime
        userProgress.totalWordsLookedUp += wordsLookedUp
    }
    
    func getReadingTrend(days: Int) -> [DailyStudyRecord] {
        return []
    }
    
    func getWeeklyComparison() -> WeeklyComparison {
        let currentWeek = StatisticsWeeklyStats(
            totalStudyTime: 3600,
            articlesRead: 5,
            wordsLearned: 25,
            averageScore: 85.0
        )
        let previousWeek = StatisticsWeeklyStats(
            totalStudyTime: 2800,
            articlesRead: 4,
            wordsLearned: 20,
            averageScore: 80.0
        )
        return WeeklyComparison(currentWeek: currentWeek, previousWeek: previousWeek)
    }
    
    func getStudyStatistics() -> StudyStatistics {
        return StudyStatistics()
    }
    
    func addBookmark(articleId: String) async throws {
        // Mock implementation
    }
    
    func updateReadingSettings(_ settings: ReadingSettingsUI) async throws {
        // Mock implementation
    }
    
    func updateVocabularySettings(_ settings: VocabularySettingsUI) async throws {
        // Mock implementation
    }
    
    func updateNotificationSettings(_ settings: NotificationSettingsUI) async throws {
        // Mock implementation
    }
    
    func addReadingTime(_ time: Double) {
        // Mock implementation
    }
    
    func addWordLookup() {
        // Mock implementation
    }
    
    func addExperience(_ points: Int, for activity: ExperienceAction) {
        // Mock implementation
    }
    
    func getUserProgress() -> UserProgress? {
        return userProgress
    }
    
    func getTodayRecord() -> DailyStudyRecord? {
        return DailyStudyRecord(
            date: Date()
        )
    }
    
    func removeBookmark(articleId: String) async throws {
        // Mock implementation
    }
    
    func isBookmarked(articleId: String) async throws -> Bool {
        return false
    }
    
    func isCompleted(articleId: String) async throws -> Bool {
        return false
    }
    
    func updateReadingProgress(articleId: String, progress: Double, readingTime: TimeInterval) async throws {
        // Mock implementation
    }
    
    func recordWordLookup(word: String, articleId: String) async throws {
        // Mock implementation
    }
    
    func getTodayStatistics() async throws -> TodayStatistics {
        return TodayStatistics(
            readingTime: 30,
            articlesRead: 2,
            wordsLookedUp: 10,
            reviewsCompleted: 5,
            dailyReadingGoalProgress: 0.6,
            consecutiveDays: 5
        )
    }
    
    func getWeeklyStatistics() async throws -> WeeklyStatistics {
        return WeeklyStatistics(
            totalReadingTime: 210,
            totalArticlesRead: 14,
            totalWordsLookedUp: 70,
            totalReviewsCompleted: 35,
            dailyAverageReadingTime: 30,
            studyDaysThisWeek: 5,
            weeklyGoalProgress: 0.8
        )
    }
    
    func getMonthlyStatistics() async throws -> MonthlyStatistics {
        return MonthlyStatistics(
            totalReadingTime: 900,
            totalArticlesRead: 60,
            totalWordsLookedUp: 300,
            totalReviewsCompleted: 150,
            dailyAverageReadingTime: 30,
            studyDaysThisMonth: 20,
            monthlyGoalProgress: 0.75,
            bestWeekReadingTime: 240
        )
    }
    
    func getOverallStatistics() async throws -> OverallStatistics {
        return OverallStatistics(
            totalReadingTime: 3600,
            totalArticlesRead: 240,
            totalWordsLookedUp: 1200,
            totalReviewsCompleted: 600,
            longestStreak: 15,
            currentStreak: 7,
            totalStudyDays: 45,
            averageReadingSpeed: 200
        )
    }
    
    func getVocabularyProgressStatistics() async throws -> VocabularyProgressStats {
        return VocabularyProgressStats(
            totalWords: 1200,
            masteredWords: 800,
            learningWords: 300,
            reviewWords: 100,
            masteryRate: 0.85,
            weeklyNewWords: 50,
            monthlyNewWords: 200,
            averageReviewAccuracy: 0.90
        )
    }
    
    func getVocabularyStatistics() async throws -> VocabularyStatisticsDomain {
        return VocabularyStatisticsDomain(
            totalWordsLearned: 1200,
            masteredWords: 800,
            reviewingWords: 300,
            newWords: 100,
            averageTestScore: 85.0,
            strongestCategories: ["阅读理解", "词汇"],
            weakestCategories: ["语法", "写作"]
        )
    }
    
    func getAchievementStatistics() async throws -> AchievementStatistics {
        return AchievementStatistics(
            totalAchievements: 15,
            unlockedAchievements: 8,
            recentAchievements: [],
            nextMilestones: ["Read 100 articles", "Master 500 words"],
            longestStreak: 7,
            recentBadges: []
        )
    }
    
    func getReadingTimeChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint] {
        return []
    }
    
    func getVocabularyChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint] {
        return []
    }
    
    func getProgressChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint] {
        return []
    }
    
    func getCurrentLevel() -> UserLevel {
        return .intermediate
    }
    
    func getLevelProgress() -> Double {
        return 0.5
    }
    
    func getExperienceToNextLevel() -> Int {
        return 500
    }
    
    func getGoalProgress() -> GoalProgress {
        return GoalProgress(
            dailyGoal: GoalItem(title: "每日阅读", current: 20, target: 30),
            weeklyGoal: GoalItem(title: "每周文章", current: 3, target: 5),
            monthlyGoal: GoalItem(title: "每月单词", current: 60, target: 100)
        )
    }
    
    func getConsecutiveDays() -> Int {
        return 5
    }
    
    func getUnlockedAchievements() -> [AchievementData] {
        return []
    }
    
    func getAvailableAchievements() -> [AchievementType] {
        return []
    }
    
    func getStudyRecommendations() -> [StudyRecommendation] {
        return []
    }
    
    func exportProgressData() -> Data? {
        return nil
    }
    
    func importProgressData(_ data: Data) -> Bool {
        return true
    }
    
    func resetProgress() {
        userProgress = UserProgress()
    }
    
    func getUserSettings() async throws -> UserSettingsUI {
        var settings = UserSettingsUI()
        settings.username = "Test User"
        settings.email = "test@example.com"
        settings.profileImageURL = nil
        settings.preferredLanguage = "zh-CN"
        settings.timezone = "Asia/Shanghai"
        settings.dateJoined = Date()
        settings.lastActiveDate = Date()
        return settings
    }
    
    func getReadingSettings() async throws -> ReadingSettingsUI {
        return ReadingSettingsUI()
    }
    
    func getVocabularySettings() async throws -> VocabularySettingsUI {
        return VocabularySettingsUI()
    }
    
    func getNotificationSettings() async throws -> NotificationSettingsUI {
        var settings = NotificationSettingsUI()
        settings.enableDailyReminder = true
        settings.dailyReminderTime = Date()
        settings.enableReviewReminder = true
        settings.reviewReminderInterval = 4
        settings.enableAchievementNotifications = true
        settings.enableProgressNotifications = true
        settings.enableWeeklyReport = true
        settings.weeklyReportDay = 1
        settings.notificationSound = "default"
        settings.enableVibration = true
        return settings
    }
    
    func getPrivacySettings() async throws -> PrivacySettingsUI {
        var settings = PrivacySettingsUI()
        settings.enableAnalytics = true
        settings.enableCrashReporting = true
        settings.shareUsageData = false
        settings.enableCloudSync = true
        settings.autoBackup = true
        settings.dataRetentionPeriod = 365
        settings.enableLocationServices = false
        return settings
    }
    
    func getAppearanceSettings() async throws -> AppearanceSettingsUI {
        return AppearanceSettingsUI(
            colorScheme: .system,
            accentColor: "#007AFF",
            enableDynamicType: true,
            enableReduceMotion: false,
            enableHighContrast: false
        )
    }
    
    func updateUserSettings(_ settings: UserSettingsUI) async throws {
        // Mock implementation
    }
    
    func updatePrivacySettings(_ settings: PrivacySettingsUI) async throws {
        // Mock implementation
    }
    
    func updateAppearanceSettings(_ settings: AppearanceSettingsUI) async throws {
        // Mock implementation
    }
    
    func resetAllData() async throws {
        // Mock implementation
        userProgress = UserProgress()
    }
}

// MARK: - Mock TestDataService
class MockTestDataService: TestDataService {
    private var testedWords: [String: [TestedWord]] = [:]
    private var testHistory: [VocabularyTest] = []
    
    init() {
        // 先构造依赖并调用父类初始化器
        let modelContainer = try! ModelContainer(for: VocabularyTest.self, TestedWord.self)
        let modelContext = ModelContext(modelContainer)
        let cacheManager = MockCacheManager()
        let errorHandler = MockErrorHandler()
        super.init(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler,
            subsystem: "com.en01.services",
            category: "MockTestDataService"
        )
        
        // 初始化一些模拟数据
        setupMockData()
    }
    
    private func setupMockData() {
        // 创建一些模拟的已测试单词
        let mockTestedWords = [
            TestedWord(
                word: "test",
                dictionaryName: "考研核心词汇",
                dictionaryFileName: "KaoYan_1.json",
                masteryLevel: MasteryLevel.familiar,
                testSessionId: UUID(),
                difficulty: "medium"
            ),
            TestedWord(
                word: "example",
                dictionaryName: "考研核心词汇", 
                dictionaryFileName: "KaoYan_1.json",
                masteryLevel: MasteryLevel.mastered,
                testSessionId: UUID(),
                difficulty: "easy"
            )
        ]
        
        testedWords["KaoYan_1.json"] = mockTestedWords
        
        // 创建一些模拟的测试历史（使用简化构造函数）
        let mockTest = VocabularyTest(
            dictionaryName: "考研核心词汇"
        )
        testHistory.append(mockTest)
    }
    
    // MARK: - Test History Management
    override func getTestHistory(limit: Int = 20) -> AnyPublisher<[VocabularyTest], Error> {
        let limitedHistory = Array(testHistory.prefix(limit))
        return Just(limitedHistory)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    override func getTestHistory(for dictionaryId: UUID) -> AnyPublisher<[VocabularyTest], Error> {
        let filteredHistory = testHistory.filter { $0.dictionaryId == dictionaryId }
        return Just(filteredHistory)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    override func getLatestTest(for dictionaryId: UUID) -> AnyPublisher<VocabularyTest?, Error> {
        let latestTest = testHistory.filter { $0.dictionaryId == dictionaryId }.last
        return Just(latestTest)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    override func getLatestTest() -> AnyPublisher<VocabularyTest?, Error> {
        return Just(testHistory.last)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    override func getIncompleteTest(for dictionaryFileName: String) -> AnyPublisher<VocabularyTest?, Error> {
        let incompleteTest = testHistory.first { test in
            test.dictionaryFileName == dictionaryFileName && !test.isCompleted
        }
        return Just(incompleteTest)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    override func deleteTestRecord(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        testHistory.removeAll { $0.id == test.id }
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Tested Words Management
    override func saveTestedWord(_ word: DictionaryWord, mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String, testSessionId: UUID?) -> AnyPublisher<Void, Error> {
        let testedWord = TestedWord(
            word: word.word,
            dictionaryName: dictionaryName,
            dictionaryFileName: dictionaryFileName,
            masteryLevel: mastery,
            testSessionId: testSessionId
        )
        
        if testedWords[dictionaryFileName] == nil {
            testedWords[dictionaryFileName] = []
        }
        testedWords[dictionaryFileName]?.append(testedWord)
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    override func getTestedWords(for dictionaryFileName: String) -> AnyPublisher<[TestedWord], Error> {
        let words = testedWords[dictionaryFileName] ?? []
        return Just(words)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getUntestedWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        // 返回一些模拟的未测试单词
        let mockWords = [
            DictionaryWord(
                word: "untested1",
                phonetic: "/ʌnˈtestɪd/",
                definitions: [
                    WordDefinition(
                        partOfSpeech: .adjective,
                        meaning: "未测试的",
                        englishMeaning: "not tested",
                        examples: ["This is an untested word."],
                        contextKeywords: ["test", "new"]
                    )
                ],
                frequency: 50,
                difficulty: .medium,
                tags: ["mock"]
            )
        ]
        
        return Just(mockWords)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Test Progress and Statistics
    override func getTestProgress(for dictionaryFileName: String) -> AnyPublisher<TestProgress, Error> {
        let testedWordsCount = testedWords[dictionaryFileName]?.count ?? 0
        let progress = TestProgress(
            dictionaryFileName: dictionaryFileName,
            dictionaryName: dictionaryFileName.replacingOccurrences(of: ".json", with: ""),
            totalWords: 1000,
            testedWords: testedWordsCount,
            untestedWords: max(0, 1000 - testedWordsCount),
            masteredWords: testedWordsCount / 3,
            familiarWords: testedWordsCount / 3,
            unfamiliarWords: testedWordsCount / 3,
            currentIndex: testedWordsCount
        )
        
        return Just(progress)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    override func getDictionaryTestResults(for dictionaryFileName: String) -> AnyPublisher<DictionaryTestResults, Error> {
        let testedWordsCount = testedWords[dictionaryFileName]?.count ?? 0
        let results = DictionaryTestResults(
            dictionaryFileName: dictionaryFileName,
            totalTestedWords: testedWordsCount,
            masteredWords: testedWordsCount / 3,
            familiarWords: testedWordsCount / 3,
            unfamiliarWords: testedWordsCount / 3,
            masteryRate: 0.67,
            lastTestDate: Date()
        )
        
        return Just(results)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Cache Management
    override func clearCacheForDictionary(_ dictionaryFileName: String) {
        // Mock implementation
        print("MockTestDataService: clearCacheForDictionary(\(dictionaryFileName)) called")
    }
}

// MARK: - Mock VocabularyTestService
class MockVocabularyTestService: VocabularyTestServiceProtocol {
    private let dictionaryService: MockDictionaryService
    private var currentTest: VocabularyTest?
    private var testHistory: [VocabularyTest] = []
    private var activeTests: [UUID: VocabularyTest] = [:]
    private var testWords: [UUID: [DictionaryWord]] = [:]
    private var testResponses: [UUID: [WordTestResponse]] = [:]
    
    init(dictionaryService: MockDictionaryService) {
        self.dictionaryService = dictionaryService
    }
    
    // MARK: - VocabularyTestServiceProtocol Implementation
    
    func getAvailableDictionaries() -> AnyPublisher<[DictionaryInfo], Error> {
        return dictionaryService.getAvailableDictionaries()
    }
    
    func loadDictionaryWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        return dictionaryService.loadDictionary(fileName: dictionary.fileName)
    }
    
    func startVocabularyTest(dictionary: DictionaryInfo, sampleSize: Int) -> AnyPublisher<VocabularyTest, Error> {
        let test = VocabularyTest(
            id: UUID(),
            dictionaryId: dictionary.id,
            dictionaryName: dictionary.displayName,
            dictionaryFileName: dictionary.fileName,
            totalWords: sampleSize,
            masteredCount: 0,
            familiarCount: 0,
            unfamiliarCount: 0,
            currentWordIndex: 0,
            isCompleted: false,
            isPaused: false,
            createdAt: Date(),
            completedAt: nil,
            estimatedVocabularySize: 0,
            accuracyPercentage: 0.0
        )
        
        currentTest = test
        activeTests[test.id] = test
        testHistory.append(test)

        // 为测试准备一组模拟未测试词
        let mockWords: [DictionaryWord] = [
            DictionaryWord(
                word: "mockword1",
                phonetic: nil,
                definitions: [WordDefinition(partOfSpeech: .noun, meaning: "示例词1")],
                frequency: 1,
                difficulty: .basic
            ),
            DictionaryWord(
                word: "mockword2",
                phonetic: nil,
                definitions: [WordDefinition(partOfSpeech: .verb, meaning: "示例词2")],
                frequency: 1,
                difficulty: .medium
            ),
            DictionaryWord(
                word: "mockword3",
                phonetic: nil,
                definitions: [WordDefinition(partOfSpeech: .adjective, meaning: "示例词3")],
                frequency: 1,
                difficulty: .advanced
            )
        ]
        testWords[test.id] = mockWords
        
        return Just(test)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func recordWordMastery(testId: UUID, word: String, masteryLevel: MasteryLevel, responseTime: TimeInterval) -> AnyPublisher<Void, Error> {
        let response = WordTestResponse(
            word: word,
            masteryLevel: masteryLevel,
            responseTime: responseTime,
            isCorrect: masteryLevel != .unfamiliar
        )
        
        if testResponses[testId] == nil {
            testResponses[testId] = []
        }
        testResponses[testId]?.append(response)
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func recordWordClick(word: String, testId: UUID) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func completeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        guard let test = activeTests[testId] else {
            return Fail(error: VocabularyTestError.testNotFound)
                .eraseToAnyPublisher()
        }
        
        let completedTest = VocabularyTest(
            id: test.id,
            dictionaryId: test.dictionaryId,
            dictionaryName: test.dictionaryName,
            dictionaryFileName: test.dictionaryFileName,
            totalWords: test.totalWords,
            masteredCount: test.masteredCount,
            familiarCount: test.familiarCount,
            unfamiliarCount: test.unfamiliarCount,
            currentWordIndex: test.currentWordIndex,
            isCompleted: true,
            isPaused: false,
            createdAt: test.createdAt,
            completedAt: Date(),
            estimatedVocabularySize: test.estimatedVocabularySize,
            accuracyPercentage: test.accuracyPercentage
        )
        
        activeTests[testId] = completedTest
        testHistory.append(completedTest)
        
        return Just(completedTest)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func pauseTest(testId: UUID) -> AnyPublisher<Void, Error> {
        guard let test = activeTests[testId] else {
            return Fail(error: VocabularyTestError.testNotFound)
                .eraseToAnyPublisher()
        }
        
        let pausedTest = VocabularyTest(
            id: test.id,
            dictionaryId: test.dictionaryId,
            dictionaryName: test.dictionaryName,
            dictionaryFileName: test.dictionaryFileName,
            totalWords: test.totalWords,
            masteredCount: test.masteredCount,
            familiarCount: test.familiarCount,
            unfamiliarCount: test.unfamiliarCount,
            currentWordIndex: test.currentWordIndex,
            isCompleted: false,
            isPaused: true,
            createdAt: test.createdAt,
            completedAt: nil,
            estimatedVocabularySize: test.estimatedVocabularySize,
            accuracyPercentage: test.accuracyPercentage
        )
        
        activeTests[testId] = pausedTest
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func resumeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        guard let test = activeTests[testId] else {
            return Fail(error: VocabularyTestError.testNotFound)
                .eraseToAnyPublisher()
        }
        
        let resumedTest = VocabularyTest(
            id: test.id,
            dictionaryId: test.dictionaryId,
            dictionaryName: test.dictionaryName,
            dictionaryFileName: test.dictionaryFileName,
            totalWords: test.totalWords,
            masteredCount: test.masteredCount,
            familiarCount: test.familiarCount,
            unfamiliarCount: test.unfamiliarCount,
            currentWordIndex: test.currentWordIndex,
            isCompleted: false,
            isPaused: false,
            createdAt: test.createdAt,
            completedAt: nil,
            estimatedVocabularySize: test.estimatedVocabularySize,
            accuracyPercentage: test.accuracyPercentage
        )
        
        activeTests[testId] = resumedTest
        
        return Just(resumedTest)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func saveTestResult(testId: UUID, word: String, isCorrect: Bool, responseTime: TimeInterval) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func saveTestResult(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        testHistory.append(test)
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestHistory(limit: Int) -> AnyPublisher<[VocabularyTest], Error> {
        let limitedHistory = Array(testHistory.prefix(limit))
        return Just(limitedHistory)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestHistory(for dictionaryId: UUID) -> AnyPublisher<[VocabularyTest], Error> {
        let filteredHistory = testHistory.filter { $0.dictionaryId == dictionaryId }
        return Just(filteredHistory)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestHistory(for dictionaryFileName: String, limit: Int) -> AnyPublisher<[VocabularyTest], Error> {
        let filteredHistory = testHistory.filter { $0.dictionaryFileName == dictionaryFileName }
        let limitedHistory = Array(filteredHistory.prefix(limit))
        return Just(limitedHistory)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getLatestTest(for dictionaryId: UUID) -> AnyPublisher<VocabularyTest?, Error> {
        let latestTest = testHistory.filter { $0.dictionaryId == dictionaryId }.last
        return Just(latestTest)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getLatestTest() -> AnyPublisher<VocabularyTest?, Error> {
        return Just(testHistory.last)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getIncompleteTest(for dictionaryFileName: String) -> AnyPublisher<VocabularyTest?, Error> {
        let incompleteTest = testHistory.first { test in
            test.dictionaryFileName == dictionaryFileName && !test.isCompleted
        }
        return Just(incompleteTest)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func deleteTestRecord(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        testHistory.removeAll { $0.id == test.id }
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func deleteTest(testId: UUID) -> AnyPublisher<Void, Error> {
        activeTests.removeValue(forKey: testId)
        testWords.removeValue(forKey: testId)
        testResponses.removeValue(forKey: testId)
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getCurrentTestForDictionary(_ dictionaryFileName: String) -> AnyPublisher<VocabularyTest?, Error> {
        let currentTest = activeTests.values.first { test in
            test.dictionaryFileName == dictionaryFileName && !test.isCompleted
        }
        return Just(currentTest)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getTestWords(testId: UUID) -> AnyPublisher<[DictionaryWord], Error> {
        let words = testWords[testId] ?? []
        return Just(words)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getWordMastery(word: String, dictionaryFileName: String) -> AnyPublisher<MasteryLevel?, Error> {
        return Just(.unfamiliar)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func updateWordMastery(word: String, dictionaryFileName: String, mastery: MasteryLevel) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getWordsByMastery(dictionaryFileName: String, mastery: MasteryLevel) -> AnyPublisher<[DictionaryWord], Error> {
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getWordStatistics(dictionaryFileName: String) -> AnyPublisher<WordStatistics, Error> {
        let statistics = WordStatistics(
            totalWords: 100,
            masteredWords: 40,
            familiarWords: 35,
            unfamiliarWords: 25,
            averageResponseTime: 2.5,
            testAccuracy: 0.75
        )
        return Just(statistics)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    @MainActor
    func saveTestedWord(_ word: DictionaryWord, mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String, testSessionId: UUID?) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    @MainActor
    func getTestedWords(for dictionaryFileName: String) -> AnyPublisher<[TestedWord], Error> {
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    @MainActor
    func getUntestedWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        return dictionaryService.loadDictionary(fileName: dictionary.fileName)
    }
    
    @MainActor
    func clearTestedWords(for dictionaryFileName: String) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    @MainActor
    func getTestProgress(for dictionaryFileName: String) -> AnyPublisher<TestProgress, Error> {
        let progress = TestProgress(
            dictionaryFileName: dictionaryFileName,
            dictionaryName: "Mock Dictionary",
            totalWords: 100,
            testedWords: 50,
            untestedWords: 50,
            masteredWords: 20,
            familiarWords: 20,
            unfamiliarWords: 10,
            currentIndex: 50
        )
        return Just(progress)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestStatistics() -> AnyPublisher<TestStatistics, Error> {
        let statistics = TestStatistics(
            totalTests: testHistory.count,
            averageScore: 75.0,
            bestScore: 95,
            improvementRate: 0.15
        )
        
        return Just(statistics)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestStatistics(testType: VocabularyTestMode) async throws -> TestStatistics {
        return TestStatistics(
            totalTests: testHistory.count,
            averageScore: 75.0,
            bestScore: 95,
            improvementRate: 0.15
        )
    }
    
    func calculateImprovementRate() -> AnyPublisher<Double, Error> {
        return Just(0.1)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getCurrentWord() -> AnyPublisher<DictionaryWord?, Error> {
        return Just(nil)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getRemainingTime() -> AnyPublisher<TimeInterval, Error> {
        return Just(1800.0)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func isTestTimedOut() -> AnyPublisher<Bool, Error> {
        return Just(false)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getDictionaryTestResults(for dictionaryFileName: String) -> AnyPublisher<DictionaryTestResults, Error> {
        let results = DictionaryTestResults(
            dictionaryFileName: dictionaryFileName,
            totalTestedWords: 100,
            masteredWords: 40,
            familiarWords: 35,
            unfamiliarWords: 25,
            masteryRate: 0.75,
            lastTestDate: Date()
        )
        return Just(results)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    @MainActor
    func batchUpdateWordMastery(words: [String], mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    @MainActor
    func getArticleWordMasteryDistribution(words: [String], dictionaryFileName: String) -> AnyPublisher<WordMasteryDistribution, Error> {
        let distribution = WordMasteryDistribution(
            totalWords: words.count,
            masteredWords: words.count / 4,
            familiarWords: words.count / 4,
            unfamiliarWords: words.count / 4,
            unknownWords: words.count / 4
        )
        return Just(distribution)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Cache Management
    func clearCache() {
        // Mock implementation - no actual cache to clear
        print("MockVocabularyTestService: clearCache() called")
    }
    
 func clearCacheForDictionary(_ dictionaryFileName: String) {
        // Mock implementation
        print("MockVocabularyTestService: clearCacheForDictionary(\(dictionaryFileName)) called")
    }
    
    func updateTestInDatabase(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Retest Methods
    
    func loadWordsForRetest(dictionary: DictionaryInfo, masteryLevels: [MasteryLevel], sampleSize: Int) -> AnyPublisher<[DictionaryWord], Error> {
        // 模拟从指定掌握程度中获取单词
        let allWords = dictionaryService.getAllWords()
        let retestWords = allWords.shuffled().prefix(sampleSize)
        
        return Just(Array(retestWords))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func startRetestVocabularyTest(dictionary: DictionaryInfo, masteryLevels: [MasteryLevel], sampleSize: Int) -> AnyPublisher<VocabularyTest, Error> {
        let test = VocabularyTest(
            id: UUID(),
            dictionaryId: dictionary.id,
            dictionaryName: dictionary.displayName,
            dictionaryFileName: dictionary.fileName,
            totalWords: sampleSize,
            masteredCount: 0,
            familiarCount: 0,
            unfamiliarCount: 0,
            currentWordIndex: 0,
            isCompleted: false,
            isPaused: false,
            createdAt: Date(),
            completedAt: nil,
            estimatedVocabularySize: 0,
            accuracyPercentage: 0.0
        )
        
        currentTest = test
        activeTests[test.id] = test
        testHistory.append(test)
        
        return Just(test)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - 缺少的协议方法
    
    func getDictionarySpecificTestHistory(for dictionaryId: UUID, limit: Int) -> AnyPublisher<[VocabularyTest], Error> {
        let filteredTests = testHistory
            .filter { $0.dictionaryId == dictionaryId }
            .prefix(limit)
        return Just(Array(filteredTests))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getGeneralTestHistory(limit: Int) -> AnyPublisher<[VocabularyTest], Error> {
        let generalTests = testHistory.prefix(limit)
        return Just(Array(generalTests))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func startDictionarySpecificTest(dictionary: DictionaryInfo, sampleSize: Int) -> AnyPublisher<VocabularyTest, Error> {
        // 创建一个模拟的词典特定测试，使用简化构造函数
        let test = VocabularyTest(
            dictionaryName: dictionary.displayName,
            sampleSize: sampleSize,
            difficultyRange: "1-4",
            isDictionarySpecific: true
        )
        
        currentTest = test
        activeTests[test.id] = test
        testHistory.append(test)
        
        return Just(test)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func startGeneralTest(dictionary: DictionaryInfo, sampleSize: Int) -> AnyPublisher<VocabularyTest, Error> {
        // 创建一个模拟的通用测试，使用简化构造函数
        let test = VocabularyTest(
            dictionaryName: "General Test",
            sampleSize: sampleSize,
            difficultyRange: "1-4",
            isDictionarySpecific: false
        )
        
        currentTest = test
        activeTests[test.id] = test
        testHistory.append(test)
        
        return Just(test)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getLatestDictionarySpecificTest(for dictionaryId: UUID) -> AnyPublisher<VocabularyTest?, Error> {
        let latestTest = testHistory.filter { $0.dictionaryId == dictionaryId }.last
        return Just(latestTest)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getLatestGeneralTest() -> AnyPublisher<VocabularyTest?, Error> {
        let latestGeneralTest = testHistory.filter { !$0.isDictionarySpecific }.last
        return Just(latestGeneralTest)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestHistoryGroupedByDictionary() -> AnyPublisher<[UUID: [VocabularyTest]], Error> {
        let groupedTests = Dictionary(grouping: testHistory) { $0.dictionaryId ?? UUID() }
        return Just(groupedTests)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
