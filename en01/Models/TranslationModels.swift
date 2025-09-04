//
//  TranslationModels.swift
//  en01
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation

// MARK: - 翻译核心模型
// 这个文件包含所有翻译相关的数据模型，确保类型定义的统一性和可访问性

/// 翻译结果模型
public struct Translation: Codable, Identifiable {
    public var id: UUID
    public let originalText: String
    public let translatedText: String
    public let sourceLanguage: String
    public let targetLanguage: String
    public let confidence: Double
    public let provider: TranslationProvider
    public let contextualMeaning: String?
    public let grammarAnalysis: GrammarAnalysis?
    public let timestamp: Date
    
    public init(
        originalText: String,
        translatedText: String,
        sourceLanguage: String = "en",
        targetLanguage: String = "zh",
        confidence: Double = 1.0,
        provider: TranslationProvider,
        contextualMeaning: String? = nil,
        grammarAnalysis: GrammarAnalysis? = nil
    ) {
        self.id = UUID()
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.confidence = confidence
        self.provider = provider
        self.contextualMeaning = contextualMeaning
        self.grammarAnalysis = grammarAnalysis
        self.timestamp = Date()
    }
}

/// 语法分析模型
public struct GrammarAnalysis: Codable {
    public let sentenceStructure: String
    public let keyPhrases: [String]
    public let grammarPoints: [String]
    public let partOfSpeech: String?
    public let wordForm: String?
    
    public init(
        sentenceStructure: String,
        keyPhrases: [String],
        grammarPoints: [String],
        partOfSpeech: String? = nil,
        wordForm: String? = nil
    ) {
        self.sentenceStructure = sentenceStructure
        self.keyPhrases = keyPhrases
        self.grammarPoints = grammarPoints
        self.partOfSpeech = partOfSpeech
        self.wordForm = wordForm
    }
}

/// 翻译提供商枚举 - 重构为细粒度提供商
public enum TranslationProvider: String, CaseIterable, Codable, Sendable {
    // 本地模型
    case local = "local"
    
    // OpenAI 系列
    case gpt35turbo = "gpt35turbo"
    case gpt4 = "gpt4"
    case gpt4turbo = "gpt4turbo"
    case gpt4o = "gpt4o"
    case gpt4omini = "gpt4omini"
    
    // Claude 系列
    case claude3haiku = "claude3haiku"
    case claude3sonnet = "claude3sonnet"
    case claude3opus = "claude3opus"
    case claude35sonnet = "claude35sonnet"
    
    // Gemini 系列
    case gemini25pro = "gemini25pro"
    case gemini25flash = "gemini25flash"
    case gemini20flash = "gemini20flash"
    case gemini20flashSpark = "gemini20flashSpark"
    case gemini15pro = "gemini15pro"
    case gemini15flash = "gemini15flash"
    
    // 其他AI模型
    case deepseekV3 = "deepseekV3"
    case qwenMax = "qwenMax"
    case doubaoLite = "doubaoLite"
    case doubaoPro = "doubaoPro"
    
    // 传统翻译服务
    case google = "google"
    case baidu = "baidu"
    case tencent = "tencent"
    
    // 兼容性：保留旧的通用提供商（用于向后兼容）
    case gemini = "gemini"  // 映射到 gemini15flash
    case geminiDirect = "gemini_direct"  // 映射到 gemini15flash
    case openai = "openai"  // 映射到 gpt4
    case doubao = "doubao"  // 映射到 doubaoLite
    case deepseek = "deepseek"  // 映射到 deepseekV3
    
    public var displayName: String {
        switch self {
        case .local:
            return "本地AI模型"
        case .gpt35turbo:
            return "GPT-3.5 Turbo"
        case .gpt4:
            return "GPT-4"
        case .gpt4turbo:
            return "GPT-4 Turbo"
        case .gpt4o:
            return "GPT-4o"
        case .gpt4omini:
            return "GPT-4o Mini"
        case .claude3haiku:
            return "Claude 3 Haiku"
        case .claude3sonnet:
            return "Claude 3 Sonnet"
        case .claude3opus:
            return "Claude 3 Opus"
        case .claude35sonnet:
            return "Claude 3.5 Sonnet"
        case .gemini25pro:
            return "Gemini 2.5 Pro"
        case .gemini25flash:
            return "Gemini 2.5 Flash"
        case .gemini20flash:
            return "Gemini 2.0 Flash"
        case .gemini20flashSpark:
            return "Gemini 2.0 Flash Spark"
        case .gemini15pro:
            return "Gemini 1.5 Pro"
        case .gemini15flash:
            return "Gemini 1.5 Flash"
        case .deepseekV3:
            return "DeepSeek V3"
        case .qwenMax:
            return "Qwen Max"
        case .doubaoLite:
            return "豆包 Lite"
        case .doubaoPro:
            return "豆包 Pro"
        case .google:
            return "Google Translate"
        case .baidu:
            return "百度翻译"
        case .tencent:
            return "腾讯翻译"
        // 兼容性映射
        case .gemini:
            return "Gemini (ClawCloud)"
        case .geminiDirect:
            return "Gemini (Google Direct)"
        case .openai:
            return "OpenAI GPT-4"
        case .doubao:
            return "豆包AI"
        case .deepseek:
            return "DeepSeek"
        }
    }
    
    public var requiresAPIKey: Bool {
        switch self {
        case .local:
            return false
        default:
            return true
        }
    }
    
    /// API密钥名称 - 同一厂商的不同模型共享API密钥
    public var apiKeyName: String {
        switch self {
        case .local:
            return "local"
        case .gpt35turbo, .gpt4, .gpt4turbo, .gpt4o, .gpt4omini, .openai:
            return "openai"
        case .claude3haiku, .claude3sonnet, .claude3opus, .claude35sonnet:
            return "anthropic"
        case .gemini25pro, .gemini25flash, .gemini20flash, .gemini20flashSpark, .gemini15pro, .gemini15flash, .gemini, .geminiDirect:
            return "gemini"
        case .deepseekV3, .deepseek:
            return "deepseek"
        case .qwenMax:
            return "qwen"
        case .doubaoLite, .doubaoPro, .doubao:
            return "doubao"
        case .google:
            return "google"
        case .baidu:
            return "baidu"
        case .tencent:
            return "tencent"
        }
    }
    
    /// 获取模型标识符
    public var modelIdentifier: String {
        switch self {
        case .local:
            return "local-model"
        case .gpt35turbo:
            return "gpt-3.5-turbo"
        case .gpt4:
            return "gpt-4"
        case .gpt4turbo:
            return "gpt-4-turbo"
        case .gpt4o:
            return "gpt-4o"
        case .gpt4omini:
            return "gpt-4o-mini"
        case .claude3haiku:
            return "claude-3-haiku-20240307"
        case .claude3sonnet:
            return "claude-3-sonnet-20240229"
        case .claude3opus:
            return "claude-3-opus-20240229"
        case .claude35sonnet:
            return "claude-3-5-sonnet-20241022"
        case .gemini25pro:
            return "gemini-2.5-pro-001"
        case .gemini25flash:
            return "gemini-2.5-flash-001"
        case .gemini20flash:
            return "gemini-2.0-flash-001"
        case .gemini20flashSpark:
            return "gemini-2.0-flash-spark-001"
        case .gemini15pro:
            return "gemini-1.5-pro-001"
        case .gemini15flash:
            return "gemini-1.5-flash-001"
        case .deepseekV3:
            return "deepseek-chat"
        case .qwenMax:
            return "qwen-max"
        case .doubaoLite:
            return "doubao-lite-4k"
        case .doubaoPro:
            return "doubao-pro-4k"
        case .google:
            return "google-translate"
        case .baidu:
            return "baidu-translate"
        case .tencent:
            return "tencent-translate"
        // 兼容性映射
        case .gemini:
            return "gemini-1.5-flash-001"
        case .geminiDirect:
            return "gemini-1.5-flash-001"
        case .openai:
            return "gpt-4"
        case .doubao:
            return "doubao-lite-4k"
        case .deepseek:
            return "deepseek-chat"
        }
    }
}

/// 翻译类型枚举
public enum TranslationType: String, CaseIterable, Codable {
    case word = "word"
    case sentence = "sentence"
    case paragraph = "paragraph"
    
    public var displayName: String {
        switch self {
        case .word:
            return "单词翻译"
        case .sentence:
            return "句子翻译"
        case .paragraph:
            return "段落翻译"
        }
    }
}

/// 翻译请求模型
public struct TranslationRequest {
    public let text: String
    public let sourceLanguage: String
    public let targetLanguage: String
    public let context: String?
    public let provider: TranslationProvider
    public let maxLength: Int
    
    public init(
        text: String,
        sourceLanguage: String = "en",
        targetLanguage: String = "zh",
        context: String? = nil,
        provider: TranslationProvider = .local,
        maxLength: Int = 1000
    ) {
        self.text = text
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.context = context
        self.provider = provider
        self.maxLength = maxLength
    }
}

/// 翻译缓存统计
public struct TranslationCacheStats {
    public let totalEntries: Int
    public let hitRate: Double
    public let missRate: Double
    public let cacheSize: Int // bytes
    public let lastCleanup: Date
    
    public init(
        totalEntries: Int,
        hitRate: Double,
        missRate: Double,
        cacheSize: Int,
        lastCleanup: Date
    ) {
        self.totalEntries = totalEntries
        self.hitRate = hitRate
        self.missRate = missRate
        self.cacheSize = cacheSize
        self.lastCleanup = lastCleanup
    }
}

/// 翻译配置
public struct TranslationConfig {
    public var primaryProvider: TranslationProvider
    public let fallbackProviders: [TranslationProvider]
    public let enableCache: Bool
    public let cacheExpiration: TimeInterval // seconds
    public let maxCacheSize: Int // entries
    public let enableLocalModel: Bool
    public let apiKeys: [TranslationProvider: String]
    
    public init(
        primaryProvider: TranslationProvider,
        fallbackProviders: [TranslationProvider],
        enableCache: Bool,
        cacheExpiration: TimeInterval,
        maxCacheSize: Int,
        enableLocalModel: Bool,
        apiKeys: [TranslationProvider: String]
    ) {
        self.primaryProvider = primaryProvider
        self.fallbackProviders = fallbackProviders
        self.enableCache = enableCache
        self.cacheExpiration = cacheExpiration
        self.maxCacheSize = maxCacheSize
        self.enableLocalModel = enableLocalModel
        self.apiKeys = apiKeys
    }
    
    public static let `default` = TranslationConfig(
        primaryProvider: .gemini,
        fallbackProviders: [.geminiDirect, .local, .openai],
        enableCache: true,
        cacheExpiration: 3600, // 1 hour
        maxCacheSize: 1000,
        enableLocalModel: true,
        apiKeys: [
            .geminiDirect: "AIzaSyBJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ"
        ]
    )
}