//
//  ResourcePathManager.swift
//  en01
//
//  Created by AI Assistant on 2024/12/30.
//

import Foundation

/// 统一的资源路径管理工具类
/// 提供安全、一致的Bundle资源访问方法
class ResourcePathManager {
    
    // MARK: - 单例模式
    static let shared = ResourcePathManager()
    private init() {}
    
    // MARK: - 缓存
    private var bundleURLCache: URL?
    private var resourcePathCache: String?
    
    // MARK: - 公共方法
    
    /// 获取Bundle的基础URL
    /// 使用bundleURL而不是resourcePath，在iOS模拟器中更可靠
    func getBundleURL() -> URL? {
        if let cached = bundleURLCache {
            return cached
        }
        
        let url = Bundle.main.bundleURL
        bundleURLCache = url
        print("📁 Bundle URL: \(url.path)")
        return url
    }
    
    /// 获取资源目录路径（兼容性方法）
    func getResourcePath() -> String? {
        if let cached = resourcePathCache {
            return cached
        }
        
        // 优先使用bundleURL构建路径
        if let bundleURL = getBundleURL() {
            let resourcePath = bundleURL.path
            resourcePathCache = resourcePath
            print("📁 Resource Path: \(resourcePath)")
            return resourcePath
        }
        
        // 降级到resourcePath
        let fallbackPath = Bundle.main.resourcePath
        resourcePathCache = fallbackPath
        print("📁 Fallback Resource Path: \(fallbackPath ?? "nil")")
        return fallbackPath
    }
    
    /// 构建完整的文件路径
    /// - Parameters:
    ///   - relativePath: 相对于Bundle的文件路径
    ///   - useURL: 是否返回URL格式，默认false返回String路径
    /// - Returns: 完整的文件路径或URL
    func buildFilePath(relativePath: String, useURL: Bool = false) -> String? {
        guard let basePath = getResourcePath() else {
            print("❌ 无法获取Bundle资源路径")
            return nil
        }
        
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
        
        if useURL {
            return "file://\(fullPath)"
        }
        
        return fullPath
    }
    
    /// 构建文件URL
    /// - Parameter relativePath: 相对于Bundle的文件路径
    /// - Returns: 文件URL
    func buildFileURL(relativePath: String) -> URL? {
        guard let bundleURL = getBundleURL() else {
            print("❌ 无法获取Bundle URL")
            return nil
        }
        
        return bundleURL.appendingPathComponent(relativePath)
    }
    
    /// 检查文件是否存在
    /// - Parameter relativePath: 相对于Bundle的文件路径
    /// - Returns: 文件是否存在
    func fileExists(relativePath: String) -> Bool {
        guard let fullPath = buildFilePath(relativePath: relativePath) else {
            return false
        }
        
        let exists = FileManager.default.fileExists(atPath: fullPath)
        if !exists {
            print("⚠️ 文件不存在: \(fullPath)")
        }
        return exists
    }
    
    /// 扫描Bundle中的所有文件
    /// - Parameters:
    ///   - fileExtension: 文件扩展名过滤（如"pdf", "md"）
    ///   - recursive: 是否递归扫描子目录
    /// - Returns: 找到的文件相对路径数组
    func scanBundleFiles(withExtension fileExtension: String? = nil, recursive: Bool = true) -> [String] {
        guard let bundleURL = getBundleURL() else {
            print("❌ 无法获取Bundle URL进行文件扫描")
            return []
        }
        
        var foundFiles: [String] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: recursive ? [] : [.skipsSubdirectoryDescendants]
        ) else {
            print("❌ 无法创建文件枚举器")
            return []
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    let relativePath = String(fileURL.path.dropFirst(bundleURL.path.count + 1))
                    
                    // 应用文件扩展名过滤
                    if let ext = fileExtension {
                        if fileURL.pathExtension.lowercased() == ext.lowercased() {
                            foundFiles.append(relativePath)
                        }
                    } else {
                        foundFiles.append(relativePath)
                    }
                }
            } catch {
                print("⚠️ 无法读取文件属性: \(fileURL.path) - \(error)")
            }
        }
        
        print("📁 扫描完成，找到 \(foundFiles.count) 个文件")
        return foundFiles.sorted()
    }
    
    /// 查找匹配关键词的文件
    /// - Parameters:
    ///   - keywords: 关键词数组
    ///   - fileExtension: 文件扩展名
    ///   - matchingStrategy: 匹配策略（包含任一关键词或包含所有关键词）
    /// - Returns: 匹配的文件路径数组
    func findFiles(containing keywords: [String], 
                   withExtension fileExtension: String,
                   matchingStrategy: FileMatchingStrategy = .containsAny) -> [String] {
        let allFiles = scanBundleFiles(withExtension: fileExtension)
        
        return allFiles.filter { filePath in
            let fileName = (filePath as NSString).lastPathComponent.lowercased()
            
            switch matchingStrategy {
            case .containsAny:
                return keywords.contains { keyword in
                    fileName.contains(keyword.lowercased())
                }
            case .containsAll:
                return keywords.allSatisfy { keyword in
                    fileName.contains(keyword.lowercased())
                }
            }
        }
    }
    
    // MARK: - 清理缓存
    
    /// 清理所有缓存
    func clearCache() {
        bundleURLCache = nil
        resourcePathCache = nil
        print("🧹 ResourcePathManager 缓存已清理")
    }
}

// MARK: - 辅助枚举

/// 文件匹配策略
enum FileMatchingStrategy {
    case containsAny    // 包含任一关键词
    case containsAll    // 包含所有关键词
}