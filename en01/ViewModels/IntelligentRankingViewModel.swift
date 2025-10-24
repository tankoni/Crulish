//
//  IntelligentRankingViewModel.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation
import SwiftUI
import Combine

@MainActor
class IntelligentRankingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var rankedArticles: [ArticleMatchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSortOption: RankingSortOption = .matchScore
    @Published var selectedReadingMode: ReadingMode = .yearlyExams
    @Published var isReverseSort: Bool = false
    
    // 新增：词典测试状态管理
    @Published var availableDictionaries: [DictionaryInfo] = []
    @Published var dictionaryTestStates: [DictionaryTestState] = []
    @Published var selectedDictionary: DictionaryInfo?
    @Published var showDictionarySelection = false
    @Published var showTestHistorySelection = false
    @Published var selectedTestState: DictionaryTestState?
    
    // 分阶段排序相关属性
    @Published var stagedRankingResults: StagedRankingResult?
    @Published var showStagedRanking = false
    @Published var currentStage: Int = 1
    
    // 新增：自适应推荐相关属性
    @Published var adaptiveRecommendations: [AdaptiveArticleRecommendation] = []
    @Published var isAdaptiveMode = false
    @Published var adaptiveWeight: Double = 0.7
    @Published var showAdaptiveInsights = false
    @Published var adaptiveWeights: AdaptiveWeights = .default
    @Published var adaptiveMode: AdaptiveMode = .balanced
    @Published var currentLearningInsights: LearningInsights?
    
    // MARK: - Dependencies
    private let rankingService: IntelligentRankingService
    private let articleService: ArticleServiceProtocol
    private let dictionaryService: DictionaryServiceProtocol
    private let userProgressService: UserProgressServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    private let soloArticleService: SoloArticleService
    
    // 新增：词汇量测试服务
    private let vocabularyTestService: VocabularyTestServiceProtocol
    
    // 新增：自适应学习服务
    private var adaptiveLearningService: AdaptiveLearningService?
    private var adaptiveRecommendationEngine: AdaptiveRecommendationEngine?
    
    private var cancellables = Set<AnyCancellable>()
    private var allRankedResults: [ArticleMatchResult] = []
    
    // 缓存相关
    private var lastRankingTimestamp: Date?
    private let rankingCacheValidityDuration: TimeInterval = 86400 // 24小时
    
    // 新增：自适应推荐缓存
    private var lastAdaptiveRecommendationTimestamp: Date?
    private let adaptiveCacheValidityDuration: TimeInterval = 3600 // 1小时
    
    // MARK: - Initialization
    init(
        articleService: ArticleServiceProtocol,
        dictionaryService: DictionaryServiceProtocol,
        userProgressService: UserProgressServiceProtocol,
        errorHandler: ErrorHandlerProtocol,
        soloArticleService: SoloArticleService,
        vocabularyTestService: VocabularyTestServiceProtocol
    ) {
        self.articleService = articleService
        self.dictionaryService = dictionaryService
        self.userProgressService = userProgressService
        self.errorHandler = errorHandler
        self.soloArticleService = soloArticleService
        self.vocabularyTestService = vocabularyTestService
        self.rankingService = IntelligentRankingService(
            dictionaryService: dictionaryService
        )
        
        setupNotificationListeners()
        setupAdaptiveLearning()
    }
    
    // 防抖机制相关属性
    private var isHandlingRankingUpdate = false
    private var lastRankingUpdateTime: Date?
    private let rankingUpdateDebounceInterval: TimeInterval = 2.0 // 2秒防抖
    private var lastProcessedTestId: String? // 记录最后处理的测试ID
    
    private func setupNotificationListeners() {
        // 监听词汇测试完成通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVocabularyTestCompleted),
            name: NSNotification.Name("VocabularyTestCompleted"),
            object: nil
        )
        
        // 监听词汇学习进度更新通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVocabularyProgressUpdate),
            name: NSNotification.Name("VocabularyProgressUpdate"),
            object: nil
        )
    }
    
    @objc private func handleVocabularyTestCompleted(_ notification: Notification) {
        // 防重复处理机制
        let now = Date()
        if isHandlingRankingUpdate {
            print("[DEBUG] 智能排序更新通知处理中，跳过重复处理")
            return
        }
        
        // 检查是否是同一个测试的重复通知
        if let testId = notification.userInfo?["testId"] as? String,
           let lastTestId = lastProcessedTestId,
           testId == lastTestId {
            print("[DEBUG] 智能排序已处理过测试ID \(testId)，跳过重复处理")
            return
        }
        
        if let lastTime = lastRankingUpdateTime,
           now.timeIntervalSince(lastTime) < rankingUpdateDebounceInterval {
            print("[DEBUG] 智能排序更新通知防抖，跳过处理")
            return
        }
        
        isHandlingRankingUpdate = true
        lastRankingUpdateTime = now
        
        // 记录处理的测试ID
        if let testId = notification.userInfo?["testId"] as? String {
            lastProcessedTestId = testId
        }
        
        print("[DEBUG] 收到词汇测试完成通知，刷新智能排序")
        
        Task {
            await self.refreshRanking()
            
            await MainActor.run {
                // 延迟重置标志，确保处理完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // 增加延迟时间
                    self.isHandlingRankingUpdate = false
                }
            }
        }
    }
    
    // 新增：设置自适应学习服务
    private func setupAdaptiveLearning() {
        // 从ServiceContainer获取自适应学习服务
        self.adaptiveLearningService = ServiceContainer.shared.getAdaptiveLearningService()
        
        // 从ServiceContainer获取自适应推荐引擎
        self.adaptiveRecommendationEngine = ServiceContainer.shared.getAdaptiveRecommendationEngine()
        
        // 配置推荐引擎到排序服务
        if let engine = adaptiveRecommendationEngine {
            rankingService.setAdaptiveRecommendationEngine(engine)
        }
    }
    
    // MARK: - Public Methods
    
    func loadRankedArticles() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let articles = try await loadArticles()
            let userVocabulary = loadUserVocabulary()
            
            // 检查是否选择了词典，如果选择了则使用基于词典的排序
            if let selectedDictionary = selectedDictionary {
                print("🎯 使用词典排序: \(selectedDictionary.name)")
                let results = await rankingService.rankArticlesByDictionary(
                    articles,
                    userVocabulary: userVocabulary,
                    dictionaryName: selectedDictionary.name
                )
                allRankedResults = results
            } else if isAdaptiveMode {
                // 使用混合推荐
                let results = try await rankingService.getHybridRecommendations(
                    articles: articles,
                    userVocabulary: userVocabulary,
                    adaptiveWeight: adaptiveWeight
                )
                allRankedResults = results
                
                // 同时获取纯自适应推荐用于展示洞察
                adaptiveRecommendations = try await rankingService.getAdaptiveRecommendations(
                    articles: articles,
                    userVocabulary: userVocabulary
                )
                lastAdaptiveRecommendationTimestamp = Date()
            } else {
                // 使用传统推荐
                let results = await rankingService.rankArticles(articles, userVocabulary: userVocabulary)
                allRankedResults = results
            }
            
            sortArticles(by: selectedSortOption)
            lastRankingTimestamp = Date()
            
        } catch {
            errorMessage = "加载文章失败: \(error.localizedDescription)"
            errorHandler.handle(AppError.unknown(error), context: "IntelligentRankingViewModel.loadRankedArticles")
        }
        
        isLoading = false
    }
    
    // 新增：切换自适应模式
    func toggleAdaptiveMode() async {
        isAdaptiveMode.toggle()
        await loadRankedArticles()
    }
    
    // 新增：调整自适应权重
    func updateAdaptiveWeight(_ weight: Double) async {
        adaptiveWeight = max(0.0, min(1.0, weight))
        if isAdaptiveMode {
            await loadRankedArticles()
        }
    }
    
    // 新增：获取自适应学习洞察
    func getAdaptiveLearningInsights() async -> LearningInsights? {
        guard let adaptiveService = adaptiveLearningService else { return nil }
        
        do {
            let analysis = try await adaptiveService.performLearningAnalysis(userId: "default")
            
            // 将分析结果转换为LearningInsights
            let insights = LearningInsights(
                learningPattern: .balanced,
                recommendationConfidence: analysis.difficultyPreference.confidenceLevel,
                adaptabilityScore: analysis.learningEfficiency.overallEfficiency * 10,
                vocabularyTrend: .stable,
                readingSpeedTrend: .stable,
                comprehensionTrend: .stable,
                vocabularyMasteryRate: Int(analysis.vocabularyLearning.masteryRate * 100),
                averageReadingSpeed: Int(analysis.readingPatterns.averageReadingSpeed),
                comprehensionAccuracy: 85,
                recommendationReasons: analysis.recommendedAdjustments.prefix(3).map { $0.description },
                learningRecommendations: analysis.learningEfficiency.optimizationSuggestions.prefix(2).map { $0.description }
            )
            
            return insights
        } catch {
            errorHandler.handle(AppError.unknown(error), context: "IntelligentRankingViewModel.getAdaptiveLearningInsights")
            return nil
        }
    }
    
    // 新增：获取推荐理由
    func getRecommendationReason(for result: ArticleMatchResult) -> String? {
        guard let recommendation = adaptiveRecommendations.first(where: { $0.article.id == result.article.id }) else {
            return nil
        }
        // 返回第一个推荐理由的描述，如果没有则返回nil
        return recommendation.recommendationReasons.first?.description
    }
    
    // 新增：记录文章交互
    func recordArticleInteraction(_ interaction: ArticleInteraction) async {
        guard let adaptiveService = adaptiveLearningService else { return }
        
        do {
            try await adaptiveService.recordLearningBehavior(
                userId: "default",
                behavior: LearningBehavior(
                    timestamp: Date(),
                    behaviorType: LearningBehaviorType.articleRead,
                    context: ["articleId": interaction.articleId.uuidString],
                    outcome: interaction.completed ? LearningOutcome.success : LearningOutcome.partial,
                    duration: interaction.duration
                )
            )
        } catch {
            errorHandler.handle(AppError.unknown(error), context: "IntelligentRankingViewModel.recordArticleInteraction")
        }
    }
    
    /// 切换阅读模式
    func switchReadingMode(to mode: ReadingMode) async {
        selectedReadingMode = mode
        await loadRankedArticles()
    }
    
    func getRankingStatistics() -> RankingStatistics {
        let totalArticles = allRankedResults.count
        let averageScore = allRankedResults.isEmpty ? 0.0 : 
            allRankedResults.map { $0.matchScore }.reduce(0, +) / Double(totalArticles)
        
        var difficultyDistribution: [IntelligentRankingDifficultyLevel: Int] = [:]
        var recommendationDistribution: [RecommendationLevel: Int] = [:]
        
        for result in allRankedResults {
            difficultyDistribution[result.difficulty, default: 0] += 1
            recommendationDistribution[result.recommendation, default: 0] += 1
        }
        
        return RankingStatistics(
            totalArticles: totalArticles,
            averageMatchScore: averageScore,
            difficultyDistribution: difficultyDistribution,
            recommendationDistribution: recommendationDistribution
        )
    }
    
    func getStatisticsForCurrentMode() -> (totalArticles: Int, averageMatchScore: Double, difficultyDistribution: [IntelligentRankingDifficultyLevel: Int]) {
        switch selectedReadingMode {
        case .yearlyExams:
            let stats = getRankingStatistics()
            return (stats.totalArticles, stats.averageMatchScore, stats.difficultyDistribution)
        case .soloArticles:
            return getSoloStatistics()
        }
    }
    
    /// 切换排序反向状态
    @MainActor
    func toggleSortReverse() {
        isReverseSort.toggle()
        // 重新应用当前排序选项
        sortArticles(by: selectedSortOption)
    }
    
    /// 按指定选项排序文章
    @MainActor
    func sortArticles(by option: RankingSortOption) {
        selectedSortOption = option
        var sortedResults = rankingService.sortResults(allRankedResults, by: option)
        
        // 如果启用了反向排序，则反转结果
        if isReverseSort {
            sortedResults.reverse()
        }
        
        rankedArticles = sortedResults
    }
    
    /// 按基础排序选项排序文章
    @MainActor
    func sortArticles(by basicOption: BasicSortOption) {
        let rankingOption = basicOption.toRankingSortOption()
        sortArticles(by: rankingOption)
    }
    
    /// 按关键词和基础选项组合排序文章
    @MainActor
    func sortArticlesWithKeywordAndBasic(keywordOption: KeywordSortOption, basicOption: BasicSortOption) {
        print("🔍 组合排序 - 关键词: \(keywordOption.rawValue), 基础: \(basicOption.rawValue)")
        
        // 先按关键词筛选文章
        let keywordFilteredArticles = filterArticlesByKeyword(allRankedResults, keyword: keywordOption)
        
        // 再按基础选项排序筛选后的文章
        let sortedArticles = sortArticlesByBasicOption(keywordFilteredArticles, option: basicOption)
        
        rankedArticles = sortedArticles
        selectedSortOption = keywordOption.toRankingSortOption()
        
        print("🔍 排序完成 - 筛选后文章数: \(keywordFilteredArticles.count), 最终排序数: \(sortedArticles.count)")
    }
    
    /// 按关键词筛选文章
    private func filterArticlesByKeyword(_ articles: [ArticleMatchResult], keyword: KeywordSortOption) -> [ArticleMatchResult] {
        let keywordText: String
        switch keyword {
        case .reading: keywordText = "阅读理解"
        case .translation: keywordText = "翻译"
        case .writing: keywordText = "写作"
        case .knowledge: keywordText = "知识运用"
        case .none: return articles
        }
        
        // 筛选包含关键词的文章，优先显示标题包含关键词的文章
        let matchingArticles = articles.filter { result in
            result.article.title.contains(keywordText) || 
            result.article.examType.contains(keywordText) ||
            result.article.content.contains(keywordText)
        }
        
        // 如果没有匹配的文章，返回所有文章
        return matchingArticles.isEmpty ? articles : matchingArticles
    }
    
    /// 按基础选项排序文章
    private func sortArticlesByBasicOption(_ articles: [ArticleMatchResult], option: BasicSortOption) -> [ArticleMatchResult] {
        switch option {
        case .matchScore:
            return articles.sorted { $0.matchScore > $1.matchScore }
        case .difficulty:
            return articles.sorted { $0.difficulty.rawValue < $1.difficulty.rawValue }
        case .recommendation:
            return articles.sorted { $0.recommendation.priority > $1.recommendation.priority }
        case .unknownWords:
            // 生词数量：越多越靠前（降序）
            return articles.sorted { $0.unknownWords > $1.unknownWords }
        case .articleLength:
            // 文章长度：越长越靠前（降序）
            return articles.sorted { $0.totalWords > $1.totalWords }
        }
    }
    
    /// 刷新排序结果
    func refreshRanking() async {
        clearCache()
        lastRankingTimestamp = nil
        await loadRankedArticles()
    }
    

    
    /// 获取推荐文章（匹配度最高的前N篇）
    func getRecommendedArticles(limit: Int = 5) -> [ArticleMatchResult] {
        return Array(rankedArticles.prefix(limit))
    }
    
    /// 根据难度筛选文章
    func filterArticlesByDifficulty(_ difficulty: IntelligentRankingDifficultyLevel) -> [ArticleMatchResult] {
        return rankedArticles.filter { $0.difficulty == difficulty }
    }
    
    /// 根据推荐等级筛选文章
    func filterArticlesByRecommendation(_ recommendation: RecommendationLevel) -> [ArticleMatchResult] {
        return rankedArticles.filter { $0.recommendation == recommendation }
    }
    
    // MARK: - 批量学习功能
    
    /// 批量标记文章为已学习，并处理文章中的所有词汇
    func markArticlesAsLearned(_ articles: [ArticleMatchResult]) async {
        print("📚 开始批量学习 \(articles.count) 篇文章")
        
        // 获取当前选中的词典名称
        guard let selectedDictionary = selectedDictionary else {
            print("❌ 批量学习失败：未选择词典")
            return
        }
        
        // 获取学习跟踪服务：用于仅在掌握程度提升时写回用户词汇
        let learningTrackingService = ServiceContainer.shared.getLearningTrackingService()
        
        var totalWordsProcessed = 0
        var totalArticlesProcessed = 0
        var dictionaryWordsUpdated = 0
        var generalWordsUpdated = 0
        
        for result in articles {
            do {
                // 标记文章为已学习
                result.article.markAsLearned()
                
                // 提取文章中的所有词汇
                let articleWords = extractWordsFromArticle(result.article)
                print("📝 文章 '\(result.article.title)' 包含 \(articleWords.count) 个词汇")
                
                if !articleWords.isEmpty {
                    // 分类处理词汇：区分词典词汇和一般词汇
                    let dictionaryWords = articleWords.filter { word in
                        // 检查是否为测试词典中的词汇（这里简化处理，实际可以通过词典服务查询）
                        return true // 暂时将所有词汇都视为需要更新的词汇
                    }
                    
                    // 优先更新词典测试结果中的词汇
                    if !dictionaryWords.isEmpty {
                        do {
                            // 批量更新词典测试结果：仅更新生词为掌握状态
                            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                                var cancellable: AnyCancellable?
                                var hasResumed = false
                                
                                // 设置30秒超时
                                let timeoutTask = Task {
                                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                                    if !hasResumed {
                                        hasResumed = true
                                        cancellable?.cancel()
                                        continuation.resume(throwing: VocabularyTestError.timeout)
                                    }
                                }
                                
                                cancellable = vocabularyTestService.batchUpdateWordMastery(
                                    words: dictionaryWords,
                                    mastery: .mastered,
                                    dictionaryName: selectedDictionary.name,
                                    dictionaryFileName: selectedDictionary.fileName
                                )
                                .sink(
                                    receiveCompletion: { completion in
                                        timeoutTask.cancel()
                                        guard !hasResumed else { return }
                                        hasResumed = true
                                        
                                        if case .failure(let error) = completion {
                                            continuation.resume(throwing: error)
                                        } else {
                                            continuation.resume(returning: ())
                                        }
                                        cancellable?.cancel()
                                    },
                                    receiveValue: { _ in }
                                )
                            }
                            
                            dictionaryWordsUpdated += dictionaryWords.count
                            print("✅ 已更新词典测试结果：\(dictionaryWords.count) 个词汇标记为掌握状态")
                            
                        } catch {
                            print("❌ 更新词典测试结果失败: \(error.localizedDescription)")
                        }
                    }
                    
                    // 条件性更新用户词汇库：仅当掌握程度提升时写入
                    for word in articleWords {
                        learningTrackingService.updateWordMasteryIfHigher(
                            word: word,
                            masteryLevel: .mastered,
                            source: "reading"
                        )
                        generalWordsUpdated += 1
                    }

                    totalWordsProcessed += articleWords.count
                }
                
                // 记录学习进度（recordArticleCompletion内部已包含经验值奖励）
                try await userProgressService.recordArticleCompletion(
                    articleId: result.article.id.uuidString,
                    readingTime: 300, // 批量操作默认5分钟阅读时间
                    wordsLookedUp: articleWords.count  // 记录处理的词汇数量
                )
                
                // 移除重复的经验值奖励，recordArticleCompletion已包含完整的经验值计算
                
                totalArticlesProcessed += 1
                print("✅ 文章已标记为学习: \(result.article.title)")
                
            } catch {
                print("❌ 标记文章学习失败: \(result.article.title) - \(error.localizedDescription)")
            }
        }
        
        print("📚 批量学习完成：")
        print("   - 处理了 \(totalArticlesProcessed) 篇文章")
        print("   - 共处理 \(totalWordsProcessed) 个词汇")
        print("   - 词典测试结果更新：\(dictionaryWordsUpdated) 个词汇")
        print("   - 用户词汇库更新：\(generalWordsUpdated) 个词汇")
    }
    
    /// 从文章中提取词汇
    private func extractWordsFromArticle(_ article: Article) -> [String] {
        let text = "\(article.title) \(article.content)"
        
        // 使用正则表达式提取英文单词
        let pattern = "\\b[a-zA-Z]+\\b"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: text.utf16.count)
        
        guard let regex = regex else { return [] }
        
        let matches = regex.matches(in: text, options: [], range: range)
        let words = matches.compactMap { match in
            Range(match.range, in: text).map { String(text[$0]).lowercased() }
        }
        
        // 过滤常见停用词和短词
        return filterWords(words)
    }
    
    /// 过滤词汇（移除停用词和无效词汇）
    private func filterWords(_ words: [String]) -> [String] {
        let stopWords = Set([
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
            "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did",
            "will", "would", "could", "should", "may", "might", "can", "must", "shall",
            "i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
            "my", "your", "his", "her", "its", "our", "their", "this", "that", "these", "those"
        ])
        
        return words.filter { word in
            word.count >= 3 && // 至少3个字符
            word.count <= 20 && // 最多20个字符
            !stopWords.contains(word) && // 不是停用词
            word.allSatisfy { $0.isLetter } // 只包含字母
        }
    }
    
    // MARK: - Solo文章相关方法
    
    /// 加载solo文章的匹配度结果
    private func loadSoloArticles() async {
        let userVocabulary = dictionaryService.getUserWordRecords()
        let matchResults = await soloArticleService.getRankedSoloArticles(userVocabulary: userVocabulary)
        
        self.rankedArticles = matchResults
        print("✅ 成功加载solo文章匹配结果，共\(matchResults.count)篇")
    }
    
    /// 获取solo文章的统计信息
    func getSoloStatistics() -> (totalArticles: Int, averageMatchScore: Double, difficultyDistribution: [IntelligentRankingDifficultyLevel: Int]) {
        return soloArticleService.getSoloArticleStatistics(matchResults: rankedArticles)
    }
    
    // 移除重复的排序方法，使用 IntelligentRankingService 的排序方法
    
    /// 清除缓存
    private func clearCache() {
        allRankedResults.removeAll()
        lastRankingTimestamp = nil
    }
    
    private func loadArticles() async throws -> [Article] {
        switch selectedReadingMode {
        case .yearlyExams:
            return articleService.getAllArticles()
        case .soloArticles:
            return soloArticleService.getAllSoloArticles()
        }
    }
    
    private func loadUserVocabulary() -> [UserWord] {
        // 从词典服务获取用户词汇数据
        return dictionaryService.getUserWordRecords()
    }
    
    /// 获取用户词汇数据的公共方法
    func getUserVocabulary() -> [UserWord] {
        return loadUserVocabulary()
    }
    
    /// 获取可用词典列表
    func getAvailableDictionaries() async throws -> [DictionaryInfo] {
        return try await rankingService.getAvailableDictionaries()
    }
    
    @objc private func handleVocabularyProgressUpdate(_ notification: Notification) {
        let now = Date()
        
        // 防抖动检查
        if let lastUpdate = lastRankingUpdateTime,
           now.timeIntervalSince(lastUpdate) < rankingUpdateDebounceInterval {
            print("[DEBUG] 词汇进度更新通知被防抖动机制忽略")
            return
        }
        
        // 防重复处理
        if isHandlingRankingUpdate {
            print("[DEBUG] 正在处理词汇进度更新，忽略重复通知")
            return
        }
        
        isHandlingRankingUpdate = true
        lastRankingUpdateTime = now
        
        print("[DEBUG] 收到词汇进度更新通知，刷新智能排序")
        
        Task {
            await MainActor.run {
                Task {
                    await self.refreshRanking()
                }
                
                // 延迟重置标志，确保处理完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.isHandlingRankingUpdate = false
                }
            }
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - 排序统计信息
struct RankingStatistics {
    let totalArticles: Int
    let averageMatchScore: Double
    let difficultyDistribution: [IntelligentRankingDifficultyLevel: Int]
    let recommendationDistribution: [RecommendationLevel: Int]
    
    var formattedAverageScore: String {
        return String(format: "%.1f", averageMatchScore)
    }
    
    var mostCommonDifficulty: IntelligentRankingDifficultyLevel? {
        return difficultyDistribution.max { $0.value < $1.value }?.key
    }
    
    var mostCommonRecommendation: RecommendationLevel? {
        return recommendationDistribution.max { $0.value < $1.value }?.key
    }
}

// MARK: - 扩展：便利方法
extension IntelligentRankingViewModel {
    
    /// 获取特定文章的详细分析
    func getArticleAnalysis(for articleId: UUID) -> ArticleMatchResult? {
        return rankedArticles.first { $0.article.id == articleId }
    }
    
    /// 检查是否需要更新排序
    var needsRankingUpdate: Bool {
        guard let lastTimestamp = lastRankingTimestamp else { return true }
        return Date().timeIntervalSince(lastTimestamp) > rankingCacheValidityDuration
    }
    
    /// 获取排序性能指标
    func getPerformanceMetrics() -> (cacheHitRate: Double, lastUpdateTime: Date?) {
        let cacheHitRate = lastRankingTimestamp != nil && !needsRankingUpdate ? 1.0 : 0.0
        return (cacheHitRate, lastRankingTimestamp)
    }
}

// MARK: - 词典测试状态管理
extension IntelligentRankingViewModel {
    
    /// 加载所有可用词典和测试状态
    func loadDictionaryTestStates() async {
        do {
            print("🔄 开始加载词典测试状态...")
            let dictionaries = try await getAvailableDictionaries()
            print("📚 获取到\(dictionaries.count)个可用词典")
            
            var testStates: [DictionaryTestState] = []
            
            // 使用async/await并行加载所有词典的测试数据
            await withTaskGroup(of: DictionaryTestState?.self) { group in
                for dictionary in dictionaries {
                    group.addTask { [weak self] in
                        guard let self = self else { return nil }
                        
                        do {
                            print("📖 正在加载词典: \(dictionary.name)")
                            
                            // 并行获取测试历史和最新测试
                            async let testHistoryTask = self.getTestHistoryAsync(for: dictionary.id)
                            async let latestTestTask = self.getLatestTestAsync(for: dictionary.id)
                            
                            let testHistory = try await testHistoryTask
                            let latestTest = try? await latestTestTask
                            
                            print("📊 词典\(dictionary.name)测试数据: 历史记录\(testHistory.count)个, 最新测试: \(latestTest?.id.uuidString ?? "无")")
                            
                            print("✅ 词典\(dictionary.name)加载完成: 历史测试\(testHistory.count)个")
                            
                            // 创建词典测试状态
                            let testState = DictionaryTestState(
                                dictionaryId: dictionary.id,
                                dictionaryName: dictionary.name,
                                dictionary: dictionary,
                                testHistory: testHistory,
                                selectedTest: latestTest
                            )
                            
                            print("📋 词典\(dictionary.name)状态: \(testState.status.displayText), 测试记录: \(testState.testForRanking?.id.uuidString ?? "无")")
                            
                            return testState
                            
                        } catch {
                            print("❌ 加载词典\(dictionary.name)失败: \(error.localizedDescription)")
                            return nil
                        }
                    }
                }
                
                // 收集所有成功加载的测试状态
                for await testState in group {
                    if let testState = testState {
                        testStates.append(testState)
                    }
                }
            }
            
            await MainActor.run {
                self.dictionaryTestStates = testStates
                print("✅ 成功加载词典测试状态，共\(testStates.count)个词典")
            }
            
        } catch {
            print("❌ 加载词典测试状态失败: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("错误详情: \(nsError.userInfo)")
            }
            await MainActor.run {
                self.errorMessage = "加载词典测试状态失败: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 私有异步辅助方法
    
    /// 异步获取测试历史
    private func getTestHistoryAsync(for dictionaryId: UUID) async throws -> [VocabularyTest] {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var hasResumed = false
            
            // 设置30秒超时
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !hasResumed {
                    hasResumed = true
                    cancellable?.cancel()
                    continuation.resume(throwing: VocabularyTestError.timeout)
                }
            }
            
            cancellable = vocabularyTestService.getTestHistory(for: dictionaryId)
                .sink(
                    receiveCompletion: { completion in
                        timeoutTask.cancel()
                        guard !hasResumed else { return }
                        hasResumed = true
                        
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { tests in
                        timeoutTask.cancel()
                        guard !hasResumed else { return }
                        hasResumed = true
                        
                        continuation.resume(returning: tests)
                        cancellable?.cancel()
                    }
                )
        }
    }
    
    /// 异步获取最新测试
    private func getLatestTestAsync(for dictionaryId: UUID) async throws -> VocabularyTest? {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var hasResumed = false
            
            // 设置30秒超时
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !hasResumed {
                    hasResumed = true
                    cancellable?.cancel()
                    continuation.resume(throwing: VocabularyTestError.timeout)
                }
            }
            
            cancellable = vocabularyTestService.getLatestTest(for: dictionaryId)
                .sink(
                    receiveCompletion: { completion in
                        timeoutTask.cancel()
                        guard !hasResumed else { return }
                        hasResumed = true
                        
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { test in
                        timeoutTask.cancel()
                        guard !hasResumed else { return }
                        hasResumed = true
                        
                        continuation.resume(returning: test)
                        cancellable?.cancel()
                    }
                )
        }
    }
    
    /// 选择词典进行智能排序
    func selectDictionary(_ dictionary: DictionaryInfo) {
        self.selectedDictionary = dictionary
        
        // 查找对应的测试状态
        if let testState = dictionaryTestStates.first(where: { $0.dictionaryId == dictionary.id }) {
            self.selectedTestState = testState
        }
        
        // 基于选中的词典重新加载和排序文章
        Task {
            await loadRankedArticles()
        }
    }
    
    /// 选择特定的测试记录
    func selectTestRecord(_ test: VocabularyTest, for testState: DictionaryTestState) {
        // 更新测试状态中的选中测试
        if let index = dictionaryTestStates.firstIndex(where: { $0.dictionaryId == testState.dictionaryId }) {
            dictionaryTestStates[index] = dictionaryTestStates[index].withSelectedTest(test)
            self.selectedTestState = dictionaryTestStates[index]
        }
        
        self.showTestHistorySelection = false
        
        // 开始排序
        Task {
            await performStagedRanking(with: selectedTestState!)
        }
    }
    
    /// 执行分阶段排序
    func performStagedRanking(with testState: DictionaryTestState) async {
        guard let selectedTest = testState.selectedTest else {
            self.errorMessage = "未找到选中的测试记录"
            return
        }
        
        self.isLoading = true
        
        do {
            // 获取文章数据
            let articles = try await loadArticles()
            
            // 获取词典信息
            guard let dictionary = availableDictionaries.first(where: { $0.id == testState.dictionaryId }) else {
                throw AppError.fileNotFound("未找到对应的词典信息: \(testState.dictionaryId)")
            }
            
            // 执行分阶段排序
            let stagedResult = try await rankingService.performStagedRanking(
                articles: articles,
                testRecord: selectedTest,
                dictionary: dictionary
            )
            
            self.stagedRankingResults = stagedResult
            self.showStagedRanking = true
            
            // 更新主排序结果为第一阶段的结果
            self.rankedArticles = stagedResult.stage1Results.map { $0.article }
                .compactMap { article in
                    // 创建一个基本的ArticleMatchResult
                    return ArticleMatchResult(
                        article: article,
                        matchScore: 0.0,
                        totalWords: 0,
                        unknownWords: 0,
                        familiarWords: 0,
                        masteredWords: 0,
                        difficulty: .intermediate,
                        recommendation: .good
                    )
                }
            
            print("✅ 分阶段排序完成，第一阶段 \(stagedResult.stage1Results.count) 篇文章，第二阶段 \(stagedResult.stage2Results.count) 篇文章")
            
        } catch {
            print("❌ 分阶段排序失败: \(error.localizedDescription)")
            self.errorMessage = "排序失败: \(error.localizedDescription)"
        }
        
        self.isLoading = false
    }
    
    /// 切换到指定阶段
    func switchToStage(_ stage: Int) {
        self.currentStage = stage
        
        guard let stagedResult = stagedRankingResults else { return }
        
        let stageResults: [Any] = stage == 1 ? stagedResult.stage1Results : stagedResult.stage2Results
        self.rankedArticles = stageResults.compactMap { result in
            let article: Article
            if let dictionaryOverlapInfo = result as? DictionaryOverlapInfo {
                article = dictionaryOverlapInfo.article
            } else if let userMasteryInfo = result as? UserMasteryInfo {
                article = userMasteryInfo.article
            } else {
                return nil
            }
            
            // 创建一个基本的ArticleMatchResult
            return ArticleMatchResult(
                article: article,
                matchScore: 0.0,
                totalWords: 0,
                unknownWords: 0,
                familiarWords: 0,
                masteredWords: 0,
                difficulty: .intermediate,
                recommendation: .good
            )
        }
    }
    
    /// 获取阶段统计信息
    func getStageStatistics(for stage: Int) -> (count: Int, averageScore: Double)? {
        guard let stagedResult = stagedRankingResults else { return nil }
        
        if stage == 1 {
            let stageResults = stagedResult.stage1Results
            let count = stageResults.count
            let averageScore = stageResults.isEmpty ? 0.0 : 
                stageResults.map { $0.overlapPercentage }.reduce(0, +) / Double(count)
            return (count, averageScore)
        } else {
            let stageResults = stagedResult.stage2Results
            let count = stageResults.count
            let averageScore = stageResults.isEmpty ? 0.0 : 
                stageResults.map { $0.masteredPercentage }.reduce(0, +) / Double(count)
            return (count, averageScore)
        }
    }
    
    /// 重置词典选择状态
    func resetDictionarySelection() {
        self.selectedDictionary = nil
        self.selectedTestState = nil
        self.showDictionarySelection = false
        self.showTestHistorySelection = false
        self.showStagedRanking = false
        self.stagedRankingResults = nil
        self.currentStage = 1
    }
}