//
//  CompositeRankingService.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CompositeRankingService: ObservableObject {
    
    // MARK: - Dependencies
    private let intelligentRankingService: IntelligentRankingService
    private let dictionaryService: DictionaryServiceProtocol
    private let vocabularyTestService: VocabularyTestServiceProtocol?
    private let errorHandler: ErrorHandlerProtocol
    
    // MARK: - Published Properties
    @Published var currentConfig: CompositeRankingConfig = .default
    @Published var availableDictionaries: [DictionaryInfo] = []
    @Published var availableTests: [VocabularyTest] = []
    @Published var isLoading: Bool = false
    @Published var lastRankingResults: [CompositeRankedArticle] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var rankingCache: [String: (results: [CompositeRankedArticle], timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟
    private let maxCacheSize = 10
    
    // MARK: - Initialization
    init(intelligentRankingService: IntelligentRankingService,
         dictionaryService: DictionaryServiceProtocol,
         vocabularyTestService: VocabularyTestServiceProtocol? = nil,
         errorHandler: ErrorHandlerProtocol) {
        self.intelligentRankingService = intelligentRankingService
        self.dictionaryService = dictionaryService
        self.vocabularyTestService = vocabularyTestService
        self.errorHandler = errorHandler
        
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // 监听配置变化
        $currentConfig
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadAvailableResources()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 执行组合排序
    func performCompositeRanking(
        articles: [Article],
        userVocabulary: [UserWord] = []
    ) async throws -> [CompositeRankedArticle] {
        print("🔄 开始执行组合排序...")
        isLoading = true
        defer { isLoading = false }
        
        // 检查缓存
        let cacheKey = generateCacheKey(articles: articles, config: currentConfig)
        if let cachedResults = getCachedResults(key: cacheKey) {
            print("✅ 使用缓存的排序结果")
            lastRankingResults = cachedResults
            return cachedResults
        }
        
        // 获取基础排序结果
        let baseResults = await intelligentRankingService.rankArticles(articles, userVocabulary: userVocabulary)
        print("📊 获得基础排序结果: \(baseResults.count) 篇文章")
        
        // 获取词典匹配信息
        let dictionaryMatchInfo = await getDictionaryMatchInfo(for: articles)
        
        // 获取测试结果信息
        let testResultInfo = await getTestResultInfo(for: articles)
        
        // 执行组合排序
        let compositeResults = await performCompositeScoring(
            baseResults: baseResults,
            dictionaryMatchInfo: dictionaryMatchInfo,
            testResultInfo: testResultInfo
        )
        
        // 缓存结果
        cacheResults(key: cacheKey, results: compositeResults)
        lastRankingResults = compositeResults
        
        print("✅ 组合排序完成，共 \(compositeResults.count) 篇文章")
        return compositeResults
    }
    
    /// 更新排序配置
    func updateConfig(_ newConfig: CompositeRankingConfig) {
        print("🔧 更新排序配置")
        currentConfig = newConfig
        clearCache() // 清除缓存以确保使用新配置
    }
    
    /// 应用预设配置
    func applyPreset(_ preset: SortPreset) {
        print("🎯 应用预设配置: \(preset.rawValue)")
        updateConfig(preset.config)
    }
    
    /// 加载可用资源
    func loadAvailableResources() async {
        print("📚 加载可用资源...")
        
        // 加载词典
        do {
            availableDictionaries = try await intelligentRankingService.getAvailableDictionaries()
            print("📖 加载了 \(availableDictionaries.count) 个词典")
        } catch {
            print("❌ 加载词典失败: \(error.localizedDescription)")
            availableDictionaries = []
        }
        
        // 加载测试记录
        if let testService = vocabularyTestService {
            testService.getTestHistory(limit: 100)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("❌ 加载测试记录失败: \(error.localizedDescription)")
                        }
                    },
                    receiveValue: { [weak self] tests in
                        self?.availableTests = tests
                        print("📝 加载了 \(tests.count) 个测试记录")
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Private Methods
    
    /// 执行组合评分
    private func performCompositeScoring(
        baseResults: [ArticleMatchResult],
        dictionaryMatchInfo: [String: DictionaryMatchInfo],
        testResultInfo: [String: TestResultInfo]
    ) async -> [CompositeRankedArticle] {
        
        let enabledCriteria = currentConfig.enabledCriteria
        guard !enabledCriteria.isEmpty else {
            print("⚠️ 没有启用的排序条件，返回基础结果")
            return baseResults.enumerated().map { index, result in
                CompositeRankedArticle(
                    article: result.article,
                    baseResult: result,
                    compositeScore: result.matchScore,
                    rank: index + 1
                )
            }
        }
        
        var compositeResults: [CompositeRankedArticle] = []
        
        for baseResult in baseResults {
            let articleId = baseResult.article.id.uuidString
            
            // 计算各个条件的分数
            var criteriaScores: [RankingSortOption: Double] = [:]
            var weightedScore: Double = 0.0
            var totalWeight: Double = 0.0
            
            for criteria in enabledCriteria {
                let score = calculateCriteriaScore(
                    criteria: criteria,
                    baseResult: baseResult,
                    dictionaryInfo: dictionaryMatchInfo[articleId],
                    testInfo: testResultInfo[articleId]
                )
                
                criteriaScores[criteria.option] = score
                weightedScore += score * criteria.weight
                totalWeight += criteria.weight
            }
            
            // 标准化综合分数
            let normalizedScore = totalWeight > 0 ? weightedScore / totalWeight : 0.0
            
            let compositeResult = CompositeRankedArticle(
                article: baseResult.article,
                baseResult: baseResult,
                compositeScore: normalizedScore,
                criteriaScores: criteriaScores,
                dictionaryMatchInfo: dictionaryMatchInfo[articleId],
                testResultInfo: testResultInfo[articleId]
            )
            
            compositeResults.append(compositeResult)
        }
        
        // 按综合分数排序
        compositeResults.sort { $0.compositeScore > $1.compositeScore }
        
        // 分配排名
        for (index, _) in compositeResults.enumerated() {
            compositeResults[index] = CompositeRankedArticle(
                article: compositeResults[index].article,
                baseResult: compositeResults[index].baseResult,
                compositeScore: compositeResults[index].compositeScore,
                criteriaScores: compositeResults[index].criteriaScores,
                rank: index + 1,
                dictionaryMatchInfo: compositeResults[index].dictionaryMatchInfo,
                testResultInfo: compositeResults[index].testResultInfo
            )
        }
        
        return compositeResults
    }
    
    /// 计算单个条件的分数
    private func calculateCriteriaScore(
        criteria: SortCriteria,
        baseResult: ArticleMatchResult,
        dictionaryInfo: DictionaryMatchInfo?,
        testInfo: TestResultInfo?
    ) -> Double {
        
        var rawScore: Double = 0.0
        
        switch criteria.option {
        case .matchScore:
            rawScore = baseResult.matchScore / 100.0
            
        case .difficulty:
            // 难度分数：初级=1.0，专家=0.0
            let difficultyLevels: [IntelligentRankingDifficultyLevel] = [.beginner, .elementary, .intermediate, .upperIntermediate, .advanced, .expert]
            if let index = difficultyLevels.firstIndex(of: baseResult.difficulty) {
                rawScore = 1.0 - (Double(index) / Double(difficultyLevels.count - 1))
            }
            
        case .recommendation:
            rawScore = Double(baseResult.recommendation.priority) / 5.0
            
        case .unknownWords:
            // 生词数量分数：适中的生词数量得分最高
            let unknownPercentage = baseResult.unknownPercentage
            if unknownPercentage >= 15 && unknownPercentage <= 35 {
                rawScore = 1.0 - abs(unknownPercentage - 25) / 25.0
            } else {
                rawScore = max(0.0, 1.0 - abs(unknownPercentage - 25) / 50.0)
            }
            
        case .articleLength:
            // 文章长度分数：适中长度得分最高
            let wordCount = Double(baseResult.totalWords)
            let idealLength: Double = 500
            let maxDeviation: Double = 1000
            rawScore = max(0.0, 1.0 - abs(wordCount - idealLength) / maxDeviation)
            
        case .keywordReading, .keywordTranslation, .keywordWriting, .keywordKnowledge:
            // 关键词匹配分数
            rawScore = calculateKeywordScore(for: criteria.option, article: baseResult.article)
        }
        
        // 集成词典信息
        if let dictInfo = dictionaryInfo, currentConfig.useDictionaryIntegration {
            let dictionaryBonus = dictInfo.matchQuality.score * 0.2
            rawScore = min(1.0, rawScore + dictionaryBonus)
        }
        
        // 集成测试结果信息
        if let testInfo = testInfo, currentConfig.useTestResults {
            let testBonus = testInfo.masteryLevel.score * 0.15
            rawScore = min(1.0, rawScore + testBonus)
        }
        
        // 应用排序方向
        if criteria.direction == .ascending {
            rawScore = 1.0 - rawScore
        }
        
        return max(0.0, min(1.0, rawScore))
    }
    
    /// 计算关键词分数
    private func calculateKeywordScore(for option: RankingSortOption, article: Article) -> Double {
        let keyword: String
        switch option {
        case .keywordReading: keyword = "阅读理解"
        case .keywordTranslation: keyword = "翻译"
        case .keywordWriting: keyword = "写作"
        case .keywordKnowledge: keyword = "知识运用"
        default: return 0.0
        }
        
        var score: Double = 0.0
        
        // 标题匹配
        if article.title.contains(keyword) {
            score += 0.5
        }
        
        // 考试类型匹配
        if article.examType.contains(keyword) {
            score += 0.3
        }
        
        // 内容匹配
        if article.content.contains(keyword) {
            score += 0.2
        }
        
        return min(1.0, score)
    }
    
    /// 获取词典匹配信息
    private func getDictionaryMatchInfo(for articles: [Article]) async -> [String: DictionaryMatchInfo] {
        guard currentConfig.useDictionaryIntegration,
              let dictionaryId = currentConfig.selectedDictionaryId,
              let dictionary = availableDictionaries.first(where: { $0.id == dictionaryId }) else {
            return [:]
        }
        
        print("📖 分析词典匹配信息: \(dictionary.displayName)")
        
        var matchInfo: [String: DictionaryMatchInfo] = [:]
        
        // 加载词典词汇
        guard let dictionaryWords = await loadDictionaryWords(dictionary: dictionary) else {
            print("❌ 无法加载词典词汇")
            return [:]
        }
        
        for article in articles {
            let articleWords = extractWordsFromArticle(article)
            let articleWordSet = Set(articleWords)
            let matchedWords = articleWordSet.intersection(dictionaryWords)
            let overlapCount = matchedWords.count
            let overlapPercentage = articleWordSet.isEmpty ? 0.0 : Double(overlapCount) / Double(articleWordSet.count) * 100
            
            let info = DictionaryMatchInfo(
                dictionaryId: dictionary.id,
                dictionaryName: dictionary.displayName,
                overlapCount: overlapCount,
                overlapPercentage: overlapPercentage,
                dictionaryWords: dictionaryWords,
                matchedWords: matchedWords
            )
            
            matchInfo[article.id.uuidString] = info
        }
        
        return matchInfo
    }
    
    /// 获取测试结果信息
    private func getTestResultInfo(for articles: [Article]) async -> [String: TestResultInfo] {
        guard currentConfig.useTestResults,
              let testId = currentConfig.selectedTestId,
              let test = availableTests.first(where: { $0.id == testId }) else {
            return [:]
        }
        
        print("📝 分析测试结果信息: \(test.dictionaryName)")
        
        // 从测试结果中提取词汇掌握信息
        let testResults = test.getTestResults()
        
        // VocabularyTestResult没有masteryLevel属性，根据isKnown分类
        let knownWords = Set(testResults.filter { $0.isKnown }.map { $0.word })
        let unknownWords = Set(testResults.filter { !$0.isKnown }.map { $0.word })
        
        // 由于VocabularyTestResult没有masteryLevel，我们将已知单词都归类为familiar
        let masteredWords: Set<String> = []
        let familiarWords = knownWords
        
        let testInfo = TestResultInfo(
            testId: test.id,
            testDate: test.createdAt,
            masteredWords: masteredWords,
            familiarWords: familiarWords,
            unknownWords: unknownWords,
            accuracyPercentage: test.accuracyPercentage,
            estimatedVocabularySize: test.estimatedVocabularySize
        )
        
        // 为所有文章应用相同的测试信息
        var testInfoMap: [String: TestResultInfo] = [:]
        for article in articles {
            testInfoMap[article.id.uuidString] = testInfo
        }
        
        return testInfoMap
    }
    
    /// 加载词典词汇
    private func loadDictionaryWords(dictionary: DictionaryInfo) async -> Set<String>? {
        do {
            let words = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[DictionaryWord], Error>) in
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
                
                cancellable = dictionaryService.loadDictionary(fileName: dictionary.fileName)
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
                        receiveValue: { words in
                            timeoutTask.cancel()
                            guard !hasResumed else { return }
                            hasResumed = true
                            
                            continuation.resume(returning: words)
                            cancellable?.cancel()
                        }
                    )
            }
            return Set(words.map { $0.word.lowercased() })
        } catch {
            print("❌ 加载词典失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 从文章中提取词汇
    private func extractWordsFromArticle(_ article: Article) -> [String] {
        let text = "\(article.title) \(article.content)"
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.compactMap { word in
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
            return cleanWord.isEmpty ? nil : cleanWord
        }
    }
    
    // MARK: - Cache Management
    
    private func generateCacheKey(articles: [Article], config: CompositeRankingConfig) -> String {
        let articleIds = articles.map { $0.id.uuidString }.sorted().joined(separator: ",")
        let configHash = String(describing: config).hash
        return "\(articleIds)_\(configHash)"
    }
    
    private func getCachedResults(key: String) -> [CompositeRankedArticle]? {
        guard let cached = rankingCache[key],
              Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration else {
            return nil
        }
        return cached.results
    }
    
    private func cacheResults(key: String, results: [CompositeRankedArticle]) {
        // 限制缓存大小
        if rankingCache.count >= maxCacheSize {
            let oldestKey = rankingCache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let keyToRemove = oldestKey {
                rankingCache.removeValue(forKey: keyToRemove)
            }
        }
        
        rankingCache[key] = (results: results, timestamp: Date())
    }
    
    private func clearCache() {
        rankingCache.removeAll()
        print("🗑️ 清除排序缓存")
    }
}