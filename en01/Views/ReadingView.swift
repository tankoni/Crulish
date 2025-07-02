//
//  ReadingView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI

struct ReadingView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var articles: [Article] = []
    @State private var filteredArticles: [Article] = []
    @State private var selectedYear: Int?
    @State private var selectedDifficulty: ArticleDifficulty?
    @State private var searchText = ""
    @State private var isShowingFilters = false
    @State private var sortOption: SortOption = .year
    
    private let years = Array(2004...2024).reversed()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                
                // 筛选栏
                if isShowingFilters {
                    filterBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 文章列表
                if appViewModel.isReading && appViewModel.currentArticle != nil {
                    // 阅读界面
                    ArticleReaderView()
                } else {
                    // 文章列表界面
                    articleListView
                }
            }
            .navigationTitle(appViewModel.isReading ? "" : "文章库")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !appViewModel.isReading {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation {
                                isShowingFilters.toggle()
                            }
                        } label: {
                            Image(systemName: isShowingFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
        }
        .onAppear {
            loadArticles()
        }
        .onChange(of: searchText) { _, newValue in
            filterArticles()
        }
        .onChange(of: selectedYear) { _, _ in
            filterArticles()
        }
        .onChange(of: selectedDifficulty) { _, _ in
            filterArticles()
        }
        .onChange(of: sortOption) { _, _ in
            sortArticles()
        }
    }
    
    // MARK: - 搜索栏
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索文章标题或内容", text: $searchText)
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
                // 年份筛选
                Menu {
                    Button("全部年份") {
                        selectedYear = nil
                    }
                    
                    ForEach(years, id: \.self) { year in
                        Button("\(year)年") {
                            selectedYear = year
                        }
                    }
                } label: {
                    FilterChip(
                        title: selectedYear != nil ? "\(selectedYear!)年" : "年份",
                        isSelected: selectedYear != nil
                    )
                }
                
                // 难度筛选
                Menu {
                    Button("全部难度") {
                        selectedDifficulty = nil
                    }
                    
                    ForEach(ArticleDifficulty.allCases, id: \.self) { difficulty in
                        Button(difficulty.displayName) {
                            selectedDifficulty = difficulty
                        }
                    }
                } label: {
                    FilterChip(
                        title: selectedDifficulty?.displayName ?? "难度",
                        isSelected: selectedDifficulty != nil
                    )
                }
                
                // 排序选项
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
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
                if selectedYear != nil || selectedDifficulty != nil {
                    Button {
                        selectedYear = nil
                        selectedDifficulty = nil
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
    
    // MARK: - 文章列表
    
    private var articleListView: some View {
        Group {
            if filteredArticles.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredArticles) { article in
                        ArticleListRow(article: article) {
                            appViewModel.startReading(article)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    loadArticles()
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("没有找到文章")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("尝试调整搜索条件或筛选器")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重置筛选") {
                searchText = ""
                selectedYear = nil
                selectedDifficulty = nil
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 数据处理
    
    private func loadArticles() {
        articles = appViewModel.loadArticles()
        filterArticles()
    }
    
    private func filterArticles() {
        var filtered = articles
        
        // 搜索过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { article in
                article.title.localizedCaseInsensitiveContains(searchText) ||
                article.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 年份过滤
        if let year = selectedYear {
            filtered = filtered.filter { $0.year == year }
        }
        
        // 难度过滤
        if let difficulty = selectedDifficulty {
            filtered = filtered.filter { $0.difficulty == difficulty }
        }
        
        filteredArticles = filtered
        sortArticles()
    }
    
    private func sortArticles() {
        switch sortOption {
        case .year:
            filteredArticles.sort { $0.year > $1.year }
        case .difficulty:
            filteredArticles.sort { $0.difficulty.rawValue < $1.difficulty.rawValue }
        case .title:
            filteredArticles.sort { $0.title < $1.title }
        case .progress:
            filteredArticles.sort { $0.readingProgress > $1.readingProgress }
        case .wordCount:
            filteredArticles.sort { $0.wordCount > $1.wordCount }
        }
    }
}

// MARK: - 子视图组件

struct ArticleListRow: View {
    let article: Article
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题和年份
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        
                        Text("\(article.year)年 · \(article.examType)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 难度标签
                    Text(article.difficulty.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(article.difficulty.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(article.difficulty.color.opacity(0.15))
                        .cornerRadius(8)
                }
                
                // 文章信息
                HStack {
                    Label("\(article.wordCount)词", systemImage: "textformat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if article.readingProgress > 0 {
                        Label("\(Int(article.readingProgress * 100))%", systemImage: "book")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if article.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                // 阅读进度条
                if article.readingProgress > 0 {
                    SwiftUI.ProgressView(value: article.readingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: article.isCompleted ? .green : .blue))
                        .scaleEffect(y: 0.8)
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

// MARK: - 排序选项

enum SortOption: String, CaseIterable {
    case year = "year"
    case difficulty = "difficulty"
    case title = "title"
    case progress = "progress"
    case wordCount = "wordCount"
    
    var displayName: String {
        switch self {
        case .year:
            return "年份"
        case .difficulty:
            return "难度"
        case .title:
            return "标题"
        case .progress:
            return "进度"
        case .wordCount:
            return "字数"
        }
    }
}

#Preview {
    ReadingView()
        .environment(AppViewModel())
}