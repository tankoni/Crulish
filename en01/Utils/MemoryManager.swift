//
//  MemoryManager.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import UIKit
import Combine

/// 内存管理器
class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    
    @Published var currentMemoryUsage: Int64 = 0
    @Published var isLowMemoryMode: Bool = false
    
    private var memoryTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 内存阈值配置
    private let lowMemoryThreshold: Int64 = 100 * 1024 * 1024 // 100MB
    private let criticalMemoryThreshold: Int64 = 50 * 1024 * 1024 // 50MB
    
    // MARK: - 内存监控
    private var memoryObservers: [WeakMemoryObserver] = []
    
    private init() {
        setupMemoryMonitoring()
        setupMemoryWarningObserver()
    }
    
    deinit {
        memoryTimer?.invalidate()
    }
    
    // MARK: - 内存监控设置
    private func setupMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 内存使用监控
    private func updateMemoryUsage() {
        currentMemoryUsage = getCurrentMemoryUsage()
        
        let wasLowMemoryMode = isLowMemoryMode
        isLowMemoryMode = currentMemoryUsage > lowMemoryThreshold
        
        if isLowMemoryMode && !wasLowMemoryMode {
            enterLowMemoryMode()
        } else if !isLowMemoryMode && wasLowMemoryMode {
            exitLowMemoryMode()
        }
        
        // 通知观察者
        notifyMemoryObservers()
    }
    
    func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    // MARK: - 内存警告处理
    public func handleMemoryWarning() {
        print("[MemoryManager] 收到内存警告，开始清理")
        
        // 强制进入低内存模式
        isLowMemoryMode = true
        
        // 执行紧急内存清理
        performEmergencyCleanup()
        
        // 通知所有观察者
        notifyMemoryWarning()
    }
    
    private func performEmergencyCleanup() {
        // 清理缓存
        CacheManager.shared.clearExpiredItems()
        
        // 清理图片缓存
        URLCache.shared.removeAllCachedResponses()
        
        // 强制垃圾回收
        autoreleasepool {
            // 触发自动释放池清理
        }
        
        print("[MemoryManager] 紧急内存清理完成")
    }
    
    // MARK: - 低内存模式管理
    private func enterLowMemoryMode() {
        print("[MemoryManager] 进入低内存模式")
        
        // 减少缓存大小
        CacheManager.shared.reduceCacheSize()
        
        // 暂停非关键任务
        pauseNonCriticalTasks()
        
        // 通知应用组件
        NotificationCenter.default.post(
            name: .memoryManagerLowMemoryMode,
            object: nil,
            userInfo: ["isLowMemory": true]
        )
    }
    
    private func exitLowMemoryMode() {
        print("[MemoryManager] 退出低内存模式")
        
        // 恢复正常缓存大小
        CacheManager.shared.restoreNormalCacheSize()
        
        // 恢复非关键任务
        resumeNonCriticalTasks()
        
        // 通知应用组件
        NotificationCenter.default.post(
            name: .memoryManagerLowMemoryMode,
            object: nil,
            userInfo: ["isLowMemory": false]
        )
    }
    
    private func pauseNonCriticalTasks() {
        // 暂停预加载
        NotificationCenter.default.post(name: .pausePreloading, object: nil)
        
        // 暂停后台任务
        NotificationCenter.default.post(name: .pauseBackgroundTasks, object: nil)
    }
    
    private func resumeNonCriticalTasks() {
        // 恢复预加载
        NotificationCenter.default.post(name: .resumePreloading, object: nil)
        
        // 恢复后台任务
        NotificationCenter.default.post(name: .resumeBackgroundTasks, object: nil)
    }
    
    // MARK: - 内存观察者管理
    func addMemoryObserver(_ observer: MemoryObserver) {
        memoryObservers.append(WeakMemoryObserver(observer))
        cleanupObservers()
    }
    
    func removeMemoryObserver(_ observer: MemoryObserver) {
        memoryObservers.removeAll { $0.observer === observer }
    }
    
    private func cleanupObservers() {
        memoryObservers.removeAll { $0.observer == nil }
    }
    
    private func notifyMemoryObservers() {
        cleanupObservers()
        memoryObservers.forEach { wrapper in
            wrapper.observer?.memoryUsageDidChange(currentMemoryUsage)
        }
    }
    
    private func notifyMemoryWarning() {
        cleanupObservers()
        memoryObservers.forEach { wrapper in
            wrapper.observer?.didReceiveMemoryWarning()
        }
    }
    
    // MARK: - 内存统计
    func getMemoryStatistics() -> MemoryStatistics {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usagePercentage = Double(currentMemoryUsage) / Double(totalMemory) * 100
        
        return MemoryStatistics(
            currentUsage: currentMemoryUsage,
            totalMemory: Int64(totalMemory),
            usagePercentage: usagePercentage,
            isLowMemoryMode: isLowMemoryMode
        )
    }
    
    // MARK: - 手动内存清理
    func performManualCleanup() {
        print("[MemoryManager] 执行手动内存清理")
        
        // 清理过期缓存
        CacheManager.shared.clearExpiredItems()
        
        // 清理临时文件
        clearTemporaryFiles()
        
        // 更新内存使用情况
        updateMemoryUsage()
    }
    
    private func clearTemporaryFiles() {
        let tempDirectory = NSTemporaryDirectory()
        let fileManager = FileManager.default
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(atPath: tempDirectory)
            for file in tempFiles {
                let filePath = (tempDirectory as NSString).appendingPathComponent(file)
                try fileManager.removeItem(atPath: filePath)
            }
            print("[MemoryManager] 临时文件清理完成")
        } catch {
            print("[MemoryManager] 临时文件清理失败: \(error)")
        }
    }
}

// MARK: - 内存观察者协议
protocol MemoryObserver: AnyObject {
    func memoryUsageDidChange(_ usage: Int64)
    func didReceiveMemoryWarning()
}

// MARK: - 弱引用包装器
private class WeakMemoryObserver {
    weak var observer: MemoryObserver?
    
    init(_ observer: MemoryObserver) {
        self.observer = observer
    }
}

// MARK: - 内存统计结构
struct MemoryStatistics {
    let currentUsage: Int64
    let totalMemory: Int64
    let usagePercentage: Double
    let isLowMemoryMode: Bool
    
    var formattedCurrentUsage: String {
        ByteCountFormatter.string(fromByteCount: currentUsage, countStyle: .memory)
    }
    
    var formattedTotalMemory: String {
        ByteCountFormatter.string(fromByteCount: totalMemory, countStyle: .memory)
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let memoryManagerLowMemoryMode = Notification.Name("memory_manager_low_memory_mode")
    static let pausePreloading = Notification.Name("pause_preloading")
    static let resumePreloading = Notification.Name("resume_preloading")
    static let pauseBackgroundTasks = Notification.Name("pause_background_tasks")
    static let resumeBackgroundTasks = Notification.Name("resume_background_tasks")
}