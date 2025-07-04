//
//  Article.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Article: @unchecked Sendable {
    var id: UUID
    var title: String
    var content: String
    var year: Int
    var examType: String // "考研一", "考研二", etc.
    var difficulty: ArticleDifficulty
    var topic: String
    var wordCount: Int
    var isCompleted: Bool
    var isBookmarked: Bool
    var readingProgress: Double // 0.0 - 1.0
    var lastReadDate: Date?
    var readingTime: TimeInterval // 总阅读时间（秒）
    var createdDate: Date
    var imageName: String // 新增图片名称属性
    
    // 关联的用户查词记录
    @Relationship(deleteRule: .cascade, inverse: \UserWordRecord.article)
    var wordRecords: [UserWordRecord] = []
    
    init(title: String, content: String, year: Int, examType: String, difficulty: ArticleDifficulty, topic: String, imageName: String) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.year = year
        self.examType = examType
        self.difficulty = difficulty
        self.topic = topic
        self.imageName = imageName
        self.wordCount = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        self.isCompleted = false
        self.isBookmarked = false
        self.readingProgress = 0.0
        self.lastReadDate = nil
        self.readingTime = 0
        self.createdDate = Date()
    }
}

enum ArticleDifficulty: String, CaseIterable, Codable {
    case easy = "简单"
    case medium = "中等"
    case hard = "困难"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .easy:
            return .green
        case .medium:
            return .orange
        case .hard:
            return .red
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .easy:
            return 1
        case .medium:
            return 2
        case .hard:
            return 3
        }
    }
}

// 文章段落模型，用于更精细的阅读控制
struct ArticleParagraph: Identifiable, Codable {
    var id = UUID()
    let content: String
    let index: Int
    var translation: String?
    var isTranslationVisible: Bool = false
    
    init(content: String, index: Int, translation: String? = nil) {
        self.content = content
        self.index = index
        self.translation = translation
    }
    
    // 兼容性属性
    var text: String {
        return content
    }
    
    var sentences: [ArticleSentence] {
        return content.components(separatedBy: ".")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .enumerated()
            .map { sentenceIndex, content in
                ArticleSentence(
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines) + ".",
                    paragraphIndex: index,
                    sentenceIndex: sentenceIndex
                )
            }
    }
}

// 文章句子模型，用于句子级别的翻译
struct ArticleSentence: Identifiable, Codable {
    var id = UUID()
    let content: String
    let paragraphIndex: Int
    let sentenceIndex: Int
    var translation: String?
    var grammarAnalysis: String?
    var isTranslationVisible: Bool = false
    
    init(content: String, paragraphIndex: Int, sentenceIndex: Int, translation: String? = nil, grammarAnalysis: String? = nil) {
        self.content = content
        self.paragraphIndex = paragraphIndex
        self.sentenceIndex = sentenceIndex
        self.translation = translation
        self.grammarAnalysis = grammarAnalysis
    }
    
    // 兼容性属性
    var text: String {
        return content
    }
}

extension Article {
    // 兼容性属性
    var paragraphs: [ArticleParagraph] {
        return getParagraphs()
    }
    
    // 获取文章的段落
    func getParagraphs() -> [ArticleParagraph] {
        let paragraphs = content.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .enumerated()
            .map { index, content in
                ArticleParagraph(content: content.trimmingCharacters(in: .whitespacesAndNewlines), index: index)
            }
        return paragraphs
    }
    
    // 获取文章的句子
    func getSentences() -> [ArticleSentence] {
        var sentences: [ArticleSentence] = []
        let paragraphs = getParagraphs()
        
        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            let paragraphSentences = paragraph.content.components(separatedBy: ".")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .enumerated()
                .map { sentenceIndex, content in
                    ArticleSentence(
                        content: content.trimmingCharacters(in: .whitespacesAndNewlines) + ".",
                        paragraphIndex: paragraphIndex,
                        sentenceIndex: sentenceIndex
                    )
                }
            sentences.append(contentsOf: paragraphSentences)
        }
        
        return sentences
    }
    
    // 更新阅读进度
    func updateProgress(_ progress: Double) {
        self.readingProgress = min(max(progress, 0.0), 1.0)
        self.lastReadDate = Date()
        
        if readingProgress >= 1.0 {
            self.isCompleted = true
        }
    }
    
    // 增加阅读时间
    func addReadingTime(_ time: TimeInterval) {
        self.readingTime += time
    }
    
    // 获取预估阅读时间（分钟）
    var estimatedReadingTime: Int {
        // 假设平均阅读速度为200词/分钟
        return max(1, wordCount / 200)
    }
    
    // 获取阅读完成百分比字符串
    var progressPercentage: String {
        return String(format: "%.0f%%", readingProgress * 100)
    }
}