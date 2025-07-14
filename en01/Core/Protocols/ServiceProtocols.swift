//
//  ServiceProtocols.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData

// MARK: - Article Service Protocol

protocol ArticleServiceProtocol {
    // 文章获取
    func getAllArticles() -> [Article]
    func getArticlesByYear(_ year: Int) -> [Article]
    func getArticlesByDifficulty(_ difficulty: ArticleDifficulty) -> [Article]
    func getArticlesByExamType(_ examType: String) -> [Article]
    func getRecentArticles(limit: Int) -> [Article]
    func getRecommendedArticles(limit: Int) -> [Article]
    func searchArticles(_ query: String) -> [Article]
    
    // 文章操作
    func updateArticle(_ article: Article)
    func markArticleAsCompleted(_ article: Article)
    func updateArticleProgress(_ article: Article, progress: Double)
    func addReadingTime(to article: Article, time: Double)
    func clearAllArticles()
    
    // 数据导入
    func importArticlesFromJSON() async throws
    func importArticlesFromPDFs()
    func initializeSampleData()
    
    // 统计信息
    func getArticleStats() -> ArticleStats
    func getAvailableYears() -> [Int]
    func getAvailableTopics() -> [String]
    func getAvailableExamTypes() -> [String]
    func getReadingStatistics() async throws -> ReadingStatistics
}

// MARK: - Dictionary Service Protocol

protocol DictionaryServiceProtocol {
    // 词典查询
    func lookupWord(_ word: String) async throws -> UserWord
    func lookupWord(_ word: String, context: String) -> DictionaryWord?
    func searchWords(_ query: String) -> [DictionaryWord]
    func addUnknownWord(_ word: UserWord) async throws
    func addWord(_ word: UserWord) async throws
    
    // 用户词汇记录
    func recordWordLookup(word: String, context: String, sentence: String, article: Article) -> UserWord
    func getUserWordRecords() -> [UserWord]
    func getWordsByMastery(_ mastery: MasteryLevel) -> [UserWord]
    func getWordsForReview() -> [UserWord]
    
    // 词汇管理
    func updateWordMastery(_ record: UserWord, level: MasteryLevel)
    func updateMasteryLevel(_ record: UserWord, level: MasteryLevel)
    func markForReview(_ record: UserWord)
    func addNote(_ record: UserWord, note: String)
    func toggleReviewFlag(for record: UserWord)
    func deleteWordRecord(_ record: UserWord)
    func clearAllRecords()
    
    // 统计信息
    func getVocabularyStats() -> VocabularyStats
    
    // 数据初始化
    func initializeDictionary() async throws
}

// MARK: - User Progress Service Protocol

protocol UserProgressServiceProtocol {
    // 进度记录
    func addReadingTime(_ time: Double)
    func addWordLookup()
    func addExperience(_ points: Int, for activity: ExperienceAction)
    func incrementArticleRead()
    func completeReview()
    func recordWordReview(word: String, correct: Bool) async throws
    func recordReviewSession(wordsReviewed: Int, correctAnswers: Int) async throws
    func recordArticleCompletion(articleId: String, readingTime: TimeInterval, wordsLookedUp: Int) async throws
    func updateReadingProgress(articleId: String, progress: Double, readingTime: TimeInterval) async throws
    func recordWordLookup(word: String, articleId: String) async throws
    func addBookmark(articleId: String) async throws
    func removeBookmark(articleId: String) async throws
    func isBookmarked(articleId: String) async throws -> Bool
    func markArticleAsCompleted(articleId: String) async throws
    func isCompleted(articleId: String) async throws -> Bool
    
    // 进度查询
    func getUserProgress() -> UserProgress?
    func getTodayRecord() -> DailyStudyRecord?
    func getReadingTrend(days: Int) -> [DailyStudyRecord]
    func getWeeklyComparison() -> WeeklyComparison
    func getStudyStatistics() -> StudyStatistics
    
    // 统计数据方法
    func getTodayStatistics() async throws -> TodayStatistics
    func getWeeklyStatistics() async throws -> WeeklyStatistics
    func getMonthlyStatistics() async throws -> MonthlyStatistics
    func getOverallStatistics() async throws -> OverallStatistics
    func getVocabularyProgressStatistics() async throws -> VocabularyProgressStats
    func getVocabularyStatistics() async throws -> VocabularyStatistics
    func getAchievementStatistics() async throws -> AchievementStatistics
    func getReadingTimeChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint]
    func getVocabularyChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint]
    func getProgressChartData(for timeRange: TimeRange) async throws -> [ChartDataPoint]
    
    // 目标和等级
    func getCurrentLevel() -> UserLevel
    func getLevelProgress() -> Double
    func getExperienceToNextLevel() -> Int
    func getGoalProgress() -> GoalProgress
    func getConsecutiveDays() -> Int
    
    // 成就系统
    func getUnlockedAchievements() -> [Achievement]
    func getAvailableAchievements() -> [AchievementType]
    
    // 学习建议
    func getStudyRecommendations() -> [StudyRecommendation]
    
    // 数据管理
    func exportProgressData() -> Data?
    func importProgressData(_ data: Data) -> Bool
    func resetProgress()
    
    // 设置管理
    func getUserSettings() async throws -> UserSettings
    func getReadingSettings() async throws -> ReadingSettings
    func getVocabularySettings() async throws -> VocabularySettings
    func getNotificationSettings() async throws -> NotificationSettings
    func getPrivacySettings() async throws -> PrivacySettings
    func getAppearanceSettings() async throws -> AppearanceSettings
    
    func updateUserSettings(_ settings: UserSettings) async throws
    func updateReadingSettings(_ settings: ReadingSettings) async throws
    func updateVocabularySettings(_ settings: VocabularySettings) async throws
    func updateNotificationSettings(_ settings: NotificationSettings) async throws
    func updatePrivacySettings(_ settings: PrivacySettings) async throws
    func updateAppearanceSettings(_ settings: AppearanceSettings) async throws
    
    // 数据重置
    func resetAllData() async throws
}

// MARK: - PDF Service Protocol

protocol PDFServiceProtocol {
    // PDF文本提取
    func extractText(from url: URL) -> String?
    
    // PDF转换为文章
    func convertPDFToArticle(from url: URL) -> Article?
    
    // 批量处理
    func convertPDFsToArticles(from urls: [URL]) -> [Article]
    
    // PDF信息解析
    func parsePDFMetadata(from url: URL) -> PDFMetadata?
}

// MARK: - Text Processor Protocol

protocol TextProcessorProtocol {
    // 文本清理
    func cleanWord(_ word: String) -> String
    func cleanText(_ text: String) -> String
    
    // 文本分词
    func tokenize(_ text: String) -> [String]
    func tokenizeText(_ text: String) -> [String]
    func extractWords(_ text: String) -> [String]
    
    // 关键词提取
    func extractKeywords(from text: String, limit: Int) -> [String]
    
    // 词形还原
    func stemWord(_ word: String) -> String
    
    // 相似度计算
    func calculateSimilarity(_ string1: String, _ string2: String) -> Double
    
    // 句子分析
    func splitIntoSentences(_ text: String) -> [String]
    func getWordContext(_ word: String, in text: String, contextLength: Int) -> String
    func getSentenceContaining(_ word: String, in text: String) -> String?
    func extractSentence(containing word: String, from text: String) -> String?
    
    // 词性标注
    func getPartOfSpeech(_ word: String) -> PartOfSpeech?
    
    // 文本统计
    func calculateReadingDifficulty(_ text: String) -> Double
    func calculateVocabularyDensity(_ text: String) -> Double
    func getTextStatistics(_ text: String) -> TextStatistics
}

// MARK: - Cache Manager Protocol

protocol CacheManagerProtocol {
    // 缓存操作
    func get<T: Codable>(_ key: String, type: T.Type) -> T?
    func set<T: Codable>(_ key: String, value: T, expiration: TimeInterval?)
    func invalidate(_ key: String)
    func invalidateAll()
    func clearAll()
    
    // 缓存管理
    func clearExpiredItems()
    func getCacheSize() -> Int
    func getCacheInfo() -> CacheInfo
    func remove(_ key: String)
    func removeByPrefix(_ prefix: String)
}

// MARK: - Error Handler Protocol

protocol ErrorHandlerProtocol {
    // 错误处理
    func handle(_ error: Error, context: String)
    func handle(_ appError: AppError)
    func logSuccess(_ message: String)
    
    // 错误状态
    var currentError: AppError? { get }
    var isShowingError: Bool { get }
    
    // 错误清除
    func dismissError()
    func clearAllErrors()
}

// MARK: - Supporting Types

/// PDF元数据信息
struct PDFMetadata {
    let fileName: String
    let year: Int?
    let examType: ExamType?
    let title: String
    let pageCount: Int?
    let fileSize: Int64?
    let creationDate: Date?
    let modificationDate: Date?
}

/// 缓存信息
struct CacheInfo {
    let itemCount: Int
    let totalSize: Int
    let hitRate: Double
    let missRate: Double
}



// AppError 定义已移至 ErrorHandler.swift 中，避免重复定义