//
//  IntelligentRankingService.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation
import SwiftUI

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
    case intermediate = "中级"
    case advanced = "高级"
    case expert = "专家"
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
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

// MARK: - 排序选项
enum RankingSortOption: String, CaseIterable {
    case matchScore = "匹配度"
    case difficulty = "难度"
    case recommendation = "推荐度"
    case unknownWords = "生词数量"
    case articleLength = "文章长度"
}

// MARK: - 智能排序服务
@MainActor
class IntelligentRankingService: ObservableObject {
    
    // MARK: - Properties
    private let dictionaryService: DictionaryServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    
    // 缓存机制
    private var rankingCache: [String: (results: [ArticleMatchResult], timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟
    private let maxCacheSize = 50
    
    // 算法参数
    private struct AlgorithmParameters {
        static let unknownWordWeight: Double = 0.4
        static let familiarWordWeight: Double = 0.3
        static let masteredWordWeight: Double = 0.2
        static let lengthWeight: Double = 0.1
        
        // 理想的生词比例范围
        static let idealUnknownRange: ClosedRange<Double> = 10.0...25.0
        static let idealFamiliarRange: ClosedRange<Double> = 30.0...50.0
        static let idealMasteredRange: ClosedRange<Double> = 25.0...60.0
    }
    
    // MARK: - Initialization
    init(dictionaryService: DictionaryServiceProtocol? = nil) {
        self.dictionaryService = dictionaryService ?? ServiceContainer.shared.getDictionaryService()
        self.errorHandler = ServiceContainer.shared.getErrorHandler()
    }
    
    // MARK: - 核心排序算法
    func rankArticles(_ articles: [Article], userVocabulary: [UserWord]) async -> [ArticleMatchResult] {
        let cacheKey = generateCacheKey(articles: articles, vocabulary: userVocabulary)
        
        // 检查缓存
        if let cached = rankingCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
            return cached.results
        }
        
        // 计算匹配度
        let results = await calculateMatchScores(articles: articles, userVocabulary: userVocabulary)
        
        // 缓存结果
        cacheResults(key: cacheKey, results: results)
        
        return results
    }
    
    // MARK: - 匹配度计算
    private func calculateMatchScores(articles: [Article], userVocabulary: [UserWord]) async -> [ArticleMatchResult] {
        let vocabularyMap = createVocabularyMap(userVocabulary)
        
        return await withTaskGroup(of: ArticleMatchResult?.self) { group in
            for article in articles {
                group.addTask {
                    await self.calculateArticleMatch(article: article, vocabularyMap: vocabularyMap)
                }
            }
            
            var results: [ArticleMatchResult] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            
            return results.sorted { $0.matchScore > $1.matchScore }
        }
    }
    
    // MARK: - 单篇文章匹配度计算
    private func calculateArticleMatch(article: Article, vocabularyMap: [String: MasteryLevel]) async -> ArticleMatchResult? {
        // 提取文章词汇
        let articleWords = extractWordsFromArticle(article)
        guard !articleWords.isEmpty else { return nil }
        
        // 统计词汇掌握情况
        let wordStats = analyzeWordMastery(words: articleWords, vocabularyMap: vocabularyMap)
        
        // 计算匹配分数
        let matchScore = calculateMatchScore(stats: wordStats, totalWords: articleWords.count)
        
        // 确定难度等级
        let difficulty = determineDifficulty(stats: wordStats, totalWords: articleWords.count)
        
        // 确定推荐等级
        let recommendation = determineRecommendation(matchScore: matchScore, stats: wordStats)
        
        return ArticleMatchResult(
            article: article,
            matchScore: matchScore,
            totalWords: articleWords.count,
            unknownWords: wordStats.unknown,
            familiarWords: wordStats.familiar,
            masteredWords: wordStats.mastered,
            difficulty: difficulty,
            recommendation: recommendation
        )
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
    private func analyzeWordMastery(words: [String], vocabularyMap: [String: MasteryLevel]) -> (unknown: Int, familiar: Int, mastered: Int) {
        var unknown = 0
        var familiar = 0
        var mastered = 0
        
        for word in words {
            switch vocabularyMap[word] {
            case .unfamiliar, .none:
                unknown += 1
            case .familiar:
                familiar += 1
            case .mastered:
                mastered += 1
            }
        }
        
        return (unknown, familiar, mastered)
    }
    
    // MARK: - 匹配分数计算
    private func calculateMatchScore(stats: (unknown: Int, familiar: Int, mastered: Int), totalWords: Int) -> Double {
        guard totalWords > 0 else { return 0 }
        
        let unknownPercentage = Double(stats.unknown) / Double(totalWords) * 100
        let familiarPercentage = Double(stats.familiar) / Double(totalWords) * 100
        let masteredPercentage = Double(stats.mastered) / Double(totalWords) * 100
        
        // 计算各项得分
        let unknownScore = calculateRangeScore(unknownPercentage, idealRange: AlgorithmParameters.idealUnknownRange)
        let familiarScore = calculateRangeScore(familiarPercentage, idealRange: AlgorithmParameters.idealFamiliarRange)
        let masteredScore = calculateRangeScore(masteredPercentage, idealRange: AlgorithmParameters.idealMasteredRange)
        
        // 加权计算总分
        let totalScore = unknownScore * AlgorithmParameters.unknownWordWeight +
                        familiarScore * AlgorithmParameters.familiarWordWeight +
                        masteredScore * AlgorithmParameters.masteredWordWeight
        
        return min(max(totalScore, 0), 100)
    }
    
    // MARK: - 范围得分计算
    private func calculateRangeScore(_ value: Double, idealRange: ClosedRange<Double>) -> Double {
        if idealRange.contains(value) {
            return 100.0
        } else if value < idealRange.lowerBound {
            let distance = idealRange.lowerBound - value
            return max(0, 100 - distance * 2)
        } else {
            let distance = value - idealRange.upperBound
            return max(0, 100 - distance * 1.5)
        }
    }
    
    // MARK: - 难度等级确定
    private func determineDifficulty(stats: (unknown: Int, familiar: Int, mastered: Int), totalWords: Int) -> IntelligentRankingDifficultyLevel {
        guard totalWords > 0 else { return .beginner }
        
        let unknownPercentage = Double(stats.unknown) / Double(totalWords) * 100
        
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
    
    // MARK: - 推荐等级确定
    private func determineRecommendation(matchScore: Double, stats: (unknown: Int, familiar: Int, mastered: Int)) -> RecommendationLevel {
        switch matchScore {
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
    
    // MARK: - 辅助方法
    private func createVocabularyMap(_ vocabulary: [UserWord]) -> [String: MasteryLevel] {
        var map: [String: MasteryLevel] = [:]
        for word in vocabulary {
            map[word.word.lowercased()] = word.masteryLevel
        }
        return map
    }
    
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
    
    func sortResults(_ results: [ArticleMatchResult], by option: RankingSortOption) -> [ArticleMatchResult] {
        switch option {
        case .matchScore:
            return results.sorted { $0.matchScore > $1.matchScore }
        case .difficulty:
            return results.sorted { $0.difficulty.rawValue < $1.difficulty.rawValue }
        case .recommendation:
            return results.sorted { $0.recommendation.priority > $1.recommendation.priority }
        case .unknownWords:
            return results.sorted { $0.unknownWords < $1.unknownWords }
        case .articleLength:
            return results.sorted { $0.totalWords < $1.totalWords }
        }
    }
}