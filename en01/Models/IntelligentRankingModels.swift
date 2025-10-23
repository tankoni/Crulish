//
//  IntelligentRankingModels.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation

// MARK: - 智能排序相关数据模型

/// 排序结果项
struct RankedArticle {
    let article: Article
    let score: Double
    let rank: Int
    
    init(article: Article, score: Double, rank: Int = 0) {
        self.article = article
        self.score = score
        self.rank = rank
    }
}

/// 排序选项
enum SortOption: String, CaseIterable {
    case difficulty = "难度"
    case length = "长度"
    case relevance = "相关性"
    case date = "日期"
    
    var systemImage: String {
        switch self {
        case .difficulty: return "chart.bar"
        case .length: return "doc.text"
        case .relevance: return "star"
        case .date: return "calendar"
        }
    }
}

/// 排序方向
enum SortDirection: String, CaseIterable {
    case ascending = "升序"
    case descending = "降序"
    
    var systemImage: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
}

/// 智能排序配置
struct IntelligentRankingConfig {
    let sortOption: SortOption
    let sortDirection: SortDirection
    let useUserPreferences: Bool
    let considerReadingHistory: Bool
    
    static let `default` = IntelligentRankingConfig(
        sortOption: .relevance,
        sortDirection: .descending,
        useUserPreferences: true,
        considerReadingHistory: true
    )
}