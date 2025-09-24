//
//  WordReviewRecord.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData

// 单词复习记录
@Model
final class WordReviewRecord: @unchecked Sendable {
    var id: UUID
    var word: String
    var correct: Bool
    var reviewDate: Date
    var responseTime: TimeInterval // 响应时间（秒）
    
    init(word: String, correct: Bool, responseTime: TimeInterval = 0) {
        self.id = UUID()
        self.word = word
        self.correct = correct
        self.reviewDate = Date()
        self.responseTime = responseTime
    }
}