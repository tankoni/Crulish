//
//  ArticleCompletionRecord.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData

// 文章完成记录
@Model
final class ArticleCompletionRecord: @unchecked Sendable {
    var id: UUID
    var articleId: String
    var completionDate: Date
    var readingTime: TimeInterval // 阅读用时（秒）
    var wordsLookedUp: Int // 查词次数
    var comprehensionScore: Double? // 理解分数（可选）
    
    init(articleId: String, readingTime: TimeInterval, wordsLookedUp: Int, comprehensionScore: Double? = nil) {
        self.id = UUID()
        self.articleId = articleId
        self.completionDate = Date()
        self.readingTime = readingTime
        self.wordsLookedUp = wordsLookedUp
        self.comprehensionScore = comprehensionScore
    }
}