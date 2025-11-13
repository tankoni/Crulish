//
//  CacheSyncManager.swift
//  en01
//
//  Created by tankoni TK on 2025/1/1.
//

import Foundation
import SwiftData

/// 缓存同步管理器 - 确保不同服务间缓存一致性
class CacheSyncManager {
    
    // MARK: - 单例
    static let shared = CacheSyncManager()
    
    // MARK: - 属性
    private let cacheManager: CacheManagerProtocol
    private let queue = DispatchQueue(label: "com.crulish.cache-sync", qos: .utility)
    
    // 缓存依赖关系映射
    private var cacheDependencies: [String: Set<String>] = [:]
    
    // 缓存失效监听器
    private var invalidationListeners: [String: [(String) -> Void]] = [:]
    
    // 批量失效队列
    private var batchInvalidationQueue: Set<String> = []
    private var batchInvalidationTimer: Timer?
    
    // 统计信息
    private var syncOperationCount: Int = 0
    private var lastSyncTime: Date?
    
    // MARK: - 初始化
    init(cacheManager: CacheManagerProtocol = CacheManager.shared) {
        self.cacheManager = cacheManager
        setupCacheDependencies()
    }
    
    // MARK: - 缓存依赖关系设置
    
    /// 设置缓存依赖关系
    private func setupCacheDependencies() {
        // 词汇测试相关缓存依赖
        addDependency(from: "vocabulary_test_", to: ["user_progress_", "statistics_", "mastery_"])
        addDependency(from: "tested_words_", to: ["vocabulary_test_", "user_words_"])
        addDependency(from: "word_mastery_", to: ["tested_words_", "statistics_"])
        
        // 用户进度相关缓存依赖
        addDependency(from: "user_progress_", to: ["achievements_", "level_", "experience_"])
        addDependency(from: "daily_record_", to: ["user_progress_", "statistics_"])
        
        // 词典相关缓存依赖
        addDependency(from: "dictionary_", to: ["user_words_", "word_lookup_"])
        addDependency(from: "user_words_", to: ["word_mastery_", "statistics_"])
        
        // 文章相关缓存依赖
        addDependency(from: "articles_", to: ["reading_progress_", "article_stats_"])
        addDependency(from: "reading_progress_", to: ["user_progress_", "statistics_"])
        
        // 统计相关缓存依赖
        addDependency(from: "statistics_", to: ["export_data_", "dashboard_"])
        
        print("✅ [CacheSyncManager] 缓存依赖关系设置完成")
    }
    
    /// 添加缓存依赖关系
    /// - Parameters:
    ///   - from: 主缓存键前缀
    ///   - to: 依赖的缓存键前缀数组
    private func addDependency(from: String, to: [String]) {
        cacheDependencies[from] = Set(to)
    }
    
    // MARK: - 智能缓存失效
    
    /// 智能缓存失效 - 根据依赖关系级联失效
    /// - Parameter keyPrefix: 缓存键前缀
    func invalidateCacheIntelligently(_ keyPrefix: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            print("🔄 [CacheSyncManager] 开始智能缓存失效: \(keyPrefix)")
            
            // 直接失效指定缓存
            self.cacheManager.removeByPrefix(keyPrefix)
            
            // 查找并失效依赖缓存
            let dependentCaches = self.findDependentCaches(for: keyPrefix)
            for dependentCache in dependentCaches {
                self.cacheManager.removeByPrefix(dependentCache)
                print("   ↳ 级联失效: \(dependentCache)")
            }
            
            // 通知监听器
            self.notifyInvalidationListeners(keyPrefix)
            
            // 更新统计
            self.syncOperationCount += 1
            self.lastSyncTime = Date()
            
            print("✅ [CacheSyncManager] 智能缓存失效完成: \(keyPrefix)")
        }
    }
    
    /// 批量智能缓存失效 - 延迟执行以优化性能
    /// - Parameter keyPrefixes: 缓存键前缀数组
    func batchInvalidateCacheIntelligently(_ keyPrefixes: [String]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 添加到批量队列
            for keyPrefix in keyPrefixes {
                self.batchInvalidationQueue.insert(keyPrefix)
            }
            
            // 重置定时器
            self.batchInvalidationTimer?.invalidate()
            self.batchInvalidationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self.executeBatchInvalidation()
            }
        }
    }
    
    /// 执行批量失效
    private func executeBatchInvalidation() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let keysToInvalidate = Array(self.batchInvalidationQueue)
            self.batchInvalidationQueue.removeAll()
            
            print("🔄 [CacheSyncManager] 开始批量智能缓存失效: \(keysToInvalidate.count) 个缓存")
            
            // 收集所有需要失效的缓存（包括依赖）
            var allCachesToInvalidate = Set<String>()
            
            for keyPrefix in keysToInvalidate {
                allCachesToInvalidate.insert(keyPrefix)
                let dependentCaches = self.findDependentCaches(for: keyPrefix)
                allCachesToInvalidate.formUnion(dependentCaches)
            }
            
            // 执行失效
            for cacheKey in allCachesToInvalidate {
                self.cacheManager.removeByPrefix(cacheKey)
            }
            
            // 通知监听器
            for keyPrefix in keysToInvalidate {
                self.notifyInvalidationListeners(keyPrefix)
            }
            
            // 更新统计
            self.syncOperationCount += allCachesToInvalidate.count
            self.lastSyncTime = Date()
            
            print("✅ [CacheSyncManager] 批量智能缓存失效完成: 实际失效 \(allCachesToInvalidate.count) 个缓存")
        }
    }
    
    /// 查找依赖缓存
    /// - Parameter keyPrefix: 主缓存键前缀
    /// - Returns: 依赖的缓存键前缀集合
    private func findDependentCaches(for keyPrefix: String) -> Set<String> {
        var dependentCaches = Set<String>()
        
        // 直接依赖
        if let directDependencies = cacheDependencies[keyPrefix] {
            dependentCaches.formUnion(directDependencies)
        }
        
        // 查找间接依赖（递归）
        for (cacheKey, dependencies) in cacheDependencies {
            if dependencies.contains(keyPrefix) {
                dependentCaches.insert(cacheKey)
                // 递归查找
                let indirectDependencies = findDependentCaches(for: cacheKey)
                dependentCaches.formUnion(indirectDependencies)
            }
        }
        
        return dependentCaches
    }
    
    // MARK: - 缓存失效监听
    
    /// 添加缓存失效监听器
    /// - Parameters:
    ///   - keyPrefix: 监听的缓存键前缀
    ///   - listener: 监听器回调
    func addInvalidationListener(for keyPrefix: String, listener: @escaping (String) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if self.invalidationListeners[keyPrefix] == nil {
                self.invalidationListeners[keyPrefix] = []
            }
            self.invalidationListeners[keyPrefix]?.append(listener)
        }
    }
    
    /// 通知缓存失效监听器
    /// - Parameter keyPrefix: 失效的缓存键前缀
    private func notifyInvalidationListeners(_ keyPrefix: String) {
        // 通知精确匹配的监听器
        if let listeners = invalidationListeners[keyPrefix] {
            for listener in listeners {
                listener(keyPrefix)
            }
        }
        
        // 通知前缀匹配的监听器
        for (listenerKey, listeners) in invalidationListeners {
            if keyPrefix.hasPrefix(listenerKey) || listenerKey.hasPrefix(keyPrefix) {
                for listener in listeners {
                    listener(keyPrefix)
                }
            }
        }
    }
    
    // MARK: - 缓存预热
    
    /// 缓存预热 - 在数据同步后预加载关键缓存
    /// - Parameter dictionaryId: 词典ID（可选）
    func warmupCache(for dictionaryId: String? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            print("🔥 [CacheSyncManager] 开始缓存预热")
            
            // 预热用户进度缓存
            self.warmupUserProgressCache()
            
            // 预热词典相关缓存
            if let dictionaryId = dictionaryId {
                self.warmupDictionaryCache(dictionaryId)
            }
            
            // 预热统计缓存
            self.warmupStatisticsCache()
            
            print("✅ [CacheSyncManager] 缓存预热完成")
        }
    }
    
    /// 预热用户进度缓存
    private func warmupUserProgressCache() {
        // 这里可以预加载一些关键的用户进度数据
        // 实际实现时需要调用相应的服务方法
        print("   ↳ 预热用户进度缓存")
    }
    
    /// 预热词典缓存
    /// - Parameter dictionaryId: 词典ID
    private func warmupDictionaryCache(_ dictionaryId: String) {
        // 这里可以预加载词典相关的关键数据
        print("   ↳ 预热词典缓存: \(dictionaryId)")
    }
    
    /// 预热统计缓存
    private func warmupStatisticsCache() {
        // 这里可以预加载统计相关的关键数据
        print("   ↳ 预热统计缓存")
    }
    
    // MARK: - 缓存健康检查
    
    /// 执行缓存健康检查
    /// - Returns: 缓存健康状态
    func performCacheHealthCheck() -> CacheHealthStatus {
        return queue.sync {
            let cacheInfo = cacheManager.getCacheInfo()
            
            let status = CacheHealthStatus(
                totalItems: cacheInfo.itemCount,
                hitRate: cacheInfo.hitRate,
                missRate: cacheInfo.missRate,
                syncOperationCount: syncOperationCount,
                lastSyncTime: lastSyncTime,
                dependencyCount: cacheDependencies.count,
                listenerCount: invalidationListeners.values.reduce(0) { $0 + $1.count }
            )
            
            print("📊 [CacheSyncManager] 缓存健康检查完成")
            print("   - 缓存项数: \(status.totalItems)")
            print("   - 命中率: \(String(format: "%.2f%%", status.hitRate * 100))")
            print("   - 同步操作数: \(status.syncOperationCount)")
            print("   - 依赖关系数: \(status.dependencyCount)")
            
            return status
        }
    }
    
    // MARK: - 缓存清理
    
    /// 清理过期和无用缓存
    func cleanupCache() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            print("🧹 [CacheSyncManager] 开始缓存清理")
            
            // 清理过期缓存
            self.cacheManager.clearExpiredItems()
            
            // 重置统计（如果需要）
            if self.syncOperationCount > 10000 {
                self.syncOperationCount = 0
                print("   ↳ 重置同步操作计数")
            }
            
            print("✅ [CacheSyncManager] 缓存清理完成")
        }
    }
    
    /// 紧急缓存清理 - 在内存不足时调用
    func emergencyCleanup() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            print("🚨 [CacheSyncManager] 执行紧急缓存清理")
            
            // 清理所有缓存
            self.cacheManager.clearAll()
            
            // 清理批量队列
            self.batchInvalidationQueue.removeAll()
            self.batchInvalidationTimer?.invalidate()
            
            // 重置统计
            self.syncOperationCount = 0
            self.lastSyncTime = nil
            
            print("✅ [CacheSyncManager] 紧急缓存清理完成")
        }
    }
}

// MARK: - 缓存健康状态

/// 缓存健康状态
struct CacheHealthStatus {
    let totalItems: Int
    let hitRate: Double
    let missRate: Double
    let syncOperationCount: Int
    let lastSyncTime: Date?
    let dependencyCount: Int
    let listenerCount: Int
    
    /// 是否健康
    var isHealthy: Bool {
        return hitRate > 0.7 && totalItems < 1000 && dependencyCount > 0
    }
    
    /// 健康评分 (0-100)
    var healthScore: Int {
        var score = 0
        
        // 命中率评分 (40分)
        score += Int(hitRate * 40)
        
        // 缓存大小评分 (30分)
        if totalItems < 500 {
            score += 30
        } else if totalItems < 1000 {
            score += 20
        } else {
            score += 10
        }
        
        // 依赖关系评分 (20分)
        if dependencyCount > 5 {
            score += 20
        } else if dependencyCount > 0 {
            score += 10
        }
        
        // 监听器评分 (10分)
        if listenerCount > 0 {
            score += 10
        }
        
        return min(score, 100)
    }
}