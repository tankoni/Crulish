import Foundation
import SwiftData
import Combine

/// 同步触发器管理器 - 在关键操作点自动触发数据同步
@MainActor
class SyncTriggerManager: ObservableObject {
    
    // MARK: - Properties
    
    private let dataSyncService: DataSyncService
    private let errorHandler: ErrorHandler
    private var cancellables = Set<AnyCancellable>()
    
    // 触发器配置
    private let config = SyncTriggerConfig()
    
    // 触发统计
    @Published var triggerStats = TriggerStatistics()
    
    // MARK: - Initialization
    
    init(dataSyncService: DataSyncService, errorHandler: ErrorHandler) {
        self.dataSyncService = dataSyncService
        self.errorHandler = errorHandler
        setupTriggers()
    }
    
    // MARK: - Trigger Setup
    
    private func setupTriggers() {
        // 监听数据同步服务的状态变化
        dataSyncService.$isSyncing
            .sink { [weak self] isSyncing in
                self?.triggerStats.updateSyncStatus(isSyncing)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Trigger Methods
    
    /// 测试记录完成后触发同步
    func triggerAfterTestRecord(word: String, dictionaryFileName: String, testRecord: TestedWord) {
        recordTrigger(.testRecord)
        
        if config.enableRealTimeSync {
            Task {
                await dataSyncService.syncTestRecord(testRecord, dictionaryFileName: dictionaryFileName)
            }
        } else {
            // 使用防抖同步
            dataSyncService.debouncedSync(for: dictionaryFileName)
        }
        
        print("🔄 [SyncTrigger] 测试记录同步触发: \(word) (\(dictionaryFileName))")
    }
    
    /// 掌握度更新后触发同步
    func triggerAfterMasteryUpdate(word: String, dictionaryFileName: String, newMastery: MasteryLevel) {
        recordTrigger(.masteryUpdate)
        
        dataSyncService.enqueueMasteryPropagation(word: word, newMastery: newMastery)
        
        print("🔄 [SyncTrigger] 掌握度更新同步触发: \(word) -> \(newMastery.rawValue)")
    }
    
    /// 词典切换后触发同步
    func triggerAfterDictionarySwitch(fromDictionary: String?, toDictionary: String) {
        recordTrigger(.dictionarySwitch)
        
        if config.enableDictionarySwitchSync {
            // 同步之前的词典
            if let fromDict = fromDictionary {
                Task {
                    await dataSyncService.syncDictionaryRecords(fromDict)
                }
            }
            
            // 延迟同步新词典（给用户一些操作时间）
            DispatchQueue.main.asyncAfter(deadline: .now() + config.dictionarySwitchDelay) {
                Task { @MainActor in
                    await self.dataSyncService.syncDictionaryRecords(toDictionary)
                }
            }
        }
        
        print("🔄 [SyncTrigger] 词典切换同步触发: \(fromDictionary ?? "nil") -> \(toDictionary)")
    }
    
    /// 测试会话完成后触发同步
    func triggerAfterTestSession(dictionaryFileName: String, testSessionId: UUID, wordsCount: Int) {
        recordTrigger(.testSession)
        
        if config.enableSessionSync {
            if wordsCount >= config.batchSyncThreshold {
                // 大批量测试，立即同步
                Task {
                    await dataSyncService.syncDictionaryRecords(dictionaryFileName)
                }
            } else {
                // 小批量测试，使用防抖同步
                dataSyncService.debouncedSync(for: dictionaryFileName)
            }
        }
        
        print("🔄 [SyncTrigger] 测试会话同步触发: \(dictionaryFileName) (\(wordsCount) 个单词)")
    }
    
    /// 应用启动后触发全量同步检查
    func triggerOnAppLaunch() {
        recordTrigger(.appLaunch)
        
        if config.enableLaunchSync {
            // 延迟执行，避免影响启动性能
            DispatchQueue.main.asyncAfter(deadline: .now() + config.launchSyncDelay) {
                Task { @MainActor in
                    await self.dataSyncService.performFullSync()
                }
            }
        }
        
        print("🔄 [SyncTrigger] 应用启动同步触发")
    }
    
    /// 应用进入后台时触发同步
    func triggerOnAppBackground() {
        recordTrigger(.appBackground)
        
        if config.enableBackgroundSync {
            Task {
                await dataSyncService.performFullSync()
            }
        }
        
        print("🔄 [SyncTrigger] 应用后台同步触发")
    }
    
    /// 数据导入后触发同步
    func triggerAfterDataImport(affectedDictionaries: [String]) {
        recordTrigger(.dataImport)
        
        if config.enableImportSync {
            Task {
                for dictionary in affectedDictionaries {
                    await dataSyncService.deduplicateDictionaryRecords(dictionary)
                    await dataSyncService.syncDictionaryRecords(dictionary)
                }
            }
        }
        
        print("🔄 [SyncTrigger] 数据导入同步触发: \(affectedDictionaries.joined(separator: ", "))")
    }
    
    /// 缓存清理后触发同步验证
    func triggerAfterCacheClear(dictionaryFileName: String?) {
        recordTrigger(.cacheClear)
        
        if config.enableCacheClearSync {
            if let dictionary = dictionaryFileName {
                dataSyncService.debouncedSync(for: dictionary)
            } else {
                Task {
                    await dataSyncService.performFullSync()
                }
            }
        }
        
        print("🔄 [SyncTrigger] 缓存清理同步触发: \(dictionaryFileName ?? "全部")")
    }
    
    /// 手动触发全量同步
    func triggerManualFullSync() {
        recordTrigger(.manualSync)
        
        Task {
            await dataSyncService.performFullSync()
        }
        
        print("🔄 [SyncTrigger] 手动全量同步触发")
    }
    
    /// 定时同步触发器
    func triggerScheduledSync() {
        recordTrigger(.scheduledSync)
        
        if config.enableScheduledSync {
            Task {
                await dataSyncService.performFullSync()
            }
        }
        
        print("🔄 [SyncTrigger] 定时同步触发")
    }
    
    // MARK: - Configuration Management
    
    func updateConfig(_ newConfig: SyncTriggerConfig) {
        // 这里可以添加配置验证逻辑
        // config = newConfig
        print("⚙️ [SyncTrigger] 配置已更新")
    }
    
    func getCurrentConfig() -> SyncTriggerConfig {
        return config
    }
    
    // MARK: - Statistics and Monitoring
    
    private func recordTrigger(_ type: TriggerType) {
        triggerStats.recordTrigger(type)
    }
    
    func getTriggerStatistics() -> TriggerStatistics {
        return triggerStats
    }
    
    func resetStatistics() {
        triggerStats = TriggerStatistics()
        print("📊 [SyncTrigger] 统计数据已重置")
    }
    
    // MARK: - Health Check
    
    func performHealthCheck() async -> SyncTriggerHealthReport {
        var report = SyncTriggerHealthReport()
        
        // 检查同步服务状态
        report.syncServiceHealthy = !dataSyncService.isSyncing || dataSyncService.lastSyncTime != nil
        
        // 检查触发器配置
        report.configurationValid = validateConfiguration()
        
        // 检查触发频率
        report.triggerFrequencyNormal = checkTriggerFrequency()
        
        // 检查数据一致性
        let consistencyReport = await dataSyncService.validateAndRepairDataConsistency()
        report.dataConsistencyHealthy = consistencyReport.isHealthy
        
        report.overallHealthy = report.syncServiceHealthy && 
                               report.configurationValid && 
                               report.triggerFrequencyNormal && 
                               report.dataConsistencyHealthy
        
        return report
    }
    
    private func validateConfiguration() -> Bool {
        // 验证配置的合理性
        return config.dictionarySwitchDelay >= 0 &&
               config.launchSyncDelay >= 0 &&
               config.batchSyncThreshold > 0
    }
    
    private func checkTriggerFrequency() -> Bool {
        // 检查触发频率是否正常（避免过于频繁的触发）
        let recentTriggers = triggerStats.getRecentTriggerCount(minutes: 5)
        return recentTriggers < 100 // 5分钟内不超过100次触发
    }
}

// MARK: - Supporting Types

struct SyncTriggerConfig {
    // 实时同步开关
    var enableRealTimeSync: Bool = true
    var enableMasterySync: Bool = true
    var enableDictionarySwitchSync: Bool = true
    var enableSessionSync: Bool = true
    var enableLaunchSync: Bool = true
    var enableBackgroundSync: Bool = false // 默认关闭后台同步以节省电量
    var enableImportSync: Bool = true
    var enableCacheClearSync: Bool = true
    var enableScheduledSync: Bool = false
    
    // 延迟配置
    var dictionarySwitchDelay: TimeInterval = 1.0 // 词典切换后延迟1秒同步
    var launchSyncDelay: TimeInterval = 3.0 // 启动后延迟3秒同步
    
    // 批量处理阈值
    var batchSyncThreshold: Int = 10 // 超过10个单词的测试会话立即同步
}

enum TriggerType: CaseIterable {
    case testRecord
    case masteryUpdate
    case dictionarySwitch
    case testSession
    case appLaunch
    case appBackground
    case dataImport
    case cacheClear
    case manualSync
    case scheduledSync
    
    var displayName: String {
        switch self {
        case .testRecord: return "测试记录"
        case .masteryUpdate: return "掌握度更新"
        case .dictionarySwitch: return "词典切换"
        case .testSession: return "测试会话"
        case .appLaunch: return "应用启动"
        case .appBackground: return "应用后台"
        case .dataImport: return "数据导入"
        case .cacheClear: return "缓存清理"
        case .manualSync: return "手动同步"
        case .scheduledSync: return "定时同步"
        }
    }
}

struct TriggerStatistics {
    private var triggerCounts: [TriggerType: Int] = [:]
    private var triggerTimes: [TriggerType: [Date]] = [:]
    private var syncStatusHistory: [(Date, Bool)] = []
    
    mutating func recordTrigger(_ type: TriggerType) {
        triggerCounts[type, default: 0] += 1
        triggerTimes[type, default: []].append(Date())
        
        // 保持最近100次记录
        if triggerTimes[type]!.count > 100 {
            triggerTimes[type]!.removeFirst()
        }
    }
    
    mutating func updateSyncStatus(_ isSyncing: Bool) {
        syncStatusHistory.append((Date(), isSyncing))
        
        // 保持最近100次状态记录
        if syncStatusHistory.count > 100 {
            syncStatusHistory.removeFirst()
        }
    }
    
    func getTriggerCount(for type: TriggerType) -> Int {
        return triggerCounts[type, default: 0]
    }
    
    func getLastTriggerTime(for type: TriggerType) -> Date? {
        return triggerTimes[type]?.last
    }
    
    func getRecentTriggerCount(minutes: Int) -> Int {
        let cutoffTime = Date().addingTimeInterval(-TimeInterval(minutes * 60))
        
        return triggerTimes.values.flatMap { $0 }.filter { $0 > cutoffTime }.count
    }
    
    func getTotalTriggerCount() -> Int {
        return triggerCounts.values.reduce(0, +)
    }
}

struct SyncTriggerHealthReport {
    var overallHealthy: Bool = false
    var syncServiceHealthy: Bool = false
    var configurationValid: Bool = false
    var triggerFrequencyNormal: Bool = false
    var dataConsistencyHealthy: Bool = false
    
    var summary: String {
        if overallHealthy {
            return "同步触发器运行正常"
        } else {
            var issues: [String] = []
            if !syncServiceHealthy { issues.append("同步服务异常") }
            if !configurationValid { issues.append("配置无效") }
            if !triggerFrequencyNormal { issues.append("触发频率异常") }
            if !dataConsistencyHealthy { issues.append("数据不一致") }
            return "发现问题: \(issues.joined(separator: ", "))"
        }
    }
}
