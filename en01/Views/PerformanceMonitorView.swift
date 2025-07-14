//
//  PerformanceMonitorView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI
import Charts

struct PerformanceMonitorView: View {
    @StateObject private var memoryManager = MemoryManager.shared
    @StateObject private var performanceConfig = PerformanceConfig.shared
    @StateObject private var testRunner = PerformanceTestRunner.shared
    @State private var cacheStatistics: CacheStatistics?
    @State private var refreshTimer: Timer?
    @State private var showingTestResults = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 内存使用情况
                    memoryUsageSection
                    
                    // 缓存统计
                    cacheStatisticsSection
                    
                    // 性能测试
                    performanceTestSection
                    
                    // 性能配置
                    performanceConfigSection
                    
                    // 优化建议
                    optimizationSuggestionsSection
                    
                    // 操作按钮
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("性能监控")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                startRefreshTimer()
                updateCacheStatistics()
            }
            .onDisappear {
                stopRefreshTimer()
            }
        }
    }
    
    // MARK: - 内存使用情况
    private var memoryUsageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.blue)
                Text("内存使用情况")
                    .font(.headline)
                Spacer()
                if memoryManager.isLowMemoryMode {
                    Text("低内存模式")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                }
            }
            
            let memoryStats = memoryManager.getMemoryStatistics()
            
            VStack(spacing: 8) {
                HStack {
                    Text("当前使用")
                    Spacer()
                    Text(memoryStats.formattedCurrentUsage)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("总内存")
                    Spacer()
                    Text(memoryStats.formattedTotalMemory)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("使用率")
                    Spacer()
                    Text(String(format: "%.1f%%", memoryStats.usagePercentage))
                        .fontWeight(.semibold)
                        .foregroundColor(memoryStats.usagePercentage > 80 ? .red : .primary)
                }
            }
            .font(.subheadline)
            
            // 内存使用进度条
            SwiftUI.ProgressView(value: memoryStats.usagePercentage, total: 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: memoryStats.usagePercentage > 80 ? .red : .blue))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 缓存统计
    private var cacheStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "externaldrive")
                    .foregroundColor(.green)
                Text("缓存统计")
                    .font(.headline)
                Spacer()
            }
            
            if let stats = cacheStatistics {
                VStack(spacing: 8) {
                    HStack {
                        Text("缓存项目数")
                        Spacer()
                        Text("\(stats.totalItems)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("命中率")
                        Spacer()
                        Text(String(format: "%.1f%%", stats.hitRate * 100))
                            .fontWeight(.semibold)
                            .foregroundColor(stats.hitRate > 0.8 ? .green : .orange)
                    }
                    
                    HStack {
                        Text("过期项目")
                        Spacer()
                        Text("\(stats.expiredItems)")
                            .fontWeight(.semibold)
                            .foregroundColor(stats.expiredItems > 0 ? .orange : .green)
                    }
                    
                    HStack {
                        Text("总请求数")
                        Spacer()
                        Text("\(stats.totalRequests)")
                            .fontWeight(.semibold)
                    }
                }
                .font(.subheadline)
                
                // 缓存命中率图表
                if stats.totalRequests > 0 {
                    Chart([
                        (value: stats.hitCount, label: "命中"),
                        (value: stats.missCount, label: "未命中")
                    ], id: \.label) { item in
                        SectorMark(
                            angle: .value("数量", item.value),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("类型", item.label))
                        .opacity(0.8)
                    }
                    .chartForegroundStyleScale([
                        "命中": Color.green,
                        "未命中": Color.red
                    ])
                    .frame(height: 120)
                    .chartLegend(position: .bottom)
                }
            } else {
                Text("正在加载缓存统计...")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 性能配置
    private var performanceConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gearshape")
                    .foregroundColor(.purple)
                Text("性能配置")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Toggle("性能监控", isOn: $performanceConfig.isPerformanceMonitoringEnabled)
                Toggle("内存警告", isOn: $performanceConfig.isMemoryWarningEnabled)
                Toggle("网络监控", isOn: $performanceConfig.isNetworkMonitoringEnabled)
                Toggle("懒加载", isOn: $performanceConfig.isLazyLoadingEnabled)
                Toggle("图片缓存", isOn: $performanceConfig.isImageCachingEnabled)
                Toggle("预加载", isOn: $performanceConfig.isPreloadingEnabled)
                Toggle("动画优化", isOn: $performanceConfig.isAnimationOptimizationEnabled)
            }
            .onChange(of: performanceConfig.isPerformanceMonitoringEnabled) {
                performanceConfig.saveSettings()
            }
            .onChange(of: performanceConfig.isMemoryWarningEnabled) {
                performanceConfig.saveSettings()
            }
            .onChange(of: performanceConfig.isNetworkMonitoringEnabled) {
                performanceConfig.saveSettings()
            }
            .onChange(of: performanceConfig.isLazyLoadingEnabled) {
                performanceConfig.saveSettings()
            }
            .onChange(of: performanceConfig.isImageCachingEnabled) {
                performanceConfig.saveSettings()
            }
            .onChange(of: performanceConfig.isPreloadingEnabled) {
                performanceConfig.saveSettings()
            }
            .onChange(of: performanceConfig.isAnimationOptimizationEnabled) {
                performanceConfig.saveSettings()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 优化建议
    @ViewBuilder
    private var optimizationSuggestionsSection: some View {
        let suggestions = performanceConfig.getOptimizationSuggestions()
        
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                    Text("优化建议")
                        .font(.headline)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(suggestion)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 性能测试
    private var performanceTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "stopwatch")
                    .foregroundColor(.red)
                Text("性能测试")
                    .font(.headline)
                Spacer()
                if testRunner.isRunning {
                    SwiftUI.ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if testRunner.isRunning {
                VStack(alignment: .leading, spacing: 8) {
                    Text("正在运行: \(testRunner.currentTest)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    SwiftUI.ProgressView(value: testRunner.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            } else if !testRunner.results.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("总体评分")
                        Spacer()
                        Text(String(format: "%.1f%%", testRunner.getOverallScore()))
                            .fontWeight(.semibold)
                            .foregroundColor(testRunner.getOverallScore() > 80 ? .green : testRunner.getOverallScore() > 60 ? .orange : .red)
                    }
                    
                    HStack {
                        Text("平均耗时")
                        Spacer()
                        Text(String(format: "%.2f ms", testRunner.getAverageDuration() * 1000))
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("通过测试")
                        Spacer()
                        Text("\(testRunner.results.filter { $0.success }.count)/\(testRunner.results.count)")
                            .fontWeight(.semibold)
                    }
                }
                .font(.subheadline)
                
                Button("查看详细结果") {
                    showingTestResults = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            } else {
                Text("点击下方按钮开始性能测试")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let errorMessage = testRunner.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingTestResults) {
            PerformanceTestResultsView(testRunner: testRunner)
        }
    }
    
    // MARK: - 操作按钮
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await testRunner.runAllTests()
                }
            }) {
                HStack {
                    Image(systemName: "play.circle")
                    Text(testRunner.isRunning ? "测试进行中..." : "运行性能测试")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(testRunner.isRunning ? Color.gray : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(testRunner.isRunning)
            
            Button(action: {
                memoryManager.performManualCleanup()
                updateCacheStatistics()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("手动清理内存")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: {
                performanceConfig.adjustConfigForDevice()
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("自动优化配置")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - 辅助方法
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            updateCacheStatistics()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func updateCacheStatistics() {
        let cacheManager = CacheManager()
        cacheStatistics = cacheManager.getStatistics()
    }
}

#Preview {
    PerformanceMonitorView()
}