//
//  TestHistoryListView.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import SwiftData
import Charts

/// 测试历史记录列表视图
struct TestHistoryListView: View {
    @ObservedObject var viewModel: VocabularyTestViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeleteAlert = false
    @State private var testToDelete: VocabularyTest?
    @State private var selectedTimeRange: TimeRange = .all
    
    var body: some View {
        VStack(spacing: 0) {
            // 自定义导航栏
            HStack {
                Button("关闭") {
                    dismiss()
                }
                
                Spacer()
                
                Text("测试历史")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Menu {
                    Button("导出数据") {
                        exportTestData()
                    }
                    
                    Button("清空历史", role: .destructive) {
                        showClearAllAlert()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            // 时间范围选择
            timeRangeSelector
            
            // 统计图表
            if !filteredTests.isEmpty {
                statisticsChartSection
            }
            
            // 历史记录列表
            historyListSection
        }
        .alert("删除测试记录", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let test = testToDelete {
                    viewModel.deleteTestFromHistory(test)
                }
            }
        } message: {
            Text("确定要删除这条测试记录吗？此操作无法撤销。")
        }
        .onAppear {
            viewModel.loadTestHistory()
        }
    }
    
    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(range.displayName) {
                        selectedTimeRange = range
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedTimeRange == range ? Color.blue : Color(.systemGray6))
                    )
                    .foregroundColor(selectedTimeRange == range ? .white : .primary)
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var statisticsChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("词汇量趋势")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
            
            // 词汇量趋势图
            Chart(filteredTests) { test in
                LineMark(
                    x: .value("日期", test.createdAt),
                    y: .value("词汇量", test.estimatedVocabulary)
                )
                .foregroundStyle(.blue)
                .symbol(.circle)
                
                AreaMark(
                    x: .value("日期", test.createdAt),
                    y: .value("词汇量", test.estimatedVocabulary)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: 200)
            .padding(.horizontal, 20)
            
            // 统计摘要
            statisticsSummary
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    private var statisticsSummary: some View {
        HStack(spacing: 20) {
            StatSummaryItem(
                title: "平均词汇量",
                value: "\(averageVocabularySize)",
                icon: "chart.bar.fill",
                color: .blue
            )
            
            StatSummaryItem(
                title: "最高词汇量",
                value: "\(maxVocabularySize)",
                icon: "arrow.up.circle.fill",
                color: .green
            )
            
            StatSummaryItem(
                title: "测试次数",
                value: "\(filteredTests.count)",
                icon: "number.circle.fill",
                color: .orange
            )
        }
        .padding(.horizontal, 20)
    }
    
    private var historyListSection: some View {
        Group {
            if filteredTests.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredTests) { test in
                        TestHistoryDetailCard(test: test, onDelete: {
                            testToDelete = test
                            showingDeleteAlert = true
                        }, viewModel: viewModel)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无测试记录")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("完成词汇量测试后，记录将显示在这里")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Computed Properties
    
    private var filteredTests: [VocabularyTest] {
        let now = Date()
        let calendar = Calendar.current
        
        return viewModel.testHistory.filter { test in
            switch selectedTimeRange {
            case .all:
                return true
            case .day:
                return calendar.isDate(test.createdAt, equalTo: now, toGranularity: .day)
            case .week:
                return calendar.isDate(test.createdAt, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(test.createdAt, equalTo: now, toGranularity: .month)
            case .threeMonths:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                return test.createdAt >= threeMonthsAgo
            case .year:
                return calendar.isDate(test.createdAt, equalTo: now, toGranularity: .year)
            }
        }.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var averageVocabularySize: Int {
        guard !filteredTests.isEmpty else { return 0 }
        let total = filteredTests.reduce(0) { $0 + $1.estimatedVocabulary }
        return total / filteredTests.count
    }

    private var maxVocabularySize: Int {
        filteredTests.map { $0.estimatedVocabulary }.max() ?? 0
    }
    
    // MARK: - Actions
    
    private func exportTestData() {
        guard let exportService = viewModel.exportService else {
            print("❌ 导出服务未初始化")
            return
        }
        
        guard !filteredTests.isEmpty else {
            print("❌ 没有测试数据可导出")
            return
        }
        
        // 使用第一个测试的词典名称作为导出参数
        let dictionaryName = filteredTests.first?.dictionaryName ?? "Unknown"
        
        Task {
            do {
                let exportURL = try await exportService.exportTestResults(for: dictionaryName, format: .markdown)
                
                // 显示分享界面
                await MainActor.run {
                    let activityVC = UIActivityViewController(
                        activityItems: [exportURL],
                        applicationActivities: nil
                    )
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        
                        // 为iPad设置popover
                        if let popover = activityVC.popoverPresentationController {
                            popover.sourceView = window
                            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                            popover.permittedArrowDirections = []
                        }
                        
                        rootVC.present(activityVC, animated: true)
                    }
                }
                
                print("✅ 测试数据导出成功")
            } catch {
                print("❌ 导出测试数据失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func showClearAllAlert() {
        // TODO: 实现清空所有历史记录功能
        print("清空所有历史记录")
    }
}

// MARK: - Supporting Views

struct TestHistoryDetailCard: View {
    let test: VocabularyTest
    let onDelete: () -> Void
    @ObservedObject var viewModel: VocabularyTestViewModel

    // 计算实时统计数据（当保存的统计数据为0时使用）
    private var calculatedStats: (mastered: Int, familiar: Int, unfamiliar: Int) {
        // 如果已有统计数据且不全为0，直接使用
        if test.masteredCount > 0 || test.familiarCount > 0 || test.unfamiliarCount > 0 {
            return (test.masteredCount, test.familiarCount, test.unfamiliarCount)
        }
        
        // 否则从测试结果中实时计算
        let results = test.getTestResults()
        var masteredCount = 0
        var familiarCount = 0
        var unfamiliarCount = 0
        
        for result in results {
            if result.isKnown {
                // 根据响应时间判断是掌握还是熟悉
                if result.responseTime < 2.0 {
                    masteredCount += 1
                } else {
                    familiarCount += 1
                }
            } else {
                unfamiliarCount += 1
            }
        }
        
        return (masteredCount, familiarCount, unfamiliarCount)
    }

    var body: some View {
        VStack(spacing: 16) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(test.dictionaryName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(formatDate(test.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("词汇量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(test.estimatedVocabulary)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            
            // 测试结果分布
            HStack(spacing: 12) {
                ResultBar(
                    title: "掌握",
                    count: calculatedStats.mastered,
                    total: test.totalWords,
                    color: .green
                )
                
                ResultBar(
                    title: "眼熟",
                    count: calculatedStats.familiar,
                    total: test.totalWords,
                    color: .orange
                )
                
                ResultBar(
                    title: "陌生",
                    count: calculatedStats.unfamiliar,
                    total: test.totalWords,
                    color: .red
                )
            }
            
            // 底部操作按钮
            HStack(spacing: 12) {
                // 选择测试按钮
                Button(action: {
                    viewModel.selectTestForContinuation(test)
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("选择测试")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                
                Spacer()
                
                Text("测试单词: \(test.totalWords)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("准确率: \(String(format: "%.1f%%", test.accuracyPercentage))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("删除", role: .destructive) {
                onDelete()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ResultBar: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 30, height: 60)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 30, height: 60 * percentage)
            }
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

struct StatSummaryItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Types

// TimeRange 已在 CommonTypes.swift 中定义

#Preview {
    let mockDictionaryService = MockDictionaryService()
    
    TestHistoryListView(
        viewModel: VocabularyTestViewModel(
            vocabularyTestService: MockVocabularyTestService(dictionaryService: mockDictionaryService),
            dictionaryService: mockDictionaryService,
            errorHandler: MockErrorHandler(),
            testResultExportService: TestResultExportService(
                modelContext: ModelContext(try! ModelContainer(for: VocabularyTest.self)),
                dictionaryService: mockDictionaryService
            )
        )
    )
}