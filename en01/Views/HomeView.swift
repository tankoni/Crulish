//
//  HomeView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var todaySummary: TodaySummary?
    @State private var streakStatus: StreakStatus?
    @State private var recommendations: [StudyRecommendation] = []
    @State private var recentArticles: [Article] = []
    @State private var recommendedArticles: [Article] = []
    @State private var isDataLoaded = false // 防止重复加载
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // 欢迎横幅
                    welcomeBanner
                    
                    // 今日学习摘要
                    todayStatsCard
                    
                    // 学习连续天数
                    streakCard
                    
                    // 快速操作
                    quickActionsCard
                    
                    // 推荐文章
                    recommendedArticlesSection
                    
                    // 最近阅读
                    recentArticlesSection
                    
                    // 学习建议
                    recommendationsSection
                }
                .padding(.horizontal)
            }
            .navigationTitle("Crulish")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                refreshData()
            }
        }
        .onAppear {
            // 避免重复加载数据
            if !isDataLoaded {
                refreshData()
                isDataLoaded = true
            }
        }
    }
    
    // MARK: - 欢迎横幅
    
    private var welcomeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingMessage)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("开始今日的英语学习之旅")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 用户等级信息
                levelBadge
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "早上好！"
        case 12..<17:
            return "下午好！"
        case 17..<22:
            return "晚上好！"
        default:
            return "夜深了，注意休息"
        }
    }
    
    private var levelBadge: some View {
        let levelInfo = appViewModel.getCurrentLevelInfo()
        
        return VStack(spacing: 4) {
            Text(levelInfo.level.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(levelInfo.level.color)
                .cornerRadius(8)
            
            Text("\(Int(levelInfo.progress * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 今日统计卡片
    
    private var todayStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("今日学习")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let summary = todaySummary, summary.isGoalAchieved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            if let summary = todaySummary {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    StatItem(
                        title: "今日阅读",
                        value: "\(summary.readingTime)分钟",
                        icon: "book.fill",
                        color: .blue
                    )
                    
                    StatItem(
                        title: "文章数",
                        value: "\(summary.articlesRead)",
                        icon: "book",
                        color: .green
                    )
                    
                    StatItem(
                        title: "查词数",
                        value: "\(summary.wordsLookedUp)",
                        icon: "text.magnifyingglass",
                        color: .orange
                    )
                    
                    StatItem(
                        title: "复习数",
                        value: "\(summary.reviewsCompleted)",
                        icon: "repeat",
                        color: .purple
                    )
                }
                
                // 目标进度条
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("每日目标进度")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(summary.dailyReadingGoalProgress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(summary.isGoalAchieved ? .green : .primary)
                    }
                    
                    SwiftUI.ProgressView(value: summary.dailyReadingGoalProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: summary.isGoalAchieved ? .green : .blue))
                }
            } else {
                Text("暂无今日数据")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 连续学习卡片
    
    private var streakCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    
                    Text("学习连续天数")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if let status = streakStatus {
                    Text(status.statusMessage)
                        .font(.caption)
                        .foregroundColor(status.statusColor)
                }
            }
            
            Spacer()
            
            if let status = streakStatus {
                Text("\(status.consecutiveDays)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(status.statusColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 快速操作
    
    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("快速开始")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionButton(
                    title: "继续阅读",
                    subtitle: "上次阅读的文章",
                    icon: "book.fill",
                    color: .blue
                ) {
                    if let article = appViewModel.getRecentArticles().first {
                        appViewModel.startReading(article)
                    }
                }
                
                QuickActionButton(
                    title: "推荐文章",
                    subtitle: "为你精选",
                    icon: "star.fill",
                    color: .yellow
                ) {
                    if let article = appViewModel.getNextRecommendedArticle() {
                        appViewModel.startReading(article)
                    }
                }
                
                QuickActionButton(
                    title: "词汇复习",
                    subtitle: "\(appViewModel.getWordsForReview().count)个待复习",
                    icon: "repeat.circle.fill",
                    color: .green
                ) {
                    appViewModel.selectTab(.vocabulary)
                }
                
                QuickActionButton(
                    title: "学习统计",
                    subtitle: "查看进度",
                    icon: "chart.bar.fill",
                    color: .purple
                ) {
                    appViewModel.selectTab(.progress)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 推荐文章
    
    private var recommendedArticlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("推荐阅读")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("查看全部") {
                    appViewModel.selectTab(.reading)
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if recommendedArticles.isEmpty {
                Text("暂无推荐文章")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(recommendedArticles.prefix(5)) { article in
                            ArticleCard(article: article) {
                                appViewModel.startReading(article)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - 最近阅读
    
    private var recentArticlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近阅读")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("查看全部") {
                    appViewModel.selectTab(.reading)
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if recentArticles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "book")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("还没有阅读记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("开始阅读第一篇文章吧！")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentArticles.prefix(3)) { article in
                        RecentArticleRow(article: article) {
                            appViewModel.startReading(article)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 学习建议
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("学习建议")
                .font(.headline)
                .fontWeight(.semibold)
            
            if recommendations.isEmpty {
                Text("暂无建议")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recommendations.prefix(3), id: \.title) { recommendation in
                        RecommendationCard(recommendation: recommendation)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 数据刷新
    
    /// 刷新主页数据（带性能优化）
    private func refreshData() {
        // 使用异步加载避免阻塞UI
        Task {
            // 并行加载数据以提高性能
            async let summaryTask = loadTodaySummary()
            async let streakTask = loadStreakStatus()
            async let recommendationsTask = loadRecommendations()
            async let recentTask = loadRecentArticles()
            async let recommendedTask = loadRecommendedArticles()
            
            // 等待所有数据加载完成
            let (summary, streak, recs, recent, recommended) = await (
                summaryTask, streakTask, recommendationsTask, recentTask, recommendedTask
            )
            
            // 在主线程更新UI
            await MainActor.run {
                self.todaySummary = summary
                self.streakStatus = streak
                self.recommendations = recs
                self.recentArticles = recent
                self.recommendedArticles = recommended
            }
        }
    }
    
    /// 异步加载今日摘要
    private func loadTodaySummary() async -> TodaySummary? {
        return appViewModel.getTodaySummary()
    }
    
    /// 异步加载连续学习状态
    private func loadStreakStatus() async -> StreakStatus? {
        return appViewModel.getStreakStatus()
    }
    
    /// 异步加载学习建议
    private func loadRecommendations() async -> [StudyRecommendation] {
        return appViewModel.getStudyRecommendations()
    }
    
    /// 异步加载最近文章
    private func loadRecentArticles() async -> [Article] {
        return appViewModel.getRecentArticles()
    }
    
    /// 异步加载推荐文章
    private func loadRecommendedArticles() async -> [Article] {
        return appViewModel.getRecommendedArticles()
    }
}

// MARK: - 子视图组件

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ArticleCard: View {
    let article: Article
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                HStack {
                    Text("\(article.year)年")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(article.difficulty.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(article.difficulty.color.opacity(0.2))
                        .foregroundColor(article.difficulty.color)
                        .cornerRadius(4)
                }
                
                if article.readingProgress > 0 {
                    SwiftUI.ProgressView(value: article.readingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
            .padding()
            .frame(width: 200)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentArticleRow: View {
    let article: Article
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        Text("\(article.year)年")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(article.difficulty.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if article.readingProgress > 0 {
                            Text("·")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(article.readingProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecommendationCard: View {
    let recommendation: StudyRecommendation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            priorityIndicator
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var priorityIndicator: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 8, height: 8)
    }
    
    private var priorityColor: Color {
        switch recommendation.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        }
    }
}

#Preview {
    HomeView()
        .environment(AppViewModel())
}