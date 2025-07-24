//
//  IconCache.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import SwiftUI
import UIKit

/// 图标缓存管理器，用于优化 SF Symbols 加载性能
class IconCache: ObservableObject {
    private var cache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.en01.iconCache", qos: .userInitiated)
    private let maxCacheSize = 50
    
    @Published private var loadedIcons: Set<String> = []
    
    init() {
        // 预加载关键图标以避免启动时的内存压力
        preloadCriticalIcons()
    }
    
    /// 预加载关键图标
    private func preloadCriticalIcons() {
        // 延迟预加载，避免启动时的内存压力
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadIconsGradually()
        }
    }
    
    /// 逐步加载图标，避免内存峰值
    private func loadIconsGradually() {
        let criticalIcons = [
            "house",
            "book",
            "text.book.closed",
            "chart.bar",
            "gear"
        ]
        
        // 每隔 100ms 加载一个图标
        for (index, iconName) in criticalIcons.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) { [weak self] in
                self?.preloadIcon(iconName)
            }
        }
    }
    
    /// 预加载单个图标
    private func preloadIcon(_ iconName: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查是否已缓存
            if self.cache[iconName] != nil {
                return
            }
            
            // 使用内存保护的方式创建图标
            autoreleasepool {
                if let image = UIImage(systemName: iconName) {
                    self.cache[iconName] = image
                    
                    DispatchQueue.main.async {
                        self.loadedIcons.insert(iconName)
                    }
                }
            }
            
            // 清理缓存以防止内存泄漏
            self.cleanupCacheIfNeeded()
        }
    }
    
    /// 获取图标，如果未缓存则异步加载
    func getIcon(_ iconName: String) -> UIImage? {
        // 首先检查缓存
        if let cachedImage = cache[iconName] {
            return cachedImage
        }
        
        // 如果未缓存，异步加载
        preloadIcon(iconName)
        
        // 返回默认图标作为占位符
        return UIImage(systemName: "circle")
    }
    
    /// 检查图标是否已加载
    func isIconLoaded(_ iconName: String) -> Bool {
        return loadedIcons.contains(iconName)
    }
    
    /// 清理缓存
    private func cleanupCacheIfNeeded() {
        if cache.count > maxCacheSize {
            // 移除最旧的缓存项
            let keysToRemove = Array(cache.keys.prefix(cache.count - maxCacheSize + 10))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
                loadedIcons.remove(key)
            }
        }
    }
    
    /// 清空所有缓存
    func clearCache() {
        queue.async { [weak self] in
            self?.cache.removeAll()
            DispatchQueue.main.async {
                self?.loadedIcons.removeAll()
            }
        }
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> (count: Int, memoryUsage: Int) {
        let count = cache.count
        let memoryUsage = cache.values.reduce(0) { result, image in
            return result + (image.pngData()?.count ?? 0)
        }
        return (count: count, memoryUsage: memoryUsage)
    }
}

/// 内存安全的图标视图
struct SafeIconView: View {
    let iconName: String
    @ObservedObject var iconCache: IconCache
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .renderingMode(.template)
            } else {
                // 使用简单的占位符避免复杂的 SF Symbol 加载
                Circle()
                    .fill(Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.primary, lineWidth: 1)
                    )
            }
        }
        .onAppear {
            loadIcon()
        }
        .onChange(of: iconCache.isIconLoaded(iconName)) {
            loadIcon()
        }
    }
    
    private func loadIcon() {
        // 使用内存保护的方式加载图标
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                let loadedImage = iconCache.getIcon(iconName)
                DispatchQueue.main.async {
                    self.image = loadedImage
                }
            }
        }
    }
}