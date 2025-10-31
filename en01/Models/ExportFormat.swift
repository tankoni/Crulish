//
//  ExportFormat.swift
//  en01
//
//  Created by AI Assistant on 2024/12/26.
//

import Foundation
import SwiftData

/// 导出格式枚举
enum ExportFormat: String, CaseIterable {
    case text = "txt"
    case csv = "csv"
    case json = "json"
    case markdown = "md"
    case pdf = "pdf"
    
    var displayName: String {
        switch self {
        case .text:
            return "Text"
        case .csv:
            return "CSV"
        case .json:
            return "JSON"
        case .markdown:
            return "Markdown"
        case .pdf:
            return "PDF"
        }
    }
    
    var fileExtension: String {
        return self.rawValue
    }
    
    var mimeType: String {
        switch self {
        case .text:
            return "text/plain"
        case .csv:
            return "text/csv"
        case .json:
            return "application/json"
        case .markdown:
            return "text/markdown"
        case .pdf:
            return "application/pdf"
        }
    }
}

/// 可导出的测试结果数据结构
struct ExportableTestResult: Codable {
    let dictionaryName: String
    let testDate: Date
    let exportDate: Date
    let knownWords: [ExportableWord]
    let unknownWords: [ExportableWord]
    
    var totalWords: Int {
        return knownWords.count + unknownWords.count
    }
    
    var knownWordsCount: Int {
        return knownWords.count
    }
    
    var unknownWordsCount: Int {
        return unknownWords.count
    }
}

/// 可导出的单词数据结构
struct ExportableWord: Codable {
    let word: String
    let definition: String
    let meanings: [String]
    let example: String?
    let testDate: Date
    let responseTime: TimeInterval
    let difficulty: String
    let masteryLevel: String
    
    init(from testedWord: TestedWord, dictionaryWord: DictionaryWord? = nil) {
        self.word = testedWord.word
        
        // 从DictionaryWord获取定义和例句
        if let dictionaryWord = dictionaryWord,
           let firstDefinition = dictionaryWord.definitions.first {
            self.definition = firstDefinition.meaning
            self.meanings = dictionaryWord.definitions.map { $0.meaning }
            self.example = firstDefinition.examples.first
        } else {
            self.definition = "暂无定义"
            self.meanings = ["暂无定义"]
            self.example = nil
        }
        
        self.testDate = testedWord.testedAt
        self.responseTime = testedWord.responseTime
        self.difficulty = testedWord.difficulty
        self.masteryLevel = testedWord.masteryLevel
    }
}

/// 导出配置
struct ExportConfiguration {
    let format: ExportFormat
    let includeTestDate: Bool
    let includeResponseTime: Bool
    let includeDifficulty: Bool
    
    static let `default` = ExportConfiguration(
        format: .markdown,
        includeTestDate: false,
        includeResponseTime: false,
        includeDifficulty: false
    )
}

/// 词汇量测试导出数据结构
struct VocabularyTestExportData: Codable {
    let dictionaryName: String
    let testDate: Date
    let exportDate: Date
    let masteredWords: [VocabularyTestWord]
    let familiarWords: [VocabularyTestWord]
    let unfamiliarWords: [VocabularyTestWord]
    
    var words: [VocabularyTestWord] {
        return masteredWords + familiarWords + unfamiliarWords
    }
    
    var totalWords: Int {
        return masteredWords.count + familiarWords.count + unfamiliarWords.count
    }
}

/// 词汇量测试单词数据结构
struct VocabularyTestWord: Codable {
    let word: String
    let definition: String
    let example: String?
    let testDate: Date
    let responseTime: Double
    let difficulty: String
    let masteryLevel: String
    
    init(from testedWord: TestedWord, dictionaryWord: DictionaryWord?) {
        self.word = testedWord.word
        
        // 从DictionaryWord获取定义和例句
        if let dictionaryWord = dictionaryWord,
           let firstDefinition = dictionaryWord.definitions.first {
            self.definition = firstDefinition.meaning
            self.example = firstDefinition.examples.first
        } else {
            self.definition = "无定义"
            self.example = nil
        }
        
        self.testDate = testedWord.testedAt
        self.responseTime = testedWord.responseTime
        self.difficulty = testedWord.difficulty
        self.masteryLevel = testedWord.masteryLevel
    }
}