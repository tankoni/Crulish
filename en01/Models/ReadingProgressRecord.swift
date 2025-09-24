//
//  ReadingProgressRecord.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData

// 阅读进度记录
@Model
final class ReadingProgressRecord: @unchecked Sendable {
    var id: UUID
    var articleId: String
    var progress: Double // 0.0 - 1.0
    var totalReadingTime: TimeInterval
    var lastReadTime: Date
    
    init(articleId: String, progress: Double, totalReadingTime: TimeInterval, lastReadTime: Date) {
        self.id = UUID()
        self.articleId = articleId
        self.progress = progress
        self.totalReadingTime = totalReadingTime
        self.lastReadTime = lastReadTime
    }
}

// MARK: - Codable Support
extension ReadingProgressRecord: Codable {
    enum CodingKeys: CodingKey {
        case id, articleId, progress, totalReadingTime, lastReadTime
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let articleId = try container.decode(String.self, forKey: .articleId)
        let progress = try container.decode(Double.self, forKey: .progress)
        let totalReadingTime = try container.decode(TimeInterval.self, forKey: .totalReadingTime)
        let lastReadTime = try container.decode(Date.self, forKey: .lastReadTime)
        
        self.init(articleId: articleId, progress: progress, totalReadingTime: totalReadingTime, lastReadTime: lastReadTime)
        self.id = id
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(articleId, forKey: .articleId)
        try container.encode(progress, forKey: .progress)
        try container.encode(totalReadingTime, forKey: .totalReadingTime)
        try container.encode(lastReadTime, forKey: .lastReadTime)
    }
}