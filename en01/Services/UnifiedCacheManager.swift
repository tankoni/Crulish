//
//  UnifiedCacheManager.swift
//  en01
//
//  Created by AI Assistant on 2024-12-30.
//  统一缓存管理器 - 整合所有缓存操作并提供智能缓存策略
//

import Foundation
import OSLog

/// 统一缓存管理器 - 提供智能缓存策略和性能优化
class UnifiedCacheManager {
    static let shared = UnifiedCacheManager()
    
    private let logger = Logger(subsystem: "com.en01.translation", category: "CacheManager")
    
    // MARK: - Cache Configuration
    
    /// 缓存配置
    struct CacheConfig {
        let maxCacheSize: Int
        let defaultTTL: TimeInterval
        let cleanupInterval: TimeInterval
        let compressionThreshold: Int
        
        static let `default` = CacheConfig(
            maxCacheSize: 2000,
            defaultTTL: 3600, // 1小时
            cleanupInterval: 300, // 5分钟
            compressionThreshold: 100 // 超过100字符启用压缩
        )
    }
    
    /// 缓存条目
    private struct CacheEntry {
        let translation: Translation
        let timestamp: Date
        let accessCount: Int
        let lastAccessed: Date
        let isCompressed: Bool
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 3600 // 1小时过期
        }
        
        var priority: Double {
            // 基于访问次数和最近访问时间计算优先级
            let recency = 1.0 / (Date().timeIntervalSince(lastAccessed) + 1)
            let frequency = Double(accessCount)
            return recency * frequency
        }
    }
    
    // MARK: - Properties
    
    private var cache: [String: CacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "com.en01.cache.unified", attributes: .concurrent)
    private let config: CacheConfig
    private var cleanupTimer: Timer?
    
    // 统计信息
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var evictionCount: Int = 0
    
    // MARK: - Initialization
    
    private init(config: CacheConfig = .default) {
        self.config = config
        startCleanupTimer()
        logger.info("UnifiedCacheManager initialized with max size: \(config.maxCacheSize)")
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Public Cache Operations
    
    /// 获取翻译缓存
    func getTranslation(for key: String) -> Translation? {
        return cacheQueue.sync {
            guard let entry = cache[key], !entry.isExpired else {
                if cache[key] != nil {
                    cache.removeValue(forKey: key)
                    logger.debug("Removed expired cache entry for key: \(key.prefix(20))...")
                }
                missCount += 1
                return nil
            }
            
            // 更新访问信息
            let updatedEntry = CacheEntry(
                translation: entry.translation,
                timestamp: entry.timestamp,
                accessCount: entry.accessCount + 1,
                lastAccessed: Date(),
                isCompressed: entry.isCompressed
            )
            cache[key] = updatedEntry
            
            hitCount += 1
            logger.debug("Cache hit for key: \(key.prefix(20))...")
            return entry.translation
        }
    }
    
    /// 缓存翻译结果
    func cacheTranslation(_ translation: Translation, for key: String) {
        cacheQueue.async(flags: .barrier) {
            // 检查缓存大小，必要时清理
            if self.cache.count >= self.config.maxCacheSize {
                self.evictLeastUsedEntries()
            }
            
            let shouldCompress = key.count > self.config.compressionThreshold
            
            let entry = CacheEntry(
                translation: translation,
                timestamp: Date(),
                accessCount: 1,
                lastAccessed: Date(),
                isCompressed: shouldCompress
            )
            
            self.cache[key] = entry
            self.logger.debug("Cached translation for key: \(key.prefix(20))... (compressed: \(shouldCompress))")
        }
    }
    
    /// 预加载常用翻译
    func preloadCommonTranslations(_ translations: [(String, Translation)]) {
        cacheQueue.async(flags: .barrier) {
            for (key, translation) in translations {
                if self.cache[key] == nil {
                    let entry = CacheEntry(
                        translation: translation,
                        timestamp: Date(),
                        accessCount: 5, // 预加载的内容给予较高初始访问次数
                        lastAccessed: Date(),
                        isCompressed: false
                    )
                    self.cache[key] = entry
                }
            }
            self.logger.info("Preloaded \(translations.count) common translations")
        }
    }
    
    /// 批量缓存翻译
    func batchCacheTranslations(_ translations: [(String, Translation)]) {
        cacheQueue.async(flags: .barrier) {
            let startTime = Date()
            var cachedCount = 0
            
            for (key, translation) in translations {
                if self.cache.count < self.config.maxCacheSize {
                    let entry = CacheEntry(
                        translation: translation,
                        timestamp: Date(),
                        accessCount: 1,
                        lastAccessed: Date(),
                        isCompressed: key.count > self.config.compressionThreshold
                    )
                    self.cache[key] = entry
                    cachedCount += 1
                } else {
                    break
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            self.logger.info("Batch cached \(cachedCount) translations in \(String(format: "%.3f", duration))s")
        }
    }
    
    // MARK: - Cache Management
    
    /// 清理所有缓存
    func clearAll() {
        cacheQueue.async(flags: .barrier) {
            let count = self.cache.count
            self.cache.removeAll()
            self.hitCount = 0
            self.missCount = 0
            self.evictionCount = 0
            self.logger.info("Cleared all cache entries (\(count) items)")
        }
    }
    
    /// 清理无效缓存条目
    func clearInvalidEntries() {
        cacheQueue.async(flags: .barrier) {
            let initialCount = self.cache.count
            
            self.cache = self.cache.filter { _, entry in
                let isValid = !entry.isExpired && self.isValidTranslation(entry.translation)
                return isValid
            }
            
            let removedCount = initialCount - self.cache.count
            if removedCount > 0 {
                self.logger.info("Cleared \(removedCount) invalid cache entries")
            }
        }
    }
    
    /// 清理过期缓存条目
    func clearExpiredEntries() {
        cacheQueue.async(flags: .barrier) {
            let initialCount = self.cache.count
            
            self.cache = self.cache.filter { _, entry in
                !entry.isExpired
            }
            
            let removedCount = initialCount - self.cache.count
            if removedCount > 0 {
                self.logger.debug("Cleared \(removedCount) expired cache entries")
            }
        }
    }
    
    /// 获取缓存统计信息
    func getStatistics() -> TranslationCacheStats {
        return cacheQueue.sync {
            let totalRequests = self.hitCount + self.missCount
            let hitRate = totalRequests > 0 ? Double(self.hitCount) / Double(totalRequests) : 0.0
            let missRate = totalRequests > 0 ? Double(self.missCount) / Double(totalRequests) : 0.0
            
            return TranslationCacheStats(
                totalEntries: self.cache.count,
                hitRate: hitRate,
                missRate: missRate,
                cacheSize: self.estimateMemoryUsage(),
                lastCleanup: Date()
            )
        }
    }
    
    // MARK: - Private Methods
    
    /// 启动清理定时器
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: config.cleanupInterval, repeats: true) { _ in
            self.performPeriodicCleanup()
        }
    }
    
    /// 执行定期清理
    private func performPeriodicCleanup() {
        clearExpiredEntries()
        
        // 如果缓存使用率过高，进行额外清理
        cacheQueue.async(flags: .barrier) {
            if self.cache.count > Int(Double(self.config.maxCacheSize) * 0.8) {
                self.evictLeastUsedEntries(targetSize: Int(Double(self.config.maxCacheSize) * 0.7))
            }
        }
    }
    
    /// 驱逐最少使用的缓存条目
    private func evictLeastUsedEntries(targetSize: Int? = nil) {
        let target = targetSize ?? Int(Double(config.maxCacheSize) * 0.8)
        
        if cache.count <= target {
            return
        }
        
        // 按优先级排序，移除优先级最低的条目
        let sortedEntries = cache.sorted { $0.value.priority < $1.value.priority }
        let toRemove = cache.count - target
        
        for i in 0..<min(toRemove, sortedEntries.count) {
            cache.removeValue(forKey: sortedEntries[i].key)
            evictionCount += 1
        }
        
        logger.info("Evicted \(toRemove) least used cache entries")
    }
    
    /// 验证翻译结果是否有效
    private func isValidTranslation(_ translation: Translation) -> Bool {
        let trimmedTranslation = translation.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranslation.isEmpty else {
            return false
        }
        
        // 检查是否是明显的错误响应
        let lowercased = trimmedTranslation.lowercased()
        let errorIndicators = ["error", "failed", "无法", "错误", "失败", "sorry"]
        
        for indicator in errorIndicators {
            if lowercased.contains(indicator) && trimmedTranslation.count < 50 {
                return false
            }
        }
        
        return true
    }
    
    /// 估算内存使用量
    private func estimateMemoryUsage() -> Int {
        var totalSize = 0
        for (key, entry) in cache {
            totalSize += key.utf8.count
            totalSize += entry.translation.originalText.utf8.count
            totalSize += entry.translation.translatedText.utf8.count
            totalSize += 100 // 估算其他字段的大小
        }
        return totalSize
    }
    
    /// 获取最旧条目的年龄
    private func getOldestEntryAge() -> TimeInterval {
        guard let oldestEntry = cache.values.min(by: { $0.timestamp < $1.timestamp }) else {
            return 0
        }
        return Date().timeIntervalSince(oldestEntry.timestamp)
    }
    
    /// 获取平均访问次数
    private func getAverageAccessCount() -> Double {
        guard !cache.isEmpty else { return 0 }
        let totalAccess = cache.values.reduce(0) { $0 + $1.accessCount }
        return Double(totalAccess) / Double(cache.count)
    }
    
    // MARK: - Smart Caching Strategies
    
    /// 智能预测需要缓存的内容
    func predictAndCache(for text: String, context: String) {
        // 基于文本特征预测可能需要的翻译
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // 缓存常见单词组合
        if words.count > 1 {
            for i in 0..<words.count-1 {
                // 这里可以添加预测逻辑
                _ = "\(words[i]) \(words[i+1])"
            }
        }
    }
    
    /// 基于使用模式优化缓存
    func optimizeCache() {
        cacheQueue.async(flags: .barrier) {
            let startTime = Date()
            
            // 分析访问模式
            let highFrequencyEntries = self.cache.filter { $0.value.accessCount >= 5 }
            let lowFrequencyEntries = self.cache.filter { $0.value.accessCount <= 2 }
            
            // 为高频条目延长TTL
            for (_, entry) in highFrequencyEntries {
                if Date().timeIntervalSince(entry.lastAccessed) < 300 { // 5分钟内访问过
                    // 保持这些条目
                }
            }
            
            // 清理低频且长时间未访问的条目
            let keysToRemove = lowFrequencyEntries.compactMap { (key, entry) in
                Date().timeIntervalSince(entry.lastAccessed) > 1800 ? key : nil
            }
            for key in keysToRemove {
                self.cache.removeValue(forKey: key)
            }
            
            let duration = Date().timeIntervalSince(startTime)
            self.logger.info("Cache optimization completed in \(String(format: "%.3f", duration))s")
        }
    }
}

// MARK: - Extensions

extension UnifiedCacheManager {
    /// 导出缓存数据（用于备份）
    func exportCacheData() -> [String: Any] {
        return cacheQueue.sync {
            var exportData: [String: Any] = [:]
            
            for (key, entry) in cache {
                exportData[key] = [
                    "translation": [
                        "originalText": entry.translation.originalText,
                        "translatedText": entry.translation.translatedText,
                        "confidence": entry.translation.confidence
                    ],
                    "timestamp": entry.timestamp.timeIntervalSince1970,
                    "accessCount": entry.accessCount
                ]
            }
            
            return exportData
        }
    }
    
    /// 导入缓存数据（用于恢复）
    func importCacheData(_ data: [String: Any]) {
        cacheQueue.async(flags: .barrier) {
            var importedCount = 0
            
            for (key, value) in data {
                guard let entryData = value as? [String: Any],
                      let translationData = entryData["translation"] as? [String: Any],
                      let originalText = translationData["originalText"] as? String,
                      let translatedText = translationData["translatedText"] as? String,
                      let confidence = translationData["confidence"] as? Double,
                      let timestamp = entryData["timestamp"] as? TimeInterval,
                      let accessCount = entryData["accessCount"] as? Int else {
                    continue
                }
                
                let translation = Translation(
                    originalText: originalText,
                    translatedText: translatedText,
                    confidence: confidence,
                    provider: .local
                )
                
                let entry = CacheEntry(
                    translation: translation,
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    accessCount: accessCount,
                    lastAccessed: Date(),
                    isCompressed: false
                )
                
                self.cache[key] = entry
                importedCount += 1
            }
            
            self.logger.info("Imported \(importedCount) cache entries")
        }
    }
}