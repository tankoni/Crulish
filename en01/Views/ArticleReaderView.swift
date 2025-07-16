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
    @State private var displayMode: DisplayMode = .pdf
    @State private var structuredText: StructuredText?
    @State private var isLoadingStructuredText = false
    
    let article: Article
    
    // PDF相关状态
    @State private var pdfURL: URL?
    @State private var showingPDFReader = false
    
    @ViewBuilder
    private var readerContent: some View {
        switch displayMode {
        case .pdf:
            if let pdfURL = pdfURL, let progressViewModel = appCoordinator.progressViewModel {
                PDFReaderView(
                    pdfURL: pdfURL,
                    article: article,
                    viewModel: progressViewModel
                )
            } else {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("PDF文件不可用")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("切换到文本模式查看内容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
        case .text:
            if let structuredText = structuredText {
                StructuredTextView(
                    structuredText: structuredText,
                    article: article
                )
            } else {
                VStack {
                     if isLoadingStructuredText {
                         VStack {
                             SwiftUI.ProgressView()
                             Text("加载中...")
                                 .foregroundColor(.secondary)
                         }
                         .frame(maxWidth: .infinity, maxHeight: .infinity)
                     } else {
                         Text("文本内容不可用")
                             .foregroundColor(.gray)
                             .frame(maxWidth: .infinity, maxHeight: .infinity)
                     }
                 }
            }
            
        case .hybrid:
            if let pdfURL = pdfURL, let structuredText = structuredText, let progressViewModel = appCoordinator.progressViewModel {
                HybridReaderView(
                    pdfURL: pdfURL,
                    structuredText: structuredText,
                    article: article,
                    viewModel: progressViewModel
                )
            } else {
                VStack {
                    Image(systemName: "doc.text.below.ecg")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("混合模式不可用")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("需要PDF文件和文本内容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            readerContent
    
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
                        // 显示模式切换按钮
                        Menu {
                            ForEach(DisplayMode.allCases, id: \.self) { mode in
                                Button(action: {
                                    switchDisplayMode(to: mode)
                                }) {
                                    HStack {
                                        Image(systemName: mode.iconName)
                                        Text(mode.displayName)
                                        if displayMode == mode {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: displayMode.iconName)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        
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
            loadPDFAndStructuredText()
        }
        .onDisappear {
            stopReading()
        }
        .onChange(of: displayMode) { _, newMode in
            if (newMode == .text || newMode == .hybrid) && structuredText == nil && !isLoadingStructuredText {
                loadStructuredText()
            }
        }
        .sheet(isPresented: $showingWordDefinition) { 
            if let progressViewModel = appCoordinator.progressViewModel {
                ArticleWordDefinitionSheet(word: selectedWord, viewModel: progressViewModel)
                    .environmentObject(appCoordinator)
            }
        }
        .sheet(isPresented: $showingSentenceTranslation) { 
            if let progressViewModel = appCoordinator.progressViewModel {
                ArticleSentenceTranslationSheet(sentence: selectedSentence, viewModel: progressViewModel)
                    .environmentObject(appCoordinator)
            }
        }
        .sheet(isPresented: $showingParagraphTranslation) { 
            if let progressViewModel = appCoordinator.progressViewModel {
                ArticleParagraphTranslationSheet(paragraph: selectedParagraph, viewModel: progressViewModel)
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
    
    private func loadPDFAndStructuredText() {
        // 加载PDF URL
        if let pdfPath = article.pdfPath {
            pdfURL = URL(fileURLWithPath: pdfPath)
        }
        
        // 如果需要结构化文本，开始加载
        if displayMode == .text || displayMode == .hybrid {
            loadStructuredText()
        }
    }
    
    private func loadStructuredText() {
         guard structuredText == nil && !isLoadingStructuredText else { return }
         
         isLoadingStructuredText = true
         
         Task {
             // 如果有PDF URL，尝试从PDF提取结构化文本
             if let pdfURL = pdfURL {
                 let pdfService = PDFService(
            modelContext: modelContext,
            cacheManager: appCoordinator.getCacheManager(),
            errorHandler: appCoordinator.getErrorHandler()
        )
                 if let extractedText = pdfService.extractTextWithLayout(from: pdfURL) {
                     await MainActor.run {
                         structuredText = extractedText
                         isLoadingStructuredText = false
                     }
                     return
                 }
             }
             
             // 否则从文本内容生成简单的结构化文本
             try? await Task.sleep(nanoseconds: 1_000_000_000)
             
             await MainActor.run {
                 let paragraphs = article.content.components(separatedBy: "\n\n")
                 let elements = paragraphs.enumerated().map { index, paragraph in
                     TextElement(
                         content: paragraph,
                         type: index == 0 ? .title : .paragraph,
                         bounds: CGRect(x: 0, y: CGFloat(index * 50), width: 300, height: 40),
                         fontInfo: FontInfo(
                             size: index == 0 ? 18 : 16,
                             weight: index == 0 ? .bold : .regular,
                             isItalic: false,
                             isBold: index == 0
                         ),
                         level: index == 0 ? 1 : nil
                     )
                 }
                 
                 structuredText = StructuredText(
                     pages: [StructuredPage(
                         pageNumber: 1,
                         elements: elements,
                         bounds: CGRect(x: 0, y: 0, width: 300, height: CGFloat(elements.count * 50))
                     )],
                     metadata: TextMetadata(
                         totalPages: 1,
                         extractionDate: Date(),
                         sourceURL: pdfURL,
                         language: "en",
                         wordCount: article.content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                     )
                 )
                 isLoadingStructuredText = false
             }
         }
     }
    
    private func switchDisplayMode(to mode: DisplayMode) {
        displayMode = mode
        
        // 如果切换到需要结构化文本的模式，确保已加载
        if (mode == .text || mode == .hybrid) && structuredText == nil && !isLoadingStructuredText {
            loadStructuredText()
        }
    }
}

// MARK: - 单词定义弹窗

struct ArticleWordDefinitionSheet: View {
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

struct ArticleSentenceTranslationSheet: View {
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

struct ArticleParagraphTranslationSheet: View {
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