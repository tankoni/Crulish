//
//  WordTestResult.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation

/// 单词测试结果数据模型
struct WordTestResult {
    let word: String
    let isKnown: Bool
    let timestamp: Date
    
    init(word: String, isKnown: Bool, timestamp: Date = Date()) {
        self.word = word
        self.isKnown = isKnown
        self.timestamp = timestamp
    }
}

// MARK: - Codable
extension WordTestResult: Codable {}

// MARK: - Identifiable
extension WordTestResult: Identifiable {
    var id: String {
        return "\(word)_\(timestamp.timeIntervalSince1970)"
    }
}

// MARK: - Equatable
extension WordTestResult: Equatable {
    static func == (lhs: WordTestResult, rhs: WordTestResult) -> Bool {
        return lhs.word == rhs.word && 
               lhs.isKnown == rhs.isKnown && 
               lhs.timestamp == rhs.timestamp
    }
}