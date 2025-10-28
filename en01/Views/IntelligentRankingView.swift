//
//  IntelligentRankingView.swift
//  en01
//
//  Created by 谭康 on 2024/12/19.
//

import SwiftUI
import Combine
import SwiftData
import PDFKit
import UniformTypeIdentifiers
import Foundation

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
    
    // 批量选择相关状态
    @State private var isBatchSelectionMode: Bool = false
    @State private var selectedArticleIds: Set<UUID> = []
    @State private var showBatchLearningConfirmation: Bool = false
    
    // 导出相关状态
    @State private var showPDFExportDialog: Bool = false
    @State private var showMarkdownExportDialog: Bool = false
    @State private var pdfExportDocument: PDFExportDocument?
    @State private var markdownExportDocument: MarkdownExportDocument?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topControlBar
                
                if viewModel.isAdaptiveMode && !isLoading {
                    adaptiveInsightSection
                }
                                
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
            .fileExporter(
                isPresented: $showPDFExportDialog,
                document: pdfExportDocument,
                contentType: .pdf,
                defaultFilename: "前10篇推荐文章.pdf"
            ) { result in
                switch result {
                case .success(let url):
                    print("✅ PDF导出成功: \(url)")
                case .failure(let error):
                    print("❌ PDF导出失败: \(error.localizedDescription)")
                }
            }
            .fileExporter(
                isPresented: $showMarkdownExportDialog,
                document: markdownExportDocument,
                contentType: .plainText,
                defaultFilename: "前10篇推荐文章.md"
            ) { result in
                switch result {
                case .success(let url):
                    print("✅ Markdown导出成功: \(url)")
                case .failure(let error):
                    print("❌ Markdown导出失败: \(error.localizedDescription)")
                }
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
    
    // MARK: - 计算属性
    
    @ViewBuilder
    private var sortOptionsSheet: some View {
        let gridColumns = Array(repeating: GridItem(.flexible()), count: 2)
        
        NavigationStack {
            VStack(spacing: 0) {
                // 标题区域
                Text("选择排序方式")
                    .font(.headline)
                    .padding()
                
                // 可滚动内容区域
                ScrollView {
                    VStack(spacing: 20) {
                        basicSortSection(gridColumns: gridColumns)
                        keywordSortSection(gridColumns: gridColumns)
                        
                        // 添加底部间距，确保内容不被按钮遮挡
                        Color.clear.frame(height: 80)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("排序选项")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                // 固定在底部的按钮
                sortActionButtons
                    .background(Color(.systemBackground))
            }
        }
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
    }
    
    @ViewBuilder
    private func basicSortSection(gridColumns: [GridItem]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("基础排序")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(BasicSortOption.allCases, id: \.self) { option in
                    sortOptionButton(
                        option: option,
                        isSelected: selectedBasicSortOption == option,
                        color: .blue,
                        action: { selectedBasicSortOption = option }
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func keywordSortSection(gridColumns: [GridItem]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("关键词排序")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(KeywordSortOption.allCases, id: \.self) { option in
                    keywordSortOptionButton(
                        option: option,
                        isSelected: selectedKeywordSortOption == option,
                        color: .green,
                        action: { selectedKeywordSortOption = option }
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func sortOptionButton(
        option: BasicSortOption,
        isSelected: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: option.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(option.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                
                Text(viewModel.isDictionaryMode ? option.dictionaryModeDescription : option.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? Color.white.opacity(0.85) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(isSelected ? color : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private func keywordSortOptionButton(
        option: KeywordSortOption,
        isSelected: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: option.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(option.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                
                Text(option.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? Color.white.opacity(0.85) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(isSelected ? color : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var sortActionButtons: some View {
        HStack(spacing: 16) {
            Button("取消") {
                showSortOptions = false
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(12)
            
            Button("应用排序") {
                applySorting()
                showSortOptions = false
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    @ViewBuilder
    private var dictionarySelectorSheet: some View {
        NavigationStack {
            List {
                ForEach(availableDictionaries, id: \.id) { dictionary in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dictionary.name)
                                .font(.headline)
                            
                            Text("\(dictionary.totalWords) 词汇")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.selectedDictionary?.id == dictionary.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedDictionary = dictionary
                        showDictionarySelector = false
                    }
                }
            }
            .navigationTitle("选择词典")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showDictionarySelector = false
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
    }
    
    @ViewBuilder
    private var testHistorySelectionSheet: some View {
        TestHistorySelectionSheet(
            isPresented: $viewModel.showTestHistorySelection,
            onTestRecordsSelected: { selectedRecords in
                Task {
                    if let _ = selectedRecords.first,
                       let testState = viewModel.selectedTestState {
                        await viewModel.performStagedRanking(with: testState)
                    }
                }
            }
        )
    }
    
    @ViewBuilder
    private var statisticsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("文章统计")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    Task {
                        let statistics = viewModel.getStatisticsForCurrentMode()
                        print("统计信息: \(statistics)")
                    }
                }) {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.blue)
                }
            }
            
            if !viewModel.rankedArticles.isEmpty {
                let difficultyStats = viewModel.getRankingStatistics().difficultyDistribution
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(Array(difficultyStats.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { difficulty in
                        DifficultyTag(difficulty: difficulty, count: difficultyStats[difficulty] ?? 0)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var mainLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在加载文章...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("暂无推荐文章")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("请选择词典或调整排序条件")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var topDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("智能推荐")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if viewModel.isAdaptiveMode {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                        Text("自适应模式")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            Text("基于您的词汇掌握情况和学习历史，为您推荐最适合的文章")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var topControlBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { showSortOptions = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("排序")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: { showDictionarySelector = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed")
                        Text(viewModel.selectedDictionary?.name ?? "选择词典")
                    }
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        let nextMode: ReadingMode = viewModel.selectedReadingMode == .soloArticles ? .yearlyExams : .soloArticles
                        await viewModel.switchReadingMode(to: nextMode)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.selectedReadingMode.iconName)
                        Text(viewModel.selectedReadingMode.displayName)
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Menu {
                    Button(action: { showAdaptiveSettings = true }) {
                        Label("自适应设置", systemImage: "brain.head.profile")
                    }
                    
                    Button(action: { showCompositeRanking = true }) {
                        Label("综合排序", systemImage: "chart.bar.xaxis")
                    }
                    
                    Button(action: { viewModel.showTestHistorySelection = true }) {
                        Label("测试历史", systemImage: "clock.arrow.circlepath")
                    }
                    
                    Button(action: { viewModel.showStagedRanking = true }) {
                        Label("分阶段排序", systemImage: "list.number")
                    }
                    
                    Divider()
                    
                    Button(action: { toggleBatchSelectionMode() }) {
                        Label(isBatchSelectionMode ? "退出批量选择" : "批量选择", 
                              systemImage: isBatchSelectionMode ? "xmark.circle" : "checkmark.circle")
                    }
                    
                    if isBatchSelectionMode && !selectedArticleIds.isEmpty {
                        Button(action: { showBatchLearningConfirmation = true }) {
                            Label("批量学习(\(selectedArticleIds.count))", systemImage: "graduationcap")
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { 
                        Task { await exportTopArticles(format: .pdf) }
                    }) {
                        Label("导出PDF", systemImage: "doc.fill")
                    }
                    
                    Button(action: { 
                        Task { await exportTopArticles(format: .markdown) }
                    }) {
                        Label("导出Markdown", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            if isBatchSelectionMode {
                HStack {
                    Text("批量选择模式")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("已选择 \(selectedArticleIds.count) 篇")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("全选") {
                        selectedArticleIds = Set(viewModel.rankedArticles.map { $0.article.id })
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Button("清空") {
                        selectedArticleIds.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var adaptiveInsightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("智能洞察")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let insights = viewModel.currentLearningInsights {
                VStack(alignment: .leading, spacing: 8) {
                    Text("学习模式: \(insights.learningPattern.rawValue)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("推荐置信度: \(String(format: "%.1f", insights.recommendationConfidence))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !insights.learningRecommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("建议：")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            ForEach(insights.learningRecommendations, id: \.self) { recommendation in
                                Text("• \(recommendation)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text("正在分析您的学习模式...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var mainContentArea: some View {
        if isLoading {
            mainLoadingView
        } else if viewModel.rankedArticles.isEmpty {
            emptyStateView
        } else {
            VStack(spacing: 16) {
                topDescriptionSection
                statisticsSection
                articleListSection
            }
        }
    }
    
    @ViewBuilder
    private var articleListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.rankedArticles, id: \.article.id) { result in
                    ArticleRankingCard(
                        result: result,
                        isSelected: selectedArticleIds.contains(result.article.id),
                        isBatchSelectionMode: isBatchSelectionMode,
                        isDictionaryMode: viewModel.selectedDictionary != nil,
                        recommendationReason: viewModel.getRecommendationReason(for: result),
                        onSelectionToggle: {
                            toggleArticleSelection(result.article.id)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var stagedRankingSheet: some View {
        StagedRankingView(
            stagedRankingService: ServiceContainer.shared.getIntelligentRankingService(),
            intelligentRankingService: ServiceContainer.shared.getIntelligentRankingService(),
            errorHandler: ServiceContainer.shared.getErrorHandler()
        )
    }
    
    // MARK: - 私有函数
    
    private func loadAvailableDictionaries() {
        Task {
            do {
                let dictionaryService = ServiceContainer.shared.getDictionaryService()
                let dictionaries = try await dictionaryService.getAvailableDictionaries().values.first(where: { _ in true }) ?? []
                await MainActor.run {
                    self.availableDictionaries = dictionaries
                    print("✅ 加载词典列表成功: \(dictionaries.count) 个词典")
                }
            } catch {
                print("❌ 加载词典列表失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadRankedArticles() {
        isLoading = true
        Task {
            await viewModel.loadRankedArticles()
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func applySorting() {
        Task {
            viewModel.sortArticlesWithKeywordAndBasic(
                keywordOption: selectedKeywordSortOption,
                basicOption: selectedBasicSortOption
            )
        }
    }
    
    private func toggleBatchSelectionMode() {
        isBatchSelectionMode.toggle()
        if !isBatchSelectionMode {
            selectedArticleIds.removeAll()
        }
    }
    
    private func toggleArticleSelection(_ articleId: UUID) {
        if selectedArticleIds.contains(articleId) {
            selectedArticleIds.remove(articleId)
        } else {
            selectedArticleIds.insert(articleId)
        }
    }
    
    private func performBatchLearning() async {
        let selectedArticles = viewModel.rankedArticles.filter { selectedArticleIds.contains($0.article.id) }
        
        for result in selectedArticles {
            result.article.markAsLearned()
        }
        
        await MainActor.run {
            selectedArticleIds.removeAll()
            isBatchSelectionMode = false
        }
        
        print("✅ 批量学习完成: \(selectedArticles.count) 篇文章")
        
        // 重新加载文章列表
        await viewModel.loadRankedArticles()
    }
    
    private func exportTopArticles(format: ExportFormat) async {
        let topArticles = Array(viewModel.rankedArticles.prefix(10))
        
        switch format {
        case .pdf:
            await exportPDFArticles(topArticles)
        case .markdown:
            await exportMarkdownArticles(topArticles)
        }
    }
    
    private func exportStagedRankingResults() async {
        // 导出分阶段排序结果
        print("导出分阶段排序结果")
    }
    
    private func exportPDFArticles(_ articles: [ArticleMatchResult]) async {
        do {
            let mergedPDF = try await mergePDFArticles(articles)
            let document = PDFExportDocument(data: mergedPDF)
            
            await MainActor.run {
                self.pdfExportDocument = document
                self.showPDFExportDialog = true
            }
            
            print("✅ PDF文档准备完成")
        } catch {
            print("❌ PDF导出失败: \(error.localizedDescription)")
        }
    }
    
    private func exportMarkdownArticles(_ articles: [ArticleMatchResult]) async {
        do {
            let mergedMarkdown = try await mergeMarkdownArticles(articles)
            let document = MarkdownExportDocument(content: mergedMarkdown)
            
            await MainActor.run {
                self.markdownExportDocument = document
                self.showMarkdownExportDialog = true
            }
            
            print("✅ Markdown文档准备完成")
        } catch {
            print("❌ Markdown导出失败: \(error.localizedDescription)")
        }
    }
    
    private func mergePDFArticles(_ articles: [ArticleMatchResult]) async throws -> Data {
        let pdfDocument = PDFDocument()
        var successfulMerges = 0
        var failedFiles: [String] = []
        
        for (index, result) in articles.enumerated() {
            let pdfPath = buildPDFPath(for: result.article)
            
            if let articlePDF = PDFDocument(url: pdfPath) {
                for pageIndex in 0..<articlePDF.pageCount {
                    if let page = articlePDF.page(at: pageIndex) {
                        pdfDocument.insert(page, at: pdfDocument.pageCount)
                    }
                }
                successfulMerges += 1
            } else {
                // 创建文本页面作为备选
                let textPage = createTextPage(for: result.article, pageNumber: index + 1)
                pdfDocument.insert(textPage, at: pdfDocument.pageCount)
                failedFiles.append(result.article.title)
            }
        }
        
        print("✅ PDF合并完成: 成功 \(successfulMerges) 个，失败 \(failedFiles.count) 个")
        if !failedFiles.isEmpty {
            print("失败的文件: \(failedFiles.joined(separator: ", "))")
        }
        
        guard let mergedData = pdfDocument.dataRepresentation() else {
            throw NSError(domain: "PDFExportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法生成PDF数据"])
        }
        
        return mergedData
    }
    
    private func mergeMarkdownArticles(_ articles: [ArticleMatchResult]) async throws -> String {
        var markdownContent = "# 前10篇推荐文章\n\n"
        markdownContent += "生成时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))\n\n"
        
        for (index, result) in articles.enumerated() {
            markdownContent += "## \(index + 1). \(result.article.title)\n\n"
            markdownContent += "**考试类型**: \(result.article.examType)\n"
            markdownContent += "**推荐等级**: \(result.recommendation.rawValue)\n"
            markdownContent += "**匹配分数**: \(Int(result.matchScore))%\n"
            markdownContent += "**难度**: \(result.difficulty.rawValue)\n\n"
            
            markdownContent += "### 词汇统计\n"
            markdownContent += "- 总词数: \(result.totalWords)\n"
            markdownContent += "- 生词数: \(result.unknownWords)\n"
            markdownContent += "- 熟悉词: \(result.familiarWords)\n"
            markdownContent += "- 掌握词: \(result.masteredWords)\n"
            markdownContent += "- 生词率: \(String(format: "%.1f", result.unknownPercentage))%\n\n"
            
            if let reason = viewModel.getRecommendationReason(for: result), !reason.isEmpty {
                markdownContent += "### 推荐理由\n"
                markdownContent += "\(reason)\n\n"
            }
            
            markdownContent += "---\n\n"
        }
        
        return markdownContent
    }
    
    private func buildPDFPath(for article: Article) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("articles").appendingPathComponent("\(article.id).pdf")
    }
    
    private func createTextPage(for article: Article, pageNumber: Int) -> PDFPage {
        let _ = CGRect(x: 0, y: 0, width: 612, height: 792) // A4 size
        let page = PDFPage()
        
        let textContent = """
        第 \(pageNumber) 篇文章
        
        标题: \(article.title)
        考试类型: \(article.examType)
        
        注意: 此文章的PDF文件未找到，显示为文本格式。
        """
        
        // 创建文本注释
        let textAnnotation = PDFAnnotation(bounds: CGRect(x: 50, y: 600, width: 500, height: 150), forType: .freeText, withProperties: nil)
        textAnnotation.contents = textContent
        textAnnotation.font = UIFont.systemFont(ofSize: 12)
        textAnnotation.fontColor = UIColor.black
        
        page.addAnnotation(textAnnotation)
        
        return page
    }
}

// MARK: - 支持结构体

// MARK: - 预览和其他视图组件

struct MasteryLevelRow: View {
    let masteryLevel: MasteryLevel
    let articleCount: Int
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(masteryLevel.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(masteryLevel.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(articleCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(masteryLevel.color)

                Text("篇文章")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

struct DictionaryTestStateRow: View {
    let dictionary: DictionaryInfo
    let testState: DictionaryTestState
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dictionary.name)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(dictionary.totalWords) 词汇")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(testState.status.displayText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(testState.status.color))
                    .cornerRadius(6)

                if testState.accuracyPercentage > 0 {
                    Text("\(Int(testState.accuracyPercentage))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

struct ArticleRankingCard: View {
    let result: ArticleMatchResult
    let isSelected: Bool
    let isBatchSelectionMode: Bool
    let isDictionaryMode: Bool
    let recommendationReason: String?
    let onSelectionToggle: () -> Void
    
    @EnvironmentObject private var appCoordinator: AppCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if isBatchSelectionMode {
                    Button(action: onSelectionToggle) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .blue : .gray)
                            .font(.title3)
                    }
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
                    Text(result.recommendation.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(result.recommendation.color)
                        .cornerRadius(6)

                    Text("\(Int(result.matchScore))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            if let reason = recommendationReason, !reason.isEmpty {
                adaptiveReasonSection(reason: reason)
            }
            
            HStack(spacing: 16) {
                ArticleStatItem(
                    title: isDictionaryMode ? "匹配词数" : "总词数", 
                    value: "\(result.totalWords)", 
                    icon: "textformat.123", 
                    color: .primary
                )
                ArticleStatItem(title: "生词数", value: "\(result.unknownWords)", icon: "questionmark.circle", color: .red)
                ArticleStatItem(title: "熟悉词", value: "\(result.familiarWords)", icon: "eye", color: .orange)
                ArticleStatItem(title: "掌握词", value: "\(result.masteredWords)", icon: "checkmark.circle", color: .green)
            }
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                    Text(result.difficulty.rawValue)
                }
                .font(.caption)
                .foregroundColor(result.difficulty.color)

                Spacer()

                Text("生词率: \(String(format: "%.1f", result.unknownPercentage))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
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
        .contentShape(Rectangle())
        .onTapGesture {
            if isBatchSelectionMode {
                onSelectionToggle()
            } else {
                print("点击文章卡片: \(result.article.title)")
                appCoordinator.startReading(result.article)
            }
        }
    }
    
    @ViewBuilder
    private func adaptiveReasonSection(reason: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(reason)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ProgressBar: View {
    let mastered: Double
    let familiar: Double
    let unknown: Double
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geometry.size.width * mastered / 100)

                Rectangle()
                    .fill(Color.orange)
                    .frame(width: geometry.size.width * familiar / 100)

                Rectangle()
                    .fill(Color.red)
                    .frame(width: geometry.size.width * unknown / 100)

                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
        }
        .frame(height: 4)
        .cornerRadius(2)
    }
}

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

#Preview {
    Text("IntelligentRankingView Preview")
        .navigationTitle("智能排序")
}