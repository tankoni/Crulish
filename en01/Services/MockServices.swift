//
//  MockServices.swift
//  en01
//
//  Created by Mock Services for SwiftUI Previews
//

import Foundation
import Combine

// MARK: - Mock Article Service
class MockArticleService: ArticleServiceProtocol {
    func getAllArticles() -> [Article] {
        return [
            Article(
                title: "Sample Article",
                content: "This is a sample article content for testing purposes.",
                year: 2024,
                examType: "考研一",
                difficulty: .medium,
                topic: "Technology",
                imageName: "sample1"
            )
        ]
    }
    
    func getArticlesByYear(_ year: Int) -> [Article] {
        return []
    }
    
    func getArticlesByDifficulty(_ difficulty: ArticleDifficulty) -> [Article] {
        return []
    }
    
    func getArticlesByExamType(_ examType: String) -> [Article] {
        return []
    }
    
    func getRecentArticles(limit: Int) -> [Article] {
        return []
    }
    
    func getRecommendedArticles(limit: Int) -> [Article] {
        return []
    }
    
    func searchArticles(_ query: String) -> [Article] {
        return []
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
        // Mock implementation
        print("[MOCK] 清除所有文章数据")
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
            totalArticles: 10,
            completedArticles: 5,
            inProgressArticles: 3,
            unreadArticles: 2,
            totalReadingTime: 1500.0,
            averageProgress: 0.5,
            yearStats: [2024: (total: 5, completed: 2)],
            difficultyStats: [.medium: (total: 5, completed: 2)],
            topicStats: ["Technology": (total: 5, completed: 2)]
        )
    }
    
    func getAvailableYears() -> [Int] {
        return [2024, 2023, 2022]
    }
    
    func getAvailableTopics() -> [String] {
        return ["Technology", "Science", "Culture"]
    }
    
    func getAvailableExamTypes() -> [String] {
        return ["考研一", "考研二"]
    }
    
    func getReadingStatistics() async throws -> ReadingStatistics {
        let stats = getArticleStats()
        return ReadingStatistics(
            completedArticles: stats.completedArticles,
            inProgressArticles: stats.inProgressArticles,
            bookmarkedArticles: 2, // Mock value
            averageReadingTime: stats.totalReadingTime / Double(stats.totalArticles > 0 ? stats.totalArticles : 1),
            favoriteTopics: Array(stats.topicStats.keys),
            difficultyDistribution: Dictionary(uniqueKeysWithValues: stats.difficultyStats.map { ($0.key.rawValue, $0.value.total) }),
            yearDistribution: Dictionary(uniqueKeysWithValues: stats.yearStats.map { (String($0.key), $0.value.total) })
        )
    }
}

// MARK: - Mock Dictionary Service
class MockDictionaryService: DictionaryServiceProtocol {
    func lookupWord(_ word: String) async throws -> UserWord {
        return UserWord(
            word: word,
            context: "Sample context",
            sentence: "This is a sample sentence.",
            selectedDefinition: WordDefinition(partOfSpeech: .noun, meaning: "A sample definition")
        )
    }
    
    func lookupWord(_ word: String, context: String) -> DictionaryWord? {
        return DictionaryWord(
            word: word,
            phonetic: "/ˈsæmpəl/",
            definitions: [WordDefinition(partOfSpeech: .noun, meaning: "A sample definition")],
            difficulty: .medium
        )
    }
    
    func searchWords(_ query: String) -> [DictionaryWord] {
        return []
    }
    
    func addUnknownWord(_ word: UserWord) async throws {
        // Mock implementation
    }
    
    func addWord(_ word: UserWord) async throws {
        // Mock implementation
    }
    
    func recordWordLookup(word: String, context: String, sentence: String, article: Article) -> UserWord {
        let userWord = UserWord(
            word: word,
            context: context,
            sentence: sentence,
            selectedDefinition: WordDefinition(partOfSpeech: .noun, meaning: "A sample definition")
        )
        userWord.articleID = article.id.uuidString
        return userWord
    }
    
    func getUserWordRecords() -> [UserWord] {
        return []
    }
    
    func getWordsByMastery(_ mastery: MasteryLevel) -> [UserWord] {
        return []
    }
    
    func getWordsForReview() -> [UserWord] {
        return []
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
        // Mock implementation
    }
    
    func getVocabularyStats() -> VocabularyStats {
        return VocabularyStats(
            totalWords: 100,
            unfamiliarWords: 30,
            familiarWords: 50,
            masteredWords: 20,
            todayLookups: 5,
            weeklyLookups: 25,
            averageLookupPerDay: 3.5,
            mostLookedUpWords: []
        )
    }
    
    func initializeDictionary() async throws {
        // Mock implementation
    }
}

// MARK: - Mock User Progress Service
class MockUserProgressService: UserProgressServiceProtocol {
    func getUserProgress() -> UserProgress? {
        return nil
    }

    func addReadingTime(_ time: Double) {}
    func addWordLookup() {}
    func addExperience(_ points: Int, for activity: ExperienceAction) {}
    func incrementArticleRead() {}
    func completeReview() {}
    
    func recordWordReview(word: String, correct: Bool) async throws {}
    func recordReviewSession(wordsReviewed: Int, correctAnswers: Int) async throws {}
    func recordArticleCompletion(articleId: String, readingTime: TimeInterval, wordsLookedUp: Int) async throws {}
    func updateReadingProgress(articleId: String, progress: Double, readingTime: TimeInterval) async throws {}
    func recordWordLookup(word: String, articleId: String) async throws {}
    func addBookmark(articleId: String) async throws {}
    func removeBookmark(articleId: String) async throws {}
    func isBookmarked(articleId: String) async throws -> Bool { return false }
    func markArticleAsCompleted(articleId: String) async throws {}
    func isCompleted(articleId: String) async throws -> Bool { return false }
    
    func getTodayRecord() -> DailyStudyRecord? {
        return nil
    }
    
    func getReadingTrend(days: Int) -> [DailyStudyRecord] {
        return []
    }
    
    func getWeeklyComparison() -> WeeklyComparison {
        return WeeklyComparison(thisWeekReadingTime: 0, lastWeekReadingTime: 0, thisWeekArticles: 0, lastWeekArticles: 0, thisWeekWords: 0, lastWeekWords: 0)
    }
    
    func getStudyStatistics() -> StudyStatistics {
        return StudyStatistics()
    }
    
    func getTodayStatistics() async throws -> TodayStatistics {
        return TodayStatistics()
    }
    
    func getWeeklyStatistics() async throws -> WeeklyStatistics {
        return WeeklyStatistics()
    }
    
    func getMonthlyStatistics() async throws -> MonthlyStatistics {
        return MonthlyStatistics()
    }
    
    func getOverallStatistics() async throws -> OverallStatistics {
        return OverallStatistics()
    }
    
    func getVocabularyProgressStatistics() async throws -> VocabularyProgressStats {
        return VocabularyProgressStats()
    }
    
    func getVocabularyStatistics() async throws -> VocabularyStatistics {
        return VocabularyStatistics(totalWords: 0, unknownWords: 0, learningWords: 0, familiarWords: 0, masteredWords: 0, wordsNeedingReview: 0)
    }
    
    func getAchievementStatistics() async throws -> AchievementStatistics {
        return AchievementStatistics()
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
        return .beginner
    }
    
    func getLevelProgress() -> Double {
        return 0.0
    }
    
    func getExperienceToNextLevel() -> Int {
        return 100
    }
    
    func getGoalProgress() -> GoalProgress {
        return GoalProgress()
    }
    
    func getConsecutiveDays() -> Int {
        return 0
    }
    
    func getUnlockedAchievements() -> [Achievement] {
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
        return false
    }
    
    func resetProgress() {}
    
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
    
    func updateUserSettings(_ settings: UserSettings) async throws {}
    func updateReadingSettings(_ settings: ReadingSettings) async throws {}
    func updateVocabularySettings(_ settings: VocabularySettings) async throws {}
    func updateNotificationSettings(_ settings: NotificationSettings) async throws {}
    func updatePrivacySettings(_ settings: PrivacySettings) async throws {}
    func updateAppearanceSettings(_ settings: AppearanceSettings) async throws {}
    
    func resetAllData() async throws {}
}

// MARK: - Mock Text Processor
class MockTextProcessor: TextProcessorProtocol {
    // 文本清理
    func cleanWord(_ word: String) -> String {
        return word.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
    }
    
    func cleanText(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 文本分词
    func tokenize(_ text: String) -> [String] {
        return text.components(separatedBy: .whitespacesAndNewlines)
    }
    
    func tokenizeText(_ text: String) -> [String] {
        return tokenize(text)
    }
    
    func extractWords(_ text: String) -> [String] {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .map { cleanWord($0) }
            .filter { !$0.isEmpty }
    }
    
    // 关键词提取
    func extractKeywords(from text: String, limit: Int) -> [String] {
        let words = extractWords(text)
        return Array(words.prefix(limit))
    }
    
    // 词形还原
    func stemWord(_ word: String) -> String {
        return cleanWord(word)
    }
    
    // 相似度计算
    func calculateSimilarity(_ string1: String, _ string2: String) -> Double {
        return 0.5
    }
    
    // 句子分析
    func splitIntoSentences(_ text: String) -> [String] {
        return text.components(separatedBy: ".")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    func getWordContext(_ word: String, in text: String, contextLength: Int) -> String {
        return text
    }
    
    func getSentenceContaining(_ word: String, in text: String) -> String? {
        let sentences = splitIntoSentences(text)
        return sentences.first { $0.contains(word) }
    }
    
    func extractSentence(containing word: String, from text: String) -> String? {
        return getSentenceContaining(word, in: text)
    }
    
    // 词性标注
    func getPartOfSpeech(_ word: String) -> PartOfSpeech? {
        return .noun
    }
    
    // 文本统计
    func calculateReadingDifficulty(_ text: String) -> Double {
        return 0.5
    }
    
    func calculateVocabularyDensity(_ text: String) -> Double {
        return 0.5
    }
    
    func getTextStatistics(_ text: String) -> TextStatistics {
        let words = extractWords(text)
        let sentences = splitIntoSentences(text)
        let characters = text.count
        let charactersNoSpaces = text.replacingOccurrences(of: " ", with: "").count
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        return TextStatistics(
            characterCount: characters,
            characterCountNoSpaces: charactersNoSpaces,
            wordCount: words.count,
            sentenceCount: sentences.count,
            paragraphCount: paragraphs.count,
            averageWordsPerSentence: sentences.isEmpty ? 0.0 : Double(words.count) / Double(sentences.count),
            averageCharactersPerWord: words.isEmpty ? 0.0 : Double(charactersNoSpaces) / Double(words.count),
            readingDifficulty: 0.5,
            vocabularyDensity: 0.5,
            estimatedReadingTime: Double(words.count) / 200.0
        )
    }
}

// MARK: - Mock Error Handler
class MockErrorHandler: ErrorHandlerProtocol {
    var currentError: AppError?
    var isShowingError: Bool = false
    
    func handle(_ error: Error, context: String) {
        let appError: AppError
        if let existingAppError = error as? AppError {
            appError = existingAppError
        } else {
            appError = AppError.unknown(error)
        }
        handle(appError)
        print("Mock Error: \(error.localizedDescription) in \(context)")
    }
    
    func handle(_ appError: AppError) {
        currentError = appError
        isShowingError = true
        print("Mock Error: \(appError.localizedDescription)")
    }

    func logSuccess(_ message: String) {
        print("Mock Success: \(message)")
    }

    func handle(_ appError: AppError, context: String) {
        print("Mock Error: \(appError.localizedDescription) in \(context)")
    }
    
    func dismissError() {
        currentError = nil
        isShowingError = false
    }
    
    func clearAllErrors() {
        currentError = nil
        isShowingError = false
    }
    
    func getErrorStatistics() -> ErrorStatistics {
        return ErrorStatistics()
    }
    
    func getRecentErrors(limit: Int) -> [ErrorRecord] {
        return []
    }
    
    func clearErrorHistory() {
        // Mock implementation
    }
    
    func exportErrorLog() -> String {
        return "Mock error log"
    }
    
    func shouldRetry(error: Error, attemptCount: Int) -> Bool {
        return false
    }
    
    func recordRecovery(from error: Error, context: String) {
        // Mock implementation
    }
}

// MARK: - Mock Cache Manager
class MockCacheManager: CacheManagerProtocol {
    private var cache: [String: Any] = [:]
    
    func get<T: Codable>(_ key: String, type: T.Type) -> T? {
        return cache[key] as? T
    }

    func set<T: Codable>(_ key: String, value: T, expiration: TimeInterval?) {
        cache[key] = value
    }
    
    func invalidate(_ key: String) {
        cache.removeValue(forKey: key)
    }
    
    func invalidateAll() {
        cache.removeAll()
    }
    
    func clearAll() {
        cache.removeAll()
    }
    
    func clearExpiredItems() {
        // Mock implementation - no expiration logic
    }
    
    func getCacheSize() -> Int {
        return cache.count
    }
    
    func getCacheInfo() -> CacheInfo {
        return CacheInfo(itemCount: cache.count, totalSize: 0, hitRate: 0.8, missRate: 0.2)
    }
    
    func remove(_ key: String) {
        cache.removeValue(forKey: key)
    }
    
    func removeByPrefix(_ prefix: String) {
        let keysToRemove = cache.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }
}