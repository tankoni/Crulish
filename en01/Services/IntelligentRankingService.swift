//
//  IntelligentRankingService.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation
import SwiftUI
import Combine

// MARK: - 文章匹配度结果
struct ArticleMatchResult {
    let article: Article
    let matchScore: Double
    let totalWords: Int
    let unknownWords: Int
    let familiarWords: Int
    let masteredWords: Int
    let difficulty: IntelligentRankingDifficultyLevel
    let recommendation: RecommendationLevel
    
    var unknownPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(unknownWords) / Double(totalWords) * 100
    }
    
    var masteredPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWords) * 100
    }
}

// MARK: - 智能排序难度等级
enum IntelligentRankingDifficultyLevel: String, CaseIterable {
    case beginner = "初级"
    case elementary = "基础"
    case intermediate = "中级"
    case upperIntermediate = "中高级"
    case advanced = "高级"
    case expert = "专家"
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .elementary: return .mint
        case .intermediate: return .orange
        case .upperIntermediate: return .yellow
        case .advanced: return .red
        case .expert: return .purple
        }
    }
}

// MARK: - 推荐等级
enum RecommendationLevel: String, CaseIterable {
    case perfect = "完美匹配"
    case excellent = "强烈推荐"
    case good = "推荐"
    case fair = "一般"
    case poor = "不推荐"
    
    var color: Color {
        switch self {
        case .perfect: return .green
        case .excellent: return .blue
        case .good: return .orange
        case .fair: return .yellow
        case .poor: return .red
        }
    }
    
    var priority: Int {
        switch self {
        case .perfect: return 5
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        }
    }
}

// MARK: - 基础排序选项
enum BasicSortOption: String, CaseIterable {
    case matchScore = "匹配度"
    case difficulty = "难度"
    case recommendation = "推荐度"
    case unknownWords = "生词数量"
    case articleLength = "文章长度"
    
    func toRankingSortOption() -> RankingSortOption {
        switch self {
        case .matchScore: return .matchScore
        case .difficulty: return .difficulty
        case .recommendation: return .recommendation
        case .unknownWords: return .unknownWords
        case .articleLength: return .articleLength
        }
    }
}

// MARK: - 关键词排序选项
enum KeywordSortOption: String, CaseIterable {
    case none = "无"
    case reading = "阅读理解"
    case translation = "翻译"
    case writing = "写作"
    case knowledge = "知识运用"
    
    func toRankingSortOption() -> RankingSortOption {
        switch self {
        case .none: return .matchScore // 默认使用匹配度排序
        case .reading: return .keywordReading
        case .translation: return .keywordTranslation
        case .writing: return .keywordWriting
        case .knowledge: return .keywordKnowledge
        }
    }
}

// MARK: - 排序选项（保持向后兼容）
enum RankingSortOption: String, CaseIterable, Codable {
    case matchScore = "匹配度"
    case difficulty = "难度"
    case recommendation = "推荐度"
    case unknownWords = "生词数量"
    case articleLength = "文章长度"
    case keywordReading = "阅读理解"
    case keywordTranslation = "翻译"
    case keywordWriting = "写作"
    case keywordKnowledge = "知识运用"
    
    // 转换为基础排序选项
    var asBasicOption: BasicSortOption? {
        switch self {
        case .matchScore: return .matchScore
        case .difficulty: return .difficulty
        case .recommendation: return .recommendation
        case .unknownWords: return .unknownWords
        case .articleLength: return .articleLength
        default: return nil
        }
    }
    
    // 转换为关键词排序选项
    var asKeywordOption: KeywordSortOption? {
        switch self {
        case .keywordReading: return .reading
        case .keywordTranslation: return .translation
        case .keywordWriting: return .writing
        case .keywordKnowledge: return .knowledge
        default: return nil
        }
    }
}

// MARK: - 智能排序服务
@MainActor
class IntelligentRankingService: ObservableObject {
    
    // MARK: - Properties
    private let dictionaryService: DictionaryServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // 词典相关属性
    private var dictionaryVocabularyCache: [String: Set<String>] = [:]
    
    // 词典匹配度算法参数
    private struct DictionaryMatchParameters {
        static let unknownWordWeight: Double = 0.6  // 提高陌生词权重
        static let familiarWordWeight: Double = 0.25
        static let masteredWordWeight: Double = 0.15
        
        // 基于词典的理想比例范围
        static let idealDictionaryUnknownRange: ClosedRange<Double> = 15.0...35.0
        static let idealDictionaryFamiliarRange: ClosedRange<Double> = 25.0...45.0
        static let idealDictionaryMasteredRange: ClosedRange<Double> = 20.0...60.0
    }
    
    // 新增：自适应推荐引擎
    private var adaptiveRecommendationEngine: AdaptiveRecommendationEngine?
    
    // 缓存机制
    private var rankingCache: [String: (results: [ArticleMatchResult], timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟
    private let maxCacheSize = 5 // 仅缓存最近5次结果
    
    // 算法参数 - 基于用户确认的推荐度权重配置
    private struct AlgorithmParameters {
        // 权重配置：生词适中，熟悉词和掌握词略多，确保可读性但有学习价值
        static let unknownWordWeight: Double = 0.25   // 生词权重
        static let familiarWordWeight: Double = 0.375 // 熟悉词权重
        static let masteredWordWeight: Double = 0.375 // 掌握词权重
        static let lengthWeight: Double = 0.0         // 移除长度权重，专注词汇掌握度
        
        // 理想的词汇比例范围 - 基于用户需求调整
        static let idealUnknownRange: ClosedRange<Double> = 20.0...30.0  // 生词20-30%
        static let idealFamiliarRange: ClosedRange<Double> = 35.0...40.0 // 熟悉词35-40%
        static let idealMasteredRange: ClosedRange<Double> = 35.0...40.0 // 掌握词35-40%
    }
    
    // MARK: - Initialization
    init(dictionaryService: DictionaryServiceProtocol? = nil) {
        self.dictionaryService = dictionaryService ?? ServiceContainer.shared.getDictionaryService()
        self.errorHandler = ServiceContainer.shared.getErrorHandler()
    }
    
    // 新增：设置自适应推荐引擎
    func setAdaptiveRecommendationEngine(_ engine: AdaptiveRecommendationEngine) {
        self.adaptiveRecommendationEngine = engine
    }
    
    // MARK: - 基于词典的排序方法
    
    /// 获取可用词典列表
    func getAvailableDictionaries() async throws -> [DictionaryInfo] {
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
            
            cancellable = dictionaryService.getAvailableDictionaries()
                .sink(
                    receiveCompletion: { completion in
                        timeoutTask.cancel()
                        guard !hasResumed else { return }
                        hasResumed = true
                        
                        switch completion {
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        case .finished:
                            break
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { dictionaries in
                        timeoutTask.cancel()
                        guard !hasResumed else { return }
                        hasResumed = true
                        
                        continuation.resume(returning: dictionaries)
                        cancellable?.cancel()
                    }
                )
        }
    }
    
    /// 基于指定词典的文章排序 - 增强版本，支持词典测试结果
    func rankArticlesByDictionary(
        _ articles: [Article], 
        userVocabulary: [UserWord],
        dictionaryName: String,
        vocabularyTestService: VocabularyTestServiceProtocol? = nil
    ) async -> [ArticleMatchResult] {
        
        // 如果提供了词汇测试服务，优先使用测试结果进行排序
        if let testService = vocabularyTestService {
            return await rankArticlesByTestResults(
                articles, 
                dictionaryName: dictionaryName, 
                testService: testService
            )
        }
        
        // 获取词典词汇
        guard let dictionaryWords = await getDictionaryVocabulary(dictionaryName: dictionaryName) else {
            // 如果获取词典失败，回退到普通排序
            return await rankArticles(articles, userVocabulary: userVocabulary)
        }
        
        // 分析用户在该词典中的掌握情况
        let userDictionaryMastery = analyzeDictionaryMastery(
            userVocabulary: userVocabulary, 
            dictionaryWords: dictionaryWords
        )
        
        // 计算基于词典的匹配度
        let results = await calculateDictionaryMatchScores(
            articles: articles, 
            dictionaryWords: dictionaryWords,
            userMastery: userDictionaryMastery
        )
        
        return results
    }
    
    /// 基于词典测试结果的文章排序 - 新增方法
    private func rankArticlesByTestResults(
        _ articles: [Article],
        dictionaryName: String,
        testService: VocabularyTestServiceProtocol
    ) async -> [ArticleMatchResult] {
        
        print("🎯 [智能排序] 使用词典测试结果进行排序: \(dictionaryName)")
        
        // 预取词典词汇，用于计算词典覆盖率
        let dictionaryWords: Set<String> = await getDictionaryVocabulary(dictionaryName: dictionaryName) ?? []
        let useCoverage = !dictionaryWords.isEmpty

        var results: [ArticleMatchResult] = []
        
        for article in articles {
            // 提取文章词汇
            let articleWords = extractWordsFromArticle(article)
            guard !articleWords.isEmpty else { continue }
            
            // 获取文章词汇掌握程度分布
            do {
                let distribution = try await withCheckedThrowingContinuation { continuation in
                    testService.getArticleWordMasteryDistribution(
                        words: articleWords, 
                        dictionaryFileName: dictionaryName
                    )
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { distribution in
                            continuation.resume(returning: distribution)
                        }
                    )
                    .store(in: &cancellables)
                }
                
                // 计算词典覆盖率（文章中属于该词典的比例）
                let coverageRatio: Double
                if useCoverage {
                    let articleSet = Set(articleWords.map { $0.lowercased() })
                    let overlapCount = articleSet.intersection(dictionaryWords).count
                    coverageRatio = articleSet.isEmpty ? 0.0 : Double(overlapCount) / Double(articleSet.count)
                } else {
                    coverageRatio = 0.0
                }

                // 计算生词权重分数（生词数量主导的排序逻辑）
                let unknownWordsCount = distribution.unfamiliarWords + distribution.unknownWords
                let totalWords = distribution.totalWords
                
                // 生词权重分数：生词数量越多分数越高，同时考虑词典覆盖率
                let unknownWordsScore = totalWords > 0 ? Double(unknownWordsCount) / Double(totalWords) * 100.0 : 0.0
                
                // 综合评分：生词数量为主导（70%），词典覆盖率为辅助（30%）
                let combinedScore = 0.7 * unknownWordsScore + 0.3 * (coverageRatio * 100.0)
                let matchScore = combinedScore
                
                // 确定难度等级
                let difficulty = determineDifficultyFromDistribution(distribution)
                
                // 确定推荐等级
                let recommendation = determineRecommendationFromScore(matchScore)
                
                let result = ArticleMatchResult(
                    article: article,
                    matchScore: matchScore,
                    totalWords: distribution.totalWords,
                    unknownWords: distribution.unfamiliarWords + distribution.unknownWords,
                    familiarWords: distribution.familiarWords,
                    masteredWords: distribution.masteredWords,
                    difficulty: difficulty,
                    recommendation: recommendation
                )
                
                results.append(result)
                
            } catch {
                print("❌ [智能排序] 获取文章词汇分布失败: \(error.localizedDescription)")
                // 如果获取失败，跳过该文章
                continue
            }
        }
        
        // 按综合分数排序（包含词典覆盖权重）
        results.sort { $0.matchScore > $1.matchScore }
        
        print("✅ [智能排序] 基于测试结果排序完成，共 \(results.count) 篇文章")
        return results
    }
    
    /// 从词汇分布确定难度等级
    private func determineDifficultyFromDistribution(_ distribution: WordMasteryDistribution) -> IntelligentRankingDifficultyLevel {
        guard distribution.totalWords > 0 else { return .beginner }
        
        let unknownPercentage = Double(distribution.unfamiliarWords + distribution.unknownWords) / Double(distribution.totalWords) * 100
        
        switch unknownPercentage {
        case 0..<15:
            return .beginner
        case 15..<30:
            return .intermediate
        case 30..<50:
            return .advanced
        default:
            return .expert
        }
    }
    
    /// 从推荐度分数确定推荐等级
    private func determineRecommendationFromScore(_ score: Double) -> RecommendationLevel {
        switch score {
        case 90...100:
            return .perfect
        case 75..<90:
            return .excellent
        case 60..<75:
            return .good
        case 40..<60:
            return .fair
        default:
            return .poor
        }
    }
    
    /// 获取词典词汇集合
    private func getDictionaryVocabulary(dictionaryName: String) async -> Set<String>? {
        // 检查缓存
        if let cached = dictionaryVocabularyCache[dictionaryName] {
            return cached
        }
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            // 通过DictionaryService获取词典词汇
            dictionaryService.loadDictionary(fileName: dictionaryName)
                .first()
                .sink(
                    receiveCompletion: { completion in
                        guard !hasResumed else { return }
                        hasResumed = true
                        
                        switch completion {
                        case .failure(let error):
                            print("❌ 获取词典词汇失败: \(error.localizedDescription)")
                            continuation.resume(returning: nil)
                        case .finished:
                            // 如果完成但没有收到值，返回nil
                            continuation.resume(returning: nil)
                        }
                    },
                    receiveValue: { dictionaryWords in
                        guard !hasResumed else { return }
                        hasResumed = true
                        
                        let wordSet = Set(dictionaryWords.map { $0.word.lowercased() })
                        
                        // 缓存结果
                        self.dictionaryVocabularyCache[dictionaryName] = wordSet
                        
                        continuation.resume(returning: wordSet)
                    }
                )
                .store(in: &self.cancellables)
        }
    }
    
    /// 分析用户在特定词典中的掌握情况
    private func analyzeDictionaryMastery(
        userVocabulary: [UserWord], 
        dictionaryWords: Set<String>
    ) -> (unknown: Set<String>, familiar: Set<String>, mastered: Set<String>) {
        
        var unknownWords = Set<String>()
        var familiarWords = Set<String>()
        var masteredWords = Set<String>()
        
        // 分析用户词汇在词典中的掌握情况
        for userWord in userVocabulary {
            let word = userWord.word.lowercased()
            
            // 只考虑词典中包含的单词
            if dictionaryWords.contains(word) {
                switch userWord.masteryLevel {
                case .unfamiliar:
                    unknownWords.insert(word)
                case .familiar:
                    familiarWords.insert(word)
                case .mastered:
                    masteredWords.insert(word)
                }
            }
        }
        
        // 词典中未测试的单词视为陌生词
        let testedWords = unknownWords.union(familiarWords).union(masteredWords)
        let untestedWords = dictionaryWords.subtracting(testedWords)
        unknownWords = unknownWords.union(untestedWords)
        
        return (unknown: unknownWords, familiar: familiarWords, mastered: masteredWords)
    }
    
    /// 计算基于词典的匹配度分数
    private func calculateDictionaryMatchScores(
        articles: [Article], 
        dictionaryWords: Set<String>,
        userMastery: (unknown: Set<String>, familiar: Set<String>, mastered: Set<String>)
    ) async -> [ArticleMatchResult] {
        
        var results: [ArticleMatchResult] = []
        
        for article in articles {
            if let result = await calculateDictionaryArticleMatch(
                article: article, 
                dictionaryWords: dictionaryWords,
                userMastery: userMastery
            ) {
                results.append(result)
            }
        }
        
        // 按匹配度排序（陌生词数量优先，然后是匹配度分数）
        return results.sorted { first, second in
            // 优先考虑陌生词数量（从高到低，学习难度从高到低）
            if first.unknownWords != second.unknownWords {
                return first.unknownWords > second.unknownWords
            }
            // 然后考虑匹配度分数
            return first.matchScore > second.matchScore
        }
    }
    
    /// 计算单篇文章与词典的匹配度
    private func calculateDictionaryArticleMatch(
        article: Article, 
        dictionaryWords: Set<String>,
        userMastery: (unknown: Set<String>, familiar: Set<String>, mastered: Set<String>)
    ) async -> ArticleMatchResult? {
        
        // 提取文章中的单词
        let articleWords = Set(extractWordsFromArticle(article).map { $0.lowercased() })
        
        // 只考虑词典中包含的单词
        let dictionaryWordsInArticle = articleWords.intersection(dictionaryWords)
        
        guard !dictionaryWordsInArticle.isEmpty else {
            return nil // 文章中没有词典词汇
        }
        
        // 分析文章中词典词汇的掌握情况
        let unknownInArticle = dictionaryWordsInArticle.intersection(userMastery.unknown)
        let familiarInArticle = dictionaryWordsInArticle.intersection(userMastery.familiar)
        let masteredInArticle = dictionaryWordsInArticle.intersection(userMastery.mastered)
        
        let stats = (
            unknown: unknownInArticle.count,
            familiar: familiarInArticle.count,
            mastered: masteredInArticle.count
        )
        
        let totalDictionaryWords = dictionaryWordsInArticle.count
        
        // 使用词典专用的匹配度计算
        let matchScore = calculateDictionaryMatchScore(stats: stats, totalWords: totalDictionaryWords)
        
        // 确定难度和推荐等级
        let difficulty = determineDifficulty(stats: stats, totalWords: totalDictionaryWords)
        let recommendation = determineRecommendation(matchScore: matchScore, stats: stats)
        
        return ArticleMatchResult(
            article: article,
            matchScore: matchScore,
            totalWords: totalDictionaryWords,
            unknownWords: stats.unknown,
            familiarWords: stats.familiar,
            masteredWords: stats.mastered,
            difficulty: difficulty,
            recommendation: recommendation
        )
    }
    
    /// 基于词典的匹配度计算（优先考虑陌生词数量）
    private func calculateDictionaryMatchScore(stats: (unknown: Int, familiar: Int, mastered: Int), totalWords: Int) -> Double {
        guard totalWords > 0 else { return 0 }
        
        let unknownPercentage = Double(stats.unknown) / Double(totalWords) * 100
        let familiarPercentage = Double(stats.familiar) / Double(totalWords) * 100
        let masteredPercentage = Double(stats.mastered) / Double(totalWords) * 100
        
        // 使用词典专用的权重和理想范围
        let unknownScore = calculateRangeScore(unknownPercentage, idealRange: DictionaryMatchParameters.idealDictionaryUnknownRange)
        let familiarScore = calculateRangeScore(familiarPercentage, idealRange: DictionaryMatchParameters.idealDictionaryFamiliarRange)
        let masteredScore = calculateRangeScore(masteredPercentage, idealRange: DictionaryMatchParameters.idealDictionaryMasteredRange)
        
        // 计算加权分数，提高陌生词权重
        let weightedScore = unknownScore * DictionaryMatchParameters.unknownWordWeight +
                           familiarScore * DictionaryMatchParameters.familiarWordWeight +
                           masteredScore * DictionaryMatchParameters.masteredWordWeight
        
        // 添加陌生词数量奖励（更多陌生词 = 更高学习价值）
        let unknownCountBonus = min(Double(stats.unknown) / 10.0, 1.0) * 10 // 最多10分奖励
        
        return min(weightedScore + unknownCountBonus, 100.0)
    }

    // MARK: - 核心排序算法
    func rankArticles(_ articles: [Article], userVocabulary: [UserWord]) async -> [ArticleMatchResult] {
        print("🔍 [智能排序] 开始排序 \(articles.count) 篇文章，用户词汇量: \(userVocabulary.count)")
        
        let cacheKey = generateCacheKey(articles: articles, vocabulary: userVocabulary)
        
        // 检查缓存
        if let cached = rankingCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
            print("✅ [智能排序] 使用缓存结果，缓存时间: \(Date().timeIntervalSince(cached.timestamp))秒前")
            return cached.results
        }
        
        print("🔄 [智能排序] 缓存未命中，开始计算匹配度...")
        
        // 计算匹配度
        let results = await calculateMatchScores(articles: articles, userVocabulary: userVocabulary)
        
        // 缓存结果
        cacheResults(key: cacheKey, results: results)
        
        print("✅ [智能排序] 排序完成，共 \(results.count) 篇文章")
        // 注释掉详细的排序结果汇总日志，减少控制台输出
        // print("📊 [智能排序] 排序结果汇总:")
        // for (index, result) in results.prefix(5).enumerated() {
        //     print("   \(index + 1). 《\(result.article.title)》- 匹配度: \(String(format: "%.1f", result.matchScore))%, 推荐: \(result.recommendation.rawValue), 难度: \(result.difficulty.rawValue)")
        // }
        // if results.count > 5 {
        //     print("   ... 还有 \(results.count - 5) 篇文章")
        // }
        
        return results
    }
    
    // 新增：自适应推荐方法
    func getAdaptiveRecommendations(
        articles: [Article], 
        userVocabulary: [UserWord],
        userId: String = "default"
    ) async throws -> [AdaptiveArticleRecommendation] {
        guard let adaptiveEngine = adaptiveRecommendationEngine else {
            throw AppError.serviceNotAvailable
        }
        
        return try await adaptiveEngine.generateAdaptiveRecommendations(
            articles: articles,
            userVocabulary: userVocabulary,
            userId: userId
        )
    }
    
    // 新增：混合推荐方法（结合基础排序和自适应推荐）
    func getHybridRecommendations(
        articles: [Article],
        userVocabulary: [UserWord],
        userId: String = "default",
        adaptiveWeight: Double = 0.7
    ) async throws -> [ArticleMatchResult] {
        
        // 获取基础推荐
        let baseRecommendations = await rankArticles(articles, userVocabulary: userVocabulary)
        
        // 如果没有自适应引擎，返回基础推荐
        guard let adaptiveEngine = adaptiveRecommendationEngine else {
            return baseRecommendations
        }
        
        // 获取自适应推荐
        let adaptiveRecommendations = try await adaptiveEngine.generateAdaptiveRecommendations(
            articles: articles,
            userVocabulary: userVocabulary,
            userId: userId
        )
        
        // 混合两种推荐结果
        return combineRecommendations(
            baseRecommendations: baseRecommendations,
            adaptiveRecommendations: adaptiveRecommendations,
            adaptiveWeight: adaptiveWeight
        )
    }
    
    // 新增：组合推荐结果
    private func combineRecommendations(
        baseRecommendations: [ArticleMatchResult],
        adaptiveRecommendations: [AdaptiveArticleRecommendation],
        adaptiveWeight: Double
    ) -> [ArticleMatchResult] {
        
        // 创建自适应推荐的映射
        let adaptiveMap = Dictionary(uniqueKeysWithValues: 
            adaptiveRecommendations.map { ($0.article.id, $0) }
        )
        
        // 为每个基础推荐计算混合分数
        let hybridResults = baseRecommendations.map { baseResult in
            if let adaptiveResult = adaptiveMap[baseResult.article.id] {
                // 计算混合分数
                let hybridScore = baseResult.matchScore * (1.0 - adaptiveWeight) + 
                                adaptiveResult.adaptiveScore * adaptiveWeight
                
                // 创建新的结果，使用混合分数
                return ArticleMatchResult(
                    article: baseResult.article,
                    matchScore: hybridScore,
                    totalWords: baseResult.totalWords,
                    unknownWords: baseResult.unknownWords,
                    familiarWords: baseResult.familiarWords,
                    masteredWords: baseResult.masteredWords,
                    difficulty: baseResult.difficulty,
                    recommendation: baseResult.recommendation
                )
            } else {
                // 没有自适应推荐，使用原始分数
                return baseResult
            }
        }
        
        // 按混合分数排序
        return hybridResults.sorted { $0.matchScore > $1.matchScore }
    }
    
    // MARK: - 匹配度计算
    private func calculateMatchScores(articles: [Article], userVocabulary: [UserWord]) async -> [ArticleMatchResult] {
        // 注释掉详细的匹配度计算日志，减少控制台输出
        // print("📝 [匹配度计算] 开始分析用户词汇掌握情况...")
        
        let unfamiliarSet = Set(userVocabulary.filter { $0.masteryLevel == .unfamiliar }.map { $0.word.lowercased() })
        let familiarSet = Set(userVocabulary.filter { $0.masteryLevel == .familiar }.map { $0.word.lowercased() })
        let masteredSet = Set(userVocabulary.filter { $0.masteryLevel == .mastered }.map { $0.word.lowercased() })
        let vocabularySet = unfamiliarSet.union(familiarSet).union(masteredSet)
        
        // print("📊 [匹配度计算] 用户词汇统计 - 陌生: \(unfamiliarSet.count), 熟悉: \(familiarSet.count), 掌握: \(masteredSet.count), 总计: \(vocabularySet.count)")
        
        return await withTaskGroup(of: ArticleMatchResult?.self) { group in
            for article in articles {
                group.addTask {
                    await self.calculateArticleMatch(
                        article: article, 
                        vocabularySet: vocabularySet,
                        familiarSet: familiarSet,
                        masteredSet: masteredSet
                    )
                }
            }
            
            var results: [ArticleMatchResult] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            
            let sortedResults = results.sorted { $0.matchScore > $1.matchScore }
            // print("🎯 [匹配度计算] 计算完成，最高匹配度: \(String(format: "%.1f", sortedResults.first?.matchScore ?? 0))%, 最低匹配度: \(String(format: "%.1f", sortedResults.last?.matchScore ?? 0))%")
            
            return sortedResults
        }
    }
    
    // MARK: - 单篇文章匹配度计算
    private func calculateArticleMatch(
        article: Article, 
        vocabularySet: Set<String>,
        familiarSet: Set<String>,
        masteredSet: Set<String>
    ) async -> ArticleMatchResult? {
        // 注释掉详细的文章分析日志，减少控制台输出
        // print("📖 [文章分析] 开始分析《\(article.title)》")
        
        // 提取文章词汇
        let articleWords = Set(extractWordsFromArticle(article))
        guard !articleWords.isEmpty else { 
            // print("⚠️ [文章分析] 《\(article.title)》无有效词汇，跳过")
            return nil 
        }
        
        // print("📝 [文章分析] 《\(article.title)》提取词汇数: \(articleWords.count)")
        
        // 统计词汇掌握情况
        let wordStats = analyzeWordMastery(
            words: articleWords, 
            vocabularySet: vocabularySet, 
            familiarSet: familiarSet, 
            masteredSet: masteredSet
        )
        
        // print("📊 [文章分析] 《\(article.title)》词汇统计 - 陌生: \(wordStats.unknown), 熟悉: \(wordStats.familiar), 掌握: \(wordStats.mastered)")
        
        // 计算匹配分数
        let matchScore = calculateMatchScore(stats: wordStats, totalWords: articleWords.count)
        // print("🎯 [文章分析] 《\(article.title)》匹配分数: \(String(format: "%.2f", matchScore))%")
        
        // 确定难度等级
        let difficulty = determineDifficulty(stats: wordStats, totalWords: articleWords.count)
        // print("📈 [文章分析] 《\(article.title)》难度等级: \(difficulty.rawValue)")
        
        // 确定推荐等级
        let recommendation = determineRecommendation(matchScore: matchScore, stats: wordStats)
        // print("⭐ [文章分析] 《\(article.title)》推荐等级: \(recommendation.rawValue)")
        
        let result = ArticleMatchResult(
            article: article,
            matchScore: matchScore,
            totalWords: articleWords.count,
            unknownWords: wordStats.unknown,
            familiarWords: wordStats.familiar,
            masteredWords: wordStats.mastered,
            difficulty: difficulty,
            recommendation: recommendation
        )
        
        // print("✅ [文章分析] 《\(article.title)》分析完成")
        return result
    }
    
    // MARK: - 词汇提取
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
    
    // MARK: - 词汇过滤
    private func filterWords(_ words: [String]) -> [String] {
        let stopWords = Set([
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
            "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did",
            "will", "would", "could", "should", "may", "might", "can", "must", "shall",
            "i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
            "this", "that", "these", "those", "my", "your", "his", "her", "its", "our", "their"
        ])
        
        return words.filter { word in
            word.count >= 3 && !stopWords.contains(word)
        }
    }
    
    // MARK: - 词汇掌握情况分析
    private func analyzeWordMastery(words: Set<String>, vocabularySet: Set<String>, familiarSet: Set<String>, masteredSet: Set<String>) -> (unknown: Int, familiar: Int, mastered: Int) {
        let unknown = words.subtracting(vocabularySet.union(familiarSet).union(masteredSet)).count
        let familiar = words.intersection(familiarSet).count
        let mastered = words.intersection(masteredSet).count
        return (unknown, familiar, mastered)
    }
    
    // MARK: - 匹配分数计算
    private func calculateMatchScore(stats: (unknown: Int, familiar: Int, mastered: Int), totalWords: Int) -> Double {
        guard totalWords > 0 else { 
            // print("⚠️ [评分计算] 总词数为0，返回0分")
            return 0 
        }
        
        let unknownPercentage = Double(stats.unknown) / Double(totalWords) * 100
        let familiarPercentage = Double(stats.familiar) / Double(totalWords) * 100
        let masteredPercentage = Double(stats.mastered) / Double(totalWords) * 100
        
        // print("📊 [评分计算] 词汇百分比 - 陌生: \(String(format: "%.1f", unknownPercentage))%, 熟悉: \(String(format: "%.1f", familiarPercentage))%, 掌握: \(String(format: "%.1f", masteredPercentage))%")
        
        // 计算各项得分
        let unknownScore = calculateRangeScore(unknownPercentage, idealRange: AlgorithmParameters.idealUnknownRange)
        let familiarScore = calculateRangeScore(familiarPercentage, idealRange: AlgorithmParameters.idealFamiliarRange)
        let masteredScore = calculateRangeScore(masteredPercentage, idealRange: AlgorithmParameters.idealMasteredRange)
        
        // print("🎯 [评分计算] 各项得分 - 陌生词得分: \(String(format: "%.1f", unknownScore)), 熟悉词得分: \(String(format: "%.1f", familiarScore)), 掌握词得分: \(String(format: "%.1f", masteredScore))")
        // print("⚖️ [评分计算] 权重配置 - 陌生词权重: \(AlgorithmParameters.unknownWordWeight), 熟悉词权重: \(AlgorithmParameters.familiarWordWeight), 掌握词权重: \(AlgorithmParameters.masteredWordWeight)")
        
        // 加权计算总分
        let totalScore = unknownScore * AlgorithmParameters.unknownWordWeight +
                        familiarScore * AlgorithmParameters.familiarWordWeight +
                        masteredScore * AlgorithmParameters.masteredWordWeight
        
        let finalScore = min(max(totalScore, 0), 100)
        // print("🏆 [评分计算] 加权总分: \(String(format: "%.2f", totalScore)) → 最终得分: \(String(format: "%.2f", finalScore))")
        
        return finalScore
    }
    
    // MARK: - 范围得分计算
    private func calculateRangeScore(_ value: Double, idealRange: ClosedRange<Double>) -> Double {
        // print("📐 [范围得分] 输入百分比: \(String(format: "%.1f", value))%, 理想范围: \(idealRange.lowerBound)-\(idealRange.upperBound)%")
        
        let score: Double
        if idealRange.contains(value) {
            score = 100.0
            // print("✅ [范围得分] 在理想范围内，得分: \(score)")
        } else if value < idealRange.lowerBound {
            let distance = idealRange.lowerBound - value
            score = max(0, 100 - distance * 2)
            // print("📉 [范围得分] 低于理想范围，距离: \(String(format: "%.1f", distance))%, 得分: \(String(format: "%.1f", score))")
        } else {
            let distance = value - idealRange.upperBound
            score = max(0, 100 - distance * 1.5)
            // print("📈 [范围得分] 高于理想范围，距离: \(String(format: "%.1f", distance))%, 得分: \(String(format: "%.1f", score))")
        }
        
        return score
    }
    
    // MARK: - 难度等级确定
    private func determineDifficulty(stats: (unknown: Int, familiar: Int, mastered: Int), totalWords: Int) -> IntelligentRankingDifficultyLevel {
        guard totalWords > 0 else { 
            // print("⚠️ [难度判定] 总词数为0，返回初级难度")
            return .beginner 
        }
        
        let unknownPercentage = Double(stats.unknown) / Double(totalWords) * 100
        // print("🎯 [难度判定] 陌生词百分比: \(String(format: "%.1f", unknownPercentage))%")
        
        let difficulty: IntelligentRankingDifficultyLevel
        switch unknownPercentage {
        case 0..<15:
            difficulty = .beginner
            // print("🟢 [难度判定] 陌生词 < 15% → 初级")
        case 15..<30:
            difficulty = .intermediate
            // print("🟡 [难度判定] 陌生词 15-30% → 中级")
        case 30..<50:
            difficulty = .advanced
            // print("🟠 [难度判定] 陌生词 30-50% → 高级")
        default:
            difficulty = .expert
            // print("🔴 [难度判定] 陌生词 ≥ 50% → 专家级")
        }
        
        return difficulty
    }
    
    // MARK: - 推荐等级确定
    private func determineRecommendation(matchScore: Double, stats: (unknown: Int, familiar: Int, mastered: Int)) -> RecommendationLevel {
        // print("⭐ [推荐判定] 匹配得分: \(String(format: "%.1f", matchScore))")
        
        let recommendation: RecommendationLevel
        switch matchScore {
        case 90...100:
            recommendation = .perfect
            // print("💯 [推荐判定] 得分 90-100 → 完美匹配")
        case 75..<90:
            recommendation = .excellent
            // print("🌟 [推荐判定] 得分 75-90 → 强烈推荐")
        case 60..<75:
            recommendation = .good
            // print("👍 [推荐判定] 得分 60-75 → 推荐")
        case 40..<60:
            recommendation = .fair
            // print("👌 [推荐判定] 得分 40-60 → 一般")
        default:
            recommendation = .poor
            // print("👎 [推荐判定] 得分 < 40 → 不推荐")
        }
        
        return recommendation
    }
    
    // MARK: - 辅助方法
    // Removed createVocabularyMap, using sets instead
    
    private func generateCacheKey(articles: [Article], vocabulary: [UserWord]) -> String {
        let articleIds = articles.map { $0.id.uuidString }.sorted().joined(separator: ",")
        let vocabularyHash = vocabulary.map { "\($0.word):\($0.masteryLevel.rawValue)" }.sorted().joined(separator: ",")
        return "\(articleIds.hashValue)_\(vocabularyHash.hashValue)"
    }
    
    private func cacheResults(key: String, results: [ArticleMatchResult]) {
        // 限制缓存大小
        if rankingCache.count >= maxCacheSize {
            let oldestKey = rankingCache.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let oldestKey = oldestKey {
                rankingCache.removeValue(forKey: oldestKey)
            }
        }
        
        rankingCache[key] = (results, Date())
    }
    
    // MARK: - 公共方法
    func clearCache() {
        rankingCache.removeAll()
    }
    
    // MARK: - 分阶段排序功能
    
    /// 执行分阶段排序
    func performStagedRanking(
        articles: [Article],
        testRecord: VocabularyTest,
        dictionary: DictionaryInfo
    ) async throws -> StagedRankingResult {
        print("🎯 开始执行分阶段排序")
        
        // 第一阶段：计算文章与词典的重合度
        let stage1Results = await calculateDictionaryOverlap(
            articles: articles,
            dictionary: dictionary
        )
        
        // 第二阶段：基于用户掌握情况排序
        let stage2Results = await calculateUserMasteryRanking(
            articles: articles,
            testRecord: testRecord,
            dictionary: dictionary
        )
        
        let result = StagedRankingResult(
            stage1Results: stage1Results,
            stage2Results: stage2Results,
            testRecord: testRecord,
            dictionary: dictionary
        )
        
        print("✅ 分阶段排序完成，第一阶段 \(stage1Results.count) 篇文章，第二阶段 \(stage2Results.count) 篇文章")
        return result
    }
    
    /// 第一阶段：计算文章与词典的重合度
    private func calculateDictionaryOverlap(
        articles: [Article],
        dictionary: DictionaryInfo
    ) async -> [DictionaryOverlapInfo] {
        print("📊 第一阶段：计算文章与词典重合度")
        
        guard let dictionaryWords = await getDictionaryVocabulary(dictionaryName: dictionary.name) else {
            print("❌ 无法获取词典词汇")
            return []
        }
        
        var results: [DictionaryOverlapInfo] = []
        
        for article in articles {
            let articleWords = Set(extractWordsFromArticle(article))
            let overlapWords = articleWords.intersection(dictionaryWords)
            
            let overlapInfo = DictionaryOverlapInfo(
                dictionaryId: dictionary.id,
                article: article,
                totalWords: articleWords.count,
                overlapWords: overlapWords.count,
                overlapWordsList: Array(overlapWords)
            )
            
            results.append(overlapInfo)
        }
        
        // 按重合度降序排序
        results.sort { $0.overlapPercentage > $1.overlapPercentage }
        
        print("✅ 第一阶段完成，平均重合度: \(results.map { $0.overlapPercentage }.reduce(0, +) / Double(results.count))%")
        return results
    }
    
    /// 第二阶段：基于用户掌握情况排序
    private func calculateUserMasteryRanking(
        articles: [Article],
        testRecord: VocabularyTest,
        dictionary: DictionaryInfo
    ) async -> [UserMasteryInfo] {
        print("🎓 第二阶段：基于用户掌握情况排序")
        
        guard let dictionaryWords = await getDictionaryVocabulary(dictionaryName: dictionary.name) else {
            print("❌ 无法获取词典词汇")
            return []
        }
        
        // 从测试记录中提取用户掌握情况
        let userMastery = extractUserMasteryFromTest(testRecord: testRecord, dictionaryWords: dictionaryWords)
        
        var results: [UserMasteryInfo] = []
        
        for article in articles {
            let articleWords = Set(extractWordsFromArticle(article))
            let dictionaryWordsInArticle = articleWords.intersection(dictionaryWords)
            
            // 计算各掌握程度的词汇数量
            let masteredCount = dictionaryWordsInArticle.intersection(userMastery.mastered).count
            let familiarCount = dictionaryWordsInArticle.intersection(userMastery.familiar).count
            let unknownCount = dictionaryWordsInArticle.intersection(userMastery.unknown).count
            
            let masteryInfo = UserMasteryInfo(
                article: article,
                masteredCount: masteredCount,
                familiarCount: familiarCount,
                unfamiliarCount: unknownCount,
                masteredWords: Array(dictionaryWordsInArticle.intersection(userMastery.mastered)),
                unfamiliarWords: Array(dictionaryWordsInArticle.intersection(userMastery.unknown))
            )
            
            results.append(masteryInfo)
        }
        
        // 按掌握度分数降序排序
        results.sort { $0.rankingScore > $1.rankingScore }
        
        print("✅ 第二阶段完成，平均掌握度分数: \(results.map { $0.rankingScore }.reduce(0, +) / Double(results.count))")
        return results
    }
    
    /// 从测试记录中提取用户掌握情况
    private func extractUserMasteryFromTest(
        testRecord: VocabularyTest,
        dictionaryWords: Set<String>
    ) -> (mastered: Set<String>, familiar: Set<String>, unknown: Set<String>) {
        var mastered = Set<String>()
        var familiar = Set<String>()
        var unknown = Set<String>()
        
        for result in testRecord.getTestResults() {
            let word = result.word.lowercased()
            if dictionaryWords.contains(word) {
                if result.isKnown {
                    // 根据响应时间判断是掌握还是熟悉
                    if result.responseTime < 2.0 {
                        mastered.insert(word)
                    } else {
                        familiar.insert(word)
                    }
                } else {
                    unknown.insert(word)
                }
            }
        }
        
        return (mastered: mastered, familiar: familiar, unknown: unknown)
    }
    
    /// 计算基于掌握情况的推荐度
    private func calculateMasteryRecommendation(
        mastered: Int,
        familiar: Int,
        unknown: Int,
        total: Int
    ) -> RecommendationLevel {
        guard total > 0 else { return .poor }
        
        let masteredPercentage = Double(mastered) / Double(total) * 100
        let familiarPercentage = Double(familiar) / Double(total) * 100
        let unknownPercentage = Double(unknown) / Double(total) * 100
        
        // 理想分布：已掌握 40-60%，熟悉 20-40%，不熟悉 10-30%
        if masteredPercentage >= 40 && masteredPercentage <= 60 &&
           familiarPercentage >= 20 && familiarPercentage <= 40 &&
           unknownPercentage >= 10 && unknownPercentage <= 30 {
            return .perfect
        } else if masteredPercentage >= 30 && unknownPercentage <= 40 {
            return .excellent
        } else if masteredPercentage >= 20 && unknownPercentage <= 50 {
            return .good
        } else if unknownPercentage <= 60 {
            return .fair
        } else {
            return .poor
        }
    }
    
    func sortResults(_ results: [ArticleMatchResult], by option: RankingSortOption) -> [ArticleMatchResult] {
        switch option {
        case .matchScore:
            return results.sorted { $0.matchScore > $1.matchScore }
        case .difficulty:
            return results.sorted { $0.difficulty.rawValue < $1.difficulty.rawValue }
        case .recommendation:
            return results.sorted { $0.recommendation.priority > $1.recommendation.priority }
        case .unknownWords:
            // 生词数量：越多越靠前（降序）
            return results.sorted { $0.unknownWords > $1.unknownWords }
        case .articleLength:
            // 文章长度：越长越靠前（降序）
            return results.sorted { $0.totalWords > $1.totalWords }
        case .keywordReading:
            return sortByKeyword(results, keyword: "阅读理解")
        case .keywordTranslation:
            return sortByKeyword(results, keyword: "翻译")
        case .keywordWriting:
            return sortByKeyword(results, keyword: "写作")
        case .keywordKnowledge:
            return sortByKeyword(results, keyword: "知识运用")
        }
    }
    
    // MARK: - 基于关键词的排序方法
    private func sortByKeyword(_ results: [ArticleMatchResult], keyword: String) -> [ArticleMatchResult] {
        print("🔍 按关键词排序: \(keyword)")
        
        return results.sorted { result1, result2 in
            // 检查标题是否包含关键词（优先级最高）
            let titleMatch1 = result1.article.title.contains(keyword)
            let titleMatch2 = result2.article.title.contains(keyword)
            
            // 检查考试类型是否包含关键词（优先级中等）
            let examTypeMatch1 = result1.article.examType.contains(keyword)
            let examTypeMatch2 = result2.article.examType.contains(keyword)
            
            // 检查内容是否包含关键词（优先级较低）
            let contentMatch1 = result1.article.content.contains(keyword)
            let contentMatch2 = result2.article.content.contains(keyword)
            
            // 计算匹配权重分数
            let score1 = calculateKeywordMatchScore(
                titleMatch: titleMatch1,
                examTypeMatch: examTypeMatch1,
                contentMatch: contentMatch1,
                matchScore: result1.matchScore
            )
            
            let score2 = calculateKeywordMatchScore(
                titleMatch: titleMatch2,
                examTypeMatch: examTypeMatch2,
                contentMatch: contentMatch2,
                matchScore: result2.matchScore
            )
            
            return score1 > score2
        }
    }
    
    /// 计算关键词匹配分数
    private func calculateKeywordMatchScore(
        titleMatch: Bool,
        examTypeMatch: Bool,
        contentMatch: Bool,
        matchScore: Double
    ) -> Double {
        var score = matchScore // 基础匹配分数
        
        // 标题匹配加权最高
        if titleMatch {
            score += 50.0
        }
        
        // 考试类型匹配加权中等
        if examTypeMatch {
            score += 30.0
        }
        
        // 内容匹配加权较低
        if contentMatch {
            score += 10.0
        }
        
        return score
    }
}