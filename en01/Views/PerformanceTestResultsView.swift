//
//  PerformanceTestResultsView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI
import Charts

struct PerformanceTestResultsView: View {
    @ObservedObject var testRunner: PerformanceTestRunner
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportSheet = false
    @State private var exportText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 总体统计
                    overallStatsSection
                    
                    // 性能图表
                    performanceChartsSection
                    
                    // 详细结果列表
                    detailedResultsSection
                }
                .padding()
            }
            .navigationTitle("测试结果")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("导出") {
                        exportText = testRunner.exportResults()
                        showingExportSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportResultsView(exportText: exportText)
        }
    }
    
    // MARK: - 总体统计
    private var overallStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.blue)
                Text("总体统计")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "总体评分",
                    value: String(format: "%.1f%%", testRunner.getOverallScore()),
                    icon: "star.fill",
                    color: scoreColor(testRunner.getOverallScore())
                )
                
                StatCard(
                    title: "平均耗时",
                    value: String(format: "%.2f ms", testRunner.getAverageDuration() * 1000),
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "通过测试",
                    value: "\(testRunner.results.filter { $0.success }.count)/\(testRunner.results.count)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "总内存使用",
                    value: ByteCountFormatter().string(fromByteCount: Int64(testRunner.getTotalMemoryUsage())),
                    icon: "memorychip.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 性能图表
    private var performanceChartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                Text("性能图表")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 20) {
                // 耗时图表
                durationChart
                
                // 内存使用图表
                memoryChart
                
                // 成功率饼图
                successRateChart
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var durationChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("测试耗时 (ms)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Chart(testRunner.results, id: \.testName) { result in
                BarMark(
                    x: .value("测试", result.testName),
                    y: .value("耗时", result.duration * 1000)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 120)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
        }
    }
    
    private var memoryChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("内存使用 (MB)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Chart(testRunner.results, id: \.testName) { result in
                BarMark(
                    x: .value("测试", result.testName),
                    y: .value("内存", Double(result.memoryUsage) / 1024.0 / 1024.0)
                )
                .foregroundStyle(.purple)
            }
            .frame(height: 120)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
        }
    }
    
    private var successRateChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("测试结果分布")
                .font(.subheadline)
                .fontWeight(.medium)
            
            let successCount = testRunner.results.filter { $0.success }.count
            let failureCount = testRunner.results.count - successCount
            
            Chart {
                SectorMark(
                    angle: .value("通过", successCount),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(.green)
                .opacity(0.8)
                
                SectorMark(
                    angle: .value("失败", failureCount),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(.red)
                .opacity(0.8)
            }
            .frame(height: 120)
            .chartLegend(position: .bottom)
        }
    }
    
    // MARK: - 详细结果列表
    private var detailedResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.gray)
                Text("详细结果")
                    .font(.headline)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(testRunner.results, id: \.testName) { result in
                    TestResultCard(result: result)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 辅助方法
    private func scoreColor(_ score: Double) -> Color {
        if score > 80 {
            return .green
        } else if score > 60 {
            return .orange
        } else {
            return .red
        }
    }
}



// MARK: - 测试结果卡片
struct TestResultCard: View {
    let result: PerformanceTestRunner.PerformanceTestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.testName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(DateFormatter.localizedString(from: result.timestamp, dateStyle: .none, timeStyle: .medium))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(result.formattedDuration)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(result.formattedMemoryUsage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(result.details)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(result.success ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 导出结果视图
struct ExportResultsView: View {
    let exportText: String
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(exportText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("导出结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("分享") {
                        showingShareSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(activityItems: [exportText])
        }
    }
}

// MARK: - 分享视图控制器
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 不需要更新
    }
}

#Preview {
    PerformanceTestResultsView(testRunner: PerformanceTestRunner.shared)
}