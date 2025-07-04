//
//  ReadingView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI

struct ReadingView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        NavigationView {
            Group {
                if appViewModel.isReading && appViewModel.currentArticle != nil {
                    // 显示文章阅读视图
                    ArticleReaderView()
                } else {
                    // 显示文章列表和分类
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // 顶部标题区域
                            headerSection
                            
                            // 文章分类
                            articleCategorySection
                                .padding(.horizontal)
                                .padding(.top, 24)

                            // 继续阅读
                            continueReadingSection
                                .padding(.horizontal)
                                .padding(.top, 32)
                                .padding(.bottom, 24)
                        }
                    }
                    .navigationBarHidden(true)
                    .background(Color(.systemGroupedBackground))
                }
            }
        }
        .onAppear {
            // 加载所有文章
            appViewModel.loadArticles()
        }
    }
    
    // MARK: - 顶部标题区域
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("阅读")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 文章分类
    private var articleCategorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("文章分类")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink(destination: ExamPaperListView(examType: "考研一")) {
                        CategoryCard(title: "考研英语一")
                    }
                    
                    NavigationLink(destination: ExamPaperListView(examType: "考研二")) {
                        CategoryCard(title: "考研英语二")
                    }
                CategoryCard(title: "雅思/托福")
                CategoryCard(title: "大学四六级")
            }
        }
    }

    // MARK: - 继续阅读
    private var continueReadingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("继续阅读")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
                Button("查看全部") {
                    // TODO: 跳转到完整的文章列表
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }

            if let lastArticle = appViewModel.articles.first(where: { $0.readingProgress > 0 && !$0.isCompleted }) {
                ArticleListRow(article: lastArticle) {
                    appViewModel.startReading(lastArticle)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("暂无阅读记录")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("开始阅读第一篇文章吧")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - 文章列表
    

    

    

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
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(article.isCompleted ? .green : .blue)
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



struct CategoryCard: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

struct ExamPaperListView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let examType: String

    private var examPapersByYear: [Int: [Article]] {
        let articles = appViewModel.articles.filter { $0.examType == examType }
        return Dictionary(grouping: articles, by: { $0.year })
    }
    
    private var sortedYears: [Int] {
        examPapersByYear.keys.sorted(by: >)
    }
    
    private var displayTitle: String {
        switch examType {
        case "考研一":
            return "考研英语一"
        case "考研二":
            return "考研英语二"
        default:
            return examType
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(sortedYears, id: \.self) { year in
                    if let articles = examPapersByYear[year] {
                        NavigationLink(destination: ArticleListView(examType: examType, year: year, articles: articles)) {
                            ExamPaperCard(year: year, examType: examType, articles: articles)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding()
        }
        .navigationTitle(displayTitle)
        .background(Color(.systemGroupedBackground))
    }
}

struct ExamPaperCard: View {
    let year: Int
    let examType: String
    let articles: [Article]
    
    private var totalTexts: Int {
        articles.count
    }
    
    private var completedTexts: Int {
        articles.filter { $0.isCompleted }.count
    }
    
    private var averageDifficulty: String {
        let difficulties = articles.map { $0.difficulty }
        let hardCount = difficulties.filter { $0 == .hard }.count
        let mediumCount = difficulties.filter { $0 == .medium }.count
        let easyCount = difficulties.filter { $0 == .easy }.count
        
        if hardCount > mediumCount && hardCount > easyCount {
            return "困难"
        } else if mediumCount > easyCount {
            return "中等"
        } else {
            return "简单"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 年份标题
            HStack {
                Text("\(year)年")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(averageDifficulty)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            
            // 试卷信息
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("\(totalTexts)篇阅读", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if completedTexts > 0 {
                        Label("\(completedTexts)/\(totalTexts)完成", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                // 进度条
                if totalTexts > 0 {
                    let progress = Double(completedTexts) / Double(totalTexts)
                    SwiftUI.ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(progress == 1.0 ? .green : .blue)
                        .scaleEffect(y: 0.8)
                }
            }
            
            // 试卷预览
            Text("包含阅读理解、完形填空等题型")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct ArticleListView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let examType: String
    let year: Int?
    let articles: [Article]
    
    init(examType: String, year: Int? = nil, articles: [Article]? = nil) {
        self.examType = examType
        self.year = year
        if let articles = articles {
            self.articles = articles
        } else {
            self.articles = []
        }
    }
    
    private var displayTitle: String {
        if let year = year {
            switch examType {
            case "考研一":
                return "\(year)年考研英语一"
            case "考研二":
                return "\(year)年考研英语二"
            default:
                return "\(year)年\(examType)"
            }
        } else {
            switch examType {
            case "考研一":
                return "考研英语一"
            case "考研二":
                return "考研英语二"
            default:
                return examType
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(articles) { article in
                    Button(action: {
                        appViewModel.startReading(article)
                    }) {
                        GridArticleRow(article: article)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .navigationTitle(displayTitle)
        .background(Color(.systemGroupedBackground))
    }
}

struct GridArticleRow: View {
    let article: Article
    
    // 获取文章内容预览（前150个字符）
    private var contentPreview: String {
        let preview = article.content.prefix(150)
        return String(preview) + (article.content.count > 150 ? "..." : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 文章内容预览区域
            VStack(alignment: .leading, spacing: 4) {
                Text(contentPreview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(height: 60, alignment: .top)
                
                // 渐变遮罩效果
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color(.systemBackground)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 20)
                    .offset(y: -20)
            }
            .frame(height: 80)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .clipped()

            Text(article.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("\(article.year)年真题")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 难度标签
                Text(article.difficulty.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(article.difficulty.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(article.difficulty.color.opacity(0.15))
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var appViewModel = AppViewModel()
        @Environment(\.modelContext) private var modelContext

        var body: some View {
            ReadingView()
                .environment(appViewModel)
                .onAppear {
                    appViewModel.setModelContext(modelContext)
                }
        }
    }

    return PreviewWrapper()
        .modelContainer(for: [Article.self, DictionaryWord.self, UserWord.self, UserWordRecord.self, UserProgress.self, DailyStudyRecord.self], inMemory: true)
}