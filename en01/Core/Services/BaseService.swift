//
//  BaseService.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData
import os.log

/// 服务基类，提供统一的错误处理、日志记录和性能监控
open class BaseService {
    
    // MARK: - 依赖注入
    
    internal var modelContext: ModelContext
    internal let cacheManager: CacheManagerProtocol
    internal let errorHandler: ErrorHandlerProtocol
    internal let logger: Logger
    
    // MARK: - 性能监控
    
    private let performanceMonitor = PerformanceMonitor()
    
    // MARK: - 初始化
    
    internal init(
        modelContext: ModelContext,
        cacheManager: CacheManagerProtocol,
        errorHandler: ErrorHandlerProtocol,
        subsystem: String = "com.en01.services",
        category: String = "BaseService"
    ) {
        self.modelContext = modelContext
        self.cacheManager = cacheManager
        self.errorHandler = errorHandler
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    // MARK: - 错误处理
    
    /// 处理并记录错误
    /// - Parameters:
    ///   - error: 发生的错误
    ///   - context: 错误上下文信息
    ///   - operation: 执行的操作名称
    internal func handleError(_ error: Error, context: String, operation: String) {
        let appError: AppError
        
        // 将系统错误转换为应用错误
        if let existingAppError = error as? AppError {
            appError = existingAppError
        } else {
            appError = AppError.unknown(error)
        }
        
        // 记录错误日志
        logger.error("[\(operation)] 操作失败: \(error.localizedDescription), 上下文: \(context)")
        
        // 通过错误处理器处理
        errorHandler.handle(appError)
    }
    
    /// 安全执行操作，自动处理错误
    /// - Parameters:
    ///   - operation: 操作名称
    ///   - context: 上下文信息
    ///   - action: 要执行的操作
    /// - Returns: 操作结果，失败时返回nil
    internal func safeExecute<T>(
        operation: String,
        context: String = "",
        action: () throws -> T
    ) -> T? {
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            let result = try action()
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // 记录性能指标
            performanceMonitor.recordOperation(operation, duration: duration)
            
            // 记录成功日志
            logger.info("[\(operation)] 操作成功完成，耗时: \(String(format: "%.3f", duration))秒")
            
            return result
        } catch {
            handleError(error, context: context, operation: operation)
            return nil
        }
    }
    
    /// 异步安全执行操作
    /// - Parameters:
    ///   - operation: 操作名称
    ///   - context: 上下文信息
    ///   - action: 要执行的异步操作
    /// - Returns: 操作结果，失败时返回nil
    internal func safeExecuteAsync<T>(
        operation: String,
        context: String = "",
        action: () async throws -> T
    ) async -> T? {
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            let result = try await action()
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            // 记录性能指标
            performanceMonitor.recordOperation(operation, duration: duration)
            
            // 记录成功日志
            logger.info("[\(operation)] 异步操作成功完成，耗时: \(String(format: "%.3f", duration))秒")
            
            return result
        } catch {
            handleError(error, context: context, operation: operation)
            return nil
        }
    }
    
    // MARK: - 数据库操作
    
    /// 安全保存模型上下文
    /// - Parameter operation: 操作名称
    /// - Returns: 是否保存成功
    @discardableResult
    internal func safeSave(operation: String = "保存数据") -> Bool {
        // 确保在主线程上执行SwiftData操作
        if Thread.isMainThread {
            return safeExecute(operation: operation) {
                try modelContext.save()
            } != nil
        } else {
            return DispatchQueue.main.sync {
                return safeExecute(operation: operation) {
                    try modelContext.save()
                } != nil
            }
        }
    }
    
    /// 安全获取数据
    /// - Parameters:
    ///   - descriptor: 获取描述符
    ///   - operation: 操作名称
    /// - Returns: 获取的数据数组
    internal func safeFetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        operation: String = "获取数据"
    ) -> [T] {
        // 确保在主线程上执行SwiftData操作
        if Thread.isMainThread {
            return safeExecute(operation: operation) {
                try modelContext.fetch(descriptor)
            } ?? []
        } else {
            return DispatchQueue.main.sync {
                return safeExecute(operation: operation) {
                    try modelContext.fetch(descriptor)
                } ?? []
            }
        }
    }
    
    // MARK: - 缓存操作
    
    /// 从缓存获取数据，如果不存在则执行提供的操作并缓存结果（用于Codable类型）
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 数据类型
    ///   - expiration: 过期时间
    ///   - operation: 操作名称
    ///   - provider: 数据提供者
    /// - Returns: 缓存或新获取的数据
    internal func getCachedOrFetch<T: Codable>(
        key: String,
        type: T.Type,
        expiration: TimeInterval = 300,
        operation: String = "获取缓存数据",
        provider: () -> T?
    ) -> T? {
        // 首先尝试从缓存获取
        if let cached = cacheManager.get(key, type: type) {
            logger.debug("[\(operation)] 缓存命中: \(key)")
            return cached
        }
        
        // 缓存未命中，执行数据提供者
        logger.debug("[\(operation)] 缓存未命中，重新获取: \(key)")
        guard let data = provider() else {
            return nil
        }
        
        // 缓存新数据
        cacheManager.set(key, value: data, expiration: expiration)
        return data
    }
    
    /// 从缓存获取数据，如果不存在则执行提供的操作（用于非Codable类型，如SwiftData模型）
    /// - Parameters:
    ///   - key: 缓存键
    ///   - expiration: 过期时间
    ///   - operation: 操作名称
    ///   - provider: 数据提供者
    /// - Returns: 缓存或新获取的数据
    internal func getCachedOrFetchModel<T>(
        key: String,
        expiration: TimeInterval = 300,
        operation: String = "获取缓存数据",
        provider: () -> T?
    ) -> T? {
        // 对于SwiftData模型，我们不使用持久化缓存，而是使用内存缓存
        // 这里简化处理，直接执行provider
        logger.debug("[\(operation)] 获取数据: \(key)")
        return provider()
    }
    
    /// 使缓存失效
    /// - Parameter key: 缓存键
    internal func invalidateCache(_ key: String) {
        if let cacheManager = cacheManager as? CacheManager {
            cacheManager.remove(key)
        }
        logger.debug("缓存已失效: \(key)")
    }
    
    /// 使用模式匹配使缓存失效
    /// - Parameter keyPrefix: 缓存键前缀
    internal func invalidateCachePattern(_ keyPrefix: String) {
        if let cacheManager = cacheManager as? CacheManager {
            cacheManager.removeByPrefix(keyPrefix)
        }
        logger.debug("缓存已失效: \(keyPrefix)*")
    }
    
    /// 安全执行操作（简化版本，用于兼容现有代码）
    /// - Parameters:
    ///   - operation: 操作名称
    ///   - action: 要执行的操作
    /// - Returns: 操作结果，失败时返回nil
    @discardableResult
    internal func performSafeOperation<T>(
        _ operation: String,
        action: () throws -> T
    ) -> T? {
        return safeExecute(operation: operation, action: action)
    }
    
    // MARK: - 性能监控
    
    /// 获取服务性能统计
    /// - Returns: 性能统计信息
    public func getPerformanceStats() -> PerformanceStats {
        return performanceMonitor.getStats()
    }
    
    /// 重置性能统计
    public func resetPerformanceStats() {
        performanceMonitor.reset()
    }
}

// MARK: - 性能监控器

private class PerformanceMonitor {
    private var operationStats: [String: OperationStats] = [:]
    private let queue = DispatchQueue(label: "com.en01.performance", attributes: .concurrent)
    
    func recordOperation(_ operation: String, duration: TimeInterval) {
        queue.async(flags: .barrier) {
            if var stats = self.operationStats[operation] {
                stats.totalCalls += 1
                stats.totalDuration += duration
                stats.averageDuration = stats.totalDuration / Double(stats.totalCalls)
                stats.minDuration = min(stats.minDuration, duration)
                stats.maxDuration = max(stats.maxDuration, duration)
                self.operationStats[operation] = stats
            } else {
                self.operationStats[operation] = OperationStats(
                    operation: operation,
                    totalCalls: 1,
                    totalDuration: duration,
                    averageDuration: duration,
                    minDuration: duration,
                    maxDuration: duration
                )
            }
        }
    }
    
    func getStats() -> PerformanceStats {
        return queue.sync {
            return PerformanceStats(operationStats: Array(operationStats.values))
        }
    }
    
    func reset() {
        queue.async(flags: .barrier) {
            self.operationStats.removeAll()
        }
    }
}

// MARK: - 性能统计数据结构

public struct PerformanceStats {
    let operationStats: [OperationStats]
    
    var totalOperations: Int {
        operationStats.reduce(0) { $0 + $1.totalCalls }
    }
    
    var totalDuration: TimeInterval {
        operationStats.reduce(0) { $0 + $1.totalDuration }
    }
    
    var averageDuration: TimeInterval {
        let total = totalOperations
        return total > 0 ? totalDuration / Double(total) : 0
    }
}

public struct OperationStats {
    let operation: String
    var totalCalls: Int
    var totalDuration: TimeInterval
    var averageDuration: TimeInterval
    var minDuration: TimeInterval
    var maxDuration: TimeInterval
}