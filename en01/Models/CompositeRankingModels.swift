//
//  CompositeRankingModels.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation
import SwiftUI

// MARK: - 排序条件
struct SortCriteria: Identifiable, Equatable {
    let id: String
    let option: RankingSortOption
    let direction: CompositeRankingSortDirection
    var weight: Double // 权重 0.0-1.0
    let isEnabled: Bool
    
    init(option: RankingSortOption, direction: CompositeRankingSortDirection = .descending, weight: Double = 1.0, isEnabled: Bool = true) {
        self.id = UUID().uuidString
        self.option = option
        self.direction = direction
        self.weight = max(0.0, min(1.0, weight))
        self.isEnabled = isEnabled
    }
    
    static func == (lhs: SortCriteria, rhs: SortCriteria) -> Bool {
        return lhs.option == rhs.option && 
               lhs.direction == rhs.direction && 
               lhs.weight == rhs.weight && 
               lhs.isEnabled == rhs.isEnabled
    }
}

// MARK: - 组合排序专用的排序方向枚举
enum CompositeRankingSortDirection: String, CaseIterable, Codable {
    case ascending = "升序"
    case descending = "降序"
    
    var systemImage: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
    
    var shortName: String {
        switch self {
        case .ascending: return "↑"
        case .descending: return "↓"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - 组合排序配置
struct CompositeRankingConfig {
    var criteria: [SortCriteria]
    var useDictionaryIntegration: Bool
    var selectedDictionaryId: UUID?
    var useTestResults: Bool
    var selectedTestId: UUID?
    
    init(criteria: [SortCriteria] = [], 
         useDictionaryIntegration: Bool = false,
         selectedDictionaryId: UUID? = nil,
         useTestResults: Bool = false,
         selectedTestId: UUID? = nil) {
        self.criteria = criteria
        self.useDictionaryIntegration = useDictionaryIntegration
        self.selectedDictionaryId = selectedDictionaryId
        self.useTestResults = useTestResults
        self.selectedTestId = selectedTestId
    }
    
    var enabledCriteria: [SortCriteria] {
        return criteria.filter { $0.isEnabled }
    }
    
    var hasValidConfiguration: Bool {
        return !enabledCriteria.isEmpty
    }
    
    // 默认配置
    static let `default` = CompositeRankingConfig(
        criteria: [
            SortCriteria(option: RankingSortOption.matchScore, direction: CompositeRankingSortDirection.descending, weight: 0.4),
            SortCriteria(option: RankingSortOption.unknownWords, direction: CompositeRankingSortDirection.ascending, weight: 0.3),
            SortCriteria(option: RankingSortOption.recommendation, direction: CompositeRankingSortDirection.descending, weight: 0.3)
        ],
        useDictionaryIntegration: true,
        useTestResults: true
    )
}

// MARK: - 排序结果项（扩展）
struct CompositeRankedArticle {
    let article: Article
    let baseResult: ArticleMatchResult
    let compositeScore: Double
    let criteriaScores: [RankingSortOption: Double]
    let rank: Int
    let dictionaryMatchInfo: DictionaryMatchInfo?
    let testResultInfo: TestResultInfo?
    
    init(article: Article, 
         baseResult: ArticleMatchResult, 
         compositeScore: Double,
         criteriaScores: [RankingSortOption: Double] = [:],
         rank: Int = 0,
         dictionaryMatchInfo: DictionaryMatchInfo? = nil,
         testResultInfo: TestResultInfo? = nil) {
        self.article = article
        self.baseResult = baseResult
        self.compositeScore = compositeScore
        self.criteriaScores = criteriaScores
        self.rank = rank
        self.dictionaryMatchInfo = dictionaryMatchInfo
        self.testResultInfo = testResultInfo
    }
}

// MARK: - 词典匹配信息
struct DictionaryMatchInfo {
    let dictionaryId: UUID
    let dictionaryName: String
    let overlapCount: Int
    let overlapPercentage: Double
    let dictionaryWords: Set<String>
    let matchedWords: Set<String>
    
    var matchQuality: MatchQuality {
        switch overlapPercentage {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .veryPoor
        }
    }
}

// MARK: - 测试结果信息
struct TestResultInfo {
    let testId: UUID
    let testDate: Date
    let masteredWords: Set<String>
    let familiarWords: Set<String>
    let unknownWords: Set<String>
    let accuracyPercentage: Double
    let estimatedVocabularySize: Int
    
    var masteryLevel: TestMasteryLevel {
        switch accuracyPercentage {
        case 90...100: return .expert
        case 80..<90: return .advanced
        case 70..<80: return .intermediate
        case 60..<70: return .beginner
        default: return .unknown
        }
    }
}

// MARK: - 匹配质量枚举
enum MatchQuality: String, CaseIterable {
    case excellent = "优秀"
    case good = "良好"
    case fair = "一般"
    case poor = "较差"
    case veryPoor = "很差"
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .veryPoor: return .gray
        }
    }
    
    var score: Double {
        switch self {
        case .excellent: return 1.0
        case .good: return 0.8
        case .fair: return 0.6
        case .poor: return 0.4
        case .veryPoor: return 0.2
        }
    }
}

// MARK: - 测试掌握水平枚举
enum TestMasteryLevel: String, CaseIterable {
    case expert = "专家"
    case advanced = "高级"
    case intermediate = "中级"
    case beginner = "初级"
    case unknown = "未知"
    
    var color: Color {
        switch self {
        case .expert: return .purple
        case .advanced: return .blue
        case .intermediate: return .green
        case .beginner: return .orange
        case .unknown: return .gray
        }
    }
    
    var score: Double {
        switch self {
        case .expert: return 1.0
        case .advanced: return 0.8
        case .intermediate: return 0.6
        case .beginner: return 0.4
        case .unknown: return 0.2
        }
    }
}

// MARK: - 排序预设配置
enum SortPreset: String, CaseIterable {
    case balanced = "均衡推荐"
    case vocabularyFocused = "词汇导向"
    case difficultyProgressive = "难度递进"
    case lengthOptimized = "长度优化"
    case testBased = "测试导向"
    case custom = "自定义"
    
    var config: CompositeRankingConfig {
        switch self {
        case .balanced:
            return CompositeRankingConfig(criteria: [
                SortCriteria(option: RankingSortOption.matchScore, direction: CompositeRankingSortDirection.descending, weight: 0.3),
                SortCriteria(option: RankingSortOption.recommendation, direction: CompositeRankingSortDirection.descending, weight: 0.3),
                SortCriteria(option: RankingSortOption.unknownWords, direction: CompositeRankingSortDirection.ascending, weight: 0.2),
                SortCriteria(option: RankingSortOption.difficulty, direction: CompositeRankingSortDirection.ascending, weight: 0.2)
            ])
        case .vocabularyFocused:
            return CompositeRankingConfig(criteria: [
                SortCriteria(option: RankingSortOption.unknownWords, direction: CompositeRankingSortDirection.ascending, weight: 0.5),
                SortCriteria(option: RankingSortOption.matchScore, direction: CompositeRankingSortDirection.descending, weight: 0.3),
                SortCriteria(option: RankingSortOption.articleLength, direction: CompositeRankingSortDirection.ascending, weight: 0.2)
            ])
        case .difficultyProgressive:
            return CompositeRankingConfig(criteria: [
                SortCriteria(option: RankingSortOption.difficulty, direction: CompositeRankingSortDirection.ascending, weight: 0.4),
                SortCriteria(option: RankingSortOption.unknownWords, direction: CompositeRankingSortDirection.ascending, weight: 0.3),
                SortCriteria(option: RankingSortOption.recommendation, direction: CompositeRankingSortDirection.descending, weight: 0.3)
            ])
        case .lengthOptimized:
            return CompositeRankingConfig(criteria: [
                SortCriteria(option: RankingSortOption.articleLength, direction: CompositeRankingSortDirection.ascending, weight: 0.4),
                SortCriteria(option: RankingSortOption.matchScore, direction: CompositeRankingSortDirection.descending, weight: 0.3),
                SortCriteria(option: RankingSortOption.unknownWords, direction: CompositeRankingSortDirection.ascending, weight: 0.3)
            ])
        case .testBased:
            return CompositeRankingConfig(criteria: [
                SortCriteria(option: RankingSortOption.matchScore, direction: CompositeRankingSortDirection.descending, weight: 0.4),
                SortCriteria(option: RankingSortOption.unknownWords, direction: CompositeRankingSortDirection.ascending, weight: 0.3),
                SortCriteria(option: RankingSortOption.recommendation, direction: CompositeRankingSortDirection.descending, weight: 0.3)
            ], useTestResults: true)
        case .custom:
            return CompositeRankingConfig.default
        }
    }
    
    var sortPresetDescription: String {
        switch self {
        case .balanced: return "综合考虑匹配度、推荐度和词汇难度"
        case .vocabularyFocused: return "优先考虑生词数量和词汇匹配度"
        case .difficultyProgressive: return "按难度递进，适合循序渐进学习"
        case .lengthOptimized: return "优先推荐适中长度的文章"
        case .testBased: return "基于词汇测试结果进行智能推荐"
        case .custom: return "自定义排序条件和权重"
    }
    }
    
    var systemImage: String {
        switch self {
        case .balanced: return "scale.3d"
        case .vocabularyFocused: return "book.fill"
        case .difficultyProgressive: return "chart.line.uptrend.xyaxis"
        case .lengthOptimized: return "doc.text"
        case .testBased: return "checkmark.circle.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}