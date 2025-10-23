//
//  IntelligentRankingView.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import SwiftUI
import Combine
import SwiftData

// MARK: - IntelligentRankingView
// 智能排序视图，使用 HomeView 中定义的 StatItem 组件

struct IntelligentRankingView: View {
    @EnvironmentObject private var viewModel: IntelligentRankingViewModel
    @State private var selectedBasicSortOption: BasicSortOption = .unknownWords
    @State private var selectedKeywordSortOption: KeywordSortOption = .reading
    @State private var availableDictionaries: [DictionaryInfo] = []
    @State private var isLoading: Bool = false
    @State private var showSortOptions: Bool = false
    @State private var showDictionarySelector: Bool = false
    @State private var showAdaptiveSettings: Bool = false
    @State private var showCompositeRanking: Bool = false
    @State private var showInsightCard: Bool = false
    
    // 批量选择功能状态
    @State private var isBatchSelectionMode: Bool = false
    @State private var selectedArticleIds: Set<String> = []
    @State private var showBatchLearningConfirmation: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部控制栏
                topControlBar
                
                // 自适应洞察卡片
                if viewModel.isAdaptiveMode && !isLoading {
                    adaptiveInsightSection
                }
                
                // 主要内容区域
                mainContentArea
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSortOptions) {
                sortOptionsSheet
            }
            .sheet(isPresented: $showDictionarySelector) {
                dictionarySelectorSheet
            }
            .sheet(isPresented: $viewModel.showTestHistorySelection) {
                testHistorySelectionSheet
            }
            .sheet(isPresented: $viewModel.showStagedRanking) {
                stagedRankingSheet
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showAdaptiveSettings) {
                AdaptiveSettingsSheet(
                    isPresented: $showAdaptiveSettings,
                    isAdaptiveEnabled: $viewModel.isAdaptiveMode,
                    adaptiveWeights: .constant(AdaptiveWeights(
                        vocabularyMatch: 0.8,
                        difficultyAdaptation: 0.7,
                        learningHistory: 0.6,
                        progressOptimization: 0.9
                    )),
                    adaptiveMode: .constant(.balanced)
                )
            }
            .sheet(isPresented: $showCompositeRanking) {
                CompositeRankingView(
                    compositeRankingService: ServiceContainer.shared.getCompositeRankingService(),
                    intelligentRankingService: ServiceContainer.shared.getIntelligentRankingService(),
                    errorHandler: ServiceContainer.shared.getErrorHandler(),
                    dictionaryService: ServiceContainer.shared.getDictionaryService()
                )
            }
            .alert("批量学习确认", isPresented: $showBatchLearningConfirmation) {
                Button("确认学习") {
                    Task {
                        await performBatchLearning()
                    }
                }
            } message: {
                Text("确定要将选中的 \(selectedArticleIds.count) 篇文章标记为已学习吗？")
            }
            .onAppear {
                loadAvailableDictionaries()
                loadRankedArticles()
            }
            .onChange(of: viewModel.selectedDictionary) { _, _ in
                Task {
                    await viewModel.loadRankedArticles()
                }
            }
        }
    }
    
    // MARK: - 测试历史选择视图
    @ViewBuilder
    private var testHistorySelectionSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部说明
                topDescriptionSection
                
                // 测试记录列表
                testRecordsList
            }
            .navigationTitle("选择测试记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        viewModel.showTestHistorySelection = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        viewModel.showTestHistorySelection = false
                        if let selectedTestState = viewModel.selectedTestState {
                            Task {
                                await viewModel.performStagedRanking(with: selectedTestState)
                            }
                        }
                    }
                    .disabled(viewModel.selectedTestState?.selectedTest == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - 顶部描述区域
    private var topDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedTestState = viewModel.selectedTestState {
                Text("选择测试记录")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("词典：\(selectedTestState.dictionary.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 测试记录列表
    private var testRecordsList: some View {
        List {
            if let selectedTestState = viewModel.selectedTestState {
                if case .multipleTests = selectedTestState.status {
                    Section {
                        ForEach(selectedTestState.testHistory, id: \.id) { test in
                            let isSelected = selectedTestState.selectedTest?.id == test.id
                            TestRecordRow(
                                test: test,
                                isSelected: isSelected,
                                onSelect: {
                                    viewModel.selectTestRecord(test, for: selectedTestState)
                                }
                            )
                        }
                    } header: {
                        Text("可用测试记录")
                    }
                }
            }
        }
    }
    
    // MARK: - 分阶段排序视图
    @ViewBuilder
    private var stagedRankingSheet: some View {
        NavigationStack {
            stagedRankingContent
                .navigationTitle("分阶段排序")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    stagedRankingToolbar
                }
        }
    }
    
    @ViewBuilder
    private var stagedRankingContent: some View {
        VStack(spacing: 0) {
            stagedRankingControlBar
            stagedRankingResultsList
        }
    }
    
    @ToolbarContentBuilder
    private var stagedRankingToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("返回") {
                viewModel.showStagedRanking = false
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("应用排序") {
                applyStagedRanking()
            }
        }
    }
    
    // MARK: - Staged Ranking Actions
    
    private func applyStagedRanking() {
        guard let results = viewModel.stagedRankingResults else { return }
        
        // 应用分阶段排序结果
        if viewModel.currentStage == 1 {
            // 处理第一阶段结果
            // 这里可以添加应用第一阶段排序的逻辑
            print("应用第一阶段排序结果，共 \(results.stage1Results.count) 项")
        } else {
            // 处理第二阶段结果
            // 这里可以添加应用第二阶段排序的逻辑
            print("应用第二阶段排序结果，共 \(results.stage2Results.count) 项")
        }
        
        viewModel.showStagedRanking = false
    }

    
    @ViewBuilder
    private var stagedRankingControlBar: some View {
        HStack {
            // 阶段切换按钮
            HStack(spacing: 8) {
                ForEach(Array(1..<3), id: \.self) { stage in
                    stageSelectorButton(stage)
                }
            }
            
            Spacer()
            
            // 当前阶段说明
            Text(stageDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    @ViewBuilder
    private var stagedRankingResultsList: some View {
        if let results = viewModel.stagedRankingResults {
            if viewModel.currentStage == 1 {
                stage1ResultsList(results: results.stage1Results)
            } else {
                stage2ResultsList(results: results.stage2Results)
            }
        } else {
            loadingView
        }
    }
    
    @ViewBuilder
    private func stage1ResultsList(results: [DictionaryOverlapInfo]) -> some View {
        List {
            ForEach(results.indices, id: \.self) { index in
                let result = results[index]
                StagedDictionaryOverlapRow(
                    result: result,
                    rank: index + 1
                )
            }
        }
    }
    
    @ViewBuilder
    private func stage2ResultsList(results: [UserMasteryInfo]) -> some View {
        List {
            ForEach(results.indices, id: \.self) { index in
                let result = results[index]
                StagedUserMasteryRow(
                    result: result,
                    rank: index + 1
                )
            }
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在生成分阶段排序...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    


    private var stageDescription: String {
        viewModel.currentStage == 1 ? "按重合度排序" : "按掌握情况排序"
    }

    @ViewBuilder
    private func stageSelectorButton(_ stage: Int) -> some View {
        let isSelected = viewModel.currentStage == stage
        Button(action: {
            viewModel.currentStage = stage
        }) {
            Text("阶段\(stage)")
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? Color.white : Color.primary)
                .cornerRadius(8)
        }
    }
    
    // MARK: - 主要内容区域
    private var mainContentArea: some View {
        VStack(spacing: 0) {
            // 统计信息区域
            if !isLoading && !viewModel.rankedArticles.isEmpty {
                statisticsSection
            }
            
            // 内容区域
            if isLoading {
                mainLoadingView
            } else if viewModel.rankedArticles.isEmpty {
                emptyStateView
            } else {
                articleListView
            }
        }
    }
    
    // MARK: - 文章列表视图
    private var articleListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.rankedArticles, id: \.article.id) { result in
                    ArticleRankingCard(
                        result: result,
                        recommendationReason: viewModel.isAdaptiveMode ? 
                            viewModel.getRecommendationReason(for: result) : nil,
                        isBatchSelectionMode: isBatchSelectionMode,
                        isSelected: selectedArticleIds.contains(result.article.id.uuidString),
                        onSelectionToggle: {
                            toggleArticleSelection(result.article.id.uuidString)
                        }
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - 自适应洞察区域
    private var adaptiveInsightSection: some View {
        Group {
            if let insights = viewModel.currentLearningInsights {
                AdaptiveInsightCard(
                    insights: insights,
                    isExpanded: showInsightCard,
                    onToggleExpansion: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showInsightCard.toggle()
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - 顶部控制栏
    private var topControlBar: some View {
        VStack(spacing: 8) {
            // 第一行：阅读模式、自适应模式、排序选项
            HStack {
                // 阅读模式切换按钮
                Button(action: { 
                    Task {
                        let newMode: ReadingMode = viewModel.selectedReadingMode == .yearlyExams ? .soloArticles : .yearlyExams
                        await viewModel.switchReadingMode(to: newMode)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.selectedReadingMode.iconName)
                        Text(viewModel.selectedReadingMode.displayName)
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // 自适应模式指示器
                if viewModel.isAdaptiveMode {
                    Button(action: { 
                        Task {
                            await viewModel.toggleAdaptiveMode()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                            Text("智能推荐")
                        }
                        .font(.subheadline)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 排序选项按钮
                Button(action: { showSortOptions = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedBasicSortOption.rawValue)
                                .font(.caption)
                            if selectedKeywordSortOption != .none {
                                Text("+ \(selectedKeywordSortOption.rawValue)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
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
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(viewModel.rankedArticles.count) 篇文章")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if viewModel.isAdaptiveMode {
                            Text("智能推荐")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            
            // 第二行：词典选择、导出、分阶段排序、批量选择
            HStack {
                // 词典选择按钮
                Button(action: { showDictionarySelector = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                        Text(viewModel.selectedDictionary?.displayName ?? "选择词典")
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // 批量选择按钮
                if !viewModel.rankedArticles.isEmpty {
                    Button(action: toggleBatchSelectionMode) {
                        HStack(spacing: 4) {
                            Image(systemName: isBatchSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                            Text(isBatchSelectionMode ? "取消选择" : "批量选择")
                        }
                        .font(.subheadline)
                        .foregroundColor(isBatchSelectionMode ? .red : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background((isBatchSelectionMode ? Color.red : Color.blue).opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 导出按钮
                Button(action: exportTopArticles) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出前10")
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // 批量学习按钮（仅在批量选择模式下显示）
                if isBatchSelectionMode && !selectedArticleIds.isEmpty {
                    Button(action: { showBatchLearningConfirmation = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                            Text("学习(\(selectedArticleIds.count))")
                        }
                        .font(.subheadline)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 组合排序按钮
                Button(action: { showCompositeRanking = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("组合排序")
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // 分阶段排序按钮（只有当选中词典有测试记录时才显示）
                if viewModel.selectedDictionary != nil && 
                   !isBatchSelectionMode && 
                   viewModel.selectedTestState?.testForRanking != nil {
                    Button(action: {
                        Task {
                            if let selectedTestState = viewModel.selectedTestState {
                                await viewModel.performStagedRanking(with: selectedTestState)
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "list.number")
                            Text("分阶段")
                        }
                        .font(.subheadline)
                        .foregroundColor(.indigo)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.indigo.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 统计信息区域
    private var statisticsSection: some View {
        VStack(spacing: 12) {
            // 难度分布统计
            HStack {
                Text("难度分布")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(IntelligentRankingDifficultyLevel.allCases, id: \.self) { difficulty in
                        let count = viewModel.rankedArticles.filter { $0.difficulty == difficulty }.count
                        DifficultyTag(difficulty: difficulty, count: count)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 加载视图
    private var mainLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在分析文章...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("暂无文章数据")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("请检查文章数据是否正确加载")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 排序选项表单
    private var sortOptionsSheet: some View {
        NavigationView {
            List {
                Section("基础排序") {
                    ForEach(BasicSortOption.allCases, id: \.self) { option in
                        HStack {
                            Text(option.rawValue)
                            Spacer()
                            if selectedBasicSortOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedBasicSortOption = option
                        }
                    }
                }
                
                Section("关键词排序（可选）") {
                    ForEach(KeywordSortOption.allCases, id: \.self) { option in
                        HStack {
                            Text(option.rawValue)
                            Spacer()
                            if selectedKeywordSortOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedKeywordSortOption = option
                        }
                    }
                }
            }
            .navigationTitle("排序选项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showSortOptions = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用") {
                        applySorting()
                        showSortOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - 词典选择表单
    private var dictionarySelectorSheet: some View {
        NavigationView {
            List {
                Section("可用词典") {
                    ForEach(viewModel.dictionaryTestStates, id: \.dictionary.id) { testState in
                        DictionaryTestStateRow(
                            testState: testState,
                            isSelected: viewModel.selectedDictionary?.id == testState.dictionary.id,
                            onSelect: {
                                viewModel.selectDictionary(testState.dictionary)
                                showDictionarySelector = false
                            }
                        )
                    }
                }
                
                Section("说明") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("智能排序功能：")
                            .fontWeight(.medium)
                        Text("• 第一阶段：按词典重合度排序")
                        Text("• 第二阶段：在相同重合度组内按掌握情况排序")
                        Text("• 优先推荐包含更多该词典词汇的文章")
                        Text("• 基于您的测试结果个性化推荐")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("选择词典")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showDictionarySelector = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - 私有方法
    private func loadAvailableDictionaries() {
        Task {
            await viewModel.loadDictionaryTestStates()
        }
    }
    
    private func loadRankedArticles() {
        Task {
            isLoading = true
            await viewModel.loadRankedArticles()
            isLoading = false
        }
    }

    
    private func applySorting() {
        Task {
            isLoading = true
            await MainActor.run {
                print("🔍 应用排序 - 基础选项: \(selectedBasicSortOption.rawValue), 关键词选项: \(selectedKeywordSortOption.rawValue)")
                
                // 如果选择了关键词排序选项（非"无"），则先按关键词筛选，再按基础选项排序
                if selectedKeywordSortOption != .none {
                    viewModel.sortArticlesWithKeywordAndBasic(
                        keywordOption: selectedKeywordSortOption,
                        basicOption: selectedBasicSortOption
                    )
                } else {
                    // 只使用基础排序选项
                    let primarySortOption = selectedBasicSortOption.toRankingSortOption()
                    viewModel.sortArticles(by: primarySortOption)
                }
            }
            isLoading = false
        }
    }
    
    // MARK: - 批量选择相关方法
    
    private func toggleBatchSelectionMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isBatchSelectionMode.toggle()
            if !isBatchSelectionMode {
                selectedArticleIds.removeAll()
            }
        }
    }
    
    private func toggleArticleSelection(_ articleId: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedArticleIds.contains(articleId) {
                selectedArticleIds.remove(articleId)
            } else {
                selectedArticleIds.insert(articleId)
            }
        }
    }
    
    private func performBatchLearning() async {
        // 获取选中的文章
        let selectedArticles = viewModel.rankedArticles.filter { selectedArticleIds.contains($0.article.id.uuidString) }
        
        // 调用批量学习方法
        await viewModel.markArticlesAsLearned(selectedArticles)
        
        // 退出批量选择模式
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                isBatchSelectionMode = false
                selectedArticleIds.removeAll()
                showBatchLearningConfirmation = false
            }
        }
        
        // 刷新排序结果
        await viewModel.refreshRanking()
    }
    
    private func exportTopArticles() {
        // 导出前10篇文章的逻辑
        let topArticles = Array(viewModel.rankedArticles.prefix(10))
        // 实现导出功能
        print("导出前10篇文章: \(topArticles.map { $0.article.title })")
    }
}

// MARK: - 测试记录行视图
struct TestRecordRow: View {
    let test: VocabularyTest
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTestDate(test.testDate))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Text("\(test.getTestResults().count) 词汇")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("正确率: \(String(format: "%.1f", test.accuracy * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTestDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 分阶段文章行视图
struct StagedArticleRow: View {
    let result: ArticleMatchResult
    let rank: Int
    let stage: Int
    
    var body: some View {
        HStack {
            // 排名
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text("匹配度: \(Int(result.matchScore))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("生词: \(result.unknownWords)")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("掌握: \(result.masteredWords)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(result.recommendation.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(result.recommendation.color)
                    .cornerRadius(4)
                
                Text(result.difficulty.rawValue)
                    .font(.caption2)
                    .foregroundColor(result.difficulty.color)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 词典重合度行视图
struct StagedDictionaryOverlapRow: View {
    let result: DictionaryOverlapInfo
    let rank: Int
    
    var body: some View {
        HStack {
            // 排名
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text("重合度: \(Int(result.overlapPercentage))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("重合词: \(result.overlapWords)")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("总词数: \(result.totalWords)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 用户掌握度行视图
struct StagedUserMasteryRow: View {
    let result: UserMasteryInfo
    let rank: Int
    
    var body: some View {
        HStack {
            // 排名
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text("掌握: \(result.masteredCount)")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("熟悉: \(result.familiarCount)")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("陌生: \(result.unfamiliarCount)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 词典测试状态行视图
struct DictionaryTestStateRow: View {
    let testState: DictionaryTestState
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // 状态指示器
                statusIndicator
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(testState.dictionary.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Text("\(testState.dictionary.totalWords) 词汇")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if case .tested = testState.status, let latestTest = testState.latestTest {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatTestDate(latestTest.testDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if case .multipleTests = testState.status, let latestTest = testState.latestTest {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatTestDate(latestTest.testDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 状态描述
                    statusDescription
                }
                
                Spacer()
                
                // 选中指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
    }
    
    private var statusColor: Color {
        switch testState.status {
        case .notTested:
            return .gray
        case .tested:
            return .green
        case .multipleTests:
            return .blue
        }
    }
    
    @ViewBuilder
    private var statusDescription: some View {
        switch testState.status {
        case .notTested:
            Text("未测试")
                .font(.caption)
                .foregroundColor(.orange)
        case .tested:
            Text("已测试 - \(testState.latestTest?.getTestResults().count ?? 0) 词")
                .font(.caption)
                .foregroundColor(.green)
        case .multipleTests:
            Text("多次测试 - 共 \(testState.testHistory.count) 次")
                .font(.caption)
                .foregroundColor(.blue)
        }
    }
    
    private func formatTestDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 文章排序卡片
struct ArticleRankingCard: View {
    let result: ArticleMatchResult
    let recommendationReason: String?
    let isBatchSelectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    @State private var showRecommendationReason = false
    @EnvironmentObject private var appCoordinator: AppCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和推荐等级
            HStack {
                // 批量选择模式下的选择框
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
            
            // 自适应推荐原因（如果有）
            if let reason = recommendationReason, !reason.isEmpty {
                adaptiveReasonSection(reason: reason)
            }
            
            // 词汇统计
            HStack(spacing: 16) {
                ArticleStatItem(title: "总词数", value: "\(result.totalWords)", icon: "textformat.123", color: .primary)
                ArticleStatItem(title: "生词数", value: "\(result.unknownWords)", icon: "questionmark.circle", color: .red)
                ArticleStatItem(title: "熟悉词", value: "\(result.familiarWords)", icon: "eye", color: .orange)
                ArticleStatItem(title: "掌握词", value: "\(result.masteredWords)", icon: "checkmark.circle", color: .green)
            }
            
            // 难度和生词率
            HStack {
                // 难度标签
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                    Text(result.difficulty.rawValue)
                }
                .font(.caption)
                .foregroundColor(result.difficulty.color)
                
                Spacer()
                
                // 生词率
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle()) // 确保整个区域可点击
        .onTapGesture {
            if isBatchSelectionMode {
                onSelectionToggle()
            } else {
                print("点击文章卡片: \(result.article.title)")
                appCoordinator.startReading(result.article)
            }
        }
    }
    
    // MARK: - 自适应推荐原因区域
    @ViewBuilder
    private func adaptiveReasonSection(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                    .font(.caption)
                
                Text("智能推荐原因")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRecommendationReason.toggle()
                    }
                }) {
                    Image(systemName: showRecommendationReason ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
            
            if showRecommendationReason {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(8)
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
                // 掌握词汇
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geometry.size.width * mastered / 100)
                
                // 熟悉词汇
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: geometry.size.width * familiar / 100)
                
                // 生词
                Rectangle()
                    .fill(Color.red)
                    .frame(width: geometry.size.width * unknown / 100)
                
                // 剩余空间
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
        }
        .frame(height: 4)
        .cornerRadius(2)
    }
}

// MARK: - 自定义统计项组件（用于文章卡片）
struct ArticleStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 难度标签
struct DifficultyTag: View {
    let difficulty: IntelligentRankingDifficultyLevel
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(difficulty.color)
                .frame(width: 8, height: 8)
            
            Text(difficulty.rawValue)
                .font(.caption)
                .foregroundColor(.primary)
            
            Text("(\(count))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }
}

// MARK: - 预览
struct IntelligentRankingView_Previews: PreviewProvider {
    static var previews: some View {
        Text("IntelligentRankingView Preview")
            .navigationTitle("智能排序")
    }
}