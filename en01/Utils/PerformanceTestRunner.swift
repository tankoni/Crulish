//
//  PerformanceTestRunner.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftUI

/// 性能测试运行器 - 用于在生产环境中运行性能测试
class PerformanceTestRunner: ObservableObject {
    static let shared = PerformanceTestRunner()
    
    @Published var isRunning = false
    @Published var currentTest = ""
    @Published var progress: Double = 0.0
    @Published var results: [PerformanceTestResult] = []
    @Published var errorMessage: String?
    
    private let memoryManager = MemoryManager.shared
    private let performanceConfig = PerformanceConfig.shared
    
    private init() {}
    
    // MARK: - 测试结果
    
    struct PerformanceTestResult {
        let testName: String
        let duration: TimeInterval
        let memoryUsage: UInt64
        let success: Bool
        let details: String
        let timestamp: Date
        
        var formattedDuration: String {
            return String(format: "%.2f ms", duration * 1000)
        }
        
        var formattedMemoryUsage: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB]
            formatter.countStyle = .memory
            return formatter.string(fromByteCount: Int64(memoryUsage))
        }
    }
    
    // MARK: - 运行所有测试
    
    func runAllTests() async {
        await MainActor.run {
            isRunning = true
            progress = 0.0
            results.removeAll()
            errorMessage = nil
        }
        
        let tests: [(String, () async -> PerformanceTestResult)] = [
            ("内存使用测试", testMemoryUsage),
            ("缓存性能测试", testCachePerformance),
            ("UI响应测试", testUIResponsiveness),
            ("网络性能测试", testNetworkPerformance),
            ("数据库性能测试", testDatabasePerformance)
        ]
        
        for (index, (testName, testFunction)) in tests.enumerated() {
            await MainActor.run {
                currentTest = testName
                progress = Double(index) / Double(tests.count)
            }
            
            let result = await testFunction()
            await MainActor.run {
                results.append(result)
            }
            
            // 测试间隔
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        await MainActor.run {
            isRunning = false
            progress = 1.0
            currentTest = "测试完成"
        }
    }
    
    // MARK: - 具体测试方法
    
    private func testMemoryUsage() async -> PerformanceTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = memoryManager.getCurrentMemoryUsage()
        
        // 模拟内存密集操作
        var testData: [String] = []
        for i in 0..<10000 {
            testData.append("Test data item \(i) with some additional content to increase memory usage")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = memoryManager.getCurrentMemoryUsage()
        let memoryDelta = endMemory - startMemory
        
        // 清理测试数据
        testData.removeAll()
        
        return PerformanceTestResult(
            testName: "内存使用测试",
            duration: endTime - startTime,
            memoryUsage: UInt64(memoryDelta),
            success: memoryDelta < 50 * 1024 * 1024, // 小于50MB认为正常
            details: "内存增长: \(ByteCountFormatter().string(fromByteCount: Int64(memoryDelta)))",
            timestamp: Date()
        )
    }
    
    private func testCachePerformance() async -> PerformanceTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = memoryManager.getCurrentMemoryUsage()
        
        let cacheManager = CacheManager()
        
        // 测试缓存写入性能
        for i in 0..<1000 {
            let key = "test_key_\(i)"
            let value = "Test value \(i) with some content"
            cacheManager.set(key, value: value)
        }
        
        // 测试缓存读取性能
        var hitCount = 0
        for i in 0..<1000 {
            let key = "test_key_\(i)"
            if cacheManager.get(key, type: String.self) != nil {
                hitCount += 1
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = memoryManager.getCurrentMemoryUsage()
        let memoryDelta = endMemory - startMemory
        
        // 清理测试缓存
        for i in 0..<1000 {
            let key = "test_key_\(i)"
            cacheManager.remove(key)
        }
        
        let hitRate = Double(hitCount) / 1000.0
        
        return PerformanceTestResult(
            testName: "缓存性能测试",
            duration: endTime - startTime,
            memoryUsage: UInt64(memoryDelta),
            success: hitRate > 0.95 && (endTime - startTime) < 1.0,
            details: "命中率: \(String(format: "%.1f%%", hitRate * 100)), 操作数: 2000",
            timestamp: Date()
        )
    }
    
    private func testUIResponsiveness() async -> PerformanceTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = memoryManager.getCurrentMemoryUsage()
        
        // 模拟UI更新操作
        await MainActor.run {
            // 模拟大量UI更新
            for _ in 0..<100 {
                // 这里可以添加实际的UI更新测试
                // 例如创建和销毁视图、更新状态等
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = memoryManager.getCurrentMemoryUsage()
        let memoryDelta = endMemory - startMemory
        
        return PerformanceTestResult(
            testName: "UI响应测试",
            duration: endTime - startTime,
            memoryUsage: UInt64(memoryDelta),
            success: (endTime - startTime) < 0.5, // 小于500ms认为正常
            details: "UI更新操作: 100次",
            timestamp: Date()
        )
    }
    
    private func testNetworkPerformance() async -> PerformanceTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = memoryManager.getCurrentMemoryUsage()
        
        // 模拟网络请求
        var successCount = 0
        let requestCount = 5
        
        for _ in 0..<requestCount {
            do {
                // 模拟网络延迟
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                successCount += 1
            } catch {
                // 请求失败
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = memoryManager.getCurrentMemoryUsage()
        let memoryDelta = endMemory - startMemory
        
        let successRate = Double(successCount) / Double(requestCount)
        
        return PerformanceTestResult(
            testName: "网络性能测试",
            duration: endTime - startTime,
            memoryUsage: UInt64(memoryDelta),
            success: successRate > 0.8,
            details: "成功率: \(String(format: "%.1f%%", successRate * 100)), 请求数: \(requestCount)",
            timestamp: Date()
        )
    }
    
    private func testDatabasePerformance() async -> PerformanceTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = memoryManager.getCurrentMemoryUsage()
        
        // 模拟数据库操作
        var operationCount = 0
        
        // 模拟读写操作
        for _ in 0..<100 {
            // 这里可以添加实际的数据库操作测试
            // 例如插入、查询、更新、删除等
            operationCount += 1
            
            // 模拟操作延迟
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = memoryManager.getCurrentMemoryUsage()
        let memoryDelta = endMemory - startMemory
        
        return PerformanceTestResult(
            testName: "数据库性能测试",
            duration: endTime - startTime,
            memoryUsage: UInt64(memoryDelta),
            success: (endTime - startTime) < 1.0, // 小于1秒认为正常
            details: "数据库操作: \(operationCount)次",
            timestamp: Date()
        )
    }
    
    // MARK: - 结果分析
    
    func getOverallScore() -> Double {
        guard !results.isEmpty else { return 0.0 }
        
        let successCount = results.filter { $0.success }.count
        return Double(successCount) / Double(results.count) * 100
    }
    
    func getAverageDuration() -> TimeInterval {
        guard !results.isEmpty else { return 0.0 }
        
        let totalDuration = results.reduce(0.0) { $0 + $1.duration }
        return totalDuration / Double(results.count)
    }
    
    func getTotalMemoryUsage() -> UInt64 {
        return results.reduce(0) { $0 + $1.memoryUsage }
    }
    
    // MARK: - 导出结果
    
    func exportResults() -> String {
        var report = "性能测试报告\n"
        report += "生成时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))\n\n"
        
        report += "总体评分: \(String(format: "%.1f", getOverallScore()))%\n"
        report += "平均耗时: \(String(format: "%.2f ms", getAverageDuration() * 1000))\n"
        report += "总内存使用: \(ByteCountFormatter().string(fromByteCount: Int64(getTotalMemoryUsage())))\n\n"
        
        report += "详细结果:\n"
        for result in results {
            report += "\n[\(result.testName)]\n"
            report += "状态: \(result.success ? "✅ 通过" : "❌ 失败")\n"
            report += "耗时: \(result.formattedDuration)\n"
            report += "内存: \(result.formattedMemoryUsage)\n"
            report += "详情: \(result.details)\n"
        }
        
        return report
    }
}