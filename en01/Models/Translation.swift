//
//  Translation.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import Foundation
import SwiftData

/// 翻译记录数据模型
@Model
class TranslationRecord {
    @Attribute(.unique) var id: String
    var originalText: String
    var translatedText: String
    var sourceLanguage: String
    var targetLanguage: String
    var confidence: Double
    var provider: String // TranslationProvider.rawValue
    var contextualMeaning: String?
    var grammarAnalysisData: Data? // JSON encoded GrammarAnalysis
    var timestamp: Date
    var isFavorite: Bool
    var usageCount: Int
    var lastUsed: Date
    
    // 关联的文章和单词
    var articleId: String?
    var wordContext: String?
    var sentenceContext: String?
    
    // 新增：上下文分析相关字段
    var contextDomain: String? // 文本领域
    var languageStyle: String? // 语言风格
    var textComplexity: Double // 文本复杂度
    var formalityScore: Double // 正式程度
    var sentimentScore: Double // 情感倾向
    
    init(
        originalText: String,
        translatedText: String,
        sourceLanguage: String = "en",
        targetLanguage: String = "zh",
        confidence: Double = 1.0,
        provider: TranslationProvider,
        contextualMeaning: String? = nil,
        grammarAnalysis: GrammarAnalysis? = nil,
        articleId: String? = nil,
        wordContext: String? = nil,
        sentenceContext: String? = nil,
        contextDomain: String? = nil,
        languageStyle: String? = nil,
        textComplexity: Double = 0.0,
        formalityScore: Double = 0.5,
        sentimentScore: Double = 0.0
    ) {
        self.id = UUID().uuidString
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.confidence = confidence
        self.provider = provider.rawValue
        self.contextualMeaning = contextualMeaning
        self.timestamp = Date()
        self.isFavorite = false
        self.usageCount = 1
        self.lastUsed = Date()
        self.articleId = articleId
        self.wordContext = wordContext
        self.sentenceContext = sentenceContext
        self.contextDomain = contextDomain
        self.languageStyle = languageStyle
        self.textComplexity = textComplexity
        self.formalityScore = formalityScore
        self.sentimentScore = sentimentScore
        
        // 编码语法分析数据
        if let grammarAnalysis = grammarAnalysis {
            self.grammarAnalysisData = try? JSONEncoder().encode(grammarAnalysis)
        }
    }
    
    // MARK: - Computed Properties
    
    var translationProvider: TranslationProvider {
        return TranslationProvider(rawValue: provider) ?? .local
    }
    
    var grammarAnalysis: GrammarAnalysis? {
        guard let data = grammarAnalysisData else { return nil }
        return try? JSONDecoder().decode(GrammarAnalysis.self, from: data)
    }
    
    // MARK: - Helper Methods
    
    func incrementUsage() {
        usageCount += 1
        lastUsed = Date()
    }
    
    func toggleFavorite() {
        isFavorite.toggle()
    }
    
    func updateGrammarAnalysis(_ analysis: GrammarAnalysis) {
        self.grammarAnalysisData = try? JSONEncoder().encode(analysis)
    }
    
    // 转换为Translation结构体
    func toTranslation() -> Translation {
        return Translation(
            originalText: originalText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            confidence: confidence,
            provider: translationProvider,
            contextualMeaning: contextualMeaning,
            grammarAnalysis: grammarAnalysis
        )
    }
}

// MARK: - Translation Statistics Model

/// 翻译统计数据模型
@Model
class TranslationStatistics {
    @Attribute(.unique) var id: String
    var date: Date
    var totalTranslations: Int
    var wordTranslations: Int
    var sentenceTranslations: Int
    var paragraphTranslations: Int
    var localModelUsage: Int
    var onlineAPIUsage: Int
    var averageConfidence: Double
    var cacheHitRate: Double
    
    // 新增：上下文分析统计
    var domainDistribution: [String: Int] // domain -> count
    var averageComplexity: Double
    var averageFormality: Double
    var sentimentDistribution: [String: Int] // positive/neutral/negative -> count
    
    init(date: Date = Date()) {
        self.id = UUID().uuidString
        self.date = Calendar.current.startOfDay(for: date)
        self.totalTranslations = 0
        self.wordTranslations = 0
        self.sentenceTranslations = 0
        self.paragraphTranslations = 0
        self.localModelUsage = 0
        self.onlineAPIUsage = 0
        self.averageConfidence = 0.0
        self.cacheHitRate = 0.0
        self.domainDistribution = [:]
        self.averageComplexity = 0.0
        self.averageFormality = 0.5
        self.sentimentDistribution = [:]
    }
    
    func incrementTranslation(type: TranslationType, provider: TranslationProvider, confidence: Double) {
        totalTranslations += 1
        
        switch type {
        case .word:
            wordTranslations += 1
        case .sentence:
            sentenceTranslations += 1
        case .paragraph:
            paragraphTranslations += 1
        }
        
        if provider == .local {
            localModelUsage += 1
        } else {
            onlineAPIUsage += 1
        }
        
        // 更新平均置信度
        averageConfidence = (averageConfidence * Double(totalTranslations - 1) + confidence) / Double(totalTranslations)
    }
}

// TranslationType 已在 TranslationModels.swift 中定义

// MARK: - Translation Cache Entry

/// 翻译缓存条目
class TranslationCacheEntry: NSObject, Codable {
    let key: String
    let translation: Translation
    let createdAt: Date
    let accessCount: Int
    let lastAccessed: Date
    
    init(key: String, translation: Translation) {
        self.key = key
        self.translation = translation
        self.createdAt = Date()
        self.accessCount = 1
        self.lastAccessed = Date()
        super.init()
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decode(String.self, forKey: .key)
        self.translation = try container.decode(Translation.self, forKey: .translation)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.accessCount = try container.decode(Int.self, forKey: .accessCount)
        self.lastAccessed = try container.decode(Date.self, forKey: .lastAccessed)
        super.init()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(translation, forKey: .translation)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(accessCount, forKey: .accessCount)
        try container.encode(lastAccessed, forKey: .lastAccessed)
    }
    
    private enum CodingKeys: String, CodingKey {
        case key, translation, createdAt, accessCount, lastAccessed
    }
    
    func accessed() -> TranslationCacheEntry {
        return TranslationCacheEntry(
            key: key,
            translation: translation,
            createdAt: createdAt,
            accessCount: accessCount + 1,
            lastAccessed: Date()
        )
    }
    
    private init(key: String, translation: Translation, createdAt: Date, accessCount: Int, lastAccessed: Date) {
        self.key = key
        self.translation = translation
        self.createdAt = createdAt
        self.accessCount = accessCount
        self.lastAccessed = lastAccessed
        super.init()
    }
    
    var isExpired: Bool {
        let expirationTime: TimeInterval = 3600 // 1 hour
        return Date().timeIntervalSince(createdAt) > expirationTime
    }
}