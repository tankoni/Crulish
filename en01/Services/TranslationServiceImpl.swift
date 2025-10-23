//
//  TranslationServiceImpl.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import Foundation
import SwiftData
import OSLog
import SwiftUI

/// 翻译服务实现类
class TranslationServiceImpl: TranslationServiceProtocol, ObservableObject {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.en01.translation", category: "TranslationService")
    private let cache: TranslationCache
    private let unifiedCacheManager = UnifiedCacheManager.shared
    private let errorHandler = TranslationErrorHandler()
    private let modelContext: ModelContext?
    private var config: TranslationConfig
    
    // MARK: - Translation Engines
    private var localEngine: LocalTranslationEngine?
    private var onlineProvider: OnlineTranslationProvider?
    private let contextAnalyzer: ContextAnalyzer
    
    init(
        modelContext: ModelContext? = nil,
        config: TranslationConfig = .default
    ) {
        self.modelContext = modelContext
        self.config = config
        self.cache = TranslationCache(
            maxCacheSize: config.maxCacheSize,
            expirationTime: config.cacheExpiration
        )
        self.contextAnalyzer = ContextAnalyzer()
        
        setupTranslationEngines()
        logger.info("TranslationService initialized with provider: \(config.primaryProvider.displayName)")
    }
    
    // MARK: - Translation Methods
    
    func translateWord(_ word: String, context: String) async throws -> Translation? {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty else {
            throw AppError.translationInvalidInput("单词不能为空")
        }
        
        // 检查统一缓存管理器
        let cacheKey = "\(cleanWord)_\(context.prefix(50))"
        if let cachedTranslation = unifiedCacheManager.getTranslation(for: cacheKey) {
            logger.debug("Cache hit for word: \(cleanWord)")
            await recordTranslationUsage(cachedTranslation)
            return cachedTranslation
        }
        
        // 使用错误处理器执行翻译
        return try await errorHandler.executeWithRetry { [self] in
            let translation = try await performTranslation(
                text: cleanWord,
                context: context,
                type: .word
            )
            
            // 验证并缓存结果
            if let cachedTranslation = translation, isValidTranslation(cachedTranslation) {
                unifiedCacheManager.cacheTranslation(cachedTranslation, for: cacheKey)
                await saveTranslationRecord(cachedTranslation, context: context)
                return cachedTranslation
            } else if translation != nil {
                self.logger.warning("Invalid translation result for word: \(cleanWord)")
            }
            
            return translation
        }
    }
    
    func translateSentence(_ sentence: String) async throws -> Translation? {
        let cleanSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSentence.isEmpty else {
            throw AppError.translationInvalidInput("句子不能为空")
        }
        
        // 检查缓存
        let cacheKey = cleanSentence
        if let cachedTranslation = cache.getTranslation(for: cacheKey) {
            logger.debug("Cache hit for sentence")
            await recordTranslationUsage(cachedTranslation)
            return cachedTranslation
        }
        
        // 执行翻译
        let translation = try await performTranslation(
            text: cleanSentence,
            context: "",
            type: .sentence
        )
        
        // 验证并缓存结果
        if let translation = translation, isValidTranslation(translation) {
            cache.cacheTranslation(translation, for: cacheKey)
            await saveTranslationRecord(translation)
            return translation
        } else if translation != nil {
            logger.warning("Invalid translation result for sentence")
        }
        
        return nil
    }
    
    func translateParagraph(_ paragraph: String) async throws -> Translation? {
        let cleanParagraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanParagraph.isEmpty else {
            throw AppError.translationInvalidInput("段落不能为空")
        }
        
        // 检查长度限制
        guard cleanParagraph.count <= 1000 else {
            throw AppError.translationInvalidInput("段落长度不能超过1000个字符")
        }
        
        // 检查缓存
        let cacheKey = cleanParagraph
        if let cachedTranslation = cache.getTranslation(for: cacheKey) {
            logger.debug("Cache hit for paragraph")
            await recordTranslationUsage(cachedTranslation)
            return cachedTranslation
        }
        
        // 执行翻译
        let translation = try await performTranslation(
            text: cleanParagraph,
            context: "",
            type: .paragraph
        )
        
        // 验证并缓存结果
        if let translation = translation, isValidTranslation(translation) {
            cache.cacheTranslation(translation, for: cacheKey)
            await saveTranslationRecord(translation)
            return translation
        } else if translation != nil {
            logger.warning("Invalid translation result for paragraph")
        }
        
        return nil
    }
    
    // MARK: - Configuration Methods
    
    func setTranslationProvider(_ provider: TranslationProvider) {
        config.primaryProvider = provider
        logger.info("Translation provider changed to: \(provider.displayName)")
    }
    
    func getAvailableProviders() -> [TranslationProvider] {
        var providers: [TranslationProvider] = []
        
        // 检查本地模型
        if isLocalModelAvailable() {
            providers.append(.local)
        }
        
        // 检查在线服务
        for provider in TranslationProvider.allCases {
            if provider != .local && hasValidAPIKey(for: provider) {
                providers.append(provider)
            }
        }
        
        return providers
    }
    
    func isLocalModelAvailable() -> Bool {
        return localEngine?.isModelLoaded ?? false
    }
    
    // MARK: - Cache Management
    
    func clearTranslationCache() {
        Task {
            unifiedCacheManager.clearAll()
            cache.clearAll() // 保持向后兼容
            logger.info("Translation cache cleared")
        }
    }
    
    /// 清理无效的缓存条目
    func clearInvalidCacheEntries() {
        Task {
            unifiedCacheManager.clearExpiredEntries()
            cache.clearInvalidEntries() // 保持向后兼容
            logger.info("Invalid cache entries cleared")
        }
    }
    
    func getCacheStatistics() -> TranslationCacheStats {
        // 优先使用统一缓存管理器的统计信息
        Task {
            let stats = unifiedCacheManager.getStatistics()
            logger.info("Cache statistics - Entries: \(stats.totalEntries), Hit Rate: \(String(format: "%.2f", stats.hitRate * 100))%, Size: \(stats.cacheSize) bytes")
        }
        return cache.getStatistics() // 返回传统缓存统计以保持兼容性
    }
    
    // MARK: - Private Methods
    
    /// 验证翻译结果是否有效
    private func isValidTranslation(_ translation: Translation) -> Bool {
        // 检查翻译文本不为空且不是纯空白字符
        let trimmedTranslation = translation.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranslation.isEmpty else {
            return false
        }
        
        // 检查原文不为空
        let trimmedOriginal = translation.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty else {
            return false
        }
        
        // 检查翻译结果不是错误信息
        let errorKeywords = ["翻译失败", "翻译服务暂时不可用", "未找到该单词的释义", "translation failed", "service unavailable"]
        let lowercaseTranslation = trimmedTranslation.lowercased()
        for keyword in errorKeywords {
            if lowercaseTranslation.contains(keyword.lowercased()) {
                return false
            }
        }
        
        return true
    }
    
    private func setupTranslationEngines() {
        // 设置本地翻译引擎
        if config.enableLocalModel {
            localEngine = LocalTranslationEngine()
            // 设置DatabaseActor
            if let modelContext = modelContext {
                let databaseActor = DatabaseActor(modelContainer: modelContext.container)
                localEngine?.setDatabaseActor(databaseActor)
            }
            Task {
                await localEngine?.loadModels()
            }
        }
        
        // 设置在线翻译提供商（共享实例）
        if hasAnyValidAPIKey() {
            onlineProvider = OnlineTranslationProvider(apiKeys: config.apiKeys)
            logger.info("Online translation provider initialized with API keys: \(config.apiKeys.keys.map { $0.displayName }.joined(separator: ", "))")
        } else {
            logger.warning("No valid API keys found, online translation will not be available")
        }
    }
    
    private func performTranslation(
        text: String,
        context: String,
        type: TranslationType
    ) async throws -> Translation? {
        // 分析上下文
        _ = await contextAnalyzer.analyzeContext(
            text: text,
            surroundingText: context,
            articleContext: ""
        )
        
        let providers = [config.primaryProvider] + config.fallbackProviders
        
        for provider in providers {
            do {
                let translation = try await translateWithProvider(
                    text: text,
                    context: context,
                    provider: provider,
                    type: type
                )
                
                if let translation = translation {
                    logger.info("Translation successful with provider: \(provider.displayName)")
                    await recordTranslationStatistics(type: type, provider: provider, confidence: translation.confidence)
                    return translation
                }
            } catch {
                logger.warning("Translation failed with provider \(provider.displayName): \(error)")
                continue
            }
        }
        
        throw AppError.translationFailed("All translation providers failed")
    }
    
    private func translateWithProvider(
        text: String,
        context: String,
        provider: TranslationProvider,
        type: TranslationType
    ) async throws -> Translation? {
        switch provider {
        case .local:
            guard let localEngine = localEngine else {
                throw AppError.translationModelNotAvailable("Local translation model not available")
            }
            return await localEngine.translate(text, context: context, type: type)
            
        default:
            guard let onlineProvider = onlineProvider else {
                throw AppError.translationServiceUnavailable("Online translation provider not initialized")
            }
            
            // 检查该provider是否有有效的API密钥
            guard hasValidAPIKey(for: provider) else {
                throw AppError.translationProviderNotConfigured("Provider \(provider.displayName) not configured with valid API key")
            }
            
            return try await onlineProvider.translate(text, context: context, type: type, provider: provider)
        }
    }
    
    private func hasValidAPIKey(for provider: TranslationProvider) -> Bool {
        guard provider.requiresAPIKey else { return true }
        
        // 对于新的细粒度提供商，使用apiKeyName来查找共享的API密钥
        let keyName = provider.apiKeyName
        
        // 首先尝试直接查找提供商的API密钥
        if config.apiKeys[provider] != nil {
            return true
        }
        
        // 然后查找共享的API密钥
        for (key, value) in config.apiKeys {
            if key.apiKeyName == keyName && !value.isEmpty {
                return true
            }
        }
        
        return false
    }
    
    /// 检查是否有任何有效的API密钥
    private func hasAnyValidAPIKey() -> Bool {
        for provider in TranslationProvider.allCases {
            if provider != .local && hasValidAPIKey(for: provider) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Data Persistence
    
    @MainActor
    private func saveTranslationRecord(_ translation: Translation, context: String = "") async {
        guard let modelContext = modelContext else { return }
        
        let record = TranslationRecord(
            originalText: translation.originalText,
            translatedText: translation.translatedText,
            sourceLanguage: translation.sourceLanguage,
            targetLanguage: translation.targetLanguage,
            confidence: translation.confidence,
            provider: translation.provider,
            contextualMeaning: translation.contextualMeaning,
            grammarAnalysis: translation.grammarAnalysis,
            wordContext: context
        )
        
        modelContext.insert(record)
        
        do {
            try modelContext.save()
            logger.debug("Translation record saved")
        } catch {
            logger.error("Failed to save translation record: \(error)")
        }
    }
    
    @MainActor
    private func recordTranslationUsage(_ translation: Translation) async {
        guard let modelContext = modelContext else { return }
        
        // 查找现有记录并增加使用次数
        let predicate = #Predicate<TranslationRecord> { record in
            record.originalText == translation.originalText &&
            record.translatedText == translation.translatedText
        }
        
        let descriptor = FetchDescriptor<TranslationRecord>(predicate: predicate)
        
        do {
            let records = try modelContext.fetch(descriptor)
            if let record = records.first {
                record.incrementUsage()
                try modelContext.save()
            }
        } catch {
            logger.error("Failed to update translation usage: \(error)")
        }
    }
    
    @MainActor
    private func recordTranslationStatistics(
        type: TranslationType,
        provider: TranslationProvider,
        confidence: Double
    ) async {
        guard let modelContext = modelContext else { return }
        
        let today = Date()
        let startOfDay = Calendar.current.startOfDay(for: today)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = #Predicate<TranslationStatistics> { stats in
            stats.date >= startOfDay && stats.date < endOfDay
        }
        
        let descriptor = FetchDescriptor<TranslationStatistics>(predicate: predicate)
        
        do {
            let existingStats = try modelContext.fetch(descriptor)
            let stats = existingStats.first ?? TranslationStatistics(date: today)
            
            if existingStats.isEmpty {
                modelContext.insert(stats)
            }
            
            stats.incrementTranslation(type: type, provider: provider, confidence: confidence)
            try modelContext.save()
        } catch {
            logger.error("Failed to record translation statistics: \(error)")
        }
    }
}