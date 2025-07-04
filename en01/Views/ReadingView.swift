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
                NavigationLink(destination: ArticleListView(examType: "考研一")) {
                        CategoryCard(title: "考研英语一")
                    }
                    
                    NavigationLink(destination: ArticleListView(examType: "考研二")) {
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

struct ArticleListView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let examType: String

    private var articles: [Article] {
        appViewModel.articles.filter { $0.examType == examType }
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
                ForEach(articles) { article in
                    NavigationLink(destination: ArticleReaderView()) {
                        GridArticleRow(article: article)
                    }
                    .onTapGesture {
                        appViewModel.startReading(article)
                    }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(article.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipped()
                .cornerRadius(8)

            Text(article.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(article.year)年真题")
                .font(.caption)
                .foregroundColor(.secondary)
            
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