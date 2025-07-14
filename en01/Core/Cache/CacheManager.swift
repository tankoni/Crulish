//
//  CacheManager.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 缓存管理器实现
class CacheManager: CacheManagerProtocol {
    static let shared = CacheManager()
    
    private var cache: [String: CacheItem] = [:]
    private let queue = DispatchQueue(label: "com.en01.cache", attributes: .concurrent)
    private let maxCacheSize: Int
    private let defaultExpiration: TimeInterval
    
    // 统计信息
    private var hitCount: Int = 0
    private var missCount: Int = 0
    
    init(maxCacheSize: Int = 100, defaultExpiration: TimeInterval = 300) {
        self.maxCacheSize = maxCacheSize
        self.defaultExpiration = defaultExpiration
        
        // 启动清理定时器
        startCleanupTimer()
        
        // 注册内存警告监听
        setupMemoryWarningObserver()
    }
    
    // MARK: - CacheManagerProtocol
    
        func get<T: Codable>(_ key: String, type: T.Type) -> T? {
        return queue.sync {
            guard let item = cache[key] else {
                missCount += 1
                return nil
            }
            
            // 检查是否过期
            if item.isExpired {
                cache.removeValue(forKey: key)
                missCount += 1
                return nil
            }
            
            // 更新访问时间
            item.lastAccessed = Date()
            hitCount += 1
            
            return item.value as? T
        }
    }
    
        func set<T: Codable>(_ key: String, value: T, expiration: TimeInterval?) {
        queue.async(flags: .barrier) {
            // 如果缓存已满，清理最旧的项目
            if self.cache.count >= self.maxCacheSize {
                self.evictOldestItems()
            }
            
                        let finalExpiration = expiration ?? self.defaultExpiration
            let expirationDate = Date().addingTimeInterval(finalExpiration)
            let item = CacheItem(value: value, expirationDate: expirationDate)
            self.cache[key] = item
        }
    }
    
    func invalidate(_ key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    func invalidateAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
            self.hitCount = 0
            self.missCount = 0
        }
    }
    
    func clearExpiredItems() {
        queue.async(flags: .barrier) {
            let now = Date()
            self.cache = self.cache.filter { !$0.value.isExpired(at: now) }
        }
    }
    
    func getCacheSize() -> Int {
        return queue.sync {
            return cache.count
        }
    }
    
    func getCacheInfo() -> CacheInfo {
        return queue.sync {
            let totalRequests = hitCount + missCount
            let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
            let missRate = totalRequests > 0 ? Double(missCount) / Double(totalRequests) : 0.0
            
            // 计算总大小（简化估算）
            let totalSize = cache.values.reduce(0) { result, item in
                return result + MemoryLayout.size(ofValue: item.value)
            }
            
            return CacheInfo(
                itemCount: cache.count,
                totalSize: totalSize,
                hitRate: hitRate,
                missRate: missRate
            )
        }
    }
    
    // MARK: - 扩展方法
    
    /// 移除指定前缀的所有缓存项
    func removeByPrefix(_ prefix: String) {
        queue.async(flags: .barrier) {
            let keysToRemove = self.cache.keys.filter { $0.hasPrefix(prefix) }
            for key in keysToRemove {
                self.cache.removeValue(forKey: key)
            }
        }
    }
    
    /// 移除单个缓存项
    func remove(_ key: String) {
        invalidate(key)
    }
    
    /// 设置缓存项（使用默认过期时间）
        func set<T: Codable>(_ key: String, value: T) {
        set(key, value: value, expiration: defaultExpiration)
    }
    
    /// 获取缓存统计信息
    func getStatistics() -> CacheStatistics {
        return queue.sync {
            let totalRequests = hitCount + missCount
            return CacheStatistics(
                hitCount: hitCount,
                missCount: missCount,
                hitRate: totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0,
                totalItems: cache.count,
                expiredItems: cache.values.filter { $0.isExpired }.count
            )
        }
    }
    
    /// 重置统计信息
    func resetStatistics() {
        queue.async(flags: .barrier) {
            self.hitCount = 0
            self.missCount = 0
        }
    }
    
    // MARK: - 内存管理支持
    
    /// 减少缓存大小（低内存模式）
    func reduceCacheSize() {
        queue.async(flags: .barrier) {
            let targetSize = self.maxCacheSize / 2
            if self.cache.count > targetSize {
                let itemsToRemove = self.cache.count - targetSize
                let sortedItems = self.cache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
                
                for i in 0..<min(itemsToRemove, sortedItems.count) {
                    self.cache.removeValue(forKey: sortedItems[i].key)
                }
            }
        }
    }
    
    /// 恢复正常缓存大小
    func restoreNormalCacheSize() {
        // 缓存大小会在新项目添加时自然恢复
        // 这里可以预加载一些常用数据
    }
    
    /// 获取内存使用估算
    func getEstimatedMemoryUsage() -> Int {
        return queue.sync {
            return cache.values.reduce(0) { result, item in
                return result + MemoryLayout.size(ofValue: item.value) + MemoryLayout.size(ofValue: item)
            }
        }
    }
    
    /// 清理所有缓存（紧急内存清理）
        func clearAll() {
        queue.sync(flags: .barrier) {
            cache.removeAll()
            hitCount = 0
            missCount = 0
        }
    }
    
    // MARK: - 私有方法
    
    private func evictOldestItems() {
        // 移除最旧的20%项目
        let itemsToRemove = max(1, maxCacheSize / 5)
        let sortedItems = cache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        
        for i in 0..<min(itemsToRemove, sortedItems.count) {
            cache.removeValue(forKey: sortedItems[i].key)
        }
    }
    
    private func startCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.clearExpiredItems()
        }
    }
    
        private func setupMemoryWarningObserver() {
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        #endif
    }
    
    private func handleMemoryWarning() {
        print("[CacheManager] 收到内存警告，开始清理缓存")
        
        queue.async(flags: .barrier) {
            // 清理过期项目
            self.clearExpiredItems()
            
            // 如果仍然有很多项目，清理最旧的50%
            if self.cache.count > self.maxCacheSize / 2 {
                let targetSize = self.maxCacheSize / 4
                let itemsToRemove = self.cache.count - targetSize
                let sortedItems = self.cache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
                
                for i in 0..<min(itemsToRemove, sortedItems.count) {
                    self.cache.removeValue(forKey: sortedItems[i].key)
                }
            }
        }
        
        print("[CacheManager] 内存警告处理完成，当前缓存项目数: \(getCacheSize())")
    }
}

// MARK: - 缓存项

private class CacheItem {
    let value: Any
    let expirationDate: Date
    var lastAccessed: Date
    
    init(value: Any, expirationDate: Date) {
        self.value = value
        self.expirationDate = expirationDate
        self.lastAccessed = Date()
    }
    
    var isExpired: Bool {
        return isExpired(at: Date())
    }
    
    func isExpired(at date: Date) -> Bool {
        return date > expirationDate
    }
}

// MARK: - 缓存统计信息

struct CacheStatistics {
    let hitCount: Int
    let missCount: Int
    let hitRate: Double
    let totalItems: Int
    let expiredItems: Int
    
    var totalRequests: Int {
        return hitCount + missCount
    }
    
    var missRate: Double {
        return 1.0 - hitRate
    }
}