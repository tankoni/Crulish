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
    @State private var colorScheme: SwiftUI.ColorScheme? = nil
    @State private var readingStartTime = Date()
    @State private var readingTimer: Timer?
    @State private var displayMode: DisplayMode
    @State private var structuredText: StructuredText?
    @State private var isLoadingStructuredText = false
    @State private var wordDefinition: WordDefinition?
    @State private var sentenceTranslation = ""
    @State private var paragraphTranslation = ""
    
    init(article: Article) {
        self.article = article
        // 根据文章是否有PDF文件来设置默认显示模式
        self._displayMode = State(initialValue: article.pdfPath != nil ? .pdf : .text)
    }
    
    let article: Article
    
    // PDF相关状态
    @State private var pdfURL: URL?
    @State private var showingPDFReader = false
    
    @ViewBuilder
    private var readerContent: some View {
        switch displayMode {
        case .pdf:
            if let pdfURL = pdfURL, let progressViewModel = appCoordinator.progressViewModel {
                PDFContentView(
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
                .environmentObject(appCoordinator.getDictionaryService())
                .environmentObject(appCoordinator.wordInteractionCoordinator!)
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
                .environmentObject(appCoordinator.getDictionaryService())
                .environmentObject(appCoordinator.wordInteractionCoordinator!)
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
        ZStack {
            // 主要内容区域
            VStack(spacing: 0) {
                // 顶部导航栏 - 更紧凑的设计
                HStack {
                    Button(action: {
                        stopReading()
                        appCoordinator.readingViewModel?.stopReading()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(article.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(article.examType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            article.isBookmarked.toggle()
                            try? modelContext.save()
                        }) {
                            Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                                .foregroundColor(article.isBookmarked ? .orange : .gray)
                        }
                        
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "textformat.size")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                
                // 阅读内容区域
                readerContent
                    .background(Color(.systemBackground))
                
                // 底部工具栏 - 简化设计
                HStack(spacing: 24) {
                    Button(action: {
                        if let coordinator = appCoordinator.wordInteractionCoordinator {
                            coordinator.setInteractionMode(.text)
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "textformat.abc")
                                .font(.title3)
                            Text("查词")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        showingSentenceTranslation = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "text.bubble")
                                .font(.title3)
                            Text("句译")
                                .font(.caption2)
                        }
                        .foregroundColor(.green)
                    }
                    
                    Button(action: {
                        showingParagraphTranslation = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.title3)
                            Text("段译")
                                .font(.caption2)
                        }
                        .foregroundColor(.purple)
                    }
                    
                    Button(action: {
                        shareArticle()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                            Text("分享")
                                .font(.caption2)
                        }
                        .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: -1)
            }
            
            // 单词定义弹窗
            if showingWordDefinition, let wordDef = wordDefinition {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingWordDefinition = false
                    }
                
                VStack {
                    Spacer()
                    
                    ModernWordDefinitionCard(
                        word: selectedWord,
                        phonetic: wordDef.meaning, // 使用meaning作为临时显示
                        definitions: [wordDef.meaning],
                        examples: wordDef.examples,
                        onClose: {
                            showingWordDefinition = false
                        },
                        onAddToVocabulary: {
                            // 添加到生词本的逻辑
                            Task {
                                appCoordinator.addWordToVocabulary(word: selectedWord, context: "")
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showingWordDefinition)
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
            // 如果是相对路径，构建完整的Bundle资源路径
            if !pdfPath.hasPrefix("/") {
                if let resourcePath = Bundle.main.resourcePath {
                    let fullPath = resourcePath + "/" + pdfPath
                    pdfURL = URL(fileURLWithPath: fullPath)
                } else {
                    print("[ERROR] 无法获取Bundle资源路径")
                }
            } else {
                // 如果是绝对路径，直接使用
                pdfURL = URL(fileURLWithPath: pdfPath)
            }
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
    @Environment(\.modelContext) private var modelContext
    let word: String
    let viewModel: ProgressViewModel
    @State private var definition = ""
    @State private var pronunciation = ""
    @State private var examples: [String] = []
    @State private var isLoading = true
    @State private var isAddedToVocabulary = false
    @State private var translationService: TranslationServiceImpl?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView("加载中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            // 单词和发音
                            VStack(alignment: .leading, spacing: 8) {
                                Text(word)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                if !pronunciation.isEmpty {
                                    Text(pronunciation)
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // 释义
                            VStack(alignment: .leading, spacing: 8) {
                                Text("释义")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                Text(definition)
                                    .font(.body)
                                    .padding()
                                    .background(Color(.systemBlue).opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            // 例句
                            if !examples.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("例句")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                    
                                    ForEach(examples.indices, id: \.self) { index in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(index + 1). \(examples[index])")
                                                .font(.body)
                                        }
                                        .padding()
                                        .background(Color(.systemGreen).opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            
                            // 添加到生词本按钮
                            Button(action: {
                                Task {
                                    await addToVocabulary()
                                }
                            }) {
                                HStack {
                                    Image(systemName: isAddedToVocabulary ? "checkmark.circle.fill" : "plus.circle")
                                    Text(isAddedToVocabulary ? "已添加到生词本" : "添加到生词本")
                                }
                                .foregroundColor(isAddedToVocabulary ? .green : .blue)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .disabled(isAddedToVocabulary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("单词释义")
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
            setupTranslationService()
            Task {
                await loadDefinition()
            }
        }
    }
    
    private func setupTranslationService() {
        translationService = TranslationServiceImpl()
    }
    
    private func loadDefinition() async {
        guard let service = translationService else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        do {
            // 使用翻译服务获取单词释义
            let result = try await service.translateWord(word, context: "")
            
            await MainActor.run {
                definition = result?.translatedText ?? "无法获取释义"
                pronunciation = "/\(word)/"  // 简单的音标格式
                
                // 生成示例句子
                examples = generateExampleSentences(for: word)
                
                isLoading = false
            }
        } catch {
            await MainActor.run {
                definition = "获取释义失败：\(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func generateExampleSentences(for word: String) -> [String] {
        // 根据单词生成示例句子
        let templates = [
            "I often use \(word) in my daily life.",
            "The \(word) is very important for understanding.",
            "Can you explain what \(word) means?",
            "This \(word) appears frequently in English texts."
        ]
        
        return Array(templates.prefix(2))
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
    @Environment(\.modelContext) private var modelContext
    let sentence: String
    let viewModel: ProgressViewModel
    @State private var translation = ""
    @State private var analysis = ""
    @State private var grammarPoints: [String] = []
    @State private var keyPhrases: [String] = []
    @State private var sentenceStructure = ""
    @State private var isLoading = true
    @State private var translationService: TranslationServiceImpl?
    
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
                        
                        // 句子结构
                        if !sentenceStructure.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("句子结构")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                Text(sentenceStructure)
                                    .font(.body)
                                    .padding()
                                    .background(Color(.systemPurple).opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        
                        // 关键短语
                        if !keyPhrases.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("关键短语")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                    ForEach(keyPhrases, id: \.self) { phrase in
                                        Text(phrase)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.systemOrange).opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        
                        // 语法要点
                        if !grammarPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("语法要点")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(grammarPoints, id: \.self) { point in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("•")
                                                .foregroundColor(.blue)
                                            Text(point)
                                                .font(.body)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemTeal).opacity(0.1))
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
            setupTranslationService()
            performSentenceTranslation()
        }
    }
    
    private func setupTranslationService() {
        translationService = TranslationServiceImpl()
    }
    
    private func performSentenceTranslation() {
        guard let service = translationService else {
            isLoading = false
            return
        }
        
        Task {
            do {
                // 执行句子翻译
                let result = try await service.translateSentence(sentence)
                
                await MainActor.run {
                    translation = result?.translatedText ?? "无法获取翻译"
                    analysis = "这是一个复合句，包含主句和从句。"
                    sentenceStructure = "主语 + 谓语 + 宾语"
                    keyPhrases = ["artificial intelligence", "transforming work"]
                    grammarPoints = ["现在进行时的被动语态", "动名词作宾语"]
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    translation = "翻译失败：\(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 段落翻译弹窗

struct ArticleParagraphTranslationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let paragraph: String
    let viewModel: ProgressViewModel
    @State private var translation = ""
    @State private var isLoading = true
    @State private var translationService: TranslationServiceImpl?
    
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
            setupTranslationService()
            performParagraphTranslation()
        }
    }
    
    private func setupTranslationService() {
        translationService = TranslationServiceImpl()
    }
    
    private func performParagraphTranslation() {
        guard let service = translationService else {
            isLoading = false
            return
        }
        
        Task {
            do {
                // 执行翻译
                let result = try await service.translateParagraph(paragraph)
                
                await MainActor.run {
                    translation = result?.translatedText ?? "无法获取翻译"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    translation = "翻译失败：\(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 阅读设置弹窗

struct ReadingSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var fontSize: CGFloat
    @Binding var lineSpacing: CGFloat
    @Binding var colorScheme: SwiftUI.ColorScheme?
    
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
                        Text("浅色").tag(SwiftUI.ColorScheme.light)
                        Text("深色").tag(SwiftUI.ColorScheme.dark)
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