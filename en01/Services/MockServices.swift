//
//  MockServices.swift
//  en01
//
//  Created by Mock Services for SwiftUI Previews
//

import Foundation
import Combine
import SwiftData
import SwiftUI
import Foundation

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
    // MARK: - Dictionary Management
    func getAvailableDictionaries() -> AnyPublisher<[DictionaryInfo], Error> {
        let mockDictionaries = [
            DictionaryInfo(
                name: "考研核心词汇",
                displayName: "考研核心词汇",
                fileName: "KaoYan_1.json",
                filePath: "/path/to/KaoYan_1.json",
                version: "1.0",
                description: "考研必备核心词汇，包含高频词汇和重点词汇",
                language: "en",
                totalWords: 3000,
                difficultyLevels: [1, 2, 3],
                categories: ["考研", "学术"]
            ),
            DictionaryInfo(
                name: "托福核心词汇",
                displayName: "托福核心词汇",
                fileName: "TOEFL_Core.json",
                filePath: "/path/to/TOEFL_Core.json",
                version: "1.0",
                description: "托福考试核心词汇集合",
                language: "en",
                totalWords: 2500,
                difficultyLevels: [2, 3, 4],
                categories: ["TOEFL", "学术"]
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
                definitions: [WordDefinition(partOfSpeech: .noun, meaning: "测试；考试", examples: ["This is a test."])],
                difficulty: .medium,
                categories: ["基础词汇"]
            ),
            DictionaryWord(
                word: "example",
                phonetic: "/ɪɡˈzæmpəl/",
                definitions: [WordDefinition(partOfSpeech: .noun, meaning: "例子；实例", examples: ["For example, this is a sample."])],
                difficulty: .basic,
                categories: ["常用词汇"]
            )
        ]
        
        return Just(mockWords)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func lookupWord(_ word: String) async throws -> UserWord {
        return UserWord(
            word: word,
            context: "Sample context",
            sentence: "This is a sample sentence.",
            selectedDefinition: WordDefinition(partOfSpeech: PartOfSpeech.noun, meaning: "A sample definition")
        )
    }
    
    func lookupWord(_ word: String, context: String) -> DictionaryWord? {
        return DictionaryWord(
            word: word,
            phonetic: "/ˈsæmpəl/",
            definitions: [WordDefinition(partOfSpeech: .noun, meaning: "A sample definition")],
            difficulty: .medium,
            categories: ["示例词汇"]
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
        let definition = WordDefinition(partOfSpeech: .noun, meaning: "A sample definition")
        let userWord = UserWord(
            word: word,
            context: context,
            sentence: sentence,
            selectedDefinition: definition
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
    
    func initializeKaoyanDictionary() async {
        // Mock implementation
    }
    
    func getKaoyanWordDetails(_ word: String) -> KaoyanWordDetails? {
        // 返回模拟的考研单词详情
        return KaoyanWordDetails(
            word: word,
            wordRank: 1000,
            bookId: "mock_book",
            usPhone: "test",
            ukPhone: "test",
            translations: [
                KaoyanWordTranslation(
                    pos: "n.",
                    tranCn: "测试；考试",
                    tranOther: nil
                ),
                KaoyanWordTranslation(
                    pos: "v.",
                    tranCn: "测试；检验",
                    tranOther: nil
                )
            ],
            sentences: [
                KaoyanWordSentence(
                    sContent: "This is a test sentence.",
                    sCn: "这是一个测试句子。"
                )
            ],
            synonyms: [
                KaoyanWordSynonym(
                    pos: "n.",
                    tran: "exam, examination",
                    synonymWords: ["exam", "examination"]
                )
            ],
            phrases: [
                KaoyanWordPhrase(
                    pContent: "test case",
                    pCn: "测试用例"
                )
            ],
            relatedWords: [
                KaoyanWordRelated(
                    pos: "v.",
                    hwd: "testing",
                    tran: "测试"
                )
            ]
        )
    }
}

// MARK: - Mock User Progress Service
class MockUserProgressService: UserProgressServiceProtocol {
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
        return WeeklyComparison(
            thisWeekReadingTime: 3600,
            lastWeekReadingTime: 2400,
            thisWeekArticles: 5,
            lastWeekArticles: 3,
            thisWeekWords: 25,
            lastWeekWords: 18
        )
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
            readingTime: 1800,
            articlesRead: 2,
            wordsLookedUp: 15,
            reviewsCompleted: 10,
            dailyReadingGoalProgress: 0.6,
            consecutiveDays: userProgress.currentStreak
        )
    }
    
    func getWeeklyStatistics() async throws -> WeeklyStatistics {
        return WeeklyStatistics(
            totalReadingTime: 3600 * 8, // 8小时
            totalArticlesRead: 12,
            totalWordsLookedUp: 85,
            totalReviewsCompleted: 45,
            dailyAverageReadingTime: 1200,
            studyDaysThisWeek: 5,
            weeklyGoalProgress: 0.8
        )
    }
    
    func getMonthlyStatistics() async throws -> MonthlyStatistics {
        return MonthlyStatistics(
            totalReadingTime: 3600 * 35, // 35小时
            totalArticlesRead: 48,
            totalWordsLookedUp: 320,
            totalReviewsCompleted: 180,
            dailyAverageReadingTime: 1200,
            studyDaysThisMonth: 22,
            monthlyGoalProgress: 0.75,
            bestWeekReadingTime: 3600 * 10
        )
    }
    
    func getOverallStatistics() async throws -> OverallStatistics {
        return OverallStatistics(
            totalReadingTime: 3600 * 25, // 25小时
            totalArticlesRead: 45,
            totalWordsLookedUp: 320,
            totalReviewsCompleted: 180,
            longestStreak: 15,
            currentStreak: 7,
            totalStudyDays: 30,
            averageReadingSpeed: 250.0
        )
    }
    
    func getReadingStatistics() async throws -> ReadingStatistics {
        return ReadingStatistics(
            completedArticles: 35,
            inProgressArticles: 5,
            bookmarkedArticles: 12,
            averageReadingTime: 480,
            favoriteTopics: ["Technology", "Science", "Business"],
            difficultyDistribution: ["Easy": 10, "Medium": 20, "Hard": 5],
            yearDistribution: ["2024": 35]
        )
    }
    
    func getVocabularyProgressStatistics() async throws -> VocabularyProgressStats {
        return VocabularyProgressStats(
            totalWords: 1250,
            masteredWords: 850,
            learningWords: 300,
            reviewWords: 100,
            masteryRate: 0.68,
            weeklyNewWords: 25,
            monthlyNewWords: 95,
            averageReviewAccuracy: 0.85
        )
    }
    
    func getAchievementStatistics() async throws -> AchievementStatistics {
        return AchievementStatistics(
            totalAchievements: 15,
            unlockedAchievements: 8,
            recentAchievements: [],
            nextMilestones: []
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
        return userProgress.level
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
        // 简化的错误处理，直接打印错误信息
        print("❌ 错误 [\(context)]: \(error.localizedDescription)")
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

// MARK: - Mock Translation Service
class MockTranslationService: TranslationServiceProtocol {
    func translateWord(_ word: String, context: String) async throws -> Translation? {
        return Translation(
            originalText: word,
            translatedText: "翻译: \(word)",
            sourceLanguage: "en",
            targetLanguage: "zh",
            confidence: 0.95,
            provider: TranslationProvider.local,
            contextualMeaning: "在上下文中的含义",
            grammarAnalysis: nil as GrammarAnalysis?
        )
    }
    
    func translateSentence(_ sentence: String) async throws -> Translation? {
        return Translation(
            originalText: sentence,
            translatedText: "句子翻译: \(sentence)",
            sourceLanguage: "en",
            targetLanguage: "zh",
            confidence: 0.90,
            provider: TranslationProvider.local,
            contextualMeaning: nil as String?,
            grammarAnalysis: nil as GrammarAnalysis?
        )
    }
    
    func translateParagraph(_ paragraph: String) async throws -> Translation? {
        return Translation(
            originalText: paragraph,
            translatedText: "段落翻译: \(paragraph)",
            sourceLanguage: "en",
            targetLanguage: "zh",
            confidence: 0.85,
            provider: TranslationProvider.local,
            contextualMeaning: nil as String?,
            grammarAnalysis: nil as GrammarAnalysis?
        )
    }
    
    func setTranslationProvider(_ provider: TranslationProvider) {
        // Mock implementation - no actual provider change
    }
    
    func getAvailableProviders() -> [TranslationProvider] {
        return [.local, .openai, .google]
    }
    
    func isLocalModelAvailable() -> Bool {
        return true
    }
    
    func clearTranslationCache() {
        // Mock implementation - no actual cache to clear
    }
    
    func getCacheStatistics() -> TranslationCacheStats {
        return TranslationCacheStats(
            totalEntries: 100,
            hitRate: 0.85,
            missRate: 0.15,
            cacheSize: 1024,
            lastCleanup: Date()
        )
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