//
//  MockServices.swift
//  en01Tests
//
//  Created by Assistant on 2024-12-19.
//

import Foundation
import SwiftData
@testable import en01

// MARK: - Mock ArticleService
class MockArticleService: ArticleServiceProtocol {
    private var articles: [Article] = [
        Article(
            id: "test-1",
            title: "Test Article 1",
            content: "This is test content for article 1",
            year: 2023,
            examType: .english1,
            difficulty: .medium,
            wordCount: 150,
            estimatedReadingTime: 8
        ),
        Article(
            id: "test-2",
            title: "Sample Article 2",
            content: "This is test content for article 2",
            year: 2023,
            examType: .english2,
            difficulty: .hard,
            wordCount: 200,
            estimatedReadingTime: 10
        )
    ]
    
    func getArticles() async throws -> [Article] {
        return articles
    }
    
    func getArticles(year: Int) async throws -> [Article] {
        return articles.filter { $0.year == year }
    }
    
    func getArticles(examType: ExamType) async throws -> [Article] {
        return articles.filter { $0.examType == examType }
    }
    
    func getArticles(difficulty: Difficulty) async throws -> [Article] {
        return articles.filter { $0.difficulty == difficulty }
    }
    
    func getArticle(id: String) async throws -> Article? {
        return articles.first { $0.id == id }
    }
    
    func searchArticles(query: String) async throws -> [Article] {
        return articles.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
    
    func getRecommendedArticles(limit: Int) async throws -> [Article] {
        return Array(articles.prefix(limit))
    }
    
    func getRecentArticles(limit: Int) async throws -> [Article] {
        return Array(articles.suffix(limit))
    }
}

// MARK: - Mock DictionaryService
class MockDictionaryService: DictionaryServiceProtocol {
    private var vocabulary: [Word] = [
        Word(
            word: "test",
            definitions: ["A procedure intended to establish the quality, performance, or reliability of something"],
            pronunciation: "/test/",
            partOfSpeech: "noun",
            examples: ["This is a test sentence"],
            difficulty: .medium,
            frequency: 0.8,
            mastery: .learning,
            dateAdded: Date(),
            lastReviewed: nil,
            reviewCount: 0,
            correctCount: 0,
            tags: ["academic"]
        ),
        Word(
            word: "example",
            definitions: ["A thing characteristic of its kind or illustrating a general rule"],
            pronunciation: "/ɪɡˈzæmpəl/",
            partOfSpeech: "noun",
            examples: ["For example, this is a sample sentence"],
            difficulty: .easy,
            frequency: 0.9,
            mastery: .mastered,
            dateAdded: Date().addingTimeInterval(-86400),
            lastReviewed: Date(),
            reviewCount: 5,
            correctCount: 4,
            tags: ["common"]
        )
    ]
    
    func lookupWord(_ word: String) async throws -> Word? {
        return vocabulary.first { $0.word.lowercased() == word.lowercased() }
    }
    
    func getUserVocabulary() async throws -> [Word] {
        return vocabulary
    }
    
    func addWord(_ word: Word) async throws {
        vocabulary.append(word)
    }
    
    func updateWord(_ word: Word) async throws {
        if let index = vocabulary.firstIndex(where: { $0.word == word.word }) {
            vocabulary[index] = word
        }
    }
    
    func deleteWord(_ word: String) async throws {
        vocabulary.removeAll { $0.word == word }
    }
    
    func getWordsForReview() async throws -> [Word] {
        return vocabulary.filter { $0.mastery != .mastered }
    }
    
    func updateWordMastery(_ word: String, mastery: WordMastery) async throws {
        if let index = vocabulary.firstIndex(where: { $0.word == word }) {
            vocabulary[index].mastery = mastery
        }
    }
    
    func recordWordLookup(_ word: String) async throws {
        // Mock implementation
    }
    
    func getVocabularyStatistics() async throws -> VocabularyStatistics {
        return VocabularyStatistics(
            totalWords: vocabulary.count,
            masteredWords: vocabulary.filter { $0.mastery == .mastered }.count,
            learningWords: vocabulary.filter { $0.mastery == .learning }.count,
            unfamiliarWords: vocabulary.filter { $0.mastery == .unfamiliar }.count,
            averageAccuracy: 0.8,
            streakDays: 5,
            wordsThisWeek: 10,
            reviewsToday: 3
        )
    }
    
    func updateMasteryLevel(word: String, level: MasteryLevel) async throws {
        // Mock implementation
    }
}

// MARK: - Mock UserProgressService
class MockUserProgressService: UserProgressServiceProtocol {
    private var userProgress = UserProgress(
        totalReadingTime: 3600,
        articlesRead: 5,
        wordsLearned: 50,
        currentStreak: 7,
        longestStreak: 15,
        lastActiveDate: Date(),
        level: 3,
        experience: 750,
        achievements: []
    )
    
    func getUserProgress() async throws -> UserProgress? {
        return userProgress
    }
    
    func updateReadingTime(duration: TimeInterval) async throws {
        userProgress.totalReadingTime += duration
    }
    
    func markArticleAsCompleted(articleId: String) async throws {
        userProgress.articlesRead += 1
    }
    
    func addWordToVocabulary(word: String) async throws {
        userProgress.wordsLearned += 1
    }
    
    func updateStreak() async throws {
        userProgress.currentStreak += 1
        if userProgress.currentStreak > userProgress.longestStreak {
            userProgress.longestStreak = userProgress.currentStreak
        }
    }
    
    func getTodayStatistics() async throws -> TodayStatistics {
        return TodayStatistics(
            readingTime: 1800,
            articlesRead: 2,
            wordsLearned: 15,
            vocabularyReviewed: 10,
            streakDays: userProgress.currentStreak,
            goalProgress: 0.6
        )
    }
    
    func getWeeklyStatistics() async throws -> WeeklyStatistics {
        return WeeklyStatistics(
            totalReadingTime: 7200,
            articlesCompleted: 8,
            newWordsLearned: 45,
            vocabularyReviews: 60,
            averageDailyTime: 1028,
            mostProductiveDay: "Monday",
            weeklyGoalProgress: 0.8
        )
    }
    
    func getMonthlyStatistics() async throws -> MonthlyStatistics {
        return MonthlyStatistics(
            totalReadingTime: 28800,
            articlesCompleted: 25,
            newWordsLearned: 150,
            vocabularyReviews: 200,
            averageDailyTime: 960,
            bestWeek: "Week 2",
            monthlyGoalProgress: 0.75
        )
    }
    
    func getOverallStatistics() async throws -> OverallStatistics {
        return OverallStatistics(
            totalReadingTime: userProgress.totalReadingTime,
            totalArticles: userProgress.articlesRead,
            totalWords: userProgress.wordsLearned,
            currentLevel: userProgress.level,
            currentExperience: userProgress.experience,
            longestStreak: userProgress.longestStreak,
            averageAccuracy: 0.85,
            joinDate: Date().addingTimeInterval(-2592000) // 30 days ago
        )
    }
    
    func getReadingStatistics() async throws -> ReadingStatistics {
        return ReadingStatistics(
            totalTime: userProgress.totalReadingTime,
            averageSessionTime: 1200,
            articlesCompleted: userProgress.articlesRead,
            averageReadingSpeed: 250,
            favoriteTimeSlot: "Evening",
            comprehensionRate: 0.88
        )
    }
    
    func getVocabularyProgressStats() async throws -> VocabularyProgressStats {
        return VocabularyProgressStats(
            totalWords: userProgress.wordsLearned,
            masteredWords: 30,
            learningWords: 15,
            unfamiliarWords: 5,
            averageRetentionRate: 0.82,
            dailyReviewTarget: 20,
            weeklyNewWordTarget: 35
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
    
    func recordWordLookup(word: String, context: String) async throws {
        // Mock implementation
    }
    
    func updateReadingProgress(articleId: String, progress: Double) async throws {
        // Mock implementation
    }
    
    func recordWordReview(word: UserWord, correct: Bool) async throws {
        // Mock implementation
    }
    
    func recordReviewSession(wordsReviewed: Int, correctAnswers: Int) async throws {
        // Mock implementation
    }
}

// MARK: - Mock TextProcessor
class MockTextProcessor: TextProcessor {
    override func processText(_ text: String) -> [ProcessedSentence] {
        let sentences = text.components(separatedBy: ". ")
        return sentences.enumerated().map { index, sentence in
            ProcessedSentence(
                id: "sentence-\(index)",
                text: sentence,
                words: sentence.components(separatedBy: " ").map { word in
                    ProcessedWord(
                        text: word,
                        isComplexWord: word.count > 6,
                        difficulty: word.count > 8 ? .hard : .medium,
                        range: NSRange(location: 0, length: word.count)
                    )
                },
                difficulty: .medium,
                range: NSRange(location: 0, length: sentence.count)
            )
        }
    }
    
    override func highlightComplexWords(in text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let words = text.components(separatedBy: " ")
        
        var currentLocation = 0
        for word in words {
            if word.count > 6 {
                let range = NSRange(location: currentLocation, length: word.count)
                attributedString.addAttribute(.backgroundColor, value: UIColor.yellow.withAlphaComponent(0.3), range: range)
            }
            currentLocation += word.count + 1
        }
        
        return attributedString
    }
}

// MARK: - Mock ErrorHandler
class MockErrorHandler: ErrorHandlerProtocol {
    private var errors: [Error] = []
    
    func handle(_ error: Error, context: String) {
        errors.append(error)
        print("Mock Error in \(context): \(error.localizedDescription)")
    }
    
    func logSuccess(_ message: String) {
        print("Mock Success: \(message)")
    }
    
    func logWarning(_ message: String) {
        print("Mock Warning: \(message)")
    }
    
    func getLastError() -> Error? {
        return errors.last
    }
    
    func clearErrors() {
        errors.removeAll()
    }
}