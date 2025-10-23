//
//  CompositeRankingView.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import SwiftUI
import SwiftData

struct CompositeRankingView: View {
    @StateObject private var viewModel: CompositeRankingViewModel
    @EnvironmentObject private var appCoordinator: AppCoordinator
    
    // UI State
    @State private var showingDictionarySelection = false
    @State private var showingTestSelection = false
    @State private var showingExportOptions = false
    @State private var showingBatchLearning = false
    @State private var showingConfigSheet = false
    @State private var showingPresetSelection = false
    @State private var showingDictionaryPicker = false
    @State private var showingTestPicker = false
    @State private var showingStatistics = false
    
    // Batch Selection
    @State private var isBatchSelectionMode = false
    @State private var selectedArticleIds: Set<String> = []
    @State private var showBatchLearningConfirmation = false
    
    init(compositeRankingService: CompositeRankingService,
         intelligentRankingService: IntelligentRankingService,
         errorHandler: ErrorHandlerProtocol,
         dictionaryService: DictionaryServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: CompositeRankingViewModel(
            compositeRankingService: compositeRankingService,
            intelligentRankingService: intelligentRankingService,
            errorHandler: errorHandler,
            dictionaryService: dictionaryService
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部控制栏
                topControlBar
                
                // 配置摘要
                if viewModel.hasValidConfig {
                    configSummaryBar
                }
                
                // 统计信息
                statisticsSection(viewModel.statistics)
                
                // 主要内容
                mainContent
            }
            .navigationTitle("智能组合排序")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingConfigSheet) {
                CompositeRankingConfigSheet(
                    config: $viewModel.config,
                    availableDictionaries: viewModel.availableDictionaries,
                    availableTests: viewModel.availableTests,
                    onConfigUpdate: { config in
                        viewModel.updateConfig(config)
                    }
                )
            }
            .sheet(isPresented: $showingPresetSelection) {
                PresetSelectionSheet(
                    selectedPreset: $viewModel.selectedPreset,
                    onPresetSelected: { preset in
                        viewModel.applyPreset(preset)
                    }
                )
            }
            .alert("批量学习确认", isPresented: $showBatchLearningConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认学习") {
                    performBatchLearning()
                }
            } message: {
                Text("确定要将选中的 \(selectedArticleIds.count) 篇文章标记为已学习吗？")
            }
            .onAppear {
                loadArticlesAndPerformRanking()
            }
        }
    }
    
    // MARK: - Top Control Bar
    
    @ViewBuilder
    private var topControlBar: some View {
        HStack(spacing: 12) {
            // 预设选择按钮
            Button(action: { showingPresetSelection = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                    Text(viewModel.selectedPreset.rawValue)
                    Image(systemName: "chevron.down")
                }
                .font(.subheadline)
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 配置按钮
            Button(action: { showingConfigSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                    Text("配置")
                    if !viewModel.hasValidConfig {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // 批量选择按钮
            Button(action: { toggleBatchSelectionMode() }) {
                HStack(spacing: 6) {
                    Image(systemName: isBatchSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    Text(isBatchSelectionMode ? "完成" : "批量")
                }
                .font(.subheadline)
                .foregroundColor(isBatchSelectionMode ? .green : .purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background((isBatchSelectionMode ? Color.green : Color.purple).opacity(0.1))
                .cornerRadius(8)
            }
            
            // 统计按钮
            Button(action: { showingStatistics.toggle() }) {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundColor(.indigo)
                    .padding(8)
                    .background(Color.indigo.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Config Summary Bar
    
    @ViewBuilder
    private var configSummaryBar: some View {
        HStack {
            Text(viewModel.configSummary)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Statistics Section
    
    @ViewBuilder
    private func statisticsSection(_ statistics: CompositeRankingStatistics) -> some View {
        if showingStatistics {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    CompositeStatCard(
                        title: "文章总数",
                        value: "\(statistics.totalArticles)",
                        icon: "doc.text",
                        color: .blue
                    )
                    
                    CompositeStatCard(
                        title: "平均分数",
                        value: String(format: "%.2f", statistics.averageScore),
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green
                    )
                    
                    CompositeStatCard(
                        title: "排序条件",
                        value: "\(statistics.enabledCriteriaCount)",
                        icon: "slider.horizontal.3",
                        color: .orange
                    )
                }
                
                HStack(spacing: 16) {
                    IntegrationStatusCard(
                        title: "词典集成",
                        isEnabled: statistics.useDictionaryIntegration,
                        icon: "book.fill"
                    )
                    
                    IntegrationStatusCard(
                        title: "测试集成",
                        isEnabled: statistics.useTestResults,
                        icon: "checkmark.seal.fill"
                    )
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading {
            loadingView
        } else if !viewModel.hasValidConfig {
            configurationRequiredView
        } else if viewModel.rankedArticles.isEmpty {
            emptyStateView
        } else {
            articleListView
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在执行智能排序...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("分析文章内容、词典匹配和测试结果")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private var configurationRequiredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("配置排序条件")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("请先配置至少一个排序条件来开始智能排序")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("配置排序") {
                showingConfigSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("暂无排序结果")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("请检查排序配置或重新加载文章")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重新排序") {
                loadArticlesAndPerformRanking()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private var articleListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.rankedArticles, id: \.article.id) { result in
                    CompositeArticleCard(
                        result: result,
                        isBatchSelectionMode: isBatchSelectionMode,
                        isSelected: selectedArticleIds.contains(result.article.id.uuidString),
                        onSelectionToggle: {
                            toggleArticleSelection(result.article.id.uuidString)
                        },
                        onTap: {
                            if !isBatchSelectionMode {
                                appCoordinator.startReading(result.article)
                            }
                        }
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button("刷新资源", systemImage: "arrow.clockwise") {
                    viewModel.refreshResources()
                }
                
                Button("重置配置", systemImage: "arrow.counterclockwise") {
                    viewModel.resetConfig()
                }
                
                if isBatchSelectionMode && !selectedArticleIds.isEmpty {
                    Button("批量学习", systemImage: "checkmark.circle") {
                        showBatchLearningConfirmation = true
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadArticlesAndPerformRanking() {
        // 这里应该从适当的数据源加载文章
        // 暂时使用空数组，实际实现时需要注入文章数据
        Task {
            await viewModel.performRanking()
        }
    }
    
    private func toggleBatchSelectionMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isBatchSelectionMode.toggle()
            if !isBatchSelectionMode {
                selectedArticleIds.removeAll()
            }
        }
    }
    
    private func toggleArticleSelection(_ articleId: String) {
        if selectedArticleIds.contains(articleId) {
            selectedArticleIds.remove(articleId)
        } else {
            selectedArticleIds.insert(articleId)
        }
    }
    
    private func performBatchLearning() {
        // 实现批量学习逻辑
        print("执行批量学习: \(selectedArticleIds)")
        selectedArticleIds.removeAll()
        isBatchSelectionMode = false
    }
}

// MARK: - Supporting Views

struct CompositeStatCard: View {
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
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct IntegrationStatusCard: View {
    let title: String
    let isEnabled: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isEnabled ? .green : .gray)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isEnabled ? .green : .gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct CompositeArticleCard: View {
    let result: CompositeRankedArticle
    let isBatchSelectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                if isBatchSelectionMode {
                    Button(action: onSelectionToggle) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isSelected ? .blue : .gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
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
                    // 排名标识
                    Text("#\(result.rank)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(6)
                    
                    // 综合分数
                    Text(String(format: "%.2f", result.compositeScore))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            // 条件分数详情
            if !result.criteriaScores.isEmpty {
                criteriaScoresView
            }
            
            // 基础统计信息
            HStack(spacing: 16) {
                ArticleStatItem(
                    title: "总词数",
                    value: "\(result.baseResult.totalWords)",
                    icon: "textformat.123",
                    color: .primary
                )
                
                ArticleStatItem(
                    title: "生词数",
                    value: "\(result.baseResult.unknownWords)",
                    icon: "questionmark.circle",
                    color: .red
                )
                
                ArticleStatItem(
                    title: "难度",
                    value: result.baseResult.difficulty.rawValue,
                    icon: "chart.bar.fill",
                    color: result.baseResult.difficulty.color
                )
                
                ArticleStatItem(
                    title: "推荐度",
                    value: result.baseResult.recommendation.rawValue,
                    icon: "star.fill",
                    color: result.baseResult.recommendation.color
                )
            }
            
            // 集成信息
            if let dictionaryInfo = result.dictionaryMatchInfo {
                dictionaryMatchView(dictionaryInfo)
            }
            
            if let testInfo = result.testResultInfo {
                testResultView(testInfo)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isBatchSelectionMode {
                onSelectionToggle()
            } else {
                onTap()
            }
        }
    }
    
    @ViewBuilder
    private var criteriaScoresView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("排序条件分数")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(Array(result.criteriaScores.keys), id: \.self) { option in
                    if let score = result.criteriaScores[option] {
                        HStack {
                            Text(option.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(String(format: "%.2f", score))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func dictionaryMatchView(_ info: DictionaryMatchInfo) -> some View {
        HStack {
            Image(systemName: "book.fill")
                .foregroundColor(.blue)
            
            Text("词典匹配: \(info.dictionaryName)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(info.overlapCount) 词 (\(String(format: "%.1f", info.overlapPercentage))%)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func testResultView(_ info: TestResultInfo) -> some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)
            
            Text("测试结果")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("掌握: \(info.masteredWords.count) 词")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Extensions

extension RankingSortOption {
    var displayName: String {
        switch self {
        case .matchScore: return "匹配度"
        case .difficulty: return "难度"
        case .recommendation: return "推荐度"
        case .unknownWords: return "生词数"
        case .articleLength: return "文章长度"
        case .keywordReading: return "阅读理解"
        case .keywordTranslation: return "翻译"
        case .keywordWriting: return "写作"
        case .keywordKnowledge: return "知识运用"
        }
    }
}