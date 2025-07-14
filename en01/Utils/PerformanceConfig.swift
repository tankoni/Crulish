//
//  PerformanceConfig.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftUI

/// 性能优化配置管理器
class PerformanceConfig: ObservableObject {
    static let shared = PerformanceConfig()
    
    // MARK: - 缓存配置
    struct CacheConfig {
        static let maxMemorySize: Int = 50 * 1024 * 1024 // 50MB
        static let maxDiskSize: Int = 200 * 1024 * 1024 // 200MB
        static let defaultExpiration: TimeInterval = 24 * 60 * 60 // 24小时
        static let imageExpiration: TimeInterval = 7 * 24 * 60 * 60 // 7天
        static let articleExpiration: TimeInterval = 3 * 24 * 60 * 60 // 3天
    }
    
    // MARK: - 列表性能配置
    struct ListConfig {
        static let lazyLoadingThreshold: Int = 20 // 超过20项使用LazyVStack
        static let batchSize: Int = 50 // 分批加载大小
        static let preloadOffset: Int = 5 // 预加载偏移量
        static let maxVisibleItems: Int = 100 // 最大可见项目数
    }
    
    // MARK: - 网络配置
    struct NetworkConfig {
        static let requestTimeout: TimeInterval = 30.0
        static let maxConcurrentRequests: Int = 6
        static let retryAttempts: Int = 3
        static let retryDelay: TimeInterval = 1.0
    }
    
    // MARK: - 图片加载配置
    struct ImageConfig {
        static let maxConcurrentDownloads: Int = 4
        static let compressionQuality: CGFloat = 0.8
        static let maxImageSize: CGSize = CGSize(width: 1024, height: 1024)
        static let thumbnailSize: CGSize = CGSize(width: 200, height: 200)
    }
    
    // MARK: - 动画配置
    struct AnimationConfig {
        static let defaultDuration: Double = 0.3
        static let fastDuration: Double = 0.15
        static let slowDuration: Double = 0.5
        static let springResponse: Double = 0.6
        static let springDamping: Double = 0.8
    }
    
    // MARK: - 内存管理配置
    struct MemoryConfig {
        static let lowMemoryThreshold: Int = 100 * 1024 * 1024 // 100MB
        static let criticalMemoryThreshold: Int = 50 * 1024 * 1024 // 50MB
        static let cacheCleanupInterval: TimeInterval = 5 * 60 // 5分钟
    }
    
    // MARK: - 性能监控配置
    @Published var isPerformanceMonitoringEnabled: Bool = true
    @Published var isMemoryWarningEnabled: Bool = true
    @Published var isNetworkMonitoringEnabled: Bool = true
    
    // MARK: - 优化开关
    @Published var isLazyLoadingEnabled: Bool = true
    @Published var isImageCachingEnabled: Bool = true
    @Published var isPreloadingEnabled: Bool = true
    @Published var isAnimationOptimizationEnabled: Bool = true
    @Published var enableCacheOptimization: Bool = true
    @Published var enableListOptimization: Bool = true
    @Published var enableImageOptimization: Bool = true
    @Published var enableAnimationOptimization: Bool = true
    @Published var enableMemoryMonitoring: Bool = true
    
    private init() {
        loadSettings()
        setupMemoryWarningObserver()
    }
    
    // MARK: - 设置管理
    private func loadSettings() {
        let defaults = UserDefaults.standard
        isPerformanceMonitoringEnabled = defaults.bool(forKey: "performance_monitoring_enabled")
        isMemoryWarningEnabled = defaults.bool(forKey: "memory_warning_enabled")
        isNetworkMonitoringEnabled = defaults.bool(forKey: "network_monitoring_enabled")
        isLazyLoadingEnabled = defaults.bool(forKey: "lazy_loading_enabled")
        isImageCachingEnabled = defaults.bool(forKey: "image_caching_enabled")
        isPreloadingEnabled = defaults.bool(forKey: "preloading_enabled")
        isAnimationOptimizationEnabled = defaults.bool(forKey: "animation_optimization_enabled")
        enableCacheOptimization = defaults.bool(forKey: "enable_cache_optimization")
        enableListOptimization = defaults.bool(forKey: "enable_list_optimization")
        enableImageOptimization = defaults.bool(forKey: "enable_image_optimization")
        enableAnimationOptimization = defaults.bool(forKey: "enable_animation_optimization")
        enableMemoryMonitoring = defaults.bool(forKey: "enable_memory_monitoring")
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isPerformanceMonitoringEnabled, forKey: "performance_monitoring_enabled")
        defaults.set(isMemoryWarningEnabled, forKey: "memory_warning_enabled")
        defaults.set(isNetworkMonitoringEnabled, forKey: "network_monitoring_enabled")
        defaults.set(isLazyLoadingEnabled, forKey: "lazy_loading_enabled")
        defaults.set(isImageCachingEnabled, forKey: "image_caching_enabled")
        defaults.set(isPreloadingEnabled, forKey: "preloading_enabled")
        defaults.set(isAnimationOptimizationEnabled, forKey: "animation_optimization_enabled")
        defaults.set(enableCacheOptimization, forKey: "enable_cache_optimization")
        defaults.set(enableListOptimization, forKey: "enable_list_optimization")
        defaults.set(enableImageOptimization, forKey: "enable_image_optimization")
        defaults.set(enableAnimationOptimization, forKey: "enable_animation_optimization")
        defaults.set(enableMemoryMonitoring, forKey: "enable_memory_monitoring")
    }
    
    // MARK: - 内存警告处理
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        guard isMemoryWarningEnabled else { return }
        
        // 清理缓存
        CacheManager.shared.clearExpiredItems()
        
        // 通知其他组件进行内存清理
        NotificationCenter.default.post(
            name: .performanceMemoryWarning,
            object: nil
        )
    }
    
    // MARK: - 性能优化建议
    func getOptimizationSuggestions() -> [String] {
        var suggestions: [String] = []
        
        if !isLazyLoadingEnabled {
            suggestions.append("启用懒加载可以提高长列表的性能")
        }
        
        if !isImageCachingEnabled {
            suggestions.append("启用图片缓存可以减少网络请求")
        }
        
        if !isPreloadingEnabled {
            suggestions.append("启用预加载可以提升用户体验")
        }
        
        if !isAnimationOptimizationEnabled {
            suggestions.append("启用动画优化可以提高界面流畅度")
        }
        
        return suggestions
    }
    
    // MARK: - 应用优化建议
    func applyOptimizationSuggestions() {
        // 启用所有推荐的优化选项
        isLazyLoadingEnabled = true
        isImageCachingEnabled = true
        isPreloadingEnabled = true
        isAnimationOptimizationEnabled = true
        enableCacheOptimization = true
        enableListOptimization = true
        enableImageOptimization = true
        enableAnimationOptimization = true
        enableMemoryMonitoring = true
        
        // 保存设置
        saveSettings()
        
        // 发送配置变更通知
        NotificationCenter.default.post(
            name: .performanceConfigChanged,
            object: nil
        )
    }
    
    // MARK: - 动态配置调整
    func adjustConfigForDevice() {
        let deviceMemory = ProcessInfo.processInfo.physicalMemory
        let deviceMemoryGB = Double(deviceMemory) / (1024 * 1024 * 1024)
        
        // 根据设备内存调整配置
        if deviceMemoryGB < 2.0 {
            // 低内存设备优化
            isPreloadingEnabled = false
            isAnimationOptimizationEnabled = true
        } else if deviceMemoryGB < 4.0 {
            // 中等内存设备
            isPreloadingEnabled = true
            isAnimationOptimizationEnabled = true
        } else {
            // 高内存设备
            isPreloadingEnabled = true
            isAnimationOptimizationEnabled = false
        }
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let performanceMemoryWarning = Notification.Name("performance_memory_warning")
    static let performanceConfigChanged = Notification.Name("performance_config_changed")
}

// MARK: - 性能优化视图修饰符
struct PerformanceOptimized: ViewModifier {
    let config = PerformanceConfig.shared
    
    func body(content: Content) -> some View {
        content
            .animation(
                config.isAnimationOptimizationEnabled ? 
                .easeInOut(duration: PerformanceConfig.AnimationConfig.defaultDuration) : 
                .none,
                value: config.isAnimationOptimizationEnabled
            )
    }
}

extension View {
    func performanceOptimized() -> some View {
        modifier(PerformanceOptimized())
    }
}