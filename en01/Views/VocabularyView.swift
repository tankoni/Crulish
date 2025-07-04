//
//  VocabularyView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI

struct VocabularyView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedTab: VocabularyTab = .myWords
    @State private var searchText = ""
    @State private var selectedMastery: MasteryLevel?
    @State private var sortOption: VocabularySortOption = .recent
    @State private var isShowingFilters = false
    @State private var myWords: [UserWord] = []
    @State private var filteredWords: [UserWord] = []
    @State private var vocabularyStats: VocabularyStats?
    @State private var debounceTask: Task<Void, Never>? // 防抖任务
    @State private var isDataLoaded = false // 防止重复加载
    
    var body: some View {
        NavigationView {
            mainContent
                .navigationTitle("词汇宝典")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        toolbarMenu
                    }
                }
        }
        .onAppear {
            // 避免重复加载数据
            if !isDataLoaded {
                loadVocabularyData()
                isDataLoaded = true
            }
        }
        .onChange(of: selectedTab) { _, _ in
            loadVocabularyData()
        }
        .onChange(of: searchText) { _, _ in
            // 防抖处理，避免频繁过滤
            debounceFilter()
        }
        .onChange(of: selectedMastery) { _, _ in
            filterWords()
        }
        .onChange(of: sortOption) { _, _ in
            sortWords()
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
                appViewModel.exportVocabulary()
            } label: {
                Label("导出词汇", systemImage: "square.and.arrow.up")
            }
            
            Button {
                appViewModel.startVocabularyReview()
            } label: {
                Label("开始复习", systemImage: "brain.head.profile")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    
    // MARK: - 标签栏
    
    private var vocabularyTabBar: some View {
        HStack(spacing: 0) {
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
                }
                .foregroundColor(selectedTab == tab ? .blue : .secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 搜索栏
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索单词或释义", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
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
                    FilterChip(
                        title: selectedMastery?.displayName ?? "掌握程度",
                        isSelected: selectedMastery != nil
                    )
                }
                
                // 排序选项
                Menu {
                    ForEach(VocabularySortOption.allCases, id: \.self) { option in
                        Button(option.displayName) {
                            sortOption = option
                        }
                    }
                } label: {
                    FilterChip(
                        title: sortOption.displayName,
                        isSelected: true
                    )
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
        case .review:
            reviewView
        case .statistics:
            statisticsView
        }
    }
    
    // MARK: - 我的单词
    
    private var myWordsView: some View {
        Group {
            if filteredWords.isEmpty {
                emptyWordsView
            } else {
                List {
                    ForEach(filteredWords) { wordRecord in
                        WordRecordRow(wordRecord: wordRecord) {
                            appViewModel.showWordDetail(wordRecord)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                appViewModel.toggleReviewFlag(for: wordRecord)
                            } label: {
                                Image(systemName: wordRecord.needsReview ? "flag.slash" : "flag")
                            }
                            .tint(.orange)
                            
                            Button {
                                appViewModel.deleteWordRecord(wordRecord)
                                loadVocabularyData()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    loadVocabularyData()
                }
            }
        }
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
                appViewModel.selectedTab = .reading
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 复习视图
    
    private var reviewView: some View {
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
                                appViewModel.startWordReview(wordRecord)
                            }
                        }
                    }
                    
                    if reviewWords.count > 10 {
                        Button("查看全部 \(reviewWords.count) 个单词") {
                            appViewModel.showAllReviewWords()
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var reviewStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("复习统计")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("开始复习") {
                    appViewModel.startVocabularyReview()
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
                    value: "\(myWords.count)",
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
    
    // MARK: - 数据处理
    
    /// 异步加载词汇数据（带性能优化）
    private func loadVocabularyData() {
        Task {
            // 并行加载数据以提高性能
            async let wordsTask = loadUserWords()
            async let statsTask = loadVocabularyStats()
            
            let (words, stats) = await (wordsTask, statsTask)
            
            // 在主线程更新UI
            await MainActor.run {
                self.myWords = words
                self.vocabularyStats = stats
                self.filterWords()
            }
        }
    }
    
    /// 异步加载用户单词
    private func loadUserWords() async -> [UserWord] {
        return appViewModel.getUserWordRecords()
    }
    
    /// 异步加载词汇统计
    private func loadVocabularyStats() async -> VocabularyStats? {
        return appViewModel.getVocabularyStats()
    }
    
    /// 防抖处理搜索，避免频繁过滤
    private func debounceFilter() {
        // 取消之前的任务
        debounceTask?.cancel()
        
        // 创建新的延迟任务
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms延迟
            
            if !Task.isCancelled {
                await MainActor.run {
                    filterWords()
                }
            }
        }
    }
    
    private func filterWords() {
        var filtered = myWords
        
        // 搜索过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { wordRecord in
                wordRecord.word.localizedCaseInsensitiveContains(searchText) ||
                wordRecord.selectedDefinition?.meaning.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // 掌握程度过滤
        if let mastery = selectedMastery {
            filtered = filtered.filter { $0.masteryLevel == mastery }
        }
        
        filteredWords = filtered
        sortWords()
    }
    
    private func sortWords() {
        switch sortOption {
        case .recent:
            filteredWords.sort(by: { $0.lastQueryDate > $1.lastQueryDate })
        case .alphabetical:
            filteredWords.sort(by: { $0.word < $1.word })
        case .frequency:
            filteredWords.sort(by: { $0.queryCount > $1.queryCount })
        case .mastery:
            filteredWords.sort(by: { $0.masteryLevel.rawValue < $1.masteryLevel.rawValue })
        }
    }
    
    // MARK: - 辅助方法
    
    private func getReviewWords() -> [UserWord]? {
        return myWords.filter { $0.needsReview }
    }
    
    private func getTodayReviewCount() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return myWords.filter { wordRecord in
            if let reviewDate = wordRecord.lastReviewDate {
                return Calendar.current.isDate(reviewDate, inSameDayAs: today)
            }
            return false
        }.count
    }
    
    private func getMasteredWordsCount() -> Int {
        return myWords.filter { $0.masteryLevel == .mastered }.count
    }
    
    private func getLearningWordsCount() -> Int {
        return myWords.filter { $0.masteryLevel == .familiar }.count
    }
    
    private func getUnfamiliarWordsCount() -> Int {
        return myWords.filter { $0.masteryLevel == .unfamiliar }.count
    }
    
    private func getMasteryPercentage(_ mastery: MasteryLevel) -> Double {
        guard !myWords.isEmpty else { return 0 }
        let count = myWords.filter { $0.masteryLevel == mastery }.count
        return Double(count) / Double(myWords.count)
    }
    
    private func getThisWeekNewWords() -> Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return myWords.filter { $0.firstQueryDate >= weekAgo }.count
    }
    
    private func getAverageDailyWords() -> Int {
        guard !myWords.isEmpty else { return 0 }
        let oldestDate = myWords.map { $0.firstQueryDate }.min() ?? Date()
        let daysSince = Calendar.current.dateComponents([.day], from: oldestDate, to: Date()).day ?? 1
        return max(1, myWords.count / max(1, daysSince))
    }
    
    private func getFrequentWords() -> [UserWord] {
        return myWords.sorted { $0.queryCount > $1.queryCount }
    }
}

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
                    
                    if wordRecord.needsReview {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                
                if let definition = wordRecord.selectedDefinition {
                    Text(definition.meaning)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text("查询 \(wordRecord.queryCount) 次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: wordRecord.lastQueryDate, relativeTo: Date()))
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
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(wordRecord.word)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let definition = wordRecord.selectedDefinition {
                        Text(definition.meaning)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ReviewStatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatCard: View {
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
                .font(.title2)
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

// MARK: - 子视图组件

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .cornerRadius(16)
    }
}

// MARK: - 枚举定义

enum VocabularyTab: String, CaseIterable {
    case myWords = "myWords"
    case review = "review"
    case statistics = "statistics"
    
    var title: String {
        switch self {
        case .myWords:
            return "我的单词"
        case .review:
            return "复习"
        case .statistics:
            return "统计"
        }
    }
}

enum VocabularySortOption: String, CaseIterable {
    case recent = "recent"
    case alphabetical = "alphabetical"
    case frequency = "frequency"
    case mastery = "mastery"
    
    var displayName: String {
        switch self {
        case .recent:
            return "最近查询"
        case .alphabetical:
            return "字母顺序"
        case .frequency:
            return "查询频率"
        case .mastery:
            return "掌握程度"
        }
    }
}

#Preview {
    VocabularyView()
        .environment(AppViewModel())
}