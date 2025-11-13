//
//  ServiceManager.swift
//  en01
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
import SwiftData

/// 服务管理器，负责统一管理所有服务和数据同步机制
@MainActor
class ServiceManager: ObservableObject {
    
    // MARK: - 核心服务
    let dictionaryService: DictionaryServiceProtocol
    let vocabularyTestService: VocabularyTestServiceProtocol
    let wordMasteryService: WordMasteryService
    
    // MARK: - 同步相关服务
    let dataSyncService: DataSyncService
    let syncTriggerManager: SyncTriggerManager
    let cacheSyncManager: CacheSyncManager
    
    // MARK: - 其他服务
    let cacheManager: CacheManagerProtocol
    let errorHandler: ErrorHandlerProtocol
    
    // MARK: - 初始化
    init(
        modelContext: ModelContext,
        cacheManager: CacheManagerProtocol,
        errorHandler: ErrorHandlerProtocol
    ) {
        self.cacheManager = cacheManager
        self.errorHandler = errorHandler
        
        // 初始化核心服务
        self.dictionaryService = DictionaryService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        )
        
        self.wordMasteryService = WordMasteryService(
            dictionaryService: dictionaryService,
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        )
        
        self.vocabularyTestService = VocabularyTestService(
            dictionaryService: dictionaryService,
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        )
        
        // 初始化同步服务
        self.cacheSyncManager = CacheSyncManager(
            cacheManager: cacheManager
        )
        
        self.dataSyncService = DataSyncService(
            modelContext: modelContext,
            errorHandler: ErrorHandler(),
            cacheSyncManager: cacheSyncManager
        )
        
        self.syncTriggerManager = SyncTriggerManager(
            dataSyncService: dataSyncService,
            errorHandler: ErrorHandler()
        )
        
        // 配置服务间的依赖关系
        setupServiceDependencies()
    }
    
    // MARK: - 服务依赖配置
    private func setupServiceDependencies() {
        // 为各服务设置同步触发器管理器
        if let dictionaryService = dictionaryService as? DictionaryService {
            dictionaryService.setSyncTriggerManager(syncTriggerManager)
        }
        
        if let vocabularyTestService = vocabularyTestService as? VocabularyTestService {
            vocabularyTestService.setSyncTriggerManager(syncTriggerManager)
        }
        
        wordMasteryService.setSyncTriggerManager(syncTriggerManager)
        
        // 启动同步触发器管理器
        // syncTriggerManager.startManager() // 方法不存在，已移除
        
        print("✅ [ServiceManager] 服务依赖配置完成")
    }
    
    // MARK: - 应用生命周期管理
    
    /// 应用启动时的初始化
    func applicationDidLaunch() {
        print("📱 [ServiceManager] 应用启动")
        syncTriggerManager.triggerOnAppLaunch()
    }
    
    /// 应用进入后台
    func applicationDidEnterBackground() {
        print("📱 [ServiceManager] 应用进入后台")
        syncTriggerManager.triggerOnAppBackground()
    }
    
    /// 应用进入前台
    func applicationWillEnterForeground() {
        print("📱 [ServiceManager] 应用即将进入前台")
        syncTriggerManager.triggerScheduledSync()
    }
    
    // MARK: - 手动同步控制
    
    /// 手动触发全量同步
    func triggerManualSync() {
        print("🔄 [ServiceManager] 手动触发同步")
        syncTriggerManager.triggerManualFullSync()
    }
    
    /// 清除所有缓存并重新同步
    func clearCacheAndResync() {
        print("🗑️ [ServiceManager] 清除缓存并重新同步")
        cacheManager.clearAll()
        // 触发全部词典的缓存清理同步，传入nil表示清理所有
        syncTriggerManager.triggerAfterCacheClear(dictionaryFileName: nil)
    }
    
    // MARK: - 数据导入导出支持
    
    /// 数据导入后的同步处理
    func handleDataImport(affectedDictionaries: [String] = []) {
        syncTriggerManager.triggerAfterDataImport(affectedDictionaries: affectedDictionaries)
    }
    
    /// 获取同步统计信息
    func getSyncStatistics() -> TriggerStatistics {
        return syncTriggerManager.getTriggerStatistics()
    }
    
    /// 获取同步健康状态
    func getSyncHealthStatus() async -> SyncTriggerHealthReport {
        return await syncTriggerManager.performHealthCheck()
    }
    
    // MARK: - 清理资源
    deinit {
        // SyncTriggerManager没有stopManager方法，移除此调用
        print("✅ [ServiceManager] 资源清理完成")
    }
}

// MARK: - 便利访问方法
extension ServiceManager {
    
    /// 获取词典服务
    var dictionary: DictionaryServiceProtocol {
        return dictionaryService
    }
    
    /// 获取词汇测试服务
    var vocabularyTest: VocabularyTestServiceProtocol {
        return vocabularyTestService
    }
    
    /// 获取单词掌握度服务
    var wordMastery: WordMasteryService {
        return wordMasteryService
    }
    
    /// 获取数据同步服务
    var dataSync: DataSyncService {
        return dataSyncService
    }
}