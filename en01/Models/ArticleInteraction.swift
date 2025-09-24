//
//  ArticleInteraction.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation

/// 文章交互记录
struct ArticleInteraction {
    let articleId: UUID
    let userId: String
    let startTime: Date
    let endTime: Date?
    let completed: Bool
    let readingProgress: Double // 0.0 - 1.0
    let wordsLookedUp: Int
    let timeSpent: TimeInterval
    let interactionType: ArticleInteractionType
    
    var duration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        }
        return timeSpent
    }
}

/// 文章交互类型
enum ArticleInteractionType: String, CaseIterable {
    case read = "read"
    case skimmed = "skimmed"
    case studied = "studied"
    case abandoned = "abandoned"
    
    var displayName: String {
        switch self {
        case .read:
            return "阅读"
        case .skimmed:
            return "浏览"
        case .studied:
            return "精读"
        case .abandoned:
            return "放弃"
        }
    }
}

/// 文章交互统计
struct ArticleInteractionStats {
    let totalInteractions: Int
    let averageReadingTime: TimeInterval
    let completionRate: Double
    let averageWordsLookedUp: Double
    let mostCommonInteractionType: ArticleInteractionType?
    
    var formattedAverageReadingTime: String {
        let minutes = Int(averageReadingTime / 60)
        let seconds = Int(averageReadingTime.truncatingRemainder(dividingBy: 60))
        return "\(minutes)分\(seconds)秒"
    }
    
    var formattedCompletionRate: String {
        return String(format: "%.1f%%", completionRate * 100)
    }
}