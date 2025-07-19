//
//  ReadingView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI
import UIKit

struct ReadingView: View {
    @ObservedObject var viewModel: ReadingViewModel
    
    init(viewModel: ReadingViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isReading && viewModel.currentArticle != nil {
                    // 显示文章阅读视图
                    ArticleReaderView(article: viewModel.currentArticle!)
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
            // ReadingView不需要加载文章，文章由其他视图传入
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
                NavigationLink(destination: UnifiedArticleListView(viewModel: viewModel, categoryType: .examOne)) {
                    CategoryCard(title: "考研英语一")
                }
                
                NavigationLink(destination: UnifiedArticleListView(viewModel: viewModel, categoryType: .examTwo)) {
                    CategoryCard(title: "考研英语二")
                }
                
                NavigationLink(destination: UnifiedArticleListView(viewModel: viewModel, categoryType: .general)) {
                    CategoryCard(title: "考研英语[通用]")
                }
                
                NavigationLink(destination: UnifiedArticleListView(viewModel: viewModel, categoryType: .cet)) {
                    CategoryCard(title: "大学四六级")
                }
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

            // 继续阅读功能需要从外部传入文章数据
            if false { // 暂时禁用，需要重构
                // ArticleListRow will be implemented when article data is available
                EmptyView()
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
    @ObservedObject var viewModel: ReadingViewModel
    let examType: String
    @State private var articles: [Article] = []
    @State private var isLoading: Bool = true
    
    init(viewModel: ReadingViewModel, examType: String) {
        self.viewModel = viewModel
        self.examType = examType
    }

    private var examPapersByYear: [Int: [Article]] {
        Dictionary(grouping: articles.filter { article in
            switch examType {
            case "考研一":
                return article.examType.contains("考研") && article.examType.contains("一")
            case "考研二":
                return article.examType.contains("考研") && article.examType.contains("二")
            default:
                return article.examType == examType
            }
        }, by: { $0.year })
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
        Group {
            if isLoading {
                VStack {
                    SwiftUI.ProgressView("加载中...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if articles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("暂无\(displayTitle)文章")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("请稍后再试")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ForEach(sortedYears, id: \.self) { year in
                            if let articles = examPapersByYear[year] {
                                NavigationLink(destination: ArticleListView(viewModel: viewModel, examType: examType, year: year, articles: articles)) {
                                    ExamPaperCard(year: year, examType: examType, articles: articles)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(displayTitle)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadArticles()
        }
    }
    
    private func loadArticles() {
        Task {
            let allArticles = viewModel.articleService.getAllArticles()
            await MainActor.run {
                self.articles = allArticles
                self.isLoading = false
            }
        }
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
    @ObservedObject var viewModel: ReadingViewModel
    let examType: String
    let year: Int?
    let articles: [Article]
    
    init(viewModel: ReadingViewModel, examType: String, year: Int? = nil, articles: [Article]? = nil) {
        self.viewModel = viewModel
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
                        viewModel.startReading(article)
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

struct DirectArticleListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appCoordinator: AppCoordinator
    @ObservedObject var viewModel: ReadingViewModel
    @State private var pdfFiles: [URL] = []
    @State private var isLoading: Bool = true
    @State private var articles: [Article] = []
    
    let examType: String
    
    init(viewModel: ReadingViewModel, examType: String) {
        self.viewModel = viewModel
        self.examType = examType
    }
    
    private var filteredAndSortedArticles: [Article] {
        let filtered = articles.filter { article in
            switch examType {
            case "考研一":
                return article.examType.contains("考研") && article.examType.contains("一")
            case "考研二":
                return article.examType.contains("考研") && article.examType.contains("二")
            default:
                return article.examType == examType
            }
        }
        // 按年份从近到远排序
        return filtered.sorted { $0.year > $1.year }
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
        Group {
            if isLoading {
                VStack {
                    SwiftUI.ProgressView("加载中...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredAndSortedArticles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("暂无\(displayTitle)文章")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("请稍后再试")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ForEach(filteredAndSortedArticles) { article in
                            Button(action: {
                                viewModel.startReading(article)
                            }) {
                                GridArticleRow(article: article)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(displayTitle)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("返回")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadArticles()
        }
    }
    
    private func loadArticles() {
        Task {
            let allArticles = viewModel.articleService.getAllArticles()
            await MainActor.run {
                self.articles = allArticles
                self.isLoading = false
            }
        }
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
    // 预览暂时禁用，需要重构ReadingView以支持依赖注入
    Text("ReadingView Preview")
}

struct PDFListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appCoordinator: AppCoordinator
    @ObservedObject var viewModel: ReadingViewModel
    @State private var pdfFiles: [URL] = []
    @State private var isLoading: Bool = true
    
    init(viewModel: ReadingViewModel) {
        self.viewModel = viewModel
    }
    
    // 添加计算属性来简化复杂表达式
    private var progressViewModel: ProgressViewModel {
        return appCoordinator.progressViewModel ?? ProgressViewModel(
            userProgressService: appCoordinator.getUserProgressService(),
            articleService: appCoordinator.getArticleService(),
            errorHandler: appCoordinator.getErrorHandler()
        )
    }
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView("加载中...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if pdfFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("暂无PDF文件")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("请稍后再试")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ForEach(pdfFiles, id: \.self) { pdfURL in
                            NavigationLink(
                                destination: PDFReaderView(
                                    pdfURL: pdfURL,
                                    article: createDummyArticle(from: pdfURL),
                                    viewModel: progressViewModel
                                )
                            ) {
                                PDFFileCard(pdfURL: pdfURL)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("真题列表")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                }
            }
        }
        .onAppear {
            loadPDFFiles()
        }
    }

    private func loadPDFFiles() {
        isLoading = true
        Task {
            let urls = await viewModel.loadPDFFiles()
            await MainActor.run {
                self.pdfFiles = urls
                self.isLoading = false
            }
        }
    }

    private func createDummyArticle(from url: URL) -> Article {
        let title = url.deletingPathExtension().lastPathComponent
        
        // 获取相对于Bundle资源目录的路径
        let relativePath: String
        if let resourcePath = Bundle.main.resourcePath {
            let resourceURL = URL(fileURLWithPath: resourcePath)
            relativePath = url.path.replacingOccurrences(of: resourceURL.path + "/", with: "")
        } else {
            relativePath = url.lastPathComponent
        }
        
        return Article(
            title: title,
            content: "This is a placeholder for the article content. The actual content will be read from the PDF.",
            year: 2024,
            examType: "真题",
            difficulty: .medium,
            topic: "综合",
            imageName: "default_image",
            pdfPath: relativePath
        )
    }
}

struct PDFFileCard: View {
    let pdfURL: URL
    
    private var fileName: String {
        pdfURL.lastPathComponent.replacingOccurrences(of: ".pdf", with: "")
    }
    
    private var year: String {
        let yearRegex = try? NSRegularExpression(pattern: "(\\d{4})年", options: [])
        let range = NSRange(location: 0, length: fileName.count)
        let match = yearRegex?.firstMatch(in: fileName, options: [], range: range)
        
        if let match = match {
            let yearString = (fileName as NSString).substring(with: match.range(at: 1))
            return "\(yearString)年"
        }
        return "未知年份"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // PDF图标区域
            VStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
                
                Text("PDF")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(year)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}



// MARK: - 统一文章列表界面
struct UnifiedArticleListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appCoordinator: AppCoordinator
    @ObservedObject var viewModel: ReadingViewModel
    @State private var articles: [Article] = []
    @State private var pdfFiles: [URL] = []
    @State private var isLoading: Bool = true
    
    let categoryType: ArticleCategoryType
    
    init(viewModel: ReadingViewModel, categoryType: ArticleCategoryType) {
        self.viewModel = viewModel
        self.categoryType = categoryType
    }
    
    private var progressViewModel: ProgressViewModel {
        return appCoordinator.progressViewModel ?? ProgressViewModel(
            userProgressService: appCoordinator.getUserProgressService(),
            articleService: appCoordinator.getArticleService(),
            errorHandler: appCoordinator.getErrorHandler()
        )
    }
    
    private var filteredAndSortedArticles: [Article] {
        let filtered = articles.filter { article in
            switch categoryType {
            case .examOne:
                return article.examType.contains("考研") && article.examType.contains("一")
            case .examTwo:
                return article.examType.contains("考研") && article.examType.contains("二")
            case .general:
                return true // 通用类型显示PDF文件
            case .cet:
                return article.examType.contains("四六级")
            }
        }
        return filtered.sorted { $0.year > $1.year }
    }
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView("加载中...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                contentView
            }
        }
        .navigationTitle(categoryType.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadData()
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if categoryType == .general || categoryType == .cet {
            // 通用类型和大学四六级显示PDF文件
            if pdfFiles.isEmpty {
                emptyStateView(message: "暂无PDF文件")
            } else {
                pdfGridView
            }
        } else {
            // 其他类型显示文章
            if filteredAndSortedArticles.isEmpty {
                emptyStateView(message: "暂无\(categoryType.displayTitle)文章")
            } else {
                articleGridView
            }
        }
    }
    
    private var articleGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(filteredAndSortedArticles) { article in
                    Button(action: {
                        viewModel.startReading(article)
                    }) {
                        GridArticleRow(article: article)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
    
    private var pdfGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(pdfFiles, id: \.self) { pdfURL in
                    NavigationLink(
                        destination: ArticleReaderView(
                            article: createDummyArticle(from: pdfURL)
                        )
                        .environmentObject(appCoordinator)
                    ) {
                        PDFFileCard(pdfURL: pdfURL)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
    
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("请稍后再试")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadData() {
        Task {
            if categoryType == .general || categoryType == .cet {
                // 加载PDF文件，传递categoryType参数
                let urls = await viewModel.loadPDFFiles(for: categoryType)
                await MainActor.run {
                    self.pdfFiles = urls
                    self.isLoading = false
                }
            } else {
                // 加载文章
                let allArticles = viewModel.articleService.getAllArticles()
                await MainActor.run {
                    self.articles = allArticles
                    self.isLoading = false
                }
            }
        }
    }
    
    private func createDummyArticle(from url: URL) -> Article {
        let title = url.deletingPathExtension().lastPathComponent
        
        // 获取相对于Bundle资源目录的路径
        let relativePath: String
        if let resourcePath = Bundle.main.resourcePath {
            let resourceURL = URL(fileURLWithPath: resourcePath)
            relativePath = url.path.replacingOccurrences(of: resourceURL.path + "/", with: "")
        } else {
            relativePath = url.lastPathComponent
        }
        
        return Article(
            title: title,
            content: "This is a placeholder for the article content. The actual content will be read from the PDF.",
            year: 2024,
            examType: "真题",
            difficulty: .medium,
            topic: "综合",
            imageName: "default_image",
            pdfPath: relativePath
        )
    }
}
