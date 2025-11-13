//
//  VocabularyView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI
import SwiftData
import Combine

struct VocabularyView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dictionaryService: DictionaryService
    @Environment(UnifiedErrorHandler.self) private var errorHandler
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @StateObject private var inputManager = UnifiedInputManager.shared
    
    @StateObject private var viewModel: VocabularyViewModel
    @State private var selectedTab: VocabularyTab = .myWords
    @State private var searchText = ""
    @State private var selectedMastery: MasteryLevel?
    @State private var sortOption: VocabularySortOption = .recent
    @State private var isShowingFilters = false
    @State private var vocabularyStats: VocabularyStats?
    @State private var debounceTask: Task<Void, Never>? // 防抖任务
    @State private var isDataLoaded = false // 防止重复加载
    
    init(viewModel: VocabularyViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    

    
    // 个人学习词典相关状态
    @State private var personalDictionaries: [PersonalDictionary] = []
    @State private var availableDictionaries: [DictionaryInfo] = []
    @State private var isShowingDictionaryImport = false
    @State private var selectedDictionariesForImport: Set<String> = []
    @State private var personalDictionaryManager: PersonalDictionaryManager?
    @State private var kaoyanDictionaryImporter: KaoyanDictionaryImporter?
    @State private var isShowingVocabularyTest = false // 控制词汇量测试界面显示
    @State private var testHistory: [VocabularyTest] = [] // 测试历史
    @State private var latestTest: VocabularyTest? // 最新测试
    @State private var isLoadingTestData = false // 测试数据加载状态
    @State private var cancellables = Set<AnyCancellable>() // Combine订阅管理
    
    // 重测模式相关状态
    @State private var isShowingRetestMode = false // 控制重测模式界面显示
    @State private var retestModeService: RetestModeService? // 重测模式服务
    @State private var quickRetestConfig: RetestConfig? // 快速重测配置
    
    // 词典专属导入导出相关状态
    @State private var isShowingDictionarySpecificImport = false // 控制词典专属导入界面显示
    @State private var isShowingDictionarySpecificExport = false // 控制词典专属导出界面显示
    @State private var selectedDictionaryForImportExport: PersonalDictionary? // 选中的词典
    
    var body: some View {
        NavigationView {
            mainContent
                .navigationTitle("词汇宝典")
                .navigationBarTitleDisplayMode(.large)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                toolbarMenu
            }
        }
        .onAppear {
            // 防止重复加载
            if !isDataLoaded {
                viewModel.loadVocabulary()
                initializePersonalDictionaryManager()
                loadTestData() // 加载测试数据
                initializeRetestModeService() // 初始化重测模式服务
                isDataLoaded = true
            }
        }
        .onChange(of: selectedTab) { _, _ in
            viewModel.loadVocabulary()
        }
        .onChange(of: searchText) { _, _ in
            // 防抖处理，避免频繁过滤
            debounceFilterWords()
        }
        .onChange(of: selectedMastery) { _, newValue in
            // 直接使用MasteryLevel，无需转换
            viewModel.setMasteryFilter(newValue)
        }
        .onChange(of: sortOption) { _, newValue in
            // 使用公共方法设置排序选项
            viewModel.setSortOption(newValue)
        }
        .sheet(isPresented: $isShowingVocabularyTest) {
            VocabularyTestView(
                vocabularyTestService: appCoordinator.getVocabularyTestService(),
                dictionaryService: dictionaryService,
                errorHandler: errorHandler,
                testResultExportService: appCoordinator.getTestResultExportService(),
                appCoordinator: appCoordinator,
                isRetestMode: quickRetestConfig != nil,
                retestConfig: quickRetestConfig
            )
            .onDisappear {
                // 清除快速重测配置
                quickRetestConfig = nil
            }
        }
        .sheet(isPresented: $isShowingRetestMode) {
            if let retestService = retestModeService {
                RetestModeView(
                    retestModeService: retestService,
                    dictionaryService: dictionaryService,
                    errorHandler: errorHandler,
                    appCoordinator: appCoordinator
                )
            }
        }
        // 新增：复习会话弹窗
        .sheet(
            isPresented: .init(
                get: { viewModel.isReviewing },
                set: { viewModel.isReviewing = $0 }
            )
        ) {
            ReviewSessionView(viewModel: viewModel)
                .environmentObject(dictionaryService)
                .environmentObject(appCoordinator)
        }
        // 监听标准词汇量测试启动通知
        .onReceive(NotificationCenter.default.publisher(for: .startVocabularyTest)) { _ in
            isShowingVocabularyTest = true
        }
        // 监听重测模式启动通知（携带 RetestConfig）
        .onReceive(NotificationCenter.default.publisher(for: .startRetestVocabularyTest)) { notification in
            if let info = notification.userInfo,
               let config = info["retestConfig"] as? RetestConfig {
                // 设置快速重测配置并展示统一测试界面
                quickRetestConfig = config
            } else {
                quickRetestConfig = nil
            }
            // 确保重测选择弹窗关闭，避免与测试界面同时显示
            isShowingRetestMode = false
            isShowingVocabularyTest = true
        }
        .sheet(isPresented: $isShowingDictionarySpecificImport) {
            DictionarySpecificImportView()
                .environmentObject(dictionaryService)
                .environment(errorHandler)
        }
        .sheet(isPresented: $isShowingDictionarySpecificExport) {
            DictionarySpecificExportView()
                .environmentObject(dictionaryService)
                .environment(errorHandler)
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            vocabularyTabBar
            searchBar
            
            if isShowingFilters {
                filterBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            contentView
        }
    }
    
    private var toolbarMenu: some View {
        Menu {
            Button {
                withAnimation {
                    isShowingFilters.toggle()
                }
            } label: {
                Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
            }
            
            Button {
                let _ = viewModel.exportVocabulary()
            } label: {
                Label("导出词汇", systemImage: "square.and.arrow.up")
            }
            
            Button {
                viewModel.startReview()
            } label: {
                Label("开始复习", systemImage: "brain.head.profile")
            }
            
            Button {
                isShowingVocabularyTest = true
            } label: {
                Label("词汇量测试", systemImage: "brain.head.profile.fill")
            }
            
            Button {
                isShowingRetestMode = true
            } label: {
                Label("重测模式", systemImage: "arrow.clockwise.circle.fill")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    
    // MARK: - 标签栏
    private var vocabularyTabBar: some View {
        HStack(spacing: 8) {
            ForEach(VocabularyTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.title)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if selectedTab == tab {
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(.blue)
                        } else {
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(.clear)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .foregroundColor(selectedTab == tab ? .blue : .secondary)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 搜索栏
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索单词或释义", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onTapGesture {
                    inputManager.beginInputSession(
                        fieldId: "vocabulary_search",
                        priority: 1,
                        inputType: .search
                    )
                }
                .onSubmit {
                    inputManager.endInputSession(fieldId: "vocabulary_search")
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    inputManager.endInputSession(fieldId: "vocabulary_search")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - 筛选栏
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 掌握程度筛选
                Menu {
                    Button("全部程度") {
                        selectedMastery = nil
                    }
                    
                    ForEach(MasteryLevel.allCases, id: \.self) { mastery in
                        Button(mastery.displayName) {
                            selectedMastery = mastery
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedMastery?.displayName ?? "掌握程度")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedMastery != nil ? Color.blue : Color(.systemGray5))
                    .foregroundColor(selectedMastery != nil ? .white : .primary)
                    .cornerRadius(16)
                }
                
                // 排序选项
                Menu {
                    ForEach(VocabularySortOption.allCases, id: \.self) { option in
                        Button(option.displayName) {
                            sortOption = option
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sortOption.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                
                // 清除筛选
                if selectedMastery != nil {
                    Button {
                        selectedMastery = nil
                    } label: {
                        Text("清除")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - 内容视图
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .myWords:
            myWordsView
        case .personalDictionaries:
            personalDictionariesView
        case .review:
            reviewView
        case .statistics:
            statisticsView
        }
    }
    
    // MARK: - 个人词典视图
    private var personalDictionariesView: some View {
        VStack(spacing: 16) {
            if personalDictionaries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("暂无个人词典")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("您可以导入词典或创建新的个人词典")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("导入词典") {
                        isShowingDictionaryImport = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(personalDictionaries, id: \.id) { dictionary in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(dictionary.displayName)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("\(dictionary.wordCount) 词")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(dictionary.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            HStack {
                                Text("创建时间：\(dictionary.importDate, formatter: dateFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // 词典专属导入导出按钮
                                HStack(spacing: 8) {
                                    Button {
                                        selectedDictionaryForImportExport = dictionary
                                        isShowingDictionarySpecificImport = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "square.and.arrow.down")
                                                .font(.caption)
                                            Text("导入")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button {
                                        selectedDictionaryForImportExport = dictionary
                                        isShowingDictionarySpecificExport = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.caption)
                                            Text("导出")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("个人词典")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("批量导入") {
                    isShowingDictionarySpecificImport = true
                }
                
                Button("批量导出") {
                    isShowingDictionarySpecificExport = true
                }
                
                Button("导入词典") {
                    isShowingDictionaryImport = true
                }
            }
        }
        .sheet(isPresented: $isShowingDictionaryImport) {
            // 词典导入界面
            NavigationView {
                VStack {
                    Text("词典导入功能")
                        .font(.headline)
                        .padding()
                    
                    Spacer()
                    
                    Button("关闭") {
                        isShowingDictionaryImport = false
                    }
                    .padding()
                }
                .navigationTitle("导入词典")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
    
    // MARK: - 重测模式卡片
    
    private var retestModeCard: some View {
        Button {
            isShowingRetestMode = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("重测模式")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("重新测试已学单词")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 词汇量测试卡片
    
    private var vocabularyTestCard: some View {
        Button {
            isShowingVocabularyTest = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("词汇量测试")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("测试词汇水平")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 测试历史区域
    
    private var testHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("测试历史")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isLoadingTestData {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if testHistory.isEmpty && !isLoadingTestData {
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("暂无测试记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("开始第一次词汇量测试吧")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else if !testHistory.isEmpty {
                VStack(spacing: 12) {
                    // 测试概览卡片
                    testStatisticsCard
                    
                    // 测试历史列表
                    LazyVStack(spacing: 8) {
                        ForEach(testHistory.prefix(5), id: \.id) { test in
                            testHistoryRow(test: test)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - 测试统计卡片
    
    private var testStatisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("测试概览")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("共 \(testHistory.count) 次测试")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let latest = latestTest {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最近测试")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatDate(latest.testDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(latest.dictionaryName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if latest.isCompleted {
                            Text("已完成")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        } else {
                            Text("未完成")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 测试历史行
    
    private func testHistoryRow(test: VocabularyTest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(test.dictionaryName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(formatDate(test.testDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if test.isCompleted {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已掌握")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(test.masteredCount)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("熟悉")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(test.familiarCount)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("不熟悉")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(test.unfamiliarCount)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("估计词汇量")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(test.estimatedVocabulary)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            } else {
                HStack {
                    Text("测试未完成")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    if test.totalWords > 0 {
                        Text("进度: \(test.knownWords + test.unknownWords)/\(test.totalWords)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    // MARK: - 我的单词
    
    @State private var selectedWordForDetail: UserWord?
    @State private var showingWordDetail = false
    
    private var myWordsView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 词汇量测试卡片
                vocabularyTestCard
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                // 重测模式入口按钮
                retestModeCard
                    .padding(.horizontal)
                    .padding(.top, 12)
                
                // 掌握程度分类按钮
                masteryLevelButtons
                
                // 测试历史区域
                testHistorySection
                
                // 单词列表
                Group {
                    if filteredMyWords.isEmpty {
                        emptyWordsView
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredMyWords) { wordRecord in
                                WordRecordRow(wordRecord: wordRecord) {
                                    selectedWordForDetail = wordRecord
                                    showingWordDetail = true
                                }
                                .padding(.horizontal, 16)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        viewModel.toggleReviewFlag(for: wordRecord)
                                    } label: {
                                        Image(systemName: wordRecord.needsReview ? "flag.slash" : "flag")
                                    }
                                    .tint(.orange)
                                    
                                    Button {
                                        viewModel.deleteWordRecord(wordRecord)
                                        viewModel.loadVocabulary()
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .tint(.red)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadVocabulary()
        }
        .sheet(isPresented: $showingWordDetail) {
            if let wordRecord = selectedWordForDetail {
                WordDetailSheet(wordRecord: wordRecord)
            }
        }
    }
    
    // MARK: - 掌握程度分类按钮
    private var masteryLevelButtons: some View {
        HStack(spacing: 12) {
            // 已掌握按钮
            MasteryLevelButton(
                title: "已掌握",
                count: getMasteredWordsCount(),
                color: .green,
                isSelected: selectedMastery == .mastered,
                action: {
                    selectedMastery = selectedMastery == .mastered ? nil : .mastered
                },
                onQuickRetest: {
                    startQuickRetest(for: .mastered)
                }
            )
            
            // 熟悉按钮
            MasteryLevelButton(
                title: "熟悉",
                count: getFamiliarWordsCount(),
                color: .orange,
                isSelected: selectedMastery == .familiar,
                action: {
                    selectedMastery = selectedMastery == .familiar ? nil : .familiar
                },
                onQuickRetest: {
                    startQuickRetest(for: .familiar)
                }
            )
            
            // 不熟悉按钮
            MasteryLevelButton(
                title: "不熟悉",
                count: getUnfamiliarWordsCount(),
                color: .red,
                isSelected: selectedMastery == .unfamiliar,
                action: {
                    selectedMastery = selectedMastery == .unfamiliar ? nil : .unfamiliar
                },
                onQuickRetest: {
                    startQuickRetest(for: .unfamiliar)
                }
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var emptyWordsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("还没有收录单词")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("开始阅读文章，点击生词即可自动收录到词汇宝典")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("开始阅读") {
                // Navigate to reading view - this should be handled by coordinator
                // For now, we'll just refresh the data
                viewModel.refreshVocabulary()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 复习视图
    
    private var reviewView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 复习统计
                reviewStatsCard
                
                // 需要复习的单词
                if let reviewWords = getReviewWords(), !reviewWords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("待复习单词")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(reviewWords.count)个")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        LazyVStack(spacing: 8) {
                            ForEach(reviewWords.prefix(10)) { wordRecord in
                                ReviewWordRow(wordRecord: wordRecord) {
                                    // 点击复习按钮：从该词开始复习会话
                                    viewModel.startReview(from: wordRecord)
                                }
                            }
                        }
                        
                        if reviewWords.count > 10 {
                            Button("查看全部 \(reviewWords.count) 个单词") {
                                viewModel.showAllReviewWords()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("今日复习已完成")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("所有单词都已复习完毕，继续保持！")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding()
        }
    }
    
    private var reviewStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("复习统计")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("开始复习") {
                    viewModel.startReview()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            HStack(spacing: 20) {
                ReviewStatItem(
                    title: "今日复习",
                    value: "\(getTodayReviewCount())",
                    color: .blue
                )
                
                ReviewStatItem(
                    title: "待复习",
                    value: "\(getReviewWords()?.count ?? 0)",
                    color: .orange
                )
                
                ReviewStatItem(
                    title: "已掌握",
                    value: "\(getMasteredWordsCount())",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 统计视图
    
    private var statisticsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 总体统计
                overallStatsCard
                
                // 掌握程度分布
                masteryDistributionCard
                
                // 学习趋势
                learningTrendCard
                
                // 高频词汇
                frequentWordsCard
            }
            .padding()
        }
    }
    
    private var overallStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("总体统计")
                .font(.headline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(
                    title: "总词汇量",
                    value: "\(viewModel.vocabulary.count)",
                    icon: "book.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "已掌握",
                    value: "\(getMasteredWordsCount())",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "学习中",
                    value: "\(getLearningWordsCount())",
                    icon: "brain.head.profile",
                    color: .orange
                )
                
                StatCard(
                    title: "生疏",
                    value: "\(getUnfamiliarWordsCount())",
                    icon: "questionmark.circle.fill",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var masteryDistributionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("掌握程度分布")
                .font(.headline)
                .fontWeight(.medium)
            
            // 简单的进度条显示分布
            VStack(spacing: 12) {
                ForEach(MasteryLevel.allCases, id: \.self) { mastery in
                    HStack {
                        Text(mastery.displayName)
                            .font(.subheadline)
                            .frame(width: 60, alignment: .leading)
                        
                        SwiftUI.ProgressView(value: getMasteryPercentage(mastery))
                            .progressViewStyle(LinearProgressViewStyle(tint: mastery.color))
                        
                        Text("\(Int(getMasteryPercentage(mastery) * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var learningTrendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习趋势")
                .font(.headline)
                .fontWeight(.medium)
            
            // 简单的趋势显示
            HStack {
                VStack(alignment: .leading) {
                    Text("本周新增")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(getThisWeekNewWords())")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("平均每日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(getAverageDailyWords())")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var frequentWordsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("高频查询词汇")
                .font(.headline)
                .fontWeight(.medium)
            
            LazyVStack(spacing: 8) {
                ForEach(getFrequentWords().prefix(5)) { wordRecord in
                    HStack {
                        Text(wordRecord.word)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(wordRecord.queryCount)次")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Circle()
                            .fill(wordRecord.masteryLevel.color)
                            .frame(width: 8, height: 8)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 单词详情弹窗
    struct WordDetailSheet: View {
        let wordRecord: UserWord
        @Environment(\.dismiss) private var dismiss
        @EnvironmentObject private var dictionaryService: DictionaryService
        @State private var wordDefinition: DictionaryWordData?
        @State private var isLoading = true
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView("加载中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let definition = wordDefinition {
                        ModernWordDefinitionCard(
                            word: wordRecord.word,
                            phonetic: definition.phonetic ?? "",
                            definitions: definition.definitions.map { $0.meaning },
                            examples: definition.definitions.flatMap { $0.examples },
                            onClose: {
                                dismiss()
                            },
                            onAddToVocabulary: { }
                        )
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            
                            Text("无法加载单词定义")
                                .font(.headline)
                            
                            Text("单词：\(wordRecord.word)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("来源：\(wordRecord.testSource ?? "未知")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationTitle("单词详情")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("关闭") {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await loadWordDefinition()
            }
        }
        
        private func loadWordDefinition() async {
            isLoading = true
            
            // 使用同步方法查找单词定义
            if let dictionaryWord = dictionaryService.lookupWord(wordRecord.word, context: wordRecord.context) {
                // 转换为DictionaryWordData格式
                let wordData = DictionaryWordData(
                    word: dictionaryWord.word,
                    phonetic: dictionaryWord.phonetic,
                    definitions: dictionaryWord.definitions.map { definition in
                        WordDefinitionData(
                            partOfSpeech: definition.partOfSpeech,
                            meaning: definition.meaning,
                            englishMeaning: definition.englishMeaning,
                            examples: definition.examples,
                            contextKeywords: definition.contextKeywords
                        )
                    },
                    frequency: dictionaryWord.frequency,
                    difficulty: dictionaryWord.difficulty,
                    tags: dictionaryWord.tags,
                    categories: dictionaryWord.categories ?? []
                )
                
                await MainActor.run {
                    self.wordDefinition = wordData
                    self.isLoading = false
                }
            } else {
                print("❌ 未找到单词定义: \(wordRecord.word)")
                await MainActor.run {
                    self.wordDefinition = nil
                    self.isLoading = false
                }
            }
        }
    }
}


// MARK: - VocabularyView 扩展
extension VocabularyView {
    // MARK: - 类型转换辅助方法
    // 删除不再需要的转换方法
    
    // MARK: - 掌握程度统计方法
    private func getMasteredWordsCount() -> Int {
        return viewModel.vocabulary.filter { word in
            word.masteryLevel == .mastered
        }.count
    }
    
    private func getFamiliarWordsCount() -> Int {
        return viewModel.vocabulary.filter { word in
            word.masteryLevel == .familiar
        }.count
    }
    
    private func getUnfamiliarWordsCount() -> Int {
        return viewModel.vocabulary.filter { word in
            word.masteryLevel == .unfamiliar
        }.count
    }
    
    private func getLearningWordsCount() -> Int {
        getFamiliarWordsCount()
    }
    
    private func getMasteryPercentage(_ mastery: MasteryLevel) -> Double {
        guard !viewModel.vocabulary.isEmpty else { return 0 }
        let count: Int
        switch mastery {
        case .mastered: count = getMasteredWordsCount()
        case .familiar: count = getFamiliarWordsCount()
        case .unfamiliar: count = getUnfamiliarWordsCount()
        }
        return Double(count) / Double(viewModel.vocabulary.count)
    }
    
    private func getThisWeekNewWords() -> Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return viewModel.vocabulary.filter { $0.firstLookupDate >= weekAgo }.count
    }
    
    private func getAverageDailyWords() -> Int {
        guard !viewModel.vocabulary.isEmpty else { return 0 }
        let oldestDate = viewModel.vocabulary.map { $0.firstLookupDate }.min() ?? Date()
        let daysSince = Calendar.current.dateComponents([.day], from: oldestDate, to: Date()).day ?? 1
        return max(1, viewModel.vocabulary.count / max(1, daysSince))
    }
    
    private func getFrequentWords() -> [UserWord] {
        return viewModel.vocabulary.sorted { $0.lookupCount > $1.lookupCount }
    }
    
    private func getReviewWords() -> [UserWord]? {
        return viewModel.vocabulary.filter { $0.isMarkedForReview }
    }
    
    private func getTodayReviewCount() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return viewModel.vocabulary.filter { 
            Calendar.current.isDate($0.lastLookupDate, inSameDayAs: today)
        }.count
    }
    
    // 计算属性：filteredMyWords
    private var filteredMyWords: [UserWord] {
        return viewModel.filteredVocabulary
    }
    
    // MARK: - 辅助方法
    
    private func initializePersonalDictionaryManager() {
        personalDictionaryManager = PersonalDictionaryManager(
            modelContext: modelContext
        )
        kaoyanDictionaryImporter = KaoyanDictionaryImporter(
            modelContext: modelContext
        )
        
        // 加载个人词典数据
        loadPersonalDictionaries()
    }
    
    private func loadPersonalDictionaries() {
        guard let manager = personalDictionaryManager else { return }
        
        Task {
            do {
                let dictionaries = try await manager.getPersonalDictionaries()
                await MainActor.run {
                    self.personalDictionaries = dictionaries
                    print("✅ 个人词典加载成功，共 \(dictionaries.count) 个词典")
                }
            } catch {
                await MainActor.run {
                    self.personalDictionaries = []
                    print("❌ 个人词典加载失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func debounceFilterWords() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms 延迟
            if !Task.isCancelled {
                await MainActor.run {
                    filterVocabularyWords()
                }
            }
        }
    }
    
    private func filterVocabularyWords() {
        viewModel.searchText = searchText
        if let masteryLevel = convertToMasteryLevel(selectedMastery) {
            viewModel.setMasteryFilter(masteryLevel)
        }
    }
    
    // MARK: - Helper Functions
    
    /// 将可选的 MasteryLevel 转换为非可选类型
    private func convertToMasteryLevel(_ level: MasteryLevel?) -> MasteryLevel? {
        return level
    }
    
    private func sortVocabularyWords() {
        viewModel.setSortOption(sortOption)
    }
    
    // MARK: - 测试数据加载
    
    private func loadTestData() {
        guard !isLoadingTestData else { return }
        
        isLoadingTestData = true
        
        let testDataService = appCoordinator.getTestDataService()
        
        // 使用Combine订阅获取测试历史
        testDataService.getTestHistory(limit: 20)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ [VocabularyView] 加载测试历史失败: \(error.localizedDescription)")
                    }
                    isLoadingTestData = false
                },
                receiveValue: { history in
                    testHistory = history
                    print("✅ [VocabularyView] 成功加载测试历史: \(history.count) 条记录")
                }
            )
            .store(in: &cancellables)
        
        // 使用Combine订阅获取最新测试
        testDataService.getLatestTest()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ [VocabularyView] 加载最新测试失败: \(error.localizedDescription)")
                    }
                },
                receiveValue: { latest in
                    latestTest = latest
                    if let latest = latest {
                        print("✅ [VocabularyView] 成功加载最新测试: \(formatDate(latest.testDate))")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 辅助方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    // MARK: - 重测模式服务初始化
    
    private func initializeRetestModeService() {
        retestModeService = appCoordinator.getRetestModeService()
        print("✅ [VocabularyView] 重测模式服务初始化成功")
    }
    
    // MARK: - 快速重测功能
    
    private func startQuickRetest(for masteryLevel: MasteryLevel) {
        Task {
            do {
                guard let retestService = retestModeService else {
                    print("❌ [VocabularyView] 重测服务未初始化")
                    return
                }
                
                // 获取可用词典
                let availableDictionaries = try await retestService.getAvailableDictionaries()
                
                // 创建重测配置
                let retestConfig = RetestConfig(
                    masteryLevels: [masteryLevel],
                    selectedDictionaries: Set(availableDictionaries.map { $0.id.uuidString }),
                    wordCount: 50, // 默认50个单词
                    randomOrder: true
                )
                
                // 筛选单词
                // 将 RetestConfig 转换为 RetestWordFilters
                        let filters = RetestWordFilters(
                            dictionaryIds: Set(availableDictionaries.map { $0.id }),
                            masteryLevels: retestConfig.masteryLevels,
                            excludeRecentlyTested: false,
                            recentTestThreshold: 24 * 60 * 60
                        )
                        let filteredWords = try await retestService.getFilteredWords(filters: filters)
                
                if filteredWords.isEmpty {
                    print("⚠️ [VocabularyView] 没有找到符合条件的单词")
                    return
                }
                
                print("✅ [VocabularyView] 快速重测：找到 \(filteredWords.count) 个\(masteryLevel.displayName)单词")
                
                // 使用统一的VocabularyTestView进行重测
                await MainActor.run {
                    // 设置重测配置并显示测试界面；先关闭重测模式弹窗
                    self.quickRetestConfig = retestConfig
                    isShowingRetestMode = false
                    isShowingVocabularyTest = true
                }
                
            } catch {
                print("❌ [VocabularyView] 快速重测失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - 掌握程度按钮组件
struct MasteryLevelButton: View {
    let title: String
    let count: Int
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    let onQuickRetest: (() -> Void)? // 新增快速重测回调
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
                
                // 快速重测按钮
                if let onQuickRetest = onQuickRetest, count > 0 {
                    Button {
                        onQuickRetest()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                            Text("重测")
                                .font(.caption2)
                        }
                        .foregroundColor(isSelected ? .white.opacity(0.8) : color.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSelected ? Color.white.opacity(0.2) : color.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - MasteryLevel 扩展
// 删除VocabularyMasteryLevel扩展，使用MasteryLevel的扩展

// MARK: - UserWord 扩展
// 注意：masteryLevel 已在 Word.swift 中定义为存储属性，此处不再重复定义

// MARK: - 子视图组件
struct WordRecordRow: View {
    let wordRecord: UserWord
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(wordRecord.word)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 掌握程度标识
                    Circle()
                        .fill(wordRecord.masteryLevel.color)
                        .frame(width: 12, height: 12)
                    
                    if wordRecord.isMarkedForReview {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                
                if let definition = wordRecord.selectedDefinition {
                    Text("\(wordRecord.word)（\(wordRecord.testSource ?? "未知")）\(definition.meaning)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text("查询 \(wordRecord.lookupCount) 次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: wordRecord.lastLookupDate, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ReviewWordRow: View {
    let wordRecord: UserWord
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(wordRecord.word)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let definition = wordRecord.selectedDefinition {
                    Text(definition.meaning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button(action: action) {
                HStack(spacing: 4) {
                    Text("复习")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}

// MARK: - 预览
#Preview {
    let container = try! ModelContainer(for: UserWord.self)
    let mockContext = ModelContext(container)
    let mockCacheManager = MockCacheManager()
    let mockErrorHandler = UnifiedErrorHandler()
    let mockAppCoordinator = AppCoordinator(serviceContainer: ServiceContainer.shared)
    
    let mockDictionaryService = DictionaryService(
        modelContext: mockContext,
        cacheManager: mockCacheManager,
        errorHandler: mockErrorHandler
    )
    
    let mockUserProgressService = UserProgressService(
        modelContext: mockContext,
        cacheManager: mockCacheManager,
        errorHandler: mockErrorHandler
    )
    
    let mockViewModel = VocabularyViewModel(
        dictionaryService: mockDictionaryService,
        userProgressService: mockUserProgressService,
        errorHandler: mockErrorHandler
    )
    
    VocabularyView(viewModel: mockViewModel)
        .modelContainer(container)
        .environmentObject(mockDictionaryService)
        .environmentObject(mockAppCoordinator)
        .environment(mockErrorHandler)
}

// 新增：复习会话视图
struct ReviewSessionView: View {
    @ObservedObject var viewModel: VocabularyViewModel
    @EnvironmentObject private var dictionaryService: DictionaryService
    @Environment(UnifiedErrorHandler.self) private var errorHandler
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if let word = viewModel.currentReviewWord {
                    Text(word.word)
                        .font(.title)
                        .fontWeight(.bold)

                    if let def = dictionaryService.lookupWord(word.word, context: word.context)?.definitions.first {
                        Text(def.meaning)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    SwiftUI.ProgressView(value: viewModel.reviewProgress)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        Button("记住了") {
                            viewModel.reviewWord(word, correct: true)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("没记住") {
                            viewModel.reviewWord(word, correct: false)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Text("没有待复习单词")
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("复习")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        viewModel.finishReview()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(true)
    }
}

// ... existing code ...
