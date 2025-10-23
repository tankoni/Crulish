//
//  MockServices.swift
//  en01Tests
//
//  Created by Assistant on 2024-12-19.
//

import Foundation
import SwiftData
import Combine
@testable import en01

// MARK: - Type Aliases
typealias Word = DictionaryWord

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
    
    func getReadingStatistics() async throws -> ReadingStatistics {
        return ReadingStatistics(
            completedArticles: 0,
            inProgressArticles: 0,
            bookmarkedArticles: 0,
            averageReadingTime: 0,
            favoriteTopics: [],
            difficultyDistribution: [:],
            yearDistribution: [:]
        )
    }
}

// MARK: - Mock DictionaryService
class MockDictionaryService: DictionaryServiceProtocol {
    private var mockWords: [DictionaryWord] = []
    
    func setupMockWords(count: Int = 1000) {
        mockWords = createMockWords(count: count)
    }
    
    func createMockWords(count: Int) -> [DictionaryWord] {
        var words: [DictionaryWord] = []
        
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
        return mockWords
    }
    
    func getRandomWords(count: Int) -> [DictionaryWord] {
        return Array(mockWords.shuffled().prefix(count))
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
    
    private var vocabulary: [UserWord] = [
        UserWord(
            word: "test",
            context: "This is a test context",
            sentence: "This is a test sentence",
            selectedDefinition: WordDefinition(partOfSpeech: .noun, meaning: "A procedure intended to establish the quality, performance, or reliability of something")
        ),
        UserWord(
            word: "example",
            context: "This is an example context",
            sentence: "For example, this is a sample sentence",
            selectedDefinition: WordDefinition(partOfSpeech: .noun, meaning: "A thing characteristic of its kind or illustrating a general rule")
        )
    ]
    
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
        vocabulary.append(word)
    }
    
    func getUserVocabulary() async throws -> [UserWord] {
        return vocabulary
    }
    
    func addWord(_ word: UserWord) async throws {
        vocabulary.append(word)
    }
    
    func getUserWordRecords() -> [UserWord] {
        return vocabulary
    }
    
    func getWordsByMastery(_ mastery: MasteryLevel) -> [UserWord] {
        return vocabulary.filter { $0.masteryLevel == mastery }
    }
    
    func getWordsForReview() -> [UserWord] {
        return vocabulary.filter { $0.isMarkedForReview }
    }
    
    func updateWordMastery(_ record: UserWord, level: MasteryLevel) {
        record.updateMasteryLevel(level)
    }
    
    func updateMasteryLevel(_ record: UserWord, level: MasteryLevel) {
        record.updateMasteryLevel(level)
    }
    
    func markForReview(_ record: UserWord) {
        record.isMarkedForReview = true
    }
    
    func addNote(_ record: UserWord, note: String) {
        record.notes = note
    }
    
    func toggleReviewFlag(for record: UserWord) {
        record.isMarkedForReview.toggle()
    }
    
    func deleteWordRecord(_ record: UserWord) {
        vocabulary.removeAll { $0.id == record.id }
    }
    
    func clearAllRecords() {
        vocabulary.removeAll()
    }
    
    func getVocabularyStats() -> VocabularyStats {
        return VocabularyStats(
            totalWords: vocabulary.count,
            masteredWords: vocabulary.filter { $0.masteryLevel == .mastered }.count,
            learningWords: vocabulary.filter { $0.masteryLevel == .familiar }.count,
            reviewWords: vocabulary.filter { $0.isMarkedForReview }.count
        )
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
        if let index = vocabulary.firstIndex(where: { $0.word == word.word }) {
            vocabulary[index] = word
        }
    }
    
    func deleteWord(_ word: String) async throws {
        vocabulary.removeAll { $0.word == word }
    }
    
    func getWordsForReview() async throws -> [UserWord] {
        return vocabulary.filter { $0.masteryLevel != .mastered }
    }
    
    func updateWordMastery(_ word: String, mastery: MasteryLevel) async throws {
        if let index = vocabulary.firstIndex(where: { $0.word == word }) {
            vocabulary[index].masteryLevel = mastery
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
    
    func getVocabularyStatistics() async throws -> VocabularyStatistics {
        return VocabularyStatistics(
            totalWords: vocabulary.count,
            unknownWords: vocabulary.filter { $0.masteryLevel == .unfamiliar }.count,
            learningWords: vocabulary.filter { $0.masteryLevel == .familiar }.count,
            familiarWords: vocabulary.filter { $0.masteryLevel == .familiar }.count,
            masteredWords: vocabulary.filter { $0.masteryLevel == .mastered }.count,
            wordsNeedingReview: vocabulary.filter { $0.isMarkedForReview }.count,
            averageLookupCount: 2.5,
            totalLookups: vocabulary.reduce(0) { $0 + $1.lookupCount }
        )
    }
    
    func updateMasteryLevel(word: String, level: MasteryLevel) async throws {
        if let index = vocabulary.firstIndex(where: { $0.word == word }) {
            vocabulary[index].masteryLevel = level
        }
    }
}

// MARK: - Test Mock UserProgressService
class TestMockUserProgressService: UserProgressServiceProtocol {
    private var userProgress: UserProgress = {
        let progress = UserProgress()
        progress.totalReadingTime = 3600
        progress.articlesRead = 5
        progress.totalWordsLookedUp = 50
        progress.currentStreak = 7
        progress.longestStreak = 15
        progress.lastStudyDate = Date()
        progress.level = .intermediate
        progress.experience = 750
        progress.achievements = []
        return progress
    }()
    
    func getUserProgress() -> UserProgress? {
        return userProgress
    }
    
    func addReadingTime(_ time: Double) {
        userProgress.totalReadingTime += time
    }
    
    func addWordLookup() {
        userProgress.totalWordsLookedUp += 1
    }
    
    func addExperience(_ points: Int, for activity: ExperienceAction) {
        userProgress.experience += points
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
    
    func updateReadingProgress(articleId: String, progress: Double, readingTime: TimeInterval) async throws {
        userProgress.totalReadingTime += readingTime
    }
    
    func recordWordLookup(word: String, articleId: String) async throws {
        userProgress.totalWordsLookedUp += 1
    }
    
    func getTodayRecord() -> DailyStudyRecord? {
        return nil
    }
    
    func getReadingTrend(days: Int) -> [DailyStudyRecord] {
        return []
    }
    
    func getWeeklyComparison() -> WeeklyComparison {
        return WeeklyComparison()
    }
    
    func getStudyStatistics() -> StudyStatistics {
        return StudyStatistics()
    }
    
    func addBookmark(articleId: String) async throws {
        // Mock implementation
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
    
    func getTodayStatistics() async throws -> TodayStatistics {
        return TodayStatistics(
            readingTime: 3600,
            articlesRead: 2,
            wordsLookedUp: 15,
            reviewsCompleted: 8,
            dailyReadingGoalProgress: 0.6,
            consecutiveDays: 5
        )
    }
    
    func getWeeklyStatistics() async throws -> WeeklyStatistics {
        return WeeklyStatistics(
            totalReadingTime: 7200,
            totalArticlesRead: 8,
            totalWordsLookedUp: 45,
            totalReviewsCompleted: 60,
            dailyAverageReadingTime: 1028,
            studyDaysThisWeek: 5,
            weeklyGoalProgress: 0.8
        )
    }
    
    func getMonthlyStatistics() async throws -> MonthlyStatistics {
        return MonthlyStatistics(
            totalReadingTime: 28800,
            totalArticlesRead: 25,
            totalWordsLookedUp: 150,
            totalReviewsCompleted: 200,
            dailyAverageReadingTime: 960,
            studyDaysThisMonth: 22,
            monthlyGoalProgress: 0.75,
            bestWeekReadingTime: 7200
        )
    }
    
    func getOverallStatistics() async throws -> OverallStatistics {
        return OverallStatistics(
            totalReadingTime: userProgress.totalReadingTime,
            totalArticlesRead: userProgress.articlesRead,
            totalWordsLookedUp: userProgress.totalWordsLookedUp,
            totalReviewsCompleted: 150,
            longestStreak: userProgress.longestStreak,
            currentStreak: userProgress.currentStreak,
            totalStudyDays: userProgress.streakDays,
            averageReadingSpeed: 250.0
        )
    }
    
    func getReadingStatistics() async throws -> ReadingStatistics {
        return ReadingStatistics(
            completedArticles: userProgress.articlesRead,
            inProgressArticles: 3,
            bookmarkedArticles: 5,
            averageReadingTime: 1200,
            favoriteTopics: ["Technology", "Science", "Business"],
            difficultyDistribution: ["Beginner": 10, "Intermediate": 15, "Advanced": 8],
            yearDistribution: ["2024": 20, "2023": 13]
        )
    }
    
    func getVocabularyProgressStatistics() async throws -> VocabularyProgressStats {
        return VocabularyProgressStats(
            totalWords: userProgress.totalWordsLookedUp,
            masteredWords: Int(Double(userProgress.totalWordsLookedUp) * 0.6),
            learningWords: Int(Double(userProgress.totalWordsLookedUp) * 0.3),
            reviewWords: Int(Double(userProgress.totalWordsLookedUp) * 0.1),
            masteryRate: 0.6,
            weeklyNewWords: 45,
            monthlyNewWords: 180,
            averageReviewAccuracy: 0.85
        )
    }
    
    func getAchievementStatistics() async throws -> AchievementStatistics {
        return AchievementStatistics(
            totalAchievements: 25,
            unlockedAchievements: userProgress.achievements.count,
            recentAchievements: ["First Article", "Week Streak"],
            nextMilestones: ["Month Streak", "100 Words"],
            longestStreak: userProgress.longestStreak,
            recentBadges: []
        )
    }
    
    func getGoalProgress() -> GoalProgress {
        return GoalProgress(
            dailyReadingProgress: 0.6,
            weeklyArticleProgress: 0.8,
            weeklyWordProgress: 0.7,
            dailyReadingGoal: 30,
            weeklyArticleGoal: 5,
            weeklyWordGoal: 25
        )
    }
    
    func getVocabularyStatistics() async throws -> VocabularyStatistics {
        return VocabularyStatistics(
            totalWords: userProgress.totalWordsLookedUp,
            unknownWords: 10,
            learningWords: 15,
            familiarWords: 20,
            masteredWords: 5,
            wordsNeedingReview: 8,
            averageLookupCount: 2.5,
            totalLookups: 125
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
        return UserLevel(rawValue: userProgress.level) ?? .beginner
    }
    
    func getLevelProgress() -> Double {
        return 0.65
    }
    
    func getExperienceToNextLevel() -> Int {
        return 250
    }
    
    func getConsecutiveDays() -> Int {
        return userProgress.currentStreak
    }
    
    func getUnlockedAchievements() -> [Achievement] {
        return userProgress.achievements
    }
    
    func getAvailableAchievements() -> [AchievementType] {
        return [.firstArticle, .streak7Days, .streak30Days]
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
        // Mock implementation
    }
    
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
    
    func updateUserSettings(_ settings: UserSettings) async throws {
        // Mock implementation
    }
    
    func updateReadingSettings(_ settings: ReadingSettings) async throws {
        // Mock implementation
    }
    
    func updateVocabularySettings(_ settings: VocabularySettings) async throws {
        // Mock implementation
    }
    
    func updateNotificationSettings(_ settings: NotificationSettings) async throws {
        // Mock implementation
    }
    
    func updatePrivacySettings(_ settings: PrivacySettings) async throws {
        // Mock implementation
    }
    
    func updateAppearanceSettings(_ settings: AppearanceSettings) async throws {
        // Mock implementation
    }
    
    func resetAllData() async throws {
        // Mock implementation
    }

}

// MARK: - Mock TextProcessor
class MockTextProcessor: TextProcessorProtocol {
    func cleanWord(_ word: String) -> String {
        return word.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }
    
    func cleanText(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func tokenize(_ text: String) -> [String] {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    func tokenizeText(_ text: String) -> [String] {
        return tokenize(text)
    }
    
    func extractWords(_ text: String) -> [String] {
        return tokenize(text)
    }
    
    func extractKeywords(from text: String, limit: Int) -> [String] {
        return Array(tokenize(text).prefix(limit))
    }
    
    func stemWord(_ word: String) -> String {
        return word
    }
    
    func calculateSimilarity(_ string1: String, _ string2: String) -> Double {
        return string1 == string2 ? 1.0 : 0.0
    }
    
    func splitIntoSentences(_ text: String) -> [String] {
        return text.components(separatedBy: ".")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    func getWordContext(_ word: String, in text: String, contextLength: Int) -> String {
        return text
    }
    
    func getSentenceContaining(_ word: String, in text: String) -> String? {
        return splitIntoSentences(text).first { $0.contains(word) }
    }
    
    func extractSentence(containing word: String, from text: String) -> String? {
        return getSentenceContaining(word, in: text)
    }
    
    func getPartOfSpeech(_ word: String) -> PartOfSpeech? {
        return .noun
    }
    
    func processText(_ text: String) -> [String] {
        let sentences = text.components(separatedBy: ". ")
        return sentences
    }
    
    func highlightComplexWords(in text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        // Mock implementation - just return the text without highlighting
        return attributedString
    }
}

// MARK: - Mock ErrorHandler
class MockErrorHandler: ErrorHandlerProtocol {
    var errors: [AppError] = []
    
    var currentError: AppError? {
        return errors.last
    }
    
    var isShowingError: Bool {
        return !errors.isEmpty
    }
    
    func handle(_ error: Error, context: String) {
        let appError: AppError
        if let existingAppError = error as? AppError {
            appError = existingAppError
        } else {
            appError = AppError.unknown(error)
        }
        handle(appError)
    }
    
    func handle(_ appError: AppError) {
        errors.append(appError)
        print("Mock Error: \(appError.localizedDescription)")
    }
    
    func logSuccess(_ message: String) {
        print("Mock Success: \(message)")
    }
    
    func dismissError() {
        if !errors.isEmpty {
            errors.removeLast()
        }
    }
    
    func clearAllErrors() {
        errors.removeAll()
    }
}