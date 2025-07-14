//
//  ArticleReaderView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI

struct ArticleReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @State private var showingWordDefinition = false
    @State private var selectedWord = ""
    @State private var showingSentenceTranslation = false
    @State private var selectedSentence = ""
    @State private var showingParagraphTranslation = false
    @State private var selectedParagraph = ""
    @State private var showingSettings = false
    @State private var fontSize: CGFloat = 16
    @State private var lineSpacing: CGFloat = 6
    @State private var colorScheme: ColorScheme = .light
    @State private var readingStartTime = Date()
    @State private var readingTimer: Timer?
    
    let article: Article
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 顶部标题区域 - 模拟真题文档样式
                    VStack(alignment: HorizontalAlignment.center, spacing: 8) {
                        Text("\(article.year)年全国硕士研究生入学统一考试英语（\(article.examType == "考研英语一" ? "一" : "二")）试题")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Section I Use of English")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.top, 4)
                        
                        Text("Directions:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Read the following text.")
                            Text("Choose the best word (s) for each numbered")
                            Text("blank and mark A, B, C or D on the ANSWER SHEET.")
                            Text("(10 points)")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    // 分隔线
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    
                    // 文章正文 - 真题文档样式
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(article.paragraphs.enumerated()), id: \.element.id) { index, paragraph in
                            VStack(alignment: .leading, spacing: 8) {
                                // 段落内容 - 使用更紧凑的排版
                                Text(paragraph.content)
                                    .font(.system(size: fontSize, weight: .regular))
                                    .lineSpacing(lineSpacing)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .onTapGesture {
                                        selectedParagraph = paragraph.content
                                        showingParagraphTranslation = true
                                    }
                                
                                // 段落翻译（如果可见）
                                if paragraph.isTranslationVisible, let translation = paragraph.translation {
                                    Text(translation)
                                        .font(.system(size: fontSize - 2))
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .padding(.top, 4)
                                }
                            }
                            .padding(.bottom, index < article.paragraphs.count - 1 ? 16 : 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        stopReading()
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "textformat.size")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {
                            article.isBookmarked.toggle()
                            try? modelContext.save()
                        }) {
                            Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 16))
                                .foregroundColor(article.isBookmarked ? .orange : .primary)
                        }
                        
                        Button(action: {
                            shareArticle()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .onAppear {
            startReading()
        }
        .onDisappear {
            stopReading()
        }
        .sheet(isPresented: $showingWordDefinition) { 
            if let progressViewModel = appCoordinator.progressViewModel {
                WordDefinitionSheet(word: selectedWord, viewModel: progressViewModel)
                    .environmentObject(appCoordinator)
            }
        }
        .sheet(isPresented: $showingSentenceTranslation) { 
            if let progressViewModel = appCoordinator.progressViewModel {
                SentenceTranslationSheet(sentence: selectedSentence, viewModel: progressViewModel)
                    .environmentObject(appCoordinator)
            }
        }
        .sheet(isPresented: $showingParagraphTranslation) { 
            if let progressViewModel = appCoordinator.progressViewModel {
                ParagraphTranslationSheet(paragraph: selectedParagraph, viewModel: progressViewModel)
                    .environmentObject(appCoordinator)
            }
        }
        .sheet(isPresented: $showingSettings) {
            ReadingSettingsSheet(
                fontSize: $fontSize,
                lineSpacing: $lineSpacing,
                colorScheme: $colorScheme
            )
        }
        .preferredColorScheme(colorScheme)
    }
    
    private func startReading() {
        readingStartTime = Date()
        // 开始阅读计时
        readingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            // 每分钟更新一次阅读时间
        }
    }
    
    private func stopReading() {
        readingTimer?.invalidate()
        readingTimer = nil
        
        let readingTime = Date().timeIntervalSince(readingStartTime)
        article.addReadingTime(readingTime)
        try? modelContext.save()
    }
    
    private func shareArticle() {
        // 分享文章功能
    }
    
    private func markAsCompleted() {
        article.isCompleted = true
        article.readingProgress = 1.0
        article.completedDate = Date()
        try? modelContext.save()
    }
}

// MARK: - 单词定义弹窗

struct WordDefinitionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let word: String
    let viewModel: ProgressViewModel
    @State private var definition: String = ""
    @State private var isLoading = true
    @State private var pronunciation: String = ""
    @State private var examples: [String] = []
    @State private var isAddedToVocabulary = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    VStack {
                        SwiftUI.ProgressView()
                            .scaleEffect(1.2)
                        Text("查询中...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // 单词和发音
                            VStack(alignment: .leading, spacing: 8) {
                                Text(word)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                if !pronunciation.isEmpty {
                                    Text(pronunciation)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            // 定义
                            VStack(alignment: .leading, spacing: 8) {
                                Text("释义")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text(definition)
                                    .font(.body)
                                    .lineSpacing(4)
                            }
                            
                            // 例句
                            if !examples.isEmpty {
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("例句")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    ForEach(examples, id: \.self) { example in
                                        Text("• \(example)")
                                            .font(.body)
                                            .lineSpacing(4)
                                            .padding(.leading, 8)
                                    }
                                }
                            }
                            
                            Spacer(minLength: 20)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("单词释义")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await addToVocabulary()
                        }
                    }) {
                        Image(systemName: isAddedToVocabulary ? "heart.fill" : "heart")
                            .foregroundColor(isAddedToVocabulary ? .red : .primary)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadDefinition()
            }
        }
    }
    
    private func loadDefinition() async {
        // 模拟网络请求延迟
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            // 模拟查词结果
            definition = "这是单词 '\(word)' 的释义。在实际应用中，这里会显示从词典API获取的真实定义。"
            pronunciation = "/\(word)/"
            examples = [
                "This is an example sentence with \(word).",
                "Another example showing how to use \(word) in context."
            ]
            isLoading = false
        }
    }
    
    private func addToVocabulary() async {
        // 添加到生词本的逻辑
        await MainActor.run {
            isAddedToVocabulary.toggle()
        }
    }
}

// MARK: - 句子翻译弹窗

struct SentenceTranslationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sentence: String
    let viewModel: ProgressViewModel
    @State private var translation = ""
    @State private var analysis = ""
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 原文
                    VStack(alignment: .leading, spacing: 8) {
                        Text("原文")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(sentence)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    if isLoading {
                        SwiftUI.ProgressView("分析中...")
                            .frame(maxWidth: .infinity)
                    } else {
                        // 翻译
                        VStack(alignment: .leading, spacing: 8) {
                            Text("翻译")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Text(translation)
                                .font(.body)
                                .padding()
                                .background(Color(.systemBlue).opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // 句式分析
                        if !analysis.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("句式分析")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                Text(analysis)
                                    .font(.body)
                                    .padding()
                                    .background(Color(.systemGreen).opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("句子翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadTranslation()
        }
    }
    
    private func loadTranslation() {
        // 模拟翻译和分析
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            translation = "这是句子的中文翻译。"
            analysis = "这是句子的语法分析。"
            isLoading = false
        }
    }
}

// MARK: - 段落翻译弹窗

struct ParagraphTranslationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let paragraph: String
    let viewModel: ProgressViewModel
    @State private var translation = ""
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 原文
                    VStack(alignment: .leading, spacing: 8) {
                        Text("原文")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(paragraph)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    if isLoading {
                        SwiftUI.ProgressView("翻译中...")
                            .frame(maxWidth: .infinity)
                    } else {
                        // 翻译
                        VStack(alignment: .leading, spacing: 8) {
                            Text("翻译")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Text(translation)
                                .font(.body)
                                .padding()
                                .background(Color(.systemBlue).opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("段落翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadTranslation()
        }
    }
    
    private func loadTranslation() {
        // 模拟翻译
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            translation = "这是段落的中文翻译。"
            isLoading = false
        }
    }
}

// MARK: - 阅读设置弹窗

struct ReadingSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var fontSize: CGFloat
    @Binding var lineSpacing: CGFloat
    @Binding var colorScheme: ColorScheme
    
    var body: some View {
        NavigationView {
            Form {
                Section("字体设置") {
                    HStack {
                        Text("字体大小")
                        Spacer()
                        Text("\(Int(fontSize))")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $fontSize,
                        in: 12...24,
                        step: 1
                    )
                    
                    HStack {
                        Text("行间距")
                        Spacer()
                        Text("\(Int(lineSpacing))")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $lineSpacing,
                        in: 4...12,
                        step: 1
                    )
                }
                
                Section("主题设置") {
                    Picker("主题", selection: $colorScheme) {
                        Text("浅色").tag(ColorScheme.light)
                        Text("深色").tag(ColorScheme.dark)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let sampleArticle = Article(
        title: "2023年考研一真题",
        content: "Artificial intelligence (AI) is transforming work, and another like Siri, autonomous vehicles and sophisticated data analysis tools. AI technologies are increasingly becoming part of our daily lives.\n\nOne of the most significant impacts of AI is in the workplace. Automation and AI-powered systems are changing how we work, creating new opportunities while also presenting challenges for workers and organizations.",
        year: 2023,
        examType: "考研英语一",
        difficulty: .medium,
        topic: "人工智能",
        imageName: "ai_article"
    )
    
    return ArticleReaderView(article: sampleArticle).modelContainer(for: [Article.self, UserProgress.self])
}