//
//  WordLookupRecord.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData

// 单词查询记录
@Model
final class WordLookupRecord: @unchecked Sendable {
    var id: UUID
    var word: String
    var articleId: String
    var lookupDate: Date
    var context: String? // 查词时的上下文
    var isNewWord: Bool // 是否为新单词
    
    init(word: String, articleId: String, context: String? = nil, isNewWord: Bool = true) {
        self.id = UUID()
        self.word = word
        self.articleId = articleId
        self.lookupDate = Date()
        self.context = context
        self.isNewWord = isNewWord
    }
}