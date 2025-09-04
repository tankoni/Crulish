//
//  IntelligentRankingView.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import SwiftUI

// MARK: - IntelligentRankingView
// 智能排序视图，使用 HomeView 中定义的 StatItem 组件

struct IntelligentRankingView: View {
    @StateObject private var rankingService = IntelligentRankingService()
    @ObservedObject var viewModel: IntelligentRankingViewModel
    
    @State private var selectedSortOption: RankingSortOption = .matchScore
    @State private var isLoading = false
    @State private var showSortOptions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部控制栏
                topControlBar
                
                // 内容区域
                if isLoading {
                    loadingView
                } else if viewModel.rankedArticles.isEmpty {
                    emptyStateView
                } else {
                    articleListView
                }
            }
            .navigationTitle("智能排序")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .sheet(isPresented: $showSortOptions) {
                sortOptionsSheet
            }
        }
        .onAppear {
            loadRankedArticles()
        }
    }
    
    // MARK: - 顶部控制栏
    private var topControlBar: some View {
        HStack {
            // 排序选项按钮
            Button(action: { showSortOptions = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(selectedSortOption.rawValue)
                    Image(systemName: "chevron.down")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // 结果统计
            if !viewModel.rankedArticles.isEmpty {
                Text("\(viewModel.rankedArticles.count) 篇文章")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    // MARK: - 文章列表
    private var articleListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.rankedArticles, id: \ArticleMatchResult.article.id) { result in
                    ArticleRankingCard(result: result)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在分析文章匹配度...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("暂无文章")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("请先添加一些文章，然后进行词汇测试以获得个性化推荐")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("开始词汇测试") {
                // 导航到词汇测试
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 刷新按钮
    private var refreshButton: some View {
        Button(action: {
            rankingService.clearCache()
            loadRankedArticles()
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(isLoading)
    }
    
    // MARK: - 排序选项表单
    private var sortOptionsSheet: some View {
        NavigationView {
            List {
                Section("排序方式") {
                    ForEach(RankingSortOption.allCases, id: \.self) { option in
                        Button(action: {
                            selectedSortOption = option
                            applySorting()
                            showSortOptions = false
                        }) {
                            HStack {
                                Text(option.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedSortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("说明") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 匹配度：基于您的词汇掌握情况计算")
                        Text("• 难度：根据生词比例确定")
                        Text("• 推荐度：综合考虑学习效果")
                        Text("• 生词数量：文章中的未掌握词汇数")
                        Text("• 文章长度：文章总词数")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("排序选项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showSortOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - 方法
    private func loadRankedArticles() {
        isLoading = true
        
        Task {
            await viewModel.loadRankedArticles()
            await MainActor.run {
                applySorting()
                isLoading = false
            }
        }
    }
    
    private func applySorting() {
        viewModel.sortArticles(by: selectedSortOption)
    }
}

// MARK: - 文章排序卡片
struct ArticleRankingCard: View {
    let result: ArticleMatchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和推荐等级
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.article.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(result.article.examType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // 推荐等级标签
                    Text(result.recommendation.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(result.recommendation.color)
                        .cornerRadius(6)
                    
                    // 匹配分数
                    Text("\(Int(result.matchScore))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            // 统计信息
            HStack(spacing: 16) {
                StatItem(title: "总词数", value: "\(result.totalWords)", icon: "textformat.123", color: .primary)
                StatItem(title: "生词数", value: "\(result.unknownWords)", icon: "questionmark.circle", color: .red)
                StatItem(title: "熟悉词", value: "\(result.familiarWords)", icon: "eye", color: .orange)
                StatItem(title: "掌握词", value: "\(result.masteredWords)", icon: "checkmark.circle", color: .green)
            }
            
            // 难度和百分比
            HStack {
                // 难度标签
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                    Text(result.difficulty.rawValue)
                }
                .font(.caption)
                .foregroundColor(result.difficulty.color)
                
                Spacer()
                
                // 生词百分比
                Text("生词率: \(String(format: "%.1f", result.unknownPercentage))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 进度条
            ProgressBar(
                mastered: result.masteredPercentage,
                familiar: Double(result.familiarWords) / Double(result.totalWords) * 100,
                unknown: result.unknownPercentage
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 进度条
struct ProgressBar: View {
    let mastered: Double
    let familiar: Double
    let unknown: Double
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                // 掌握部分
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geometry.size.width * mastered / 100)
                
                // 眼熟部分
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: geometry.size.width * familiar / 100)
                
                // 生词部分
                Rectangle()
                    .fill(Color.red)
                    .frame(width: geometry.size.width * unknown / 100)
                
                // 填充剩余空间
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
        }
        .frame(height: 4)
        .cornerRadius(2)
    }
}

// MARK: - 预览
struct IntelligentRankingView_Previews: PreviewProvider {
    static var previews: some View {
        Text("IntelligentRankingView Preview")
            .navigationTitle("智能排序")
    }
}