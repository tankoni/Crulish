import SwiftUI
import Charts

struct ProgressDashboardView: View {
    @ObservedObject var viewModel: ProgressViewModel
    
    init(viewModel: ProgressViewModel) {
        self.viewModel = viewModel
    }
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedChartType: ChartType = .readingTime
    @State private var isDataLoaded = false
    @State private var showingExportSheet = false
    @State private var animateCharts = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // 时间范围选择器
                    timeRangeSelector
                    
                    // 今日统计概览
                    todayOverviewSection
                    
                    // 学习趋势图表
                    learningTrendsSection
                    
                    // 详细统计卡片
                    detailedStatsSection
                    
                    // 词汇进度分析
                    vocabularyProgressSection
                    
                    // 成就统计
                    achievementStatsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100) // 为底部导航栏留空间
            }
            .navigationTitle("学习统计")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("刷新数据", systemImage: "arrow.clockwise") {
                            refreshData()
                        }
                        Button("导出数据", systemImage: "square.and.arrow.up") {
                            showingExportSheet = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            if !isDataLoaded {
                loadData()
                isDataLoaded = true
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            exportDataSheet
        }
        .refreshable {
             await refreshDataAsync()
         }
     }
    
    // MARK: - 时间范围选择器
    private var timeRangeSelector: some View {
        HStack {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedTimeRange = range
                    viewModel.setTimeRange(range.rawValue)
                }) {
                    Text(range.displayName)
                        .font(.subheadline)
                        .fontWeight(selectedTimeRange == range ? .semibold : .regular)
                        .foregroundColor(selectedTimeRange == range ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTimeRange == range ? Color.blue : Color(.systemGray6))
                        )
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 今日统计概览
    private var todayOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("今日学习概览")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "阅读时长",
                    value: formatTime(viewModel.todayStats.readingTime),
                    icon: "clock",
                    color: .blue
                )
                
                StatCard(
                    title: "文章阅读",
                    value: "\(viewModel.todayStats.articlesRead)",
                    icon: "doc.text",
                    color: .green
                )
                
                StatCard(
                    title: "单词查询",
                    value: "\(viewModel.todayStats.wordsLookedUp)",
                    icon: "magnifyingglass",
                    color: .orange
                )
                
                StatCard(
                    title: "复习完成",
                    value: "\(viewModel.todayStats.reviewsCompleted)",
                    icon: "repeat",
                    color: .purple
                )
            }
            
            // 今日目标进度
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("今日目标进度")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(viewModel.todayGoalProgress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                ProgressView(value: viewModel.todayGoalProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 1.5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
     }
    
    // MARK: - 学习趋势图表
    private var learningTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("学习趋势")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Picker("图表类型", selection: $selectedChartType) {
                    Text("阅读时长").tag(ChartType.readingTime)
                    Text("词汇学习").tag(ChartType.vocabulary)
                    Text("学习进度").tag(ChartType.progress)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            Group {
                switch selectedChartType {
                case .readingTime:
                    ChartView(
                        data: viewModel.readingTimeChartData,
                        title: "阅读时长趋势",
                        color: .blue,
                        animate: animateCharts
                    )
                case .vocabulary:
                    ChartView(
                        data: viewModel.vocabularyChartData,
                        title: "词汇学习趋势",
                        color: .green,
                        animate: animateCharts
                    )
                case .progress:
                    ChartView(
                        data: viewModel.progressChartData,
                        title: "学习进度趋势",
                        color: .purple,
                        animate: animateCharts
                    )
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 详细统计卡片
    private var detailedStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("详细统计")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                // 周统计
                DetailedStatCard(
                    title: "本周统计",
                    stats: [
                        ("阅读时长", formatTime(viewModel.weeklyStats.totalReadingTime)),
                        ("文章数量", "\(viewModel.weeklyStats.totalArticlesRead)"),
                        ("单词查询", "\(viewModel.weeklyStats.totalWordsLookedUp)"),
                        ("复习次数", "\(viewModel.weeklyStats.totalReviewsCompleted)")
                    ],
                    color: .blue
                )
                
                // 月统计
                DetailedStatCard(
                    title: "本月统计",
                    stats: [
                        ("阅读时长", formatTime(viewModel.monthlyStats.totalReadingTime)),
                        ("文章数量", "\(viewModel.monthlyStats.totalArticlesRead)"),
                        ("单词查询", "\(viewModel.monthlyStats.totalWordsLookedUp)"),
                        ("复习次数", "\(viewModel.monthlyStats.totalReviewsCompleted)")
                    ],
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 词汇进度分析
    private var vocabularyProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("词汇进度分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // 掌握程度分布
                VStack(alignment: .leading, spacing: 8) {
                    Text("掌握程度分布")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    MasteryProgressBar(
                        title: "已掌握",
                        count: viewModel.vocabularyStats.masteredWords,
                        total: viewModel.vocabularyStats.totalWords,
                        color: .green
                    )
                    
                    MasteryProgressBar(
                        title: "学习中",
                        count: viewModel.vocabularyStats.learningWords,
                        total: viewModel.vocabularyStats.totalWords,
                        color: .orange
                    )
                    
                    MasteryProgressBar(
                        title: "待复习",
                        count: viewModel.vocabularyStats.reviewWords,
                        total: viewModel.vocabularyStats.totalWords,
                        color: .blue
                    )
                }
                
                Divider()
                
                // 学习效率
                HStack {
                    VStack(alignment: .leading) {
                        Text("总词汇量")
                            .font(.caption)
                        Text("\(viewModel.vocabularyStats.totalWords)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("掌握率")
                            .font(.caption)
                        Text("\(Int(viewModel.vocabularyStats.masteryRate * 100))%")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 成就统计
    private var achievementStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("成就统计")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("查看全部") {
                    // TODO: 实现查看全部成就功能
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                // 学习连续天数
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("最长连击记录")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(viewModel.achievementStats.longestStreak) 天")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("当前连击")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.overallStats.currentStreak) 天")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                
                // 成就徽章
                AchievementBadgeGrid(
                    badges: Array(viewModel.achievementStats.recentBadges.prefix(4)),
                    columns: 4,
                    size: .medium
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 辅助方法
    private func refreshDataAsync() async {
        viewModel.refreshData()
        withAnimation(.easeInOut(duration: 0.5)) {
            animateCharts.toggle()
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func loadData() {
        Task {
            await MainActor.run {
                viewModel.loadAllStatistics()
            }
        }
    }
    
    private func refreshData() {
        Task {
            await refreshDataAsync()
        }
    }
    
    private var exportDataSheet: some View {
        NavigationView {
            VStack {
                Text("导出学习数据")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding()
                
                // TODO: 实现数据导出功能
                Text("功能开发中...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("导出数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        showingExportSheet = false
                    }
                }
            }
        }
    }
}

// MARK: - 支持类型
enum ChartType {
    case readingTime
    case vocabulary
    case progress
}