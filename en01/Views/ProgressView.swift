//
//  ProgressView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI
import Charts

struct ProgressView: View {
    @ObservedObject var viewModel: ProgressViewModel
    
    init(viewModel: ProgressViewModel) {
        self.viewModel = viewModel
    }
    @State private var selectedTimeRange: TimeRange = .week
    @State private var progressData: ProgressData?
    @State private var achievements: [Achievement] = []
    @State private var isLoading = false
    @State private var isDataLoaded = false // 防止重复加载
    @State private var isShowingAchievements = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 用户等级卡片
                    userLevelCard
                    
                    // 今日统计
                    todayStatsCard
                    
                    // 学习趋势
                    learningTrendCard
                    
                    // 成就展示
                    achievementsCard
                    
                    // 详细统计
                    detailedStatsCard
                }
                .padding()
            }
            .navigationTitle("学习进度")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            if let _ = viewModel.exportProgressData() {
                                // Handle export data
                            }
                        } label: {
                            Label("导出数据", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            viewModel.refreshData()
                        } label: {
                            Label("刷新数据", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAchievements) {
            AchievementsView(achievements: achievements)
        }
        .onAppear {
            // 避免重复加载数据
            if !isDataLoaded {
                loadProgressData()
                isDataLoaded = true
            }
        }
        .onChange(of: selectedTimeRange) {
            loadProgressData()
        }
    }
    
    // MARK: - 用户等级卡片
    
    private var userLevelCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前等级")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("初学者")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // 等级图标
                Image(systemName: "star")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            // 经验值进度
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("经验值")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("0 / 100")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                SwiftUI.ProgressView(value: 0.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 1.5)
                
                Text("距离下一等级还需 100 经验值")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 今日统计卡片
    
    private var todayStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("今日学习")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("连续 \(viewModel.todayStats.consecutiveDays) 天")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                TodayStatItem(
                    title: "阅读时间",
                    value: formatTime(viewModel.todayStats.readingTime),
                    icon: "clock.fill",
                    color: .blue
                )
                
                TodayStatItem(
                    title: "查词次数",
                    value: "\(viewModel.todayStats.wordsLookedUp)",
                    icon: "book.fill",
                    color: .green
                )
                
                TodayStatItem(
                    title: "完成文章",
                    value: "\(viewModel.todayStats.articlesRead)",
                    icon: "doc.text.fill",
                    color: .purple
                )
                
                TodayStatItem(
                    title: "复习单词",
                    value: "\(viewModel.todayStats.reviewsCompleted)",
                    icon: "brain.head.profile",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 学习趋势卡片
    
    private var learningTrendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("学习趋势")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Picker("时间范围", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 150)
            }
            
            // 图表
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(getChartData(), id: \.date) { record in
                        LineMark(
                            x: .value("日期", record.date),
                            y: .value("阅读时间", record.readingTime / 60) // 转换为分钟
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("日期", record.date),
                            y: .value("阅读时间", record.readingTime / 60)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Double.self) {
                                Text("\(Int(intValue))分")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
            } else {
                // iOS 15 及以下的简单图表替代
                simpleChart
            }
            
            // 趋势统计
            HStack {
                TrendStatItem(
                    title: "平均每日",
                    value: formatTime(getAverageDailyTime()),
                    trend: .stable
                )
                
                Spacer()
                
                TrendStatItem(
                    title: "最长连续",
                    value: "\(viewModel.todayStats.consecutiveDays)天",
                    trend: .up
                )
                
                Spacer()
                
                TrendStatItem(
                    title: "本周总计",
                    value: formatTime(getWeeklyTotal()),
                    trend: .up
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // iOS 15 兼容的简单图表
    private var simpleChart: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(getChartData().suffix(7), id: \.date) { record in
                VStack {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 20, height: max(4, CGFloat(record.readingTime / 60) * 2))
                        .cornerRadius(2)
                    
                    Text("\(Calendar.current.component(.day, from: record.date))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 成就卡片
    
    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("最近成就")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("查看全部") {
                    isShowingAchievements = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if achievements.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("继续学习解锁成就")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(achievements.prefix(6)) { achievement in
                        AchievementBadge(achievement: achievement)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 详细统计卡片
    
    private var detailedStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("详细统计")
                .font(.headline)
                .fontWeight(.medium)
            
            VStack(spacing: 12) {
                DetailedStatRow(
                    title: "总阅读时间",
                    value: formatTime(viewModel.overallStats.totalReadingTime),
                    icon: "clock"
                )
                
                DetailedStatRow(
                    title: "已读文章",
                    value: "\(viewModel.readingStats.completedArticles) 篇",
                    icon: "doc.text"
                )
                
                DetailedStatRow(
                    title: "查词总数",
                    value: "\(viewModel.vocabularyStats.totalWords) 次",
                    icon: "book"
                )
                
                DetailedStatRow(
                    title: "复习完成",
                    value: "\(viewModel.todayStats.reviewsCompleted) 次",
                    icon: "brain.head.profile"
                )
                
                DetailedStatRow(
                    title: "学习天数",
                    value: "\(viewModel.todayStats.consecutiveDays) 天",
                    icon: "calendar"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 数据处理
    
    /// 异步加载进度数据（带性能优化）
    private func loadProgressData() {
        isLoading = true
        
        Task {
            // 并行加载数据以提高性能
            async let progressTask = loadUserProgress()
            async let achievementsTask = loadAchievements()
            async let statisticsTask = loadStatistics()
            
            let (progress, achievements, statistics) = await (progressTask, achievementsTask, statisticsTask)
            
            // 在主线程更新UI
            await MainActor.run {
                self.progressData = ProgressData(
                    userProgress: progress,
                    statistics: statistics
                )
                self.achievements = achievements
                self.isLoading = false
            }
        }
    }
    
    /// 异步加载用户进度
    private func loadUserProgress() async -> UserProgress? {
        // Return mock user progress for now
        let userProgress = UserProgress()
        userProgress.totalReadingTime = 1800
        userProgress.totalArticlesRead = 5
        userProgress.totalWordsLookedUp = 300
        userProgress.lastStudyDate = Date()
        userProgress.experience = 150
        return userProgress
    }
    
    /// 异步加载成就
    private func loadAchievements() async -> [Achievement] {
        return []
    }
    
    /// 异步加载统计数据
    private func loadStatistics() async -> ProgressStatistics {
        return await MainActor.run {
            // 根据选择的时间范围加载相应的统计数据
            let weeklyStats = WeeklyStats(readingTime: 0, articlesRead: 0, wordsLookedUp: 0, averageDailyTime: 0, streakDays: 0)
            let monthlyStats = MonthlyStats(readingTime: 0, articlesRead: 0, wordsLookedUp: 0, averageDailyTime: 0, totalDays: 0)
            
            return ProgressStatistics(
                weeklyStats: weeklyStats,
                monthlyStats: monthlyStats,
                dailyRecords: []
            )
        }
    }
    
    // MARK: - 计算属性
    
    private var weeklyStats: WeeklyStats {
        return progressData?.statistics.weeklyStats ?? WeeklyStats(readingTime: 0, articlesRead: 0, wordsLookedUp: 0, averageDailyTime: 0, streakDays: 0)
    }
    
    private func getChartData() -> [DailyStudyRecord] {
        // Return mock chart data for now
        return []
    }
    
    private func getAverageDailyTime() -> TimeInterval {
        let data = getChartData()
        guard !data.isEmpty else { return 0 }
        let total = data.reduce(0) { $0 + $1.readingTime }
        return total / Double(data.count)
    }
    
    private func getWeeklyTotal() -> TimeInterval {
        return weeklyStats.thisWeekReadingTime
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - 子视图组件

struct TodayStatItem: View {
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
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TrendStatItem: View {
    let title: String
    let value: String
    let trend: TrendDirection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: trend.iconName)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: achievement.iconName)
                .font(.title2)
                .foregroundColor(achievement.isUnlocked ? .yellow : .secondary)
            
            Text(achievement.title)
                .font(.caption2)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 60, height: 60)
        .background(achievement.isUnlocked ? Color.yellow.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(8)
        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
    }
}

struct DetailedStatRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 成就详情视图

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    let achievements: [Achievement]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AchievementType.allCases, id: \.self) { type in
                    Section(type.displayName) {
                        ForEach(achievements.filter { $0.type == type }) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                }
            }
            .navigationTitle("成就")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    
    var body: some View {
        HStack {
            Image(systemName: achievement.iconName)
                .font(.title2)
                .foregroundColor(achievement.isUnlocked ? .yellow : .secondary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if achievement.isUnlocked {
                    let date = achievement.unlockedDate
                    Text("解锁于 \(DateFormatter.shortDate.string(from: date))")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
    }
}

// MARK: - 枚举和扩展

enum TimeRange: String, CaseIterable {
    case week = "week"
    case month = "month"
    
    var displayName: String {
        switch self {
        case .week:
            return "周"
        case .month:
            return "月"
        }
    }
}

enum TrendDirection {
    case up, down, stable
    
    var iconName: String {
        switch self {
        case .up:
            return "arrow.up.right"
        case .down:
            return "arrow.down.right"
        case .stable:
            return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up:
            return .green
        case .down:
            return .red
        case .stable:
            return .secondary
        }
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

#Preview {
    ProgressView(viewModel: ProgressViewModel(
        userProgressService: MockUserProgressService(),
        articleService: MockArticleService(),
        errorHandler: MockErrorHandler()
    ))
}