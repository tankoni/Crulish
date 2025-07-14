//
//  PerformanceTestApp.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI

/// 性能测试应用入口 - 用于演示和测试性能监控功能
struct PerformanceTestApp: View {
    @StateObject private var viewModel = PerformanceTestAppViewModel()
    @StateObject private var performanceConfig = PerformanceConfig.shared
    @StateObject private var testRunner = PerformanceTestRunner.shared
    @State private var showingPerformanceMonitor = false
    @State private var showingTestResults = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 应用标题
                    headerSection
                    
                    // 快速状态概览
                    quickStatusSection
                    
                    // 性能测试控制
                    performanceTestSection
                    
                    // 内存管理控制
                    memoryManagementSection
                    
                    // 性能配置
                    performanceConfigSection
                    
                    // 导航链接
                    navigationSection
                }
                .padding()
            }
            .navigationTitle("性能测试")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("监控") {
                        showingPerformanceMonitor = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingPerformanceMonitor) {
            PerformanceMonitorView()
        }
        .sheet(isPresented: $showingTestResults) {
            PerformanceTestResultsView(testRunner: testRunner)
        }
        .onAppear {
            // 启动性能监控
            viewModel.startMonitoring()
        }
    }

    // MARK: - 应用标题
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "speedometer")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("性能测试中心")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("监控应用性能，优化用户体验")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - 快速状态概览
    private var quickStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("系统状态")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatusCard(
                    title: "内存使用",
                    value: ByteCountFormatter().string(fromByteCount: viewModel.currentMemoryUsage),
                    icon: "memorychip",
                    color: viewModel.isLowMemoryMode ? .red : .green
                )
                
                StatusCard(
                    title: "低内存模式",
                    value: viewModel.isLowMemoryMode ? "开启" : "关闭",
                    icon: "exclamationmark.triangle",
                    color: viewModel.isLowMemoryMode ? .orange : .gray
                )
                
                StatusCard(
                    title: "缓存优化",
                    value: performanceConfig.enableCacheOptimization ? "开启" : "关闭",
                    icon: "externaldrive",
                    color: performanceConfig.enableCacheOptimization ? .green : .gray
                )
                
                StatusCard(
                    title: "动画优化",
                    value: performanceConfig.enableAnimationOptimization ? "开启" : "关闭",
                    icon: "wand.and.stars",
                    color: performanceConfig.enableAnimationOptimization ? .green : .gray
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 性能测试控制
    private var performanceTestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "play.circle")
                    .foregroundColor(.green)
                Text("性能测试")
                    .font(.headline)
                Spacer()
            }
            
            if testRunner.isRunning {
                VStack(spacing: 12) {
                    HStack {
                        Text("正在运行: \(testRunner.currentTest)")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(testRunner.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    SwiftUI.ProgressView(value: testRunner.progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            } else {
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await testRunner.runAllTests()
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("运行所有测试")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    if !testRunner.results.isEmpty {
                        Button("查看测试结果") {
                            showingTestResults = true
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
            if let errorMessage = testRunner.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 内存管理控制
    private var memoryManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.purple)
                Text("内存管理")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    viewModel.handleMemoryWarning()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清理内存")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    viewModel.toggleLowMemoryMode()
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text(viewModel.isLowMemoryMode ? "退出低内存模式" : "启用低内存模式")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isLowMemoryMode ? Color.red : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 性能配置
    private var performanceConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.gray)
                Text("性能配置")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Toggle("缓存优化", isOn: $performanceConfig.enableCacheOptimization)
                Toggle("列表优化", isOn: $performanceConfig.enableListOptimization)
                Toggle("图片优化", isOn: $performanceConfig.enableImageOptimization)
                Toggle("动画优化", isOn: $performanceConfig.enableAnimationOptimization)
                Toggle("内存监控", isOn: $performanceConfig.enableMemoryMonitoring)
            }
            
            Button("应用优化建议") {
                performanceConfig.applyOptimizationSuggestions()
            }
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 导航链接
    private var navigationSection: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: PerformanceMonitorView()) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("性能监控")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .foregroundColor(.primary)
            
            if !testRunner.results.isEmpty {
                NavigationLink(destination: PerformanceTestResultsView(testRunner: testRunner)) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("测试结果")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - 状态卡片
struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - ViewModel
class PerformanceTestAppViewModel: ObservableObject, MemoryObserver {
    private let memoryManager = MemoryManager.shared
    
    @Published var currentMemoryUsage: Int64 = 0
    @Published var isLowMemoryMode: Bool = false
    
    init() {
        currentMemoryUsage = memoryManager.currentMemoryUsage
        isLowMemoryMode = memoryManager.isLowMemoryMode
    }
    
    func startMonitoring() {
        memoryManager.addMemoryObserver(self)
    }
    
    func handleMemoryWarning() {
        memoryManager.handleMemoryWarning()
    }
    
    func toggleLowMemoryMode() {
        // Toggle low memory mode logic
        isLowMemoryMode.toggle()
    }
    
    // MARK: - MemoryObserver
    func memoryUsageDidChange(_ usage: Int64) {
        DispatchQueue.main.async {
            self.currentMemoryUsage = usage
        }
    }
    
    func didReceiveMemoryWarning() {
        DispatchQueue.main.async {
            self.isLowMemoryMode = true
        }
    }
}

#Preview {
    PerformanceTestApp()
}