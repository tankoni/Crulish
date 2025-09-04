//
//  TranslationCache.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import Foundation
import OSLog

/// 翻译缓存管理器
class TranslationCache {
    private let logger = Logger(subsystem: "com.en01.translation", category: "TranslationCache")
    private let cache = NSCache<NSString, TranslationCacheEntry>()
    private let queue = DispatchQueue(label: "translation.cache", qos: .utility)
    private var accessLog: [String: Date] = [:]
    private var hitCount = 0
    private var missCount = 0
    
    // 缓存配置
    private let maxCacheSize: Int
    private let expirationTime: TimeInterval
    private let cleanupInterval: TimeInterval = 300 // 5分钟清理一次
    private var lastCleanup = Date()
    
    init(maxCacheSize: Int = 1000, expirationTime: TimeInterval = 3600) {
        self.maxCacheSize = maxCacheSize
        self.expirationTime = expirationTime
        
        // 配置NSCache
        cache.countLimit = maxCacheSize
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // 启动定期清理
        startPeriodicCleanup()
        
        logger.info("TranslationCache initialized with maxSize: \(maxCacheSize), expiration: \(expirationTime)s")
    }
    
    // MARK: - Cache Operations
    
    /// 获取缓存的翻译
    func getTranslation(for key: String) -> Translation? {
        return queue.sync {
            let cacheKey = NSString(string: generateCacheKey(key))
            
            if let entry = cache.object(forKey: cacheKey) {
                // 检查是否过期
                if entry.isExpired {
                    cache.removeObject(forKey: cacheKey)
                    missCount += 1
                    logger.debug("Cache entry expired for key: \(key)")
                    return nil
                }
                
                // 检查翻译结果是否有效
                if !isValidTranslation(entry.translation) {
                    cache.removeObject(forKey: cacheKey)
                    missCount += 1
                    logger.debug("Invalid translation found in cache for key: \(key), removing")
                    return nil
                }
                
                // 更新访问记录
                accessLog[key] = Date()
                hitCount += 1
                
                logger.debug("Cache hit for key: \(key)")
                return entry.translation
            }
            
            missCount += 1
            logger.debug("Cache miss for key: \(key)")
            return nil
        }
    }
    
    /// 缓存翻译结果
    func cacheTranslation(_ translation: Translation, for key: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 验证翻译结果有效性
            guard self.isValidTranslation(translation) else {
                self.logger.warning("Attempted to cache invalid translation for key: \(key)")
                return
            }
            
            let cacheKey = NSString(string: self.generateCacheKey(key))
            let entry = TranslationCacheEntry(key: key, translation: translation)
            
            // 计算缓存成本（基于文本长度）
            let cost = translation.originalText.count + translation.translatedText.count
            
            self.cache.setObject(entry, forKey: cacheKey, cost: cost)
            self.accessLog[key] = Date()
            
            self.logger.debug("Cached translation for key: \(key), cost: \(cost)")
            
            // 检查是否需要清理
            self.performCleanupIfNeeded()
        }
    }
    
    /// 生成缓存键
    private func generateCacheKey(_ text: String) -> String {
        // 使用文本的哈希值作为缓存键，确保一致性
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "translation_\(normalized.hashValue)"
    }
    
    // MARK: - Cache Management
    
    /// 清除所有缓存
    func clearAll() {
        queue.async { [weak self] in
            self?.cache.removeAllObjects()
            self?.accessLog.removeAll()
            self?.hitCount = 0
            self?.missCount = 0
            self?.logger.info("Translation cache cleared")
        }
    }
    
    /// 清除过期缓存
    func clearExpired() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            var expiredKeys: [NSString] = []
            let currentTime = Date()
            
            // 遍历访问日志找出过期的键
            for (key, accessTime) in self.accessLog {
                if currentTime.timeIntervalSince(accessTime) > self.expirationTime {
                    let cacheKey = NSString(string: self.generateCacheKey(key))
                    expiredKeys.append(cacheKey)
                }
            }
            
            // 移除过期缓存
            for key in expiredKeys {
                self.cache.removeObject(forKey: key)
            }
            
            // 清理访问日志
            self.accessLog = self.accessLog.filter { _, accessTime in
                currentTime.timeIntervalSince(accessTime) <= self.expirationTime
            }
            
            self.lastCleanup = currentTime
            self.logger.info("Cleared \(expiredKeys.count) expired cache entries")
        }
    }
    
    /// 获取缓存统计信息
    func getStatistics() -> TranslationCacheStats {
        return queue.sync {
            let totalRequests = hitCount + missCount
            let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
            let missRate = totalRequests > 0 ? Double(missCount) / Double(totalRequests) : 0.0
            
            return TranslationCacheStats(
                totalEntries: accessLog.count,
                hitRate: hitRate,
                missRate: missRate,
                cacheSize: estimateCacheSize(),
                lastCleanup: lastCleanup
            )
        }
    }
    
    /// 估算缓存大小（字节）
    private func estimateCacheSize() -> Int {
        // 简单估算：每个缓存条目平均100字节
        return accessLog.count * 100
    }
    
    // MARK: - Periodic Cleanup
    
    /// 启动定期清理
    private func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.performCleanupIfNeeded()
        }
    }
    
    /// 执行清理（如果需要）
    private func performCleanupIfNeeded() {
        let timeSinceLastCleanup = Date().timeIntervalSince(lastCleanup)
        if timeSinceLastCleanup > cleanupInterval {
            clearExpired()
        }
    }
    
    // MARK: - Cache Warming
    
    /// 预热缓存（加载常用翻译）
    func warmupCache(with commonTranslations: [String: Translation]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            for (key, translation) in commonTranslations {
                self.cacheTranslation(translation, for: key)
            }
            
            self.logger.info("Cache warmed up with \(commonTranslations.count) common translations")
        }
    }
    
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
    
    /// 清除无效的缓存条目
    func clearInvalidEntries() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            var invalidKeys: [NSString] = []
            
            // 遍历所有缓存条目，找出无效的
            for key in self.accessLog.keys {
                let cacheKey = NSString(string: self.generateCacheKey(key))
                if let entry = self.cache.object(forKey: cacheKey) {
                    if !self.isValidTranslation(entry.translation) {
                        invalidKeys.append(cacheKey)
                    }
                }
            }
            
            // 移除无效条目
            for key in invalidKeys {
                self.cache.removeObject(forKey: key)
            }
            
            if !invalidKeys.isEmpty {
                self.logger.info("Cleared \(invalidKeys.count) invalid cache entries")
            }
        }
    }
    
    /// 预加载高频词汇翻译
    func preloadFrequentWords(_ words: [String], using translationService: TranslationServiceProtocol) {
        Task {
            for word in words {
                // 检查是否已缓存
                if getTranslation(for: word) == nil {
                    do {
                        if let translation = try await translationService.translateWord(word, context: "") {
                            cacheTranslation(translation, for: word)
                        }
                    } catch {
                        logger.error("Failed to preload translation for word: \(word), error: \(error)")
                    }
                }
            }
            
            logger.info("Preloaded translations for \(words.count) frequent words")
        }
    }
}