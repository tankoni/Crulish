//
//  ReviewSessionRecord.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData

// 复习会话记录
@Model
final class ReviewSessionRecord: @unchecked Sendable {
    var id: UUID
    var sessionDate: Date
    var wordsReviewed: Int
    var correctAnswers: Int
    var totalTime: TimeInterval // 总用时（秒）
    var averageResponseTime: TimeInterval // 平均响应时间（秒）
    
    init(wordsReviewed: Int, correctAnswers: Int, totalTime: TimeInterval = 0) {
        self.id = UUID()
        self.sessionDate = Date()
        self.wordsReviewed = wordsReviewed
        self.correctAnswers = correctAnswers
        self.totalTime = totalTime
        self.averageResponseTime = wordsReviewed > 0 ? totalTime / Double(wordsReviewed) : 0
    }
    
    var accuracy: Double {
        return wordsReviewed > 0 ? Double(correctAnswers) / Double(wordsReviewed) : 0
    }
}