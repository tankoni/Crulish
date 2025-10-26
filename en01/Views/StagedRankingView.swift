import SwiftUI
import SwiftData

struct StagedRankingView: View {
    let stagedRankingService: IntelligentRankingService
    let intelligentRankingService: IntelligentRankingService
    let errorHandler: ErrorHandlerProtocol
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: IntelligentRankingViewModel
    
    @State private var selectedStage: Int = 1
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 阶段选择器
                stageSelector
                
                // 统计信息
                statisticsSection
                
                // 内容区域
                contentArea
            }
            .navigationTitle("分阶段排序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用到主列表") {
                        applyToMainList()
                        dismiss()
                    }
                    .disabled(viewModel.stagedRankingResults == nil)
                }
            }
            .onAppear {
                selectedStage = viewModel.currentStage
            }
        }
    }
    
    @ViewBuilder
    private var stageSelector: some View {
        HStack(spacing: 0) {
            Button(action: {
                selectedStage = 1
                viewModel.switchToStage(1)
            }) {
                VStack(spacing: 4) {
                    Text("第一阶段")
                        .font(.headline)
                        .fontWeight(selectedStage == 1 ? .bold : .medium)
                    
                    Text("词典重合度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedStage == 1 ? Color.blue.opacity(0.1) : Color.clear)
                .foregroundColor(selectedStage == 1 ? .blue : .primary)
            }
            
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
            
            Button(action: {
                selectedStage = 2
                viewModel.switchToStage(2)
            }) {
                VStack(spacing: 4) {
                    Text("第二阶段")
                        .font(.headline)
                        .fontWeight(selectedStage == 2 ? .bold : .medium)
                    
                    Text("用户掌握度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedStage == 2 ? Color.blue.opacity(0.1) : Color.clear)
                .foregroundColor(selectedStage == 2 ? .blue : .primary)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var statisticsSection: some View {
        if let statistics = viewModel.getStageStatistics(for: selectedStage) {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("文章数量")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(statistics.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(selectedStage == 1 ? "平均重合度" : "平均掌握度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(statistics.averageScore))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                
                // 进度条
                ProgressView(value: statistics.averageScore / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: selectedStage == 1 ? .blue : .green))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            loadingView
        } else if let errorMessage = errorMessage {
            errorView(errorMessage)
        } else if let stagedResult = viewModel.stagedRankingResults {
            articleListView(stagedResult)
        } else {
            emptyStateView
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在分析排序结果...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("出现错误")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重试") {
                // 重新加载数据的逻辑
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.number")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("暂无排序结果")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("请先选择测试记录进行分阶段排序")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func articleListView(_ stagedResult: StagedRankingResult) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if selectedStage == 1 {
                    ForEach(stagedResult.stage1Results, id: \.article.id) { result in
                        Stage1ArticleCard(result: result)
                    }
                } else {
                    ForEach(stagedResult.stage2Results, id: \.article.id) { result in
                        Stage2ArticleCard(result: result)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private func applyToMainList() {
        viewModel.switchToStage(selectedStage)
    }
}

struct Stage1ArticleCard: View {
    let result: DictionaryOverlapInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.article.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(result.overlapPercentage))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("重合度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label("\(result.overlapWords) 词汇", systemImage: "text.word.spacing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("总词汇: \(result.totalWords)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 进度条
            ProgressView(value: result.overlapPercentage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct Stage2ArticleCard: View {
    let result: UserMasteryInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.article.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(result.masteredPercentage))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("掌握度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已掌握")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(result.masteredCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("熟悉")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(result.familiarCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("未知")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(result.unfamiliarCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            
            // 进度条
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    let masteredWidth = geometry.size.width * result.masteredPercentage / 100
                    let familiarPercentage = Double(result.familiarCount) / Double(result.totalCount) * 100
                    let familiarWidth = geometry.size.width * familiarPercentage / 100
                    let unfamiliarWidth = geometry.size.width * result.unfamiliarPercentage / 100
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: masteredWidth)
                    
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: familiarWidth)
                    
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: unfamiliarWidth)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    let modelContext = ModelContext(try! ModelContainer(for: Article.self))
    let cacheManager = CacheManager()
    let errorHandler = UnifiedErrorHandler()
    let pdfService = PDFService(
        modelContext: modelContext,
        cacheManager: cacheManager,
        errorHandler: errorHandler
    )
    
    let dictionaryService = DictionaryService(
        modelContext: modelContext,
        cacheManager: cacheManager,
        errorHandler: errorHandler
    )
    
    let userProgressService = UserProgressService(
        modelContext: modelContext,
        cacheManager: cacheManager,
        errorHandler: errorHandler
    )
    
    let vocabularyTestService = VocabularyTestService(
        dictionaryService: dictionaryService,
        modelContext: modelContext,
        cacheManager: cacheManager,
        errorHandler: errorHandler
    )

    let articleService = ArticleService(
        modelContext: modelContext,
        cacheManager: cacheManager,
        errorHandler: errorHandler,
        pdfService: pdfService
    )

    let soloArticleService = SoloArticleService(
        modelContext: modelContext,
        cacheManager: cacheManager,
        errorHandler: errorHandler
    )

    let intelligentRankingService = IntelligentRankingService(
        dictionaryService: dictionaryService,
        vocabularyTestService: vocabularyTestService
    )
    
    StagedRankingView(
        stagedRankingService: intelligentRankingService,
        intelligentRankingService: intelligentRankingService,
        errorHandler: errorHandler
    )
    .environmentObject(IntelligentRankingViewModel(
        articleService: articleService,
        dictionaryService: dictionaryService,
        userProgressService: userProgressService,
        errorHandler: errorHandler,
        soloArticleService: soloArticleService,
        vocabularyTestService: vocabularyTestService
    ))
}