//
//  StatisticsView.swift
//  en01
//
//  Created by AI Assistant on 2024/12/30.
//

import SwiftUI
import Charts
import SwiftData

/// 统计数据主视图
struct StatisticsView: View {
    @ObservedObject var viewModel: ProgressViewModel
    @State private var selectedTab = 0
    @State private var showingExportView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部标签选择器
                tabSelector
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    // 学习概览
                    learningOverviewTab
                        .tag(0)
                    
                    // 词汇统计
                    vocabularyStatsTab
                        .tag(1)
                    
                    // 阅读统计
                    readingStatsTab
                        .tag(2)
                    
                    // 成就系统
                    achievementTab
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("学习统计")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("导出") {
                        showingExportView = true
                    }
                    .sheet(isPresented: $showingExportView) {
                        StatisticsExportView(
                            viewModel: viewModel,
                            statisticsExportService: viewModel.getStatisticsExportService()
                        )
                    }
                }
            }
            .onAppear {
                viewModel.loadAllStatistics()
            }
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabItems.enumerated()), id: \.offset) { index, item in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .medium))
                        Text(item.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == index ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(.systemGray6))
        .overlay(
            // 选中指示器
            Rectangle()
                .fill(Color.blue)
                .frame(height: 2)
                .offset(x: CGFloat(selectedTab) * (UIScreen.main.bounds.width / CGFloat(tabItems.count)) - UIScreen.main.bounds.width / 2 + UIScreen.main.bounds.width / CGFloat(tabItems.count) / 2)
                .animation(.easeInOut(duration: 0.3), value: selectedTab),
            alignment: .bottom
        )
    }
    
    private var tabItems: [(title: String, icon: String)] {
        [
            ("概览", "chart.bar.fill"),
            ("词汇", "book.fill"),
            ("阅读", "book.fill"),
            ("成就", "trophy.fill")
        ]
    }
    
    // MARK: - Learning Overview Tab
    private var learningOverviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 今日统计卡片
                todayStatsSection
                
                // 学习趋势图表
                learningTrendsSection
                
                // 周月统计对比
                weeklyMonthlyComparisonSection
                
                // 学习目标进度
                goalProgressSection
            }
            .padding()
        }
    }
    
    // MARK: - Vocabulary Stats Tab
    private var vocabularyStatsTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 词汇掌握概览
                vocabularyOverviewSection
                
                // 掌握程度分布
                masteryDistributionSection
                
                // 词汇学习趋势
                vocabularyTrendsSection
                
                // 复习统计
                reviewStatsSection
            }
            .padding()
        }
    }
    
    // MARK: - Reading Stats Tab
    private var readingStatsTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 阅读概览
                readingOverviewSection
                
                // 阅读时长趋势
                readingTimeTrendsSection
                
                // 文章统计
                articleStatsSection
                
                // 阅读偏好分析
                readingPreferencesSection
            }
            .padding()
        }
    }
    
    // MARK: - Achievement Tab
    private var achievementTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 成就概览
                achievementOverviewSection
                
                // 最近获得的成就
                recentAchievementsSection
                
                // 学习连续天数
                streakSection
                
                // 即将达成的成就
                upcomingAchievementsSection
            }
            .padding()
        }
    }
    
    // MARK: - Today Stats Section
    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今日学习")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "阅读时长",
                    value: formatTime(viewModel.todayStats.readingTime),
                    icon: "clock.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "文章阅读",
                    value: "\(viewModel.todayStats.articlesRead)",
                    icon: "book.fill",
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
        }
    }
    
    // MARK: - Learning Trends Section
    private var learningTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习趋势")
                .font(.title2)
                .fontWeight(.bold)
            
            if !viewModel.readingTimeChartData.isEmpty {
                ChartView(
                    data: viewModel.readingTimeChartData,
                    title: "阅读时长趋势",
                    color: .blue,
                    animate: true
                )
                .frame(height: 200)
            } else {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
    }
    
    // MARK: - Weekly Monthly Comparison Section
    private var weeklyMonthlyComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("统计对比")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                DetailedStatCard(
                    title: "本周统计",
                    stats: [
                        ("阅读时长", formatTime(viewModel.weeklyStats.totalReadingTime)),
                        ("文章数量", "\(viewModel.weeklyStats.totalArticlesRead)"),
                        ("单词查询", "\(viewModel.weeklyStats.totalWordsLookedUp)"),
                        ("学习天数", "\(viewModel.weeklyStats.studyDaysThisWeek)")
                    ],
                    color: .blue
                )
                
                DetailedStatCard(
                    title: "本月统计",
                    stats: [
                        ("阅读时长", formatTime(viewModel.monthlyStats.totalReadingTime)),
                        ("文章数量", "\(viewModel.monthlyStats.totalArticlesRead)"),
                        ("单词查询", "\(viewModel.monthlyStats.totalWordsLookedUp)"),
                        ("学习天数", "\(viewModel.monthlyStats.studyDaysThisMonth)")
                    ],
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Goal Progress Section
    private var goalProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("目标进度")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                goalProgressBar("今日目标", progress: viewModel.todayGoalProgress, color: .blue)
                goalProgressBar("本周目标", progress: viewModel.weeklyGoalProgress, color: .green)
                goalProgressBar("本月目标", progress: viewModel.monthlyGoalProgress, color: .purple)
            }
        }
    }
    
    private func goalProgressBar(_ title: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(y: 2)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Vocabulary Overview Section
    private var vocabularyOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("词汇概览")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "总词汇量",
                    value: "\(viewModel.vocabularyStats.totalWords)",
                    icon: "book.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "已掌握",
                    value: "\(viewModel.vocabularyStats.masteredWords)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "学习中",
                    value: "\(viewModel.vocabularyStats.learningWords)",
                    icon: "brain.head.profile",
                    color: .orange
                )
                
                StatCard(
                    title: "掌握率",
                    value: "\(Int(viewModel.vocabularyStats.masteryRate * 100))%",
                    icon: "chart.pie.fill",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Mastery Distribution Section
    private var masteryDistributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("掌握程度分布")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
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
                
                let unlearned = viewModel.vocabularyStats.totalWords - viewModel.vocabularyStats.masteredWords - viewModel.vocabularyStats.learningWords - viewModel.vocabularyStats.reviewWords
                MasteryProgressBar(
                    title: "未学习",
                    count: max(0, unlearned),
                    total: viewModel.vocabularyStats.totalWords,
                    color: .gray
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Vocabulary Trends Section
    private var vocabularyTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("词汇学习趋势")
                .font(.title2)
                .fontWeight(.bold)
            
            if !viewModel.vocabularyChartData.isEmpty {
                ChartView(
                    data: viewModel.vocabularyChartData,
                    title: "词汇学习趋势",
                    color: .green,
                    animate: true
                )
                .frame(height: 200)
            } else {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
    }
    
    // MARK: - Review Stats Section
    private var reviewStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("复习统计")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "本周新词",
                    value: "\(viewModel.vocabularyStats.weeklyNewWords)",
                    icon: "plus.circle.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "本月新词",
                    value: "\(viewModel.vocabularyStats.monthlyNewWords)",
                    icon: "calendar",
                    color: .green
                )
                
                StatCard(
                    title: "复习准确率",
                    value: "\(Int(viewModel.vocabularyStats.averageReviewAccuracy * 100))%",
                    icon: "target",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Reading Overview Section
    private var readingOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("阅读概览")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "已完成文章",
                    value: "\(viewModel.readingStats.completedArticles)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "进行中文章",
                    value: "\(viewModel.readingStats.inProgressArticles)",
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "收藏文章",
                    value: "\(viewModel.readingStats.bookmarkedArticles)",
                    icon: "bookmark.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "平均阅读时长",
                    value: formatTime(viewModel.readingStats.averageReadingTime),
                    icon: "timer",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Reading Time Trends Section
    private var readingTimeTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("阅读时长趋势")
                .font(.title2)
                .fontWeight(.bold)
            
            if !viewModel.readingTimeChartData.isEmpty {
                ChartView(
                    data: viewModel.readingTimeChartData,
                    title: "阅读时长趋势",
                    color: .blue,
                    animate: true
                )
                .frame(height: 200)
            } else {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
    }
    
    // MARK: - Article Stats Section
    private var articleStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("文章统计")
                .font(.title2)
                .fontWeight(.bold)
            
            // 难度分布
            if !viewModel.readingStats.difficultyDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("难度分布")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ForEach(Array(viewModel.readingStats.difficultyDistribution.sorted(by: { $0.key < $1.key })), id: \.key) { difficulty, count in
                        HStack {
                            Text(difficulty)
                                .font(.subheadline)
                            Spacer()
                            Text("\(count) 篇")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Reading Preferences Section
    private var readingPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("阅读偏好")
                .font(.title2)
                .fontWeight(.bold)
            
            if !viewModel.readingStats.favoriteTopics.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("喜爱主题")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(viewModel.readingStats.favoriteTopics.prefix(6), id: \.self) { topic in
                            Text(topic)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Achievement Overview Section
    private var achievementOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("成就概览")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "总成就数",
                    value: "\(viewModel.achievementStats.totalAchievements)",
                    icon: "trophy.fill",
                    color: .gold
                )
                
                StatCard(
                    title: "已解锁",
                    value: "\(viewModel.achievementStats.unlockedAchievements)",
                    icon: "checkmark.seal.fill",
                    color: .green
                )
                
                StatCard(
                    title: "完成率",
                    value: "\(viewModel.achievementStats.totalAchievements > 0 ? Int(Double(viewModel.achievementStats.unlockedAchievements) / Double(viewModel.achievementStats.totalAchievements) * 100) : 0)%",
                    icon: "percent",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Recent Achievements Section
    private var recentAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近获得的成就")
                .font(.title2)
                .fontWeight(.bold)
            
            if !viewModel.achievementStats.recentBadges.isEmpty {
                AchievementBadgeGrid(
                    badges: Array(viewModel.achievementStats.recentBadges.prefix(8)),
                    columns: 4,
                    size: .medium
                )
            } else {
                Text("暂无成就")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Streak Section
    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习连续天数")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "当前连续",
                    value: "\(viewModel.overallStats.currentStreak) 天",
                    icon: "flame.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "最长连续",
                    value: "\(viewModel.achievementStats.longestStreak) 天",
                    icon: "crown.fill",
                    color: .gold
                )
            }
        }
    }
    
    // MARK: - Upcoming Achievements Section
    private var upcomingAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("即将达成的成就")
                .font(.title2)
                .fontWeight(.bold)
            
            if !viewModel.achievementStats.nextMilestones.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.achievementStats.nextMilestones.prefix(5), id: \.self) { milestone in
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.blue)
                            Text(milestone)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                Text("暂无即将达成的成就")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Color Extension
extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}

#Preview {
    // 创建一个用于预览的 mock ProgressViewModel
    let mockUserProgressService = MockUserProgressService()
    let mockArticleService = MockArticleService()
    let mockErrorHandler = UnifiedErrorHandler()
    let mockStatisticsExportService: StatisticsExportServiceProtocol = StatisticsExportService(
        modelContext: try! ModelContainer(for: VocabularyTest.self, TestedWord.self).mainContext,
        vocabularyTestService: MockVocabularyTestService(dictionaryService: MockDictionaryService()),
        errorHandler: mockErrorHandler,
        dictionaryService: MockDictionaryService()
    )
    let mockProgressViewModel = ProgressViewModel(
        userProgressService: mockUserProgressService,
        articleService: mockArticleService,
        errorHandler: mockErrorHandler,
        statisticsExportService: mockStatisticsExportService
    )
    
    StatisticsView(viewModel: mockProgressViewModel)
}