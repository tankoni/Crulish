//
//  AppViewModel.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Data Type Enum

enum DataType: String, CaseIterable {
    case vocabulary = "vocabulary"
    case progress = "progress"
    case articles = "articles"
    case settings = "settings"
    
    var displayName: String {
        switch self {
        case .vocabulary:
            return "词汇数据"
        case .progress:
            return "学习进度"
        case .articles:
            return "文章数据"
        case .settings:
            return "应用设置"
        }
    }
    
    var description: String {
        switch self {
        case .vocabulary:
            return "个人词汇记录和掌握程度"
        case .progress:
            return "学习统计和成就记录"
        case .articles:
            return "文章阅读进度和笔记"
        case .settings:
            return "个人偏好设置"
        }
    }
}

@Observable
class AppViewModel {
    // MARK: - Services
    var articleService: ArticleService
    var dictionaryService: DictionaryService
    var userProgressService: UserProgressService
    var textProcessor: TextProcessor
    var settings: AppSettings
    
    // MARK: - State
    var selectedTab: TabSelection = .home
    var currentArticle: Article?
    var selectedWord: DictionaryWord?
    var selectedUserWordRecord: UserWordRecord?
    var isShowingWordDetail = false
    var isShowingSettings = false
    var isShowingProgress = false
    
    // MARK: - Reading State
    var readingProgress: Double = 0.0
    var isReading = false
    var readingStartTime: Date?
    var highlightedWord: String?
    var selectedSentence: String?
    var isShowingTranslation = false
    
    // MARK: - Search State
    var searchText = ""
    var searchResults: [Article] = []
    var isSearching = false
    
    // MARK: - Error Handling
    var errorMessage: String?
    var isShowingError = false
    
    init() {
        self.articleService = ArticleService()
        self.dictionaryService = DictionaryService()
        self.userProgressService = UserProgressService()
        self.textProcessor = TextProcessor()
        self.settings = AppSettings()
    }
    
    // MARK: - Initialization
    
    func setModelContext(_ context: ModelContext) {
        articleService.setModelContext(context)
        dictionaryService.setModelContext(context)
        userProgressService.setModelContext(context)
        
        // 初始化示例数据
        Task {
            await initializeData()
        }
    }
    
    @MainActor
    private func initializeData() async {
        // 初始化文章数据
        articleService.initializeSampleData()
        
        // 初始化词典数据
        dictionaryService.initializeSampleDictionary()
    }
    
    // MARK: - Tab Navigation
    
    func selectTab(_ tab: TabSelection) {
        selectedTab = tab
    }
    
    // MARK: - Article Management
    
    func loadArticles() -> [Article] {
        return articleService.getAllArticles()
    }
    
    func getArticlesByYear(_ year: Int) -> [Article] {
        return articleService.getArticlesByYear(year)
    }
    
    func getArticlesByDifficulty(_ difficulty: ArticleDifficulty) -> [Article] {
        return articleService.getArticlesByDifficulty(difficulty)
    }
    
    func getRecentArticles() -> [Article] {
        return articleService.getRecentlyReadArticles()
    }
    
    func getRecommendedArticles() -> [Article] {
        return articleService.getRecommendedArticles()
    }
    
    func searchArticles(_ query: String) {
        isSearching = true
        searchText = query
        
        if query.isEmpty {
            searchResults = []
        } else {
            searchResults = articleService.searchArticles(query: query)
        }
        
        isSearching = false
    }
    
    // MARK: - Reading Management
    
    func startReading(_ article: Article) {
        currentArticle = article
        isReading = true
        readingStartTime = Date()
        readingProgress = article.readingProgress
        selectedTab = .reading
    }
    
    func pauseReading() {
        guard let startTime = readingStartTime else { return }
        
        let readingTime = Date().timeIntervalSince(startTime) / 60.0 // 转换为分钟
        userProgressService.addReadingTime(readingTime)
        
        readingStartTime = nil
    }
    
    func resumeReading() {
        readingStartTime = Date()
    }
    
    func stopReading() {
        guard let article = currentArticle else { return }
        
        // 记录阅读时间
        if let startTime = readingStartTime {
            let readingTime = Date().timeIntervalSince(startTime) / 60.0
            userProgressService.addReadingTime(readingTime)
            articleService.addReadingTime(to: article, time: readingTime)
        }
        
        // 重置状态
        isReading = false
        readingStartTime = nil
        currentArticle = nil
        selectedTab = .home
    }
    
    func addReadingTime(_ minutes: Double) {
        userProgressService.addReadingTime(minutes)
    }
    
    func addUnknownWord(_ word: String) {
        guard let article = currentArticle else { return }
        
        let cleanWord = textProcessor.cleanWord(word)
        let wordRecord = dictionaryService.recordWordLookup(
            word: cleanWord,
            context: "",
            sentence: "",
            article: article
        )
        
        // 标记为生词
        if let record = wordRecord {
            dictionaryService.updateWordMastery(record, level: .unfamiliar)
        }
        
        // 更新统计
        userProgressService.addWordLookup()
        userProgressService.addExperience(5, for: .lookupWord)
    }
    
    // MARK: - Bookmark Management
    
    func toggleBookmark(_ article: Article) {
        // Toggle bookmark status
        article.isBookmarked.toggle()
        
        // Save changes
        articleService.updateArticle(article)
        
        // Update statistics if bookmarked
        if article.isBookmarked {
            userProgressService.addExperience(2, for: .bookmarkArticle)
        }
    }
    
    func markAsCompleted(_ article: Article) {
        articleService.markArticleAsCompleted(article)
        userProgressService.incrementArticleRead()
        userProgressService.addExperience(10, for: .readArticle)
    }
    
    func shareArticle(_ article: Article) {
        // Implementation for sharing article
        // This could involve creating a share sheet or copying to clipboard
    }
    
    // MARK: - Word Lookup Methods
    
    func lookupWord(_ word: String) async -> [DictionaryWord] {
        let cleanWord = textProcessor.cleanWord(word)
        
        // Look up word in dictionary
        if let dictionaryWord = dictionaryService.lookupWord(cleanWord, context: "") {
            return [dictionaryWord]
        }
        
        return []
    }
    
    func recordWordLookup(word: String, definition: WordDefinition, context: String?) {
        guard let article = currentArticle else { return }
        
        _ = dictionaryService.recordWordLookup(
            word: word,
            context: context ?? "",
            sentence: "",
            article: article
        )
        
        // Update statistics
        userProgressService.addWordLookup()
        userProgressService.addExperience(3, for: .lookupWord)
    }
    
    var currentReadingContext: String? {
        return currentArticle?.title
    }
    
    func finishReading() {
        guard let article = currentArticle else { return }
        
        // 记录阅读时间
        if let startTime = readingStartTime {
            let readingTime = Date().timeIntervalSince(startTime) / 60.0
            userProgressService.addReadingTime(readingTime)
            articleService.addReadingTime(to: article, time: readingTime)
        }
        
        // 标记文章为已完成
        if readingProgress >= 1.0 {
            articleService.markArticleAsCompleted(article)
            userProgressService.incrementArticleRead()
            userProgressService.addExperience(0, for: .readArticle)
        }
        
        // 更新阅读进度
        articleService.updateArticleProgress(article, progress: readingProgress)
        
        // 重置状态
        isReading = false
        readingStartTime = nil
        currentArticle = nil
        selectedTab = .home
    }
    
    func updateReadingProgress(_ progress: Double) {
        readingProgress = progress
        
        if let article = currentArticle {
            articleService.updateArticleProgress(article, progress: progress)
        }
    }
    
    // MARK: - Word Lookup
    
    func lookupWord(_ word: String, in context: String) {
        let cleanWord = textProcessor.cleanWord(word)
        
        // 查找词典中的单词
        if let dictionaryWord = dictionaryService.lookupWord(cleanWord, context: context) {
            selectedWord = dictionaryWord
            
            // 记录查词行为
            if let article = currentArticle {
                let sentence = textProcessor.getSentenceContaining(cleanWord, in: context) ?? context
                let wordRecord = dictionaryService.recordWordLookup(
                    word: cleanWord,
                    context: context,
                    sentence: sentence,
                    article: article
                )
                selectedUserWordRecord = wordRecord
            }
            
            // 更新统计
            userProgressService.addWordLookup()
            userProgressService.addExperience(0, for: .lookupWord)
            
            // 高亮显示单词
            highlightedWord = cleanWord
            
            // 显示单词详情
            isShowingWordDetail = true
        } else {
            showError("未找到单词: \(cleanWord)")
        }
    }
    
    func selectSentence(_ sentence: String) {
        selectedSentence = sentence
        isShowingTranslation = true
    }
    
    func dismissWordDetail() {
        isShowingWordDetail = false
        selectedWord = nil
        selectedUserWordRecord = nil
        highlightedWord = nil
    }
    
    func dismissTranslation() {
        isShowingTranslation = false
        selectedSentence = nil
    }
    
    // MARK: - Vocabulary Management
    
    func getPersonalVocabulary() -> [UserWordRecord] {
        return dictionaryService.getUserWordRecords()
    }
    
    func getVocabularyByMastery(_ mastery: MasteryLevel) -> [UserWordRecord] {
        return dictionaryService.getWordsByMastery(mastery)
    }
    
    func getWordsForReview() -> [UserWordRecord] {
        return dictionaryService.getWordsForReview()
    }
    
    func updateWordMastery(_ record: UserWordRecord, mastery: MasteryLevel) {
        dictionaryService.updateWordMastery(record, level: mastery)
        
        if mastery == .mastered {
            userProgressService.completeReview()
            userProgressService.addExperience(0, for: .completeReview)
        }
    }
    
    func markWordForReview(_ record: UserWordRecord) {
        dictionaryService.markForReview(record)
    }
    
    func addWordNote(_ record: UserWordRecord, note: String) {
        dictionaryService.addNote(record, note: note)
    }
    
    // MARK: - Statistics
    
    func getStudyStatistics() -> StudyStatistics {
        return userProgressService.getStudyStatistics()
    }
    
    func getArticleStatistics() -> ArticleStats {
        return articleService.getArticleStats()
    }
    
    func getVocabularyStatistics() -> VocabularyStats {
        return dictionaryService.getVocabularyStats()
    }
    
    func getUserWordRecords() -> [UserWordRecord] {
        return dictionaryService.getUserWordRecords()
    }
    
    func getVocabularyStats() -> VocabularyStats {
        return dictionaryService.getVocabularyStats()
    }
    
    func startWordReview(_ wordRecord: UserWordRecord) {
        selectedUserWordRecord = wordRecord
        // 可以在这里添加开始单词复习的逻辑
    }
    
    func startVocabularyReview() {
        // 开始词汇复习的逻辑
        let reviewWords = getWordsForReview()
        if !reviewWords.isEmpty {
            selectedUserWordRecord = reviewWords.first
        }
    }
    
    func exportVocabulary() {
        // 导出词汇的逻辑
        // 这里可以实现导出功能
    }
    
    func showWordDetail(_ wordRecord: UserWordRecord) {
        selectedUserWordRecord = wordRecord
        isShowingWordDetail = true
    }
    
    func toggleReviewFlag(for wordRecord: UserWordRecord) {
        dictionaryService.toggleReviewFlag(for: wordRecord)
    }
    
    func deleteWordRecord(_ wordRecord: UserWordRecord) {
        dictionaryService.deleteWordRecord(wordRecord)
    }
    
    func showAllReviewWords() {
        // 显示所有复习单词的逻辑
        // 可以导航到复习页面或显示完整列表
    }
    
    func getWeeklyComparison() -> WeeklyComparison {
        return userProgressService.getWeeklyComparison()
    }
    
    func getReadingTrend(days: Int = 7) -> [DailyStudyRecord] {
        return userProgressService.getReadingTrend(days: days)
    }
    
    // MARK: - Achievements
    
    func getUnlockedAchievements() -> [Achievement] {
        return userProgressService.getUnlockedAchievements()
    }
    
    func getAvailableAchievements() -> [AchievementType] {
        return userProgressService.getAvailableAchievements()
    }
    
    // MARK: - Settings
    
    func showSettings() {
        isShowingSettings = true
    }
    
    func dismissSettings() {
        isShowingSettings = false
    }
    
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        settings.saveSettings()
    }
    
    // MARK: - Progress
    
    func showProgress() {
        isShowingProgress = true
    }
    
    func dismissProgress() {
        isShowingProgress = false
    }
    
    func exportProgress() {
        // 导出用户进度数据
        if userProgressService.exportProgressData() != nil {
            // TODO: 实现文件保存或分享功能
            print("Progress data exported successfully")
        }
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
    
    func dismissError() {
        isShowingError = false
        errorMessage = nil
    }
    
    // MARK: - Data Management
    
    func exportData(types: Set<DataType>) async -> Bool {
        // TODO: 实现数据导出
        return true
    }
    
    func importData() async -> Result<Void, Error> {
        // TODO: 实现数据导入
        return .success(())
    }
    
    func clearCache() {
        // TODO: 实现清除缓存
    }
    
    func resetAllData() {
        // 重置用户进度
        userProgressService.resetProgress()
        
        // 清除所有文章的阅读记录
        for article in articleService.getAllArticles() {
            article.isCompleted = false
            article.readingTime = 0
            article.lastReadDate = nil
            article.readingProgress = 0.0
        }
        
        // 清除所有词汇记录
        dictionaryService.clearAllRecords()
        
        // 重置设置为默认值
        settings = AppSettings()
    }
    
    func resetProgress() {
        userProgressService.resetProgress()
    }
    
    func getTodayReadingTime() -> Double {
        let todayRecord = userProgressService.getTodayRecord()
        return todayRecord?.readingTime ?? 0
    }
    
    func getTodayWordLookups() -> Int {
        let todayRecord = userProgressService.getTodayRecord()
        return todayRecord?.wordsLookedUp ?? 0
    }
    
    func getTodayCompletedArticles() -> Int {
        let todayRecord = userProgressService.getTodayRecord()
        return todayRecord?.articlesRead ?? 0
    }
    
    func getTodayReviewedWords() -> Int {
        let todayRecord = userProgressService.getTodayRecord()
        return todayRecord?.reviewsCompleted ?? 0
    }
    
    func getUserProgress() -> UserProgress? {
        return userProgressService.getUserProgress()
    }
    
    func getWeeklyStats() -> WeeklyComparison {
        return userProgressService.getWeeklyComparison()
    }
    
    func getMonthlyStats() -> WeeklyComparison {
        // For now, return weekly stats as monthly stats placeholder
        return userProgressService.getWeeklyComparison()
    }
    
    func getRecentAchievements() -> [Achievement] {
        return userProgressService.getUnlockedAchievements()
    }
    
    func openFeedback() {
        // TODO: 打开反馈页面
        if let url = URL(string: "mailto:feedback@example.com") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    func rateApp() {
        // TODO: 打开应用商店评分
        if let url = URL(string: "https://apps.apple.com/app/id123456789") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    func openPrivacyPolicy() {
        // TODO: 打开隐私政策
        if let url = URL(string: "https://example.com/privacy") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    func exportUserData() -> Data? {
         return userProgressService.exportProgressData()
     }
     
     func importUserData(_ data: Data) -> Bool {
         return userProgressService.importProgressData(data)
     }
    
    // MARK: - Recommendations
    
    func getStudyRecommendations() -> [StudyRecommendation] {
        return userProgressService.getStudyRecommendations()
    }
    
    func getGoalProgress() -> GoalProgress {
        return userProgressService.getGoalProgress()
    }
}

// MARK: - Tab Selection

enum TabSelection: String, CaseIterable {
    case home = "home"
    case reading = "reading"
    case vocabulary = "vocabulary"
    case progress = "progress"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .home:
            return "首页"
        case .reading:
            return "阅读"
        case .vocabulary:
            return "词汇"
        case .progress:
            return "进度"
        case .settings:
            return "设置"
        }
    }
    
    var iconName: String {
        switch self {
        case .home:
            return "house"
        case .reading:
            return "book"
        case .vocabulary:
            return "text.book.closed"
        case .progress:
            return "chart.bar"
        case .settings:
            return "gear"
        }
    }
}

// MARK: - Extensions

extension AppViewModel {
    // 获取当前用户等级信息
    func getCurrentLevelInfo() -> (level: UserLevel, progress: Double, experienceToNext: Int) {
        let level = userProgressService.getCurrentLevel()
        let progress = userProgressService.getLevelProgress()
        let experienceToNext = userProgressService.getExperienceToNextLevel()
        
        return (level, progress, experienceToNext)
    }
    
    // 获取今日学习摘要
    func getTodaySummary() -> TodaySummary {
        let todayRecord = userProgressService.getTodayRecord()
        let goalProgress = getGoalProgress()
        
        return TodaySummary(
            readingTime: todayRecord?.readingTime ?? 0,
            articlesRead: todayRecord?.articlesRead ?? 0,
            wordsLookedUp: todayRecord?.wordsLookedUp ?? 0,
            reviewsCompleted: todayRecord?.reviewsCompleted ?? 0,
            dailyReadingGoalProgress: goalProgress.dailyReadingProgress,
            consecutiveDays: userProgressService.getConsecutiveDays()
        )
    }
    
    // 检查是否有待复习的单词
    func hasWordsToReview() -> Bool {
        return !getWordsForReview().isEmpty
    }
    
    // 获取推荐的下一篇文章
    func getNextRecommendedArticle() -> Article? {
        let recommended = getRecommendedArticles()
        return recommended.first
    }
    
    // 获取学习连续天数状态
    func getStreakStatus() -> StreakStatus {
        let consecutiveDays = userProgressService.getConsecutiveDays()
        let todayRecord = userProgressService.getTodayRecord()
        let hasStudiedToday = (todayRecord?.readingTime ?? 0) > 0
        
        return StreakStatus(
            consecutiveDays: consecutiveDays,
            hasStudiedToday: hasStudiedToday,
            isAtRisk: !hasStudiedToday && consecutiveDays > 0
        )
    }
}

// MARK: - Helper Structures

// 今日学习摘要
struct TodaySummary {
    let readingTime: Double
    let articlesRead: Int
    let wordsLookedUp: Int
    let reviewsCompleted: Int
    let dailyReadingGoalProgress: Double
    let consecutiveDays: Int
    
    var formattedReadingTime: String {
        let minutes = Int(readingTime)
        return "\(minutes)分钟"
    }
    
    var isGoalAchieved: Bool {
        return dailyReadingGoalProgress >= 1.0
    }
}

// 连续学习状态
struct StreakStatus {
    let consecutiveDays: Int
    let hasStudiedToday: Bool
    let isAtRisk: Bool
    
    var statusMessage: String {
        if hasStudiedToday {
            return "今日已学习 · 连续\(consecutiveDays)天"
        } else if isAtRisk {
            return "连续记录面临中断 · \(consecutiveDays)天"
        } else {
            return "开始今日学习"
        }
    }
    
    var statusColor: Color {
        if hasStudiedToday {
            return .green
        } else if isAtRisk {
            return .orange
        } else {
            return .blue
        }
    }
}