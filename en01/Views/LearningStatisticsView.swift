//
//  LearningStatisticsView.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import SwiftUI
import Charts
import SwiftData

/// 学习统计页面 - 展示全面的学习数据统计和可视化图表
struct LearningStatisticsView: View {
    
    // MARK: - Properties
    
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var statisticsService: StatisticsService
    @StateObject private var articleService: ArticleService
    
    @State private var selectedTimeRange: TimeRange = .week
    @State private var isLoading = false
    @State private var vocabularyStats = VocabularyMasteryStatistics.empty
    @State private var learningTrend = StatisticsLearningTrendData.empty(days: 7)
    @State private var testHistory = TestHistoryStatistics.empty
    @State private var readingStats = ReadingStatisticsDomain.empty
    @State private var efficiencyData = LearningEfficiencyData.empty
    
    // MARK: - Initializer
    
    init() {
        let cacheManager = CacheManager()
        let errorHandler = UnifiedErrorHandler()
        
        // 创建临时的 ModelContainer 用于初始化
        let container = try! ModelContainer(for: UserWord.self, LearningRecord.self, VocabularyTest.self, WordClickRecord.self, Article.self)
        let tempContext = container.mainContext
        
        // 创建PDFService
        let pdfService = PDFService(
            modelContext: tempContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        )
        
        _statisticsService = StateObject(wrappedValue: StatisticsService(
            modelContext: tempContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        ))
        
        _articleService = StateObject(wrappedValue: ArticleService(
            modelContext: tempContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler,
            pdfService: pdfService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // 时间范围选择器
                    timeRangeSelector
                    
                    // 词汇掌握情况
                    vocabularyMasterySection
                    
                    // 学习趋势图表
                    learningTrendSection
                    
                    // 测试历史统计
                    testHistorySection
                    
                    // 阅读统计
                    readingStatisticsSection
                    
                    // 学习效率分析
                    efficiencyAnalysisSection
                }
                .padding()
            }
            .navigationTitle("学习统计")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        refreshStatistics()
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                loadStatistics()
            }
        }
    }
    
    // MARK: - View Components
    
    private var timeRangeSelector: some View {
        Picker("时间范围", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: selectedTimeRange) { _, newValue in
            loadLearningTrend(for: newValue)
        }
    }
    
    private var vocabularyMasterySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("词汇掌握情况")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 总体统计卡片
            HStack(spacing: 12) {
                StatCard(
                    title: "总词汇量",
                    value: "\(vocabularyStats.totalWords)",
                    icon: "book.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "掌握率",
                    value: "\(Int(vocabularyStats.masteredPercentage))%",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "眼熟词汇",
                    value: "\(vocabularyStats.familiarWords)",
                    icon: "eye.fill",
                    color: .orange
                )
            }
            
            // 掌握程度分布图
            if vocabularyStats.totalWords > 0 {
                VocabularyMasteryChart(statistics: vocabularyStats)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var learningTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习趋势")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !learningTrend.dailyData.isEmpty {
                LearningTrendChart(trendData: learningTrend)
                    .frame(height: 250)
            } else {
                Text("暂无学习数据")
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            }
            
            // 趋势统计
            HStack(spacing: 12) {
                TrendStatItem(
                    title: "日均学习",
                    value: "\(learningTrend.averageWordsPerDay)词",
                    icon: "calendar"
                )
                
                TrendStatItem(
                    title: "日均点击",
                    value: "\(learningTrend.averageClicksPerDay)次",
                    icon: "hand.tap"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var testHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("测试历史")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                StatCard(
                    title: "完成测试",
                    value: "\(testHistory.completedTests)",
                    icon: "checkmark.square.fill",
                    color: .green
                )
                
                StatCard(
                    title: "平均分数",
                    value: "\(Int(testHistory.averageScore))%",
                    icon: "chart.bar.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "最高分数",
                    value: "\(Int(testHistory.bestScore))%",
                    icon: "star.fill",
                    color: .yellow
                )
            }
            
            // 词典测试详情
            if !testHistory.dictionaryStats.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("各词典表现")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(Array(testHistory.dictionaryStats.keys.sorted()), id: \.self) { dictionary in
                        if let stats = testHistory.dictionaryStats[dictionary] {
                            DictionaryTestRow(dictionary: dictionary, stats: stats)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var readingStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("阅读统计")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                StatCard(
                    title: "阅读文章",
                    value: "\(readingStats.totalArticlesRead)",
                    icon: "doc.text.fill",
                    color: .purple
                )
                
                StatCard(
                    title: "阅读时长",
                    value: formatTime(readingStats.totalReadingTime),
                    icon: "clock.fill",
                    color: .indigo
                )
            }
            
            // 显示喜欢的话题
            if !readingStats.favoriteCategories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最喜欢的话题")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(Array(readingStats.favoriteCategories.prefix(10)), id: \.self) { topic in
                            HStack {
                                Text(topic)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var efficiencyAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习效率分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                StatCard(
                    title: "提升率",
                    value: "\(Int(efficiencyData.improvementRate * 100))%",
                    icon: "arrow.up.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "日均学习",
                    value: "\(Int(efficiencyData.dailyLearningRate))",
                    icon: "calendar.badge.plus",
                    color: .blue
                )
            }
            
            // 学习建议
            VStack(alignment: .leading, spacing: 8) {
                Text("学习建议")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("建议每日学习目标：\(efficiencyData.recommendedDailyGoal) 个单词")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Methods
    
    private func loadStatistics() {
        isLoading = true
        
        Task {
            do {
                // 使用ArticleService获取阅读统计
                let domainStats = try await articleService.getReadingStatistics()
                await MainActor.run {
                    // 直接使用领域模型
                    self.readingStats = domainStats
                }
            } catch {
                print("❌ 加载阅读统计失败: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                vocabularyStats = statisticsService.getVocabularyMasteryStatistics()
                testHistory = statisticsService.getTestHistoryStatistics()
                efficiencyData = statisticsService.getLearningEfficiencyAnalysis()
                loadLearningTrend(for: selectedTimeRange)
                
                isLoading = false
            }
        }
    }
    
    private func loadLearningTrend(for timeRange: TimeRange) {
        learningTrend = statisticsService.getLearningTrend(days: timeRange.days)
    }
    
    private func refreshStatistics() {
        statisticsService.clearStatisticsCache()
        loadStatistics()
    }
    
    // MARK: - Helper Methods
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

struct VocabularyMasteryChart: View {
    let statistics: VocabularyMasteryStatistics
    
    var body: some View {
        Chart {
            SectorMark(
                angle: .value("掌握", statistics.masteredWords),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(.green)
            .opacity(0.8)
            
            SectorMark(
                angle: .value("眼熟", statistics.familiarWords),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(.orange)
            .opacity(0.8)
            
            SectorMark(
                angle: .value("陌生", statistics.unfamiliarWords),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(.red)
            .opacity(0.8)
        }
        .chartLegend(position: .bottom)
    }
}

struct LearningTrendChart: View {
    let trendData: StatisticsLearningTrendData
    
    var body: some View {
        Chart(trendData.dailyData, id: \.date) { data in
            LineMark(
                x: .value("日期", data.date),
                y: .value("学习单词", data.wordsLearned)
            )
            .foregroundStyle(.blue)
            .symbol(Circle())
            
            AreaMark(
                x: .value("日期", data.date),
                y: .value("学习单词", data.wordsLearned)
            )
            .foregroundStyle(.blue.opacity(0.2))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
}

struct DictionaryTestRow: View {
    let dictionary: String
    let stats: DictionaryTestStats
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dictionary)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(stats.testCount) 次测试")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(stats.averageScore))%")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("最高 \(Int(stats.bestScore))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .cornerRadius(6)
    }
}

struct TrendStatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .cornerRadius(6)
    }
}

// MARK: - Time Range Enum

// 注释：TimeRange枚举已在CommonTypes.swift中定义，此处删除重复定义

// MARK: - Preview

struct LearningStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        LearningStatisticsView()
    }
}