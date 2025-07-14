//
//  ArticleReaderView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI

struct ArticleReaderView: View {
    @ObservedObject var viewModel: ReadingViewModel
    @State private var selectedWord: String?
    @State private var selectedSentence: String?
    @State private var selectedParagraph: String?
    @State private var showingWordDefinition = false
    @State private var showingSentenceTranslation = false
    @State private var showingParagraphTranslation = false
    @State private var scrollPosition: CGFloat = 0
    @State private var isShowingSettings = false
    @State private var readingStartTime = Date()
    @State private var isInitialized = false // 防止重复初始化
    @State private var lookupTask: Task<Void, Never>? // 查词任务
    
    /// 异步查词（带性能优化）
    private func lookupWord(_ word: String) {
        selectedWord = word
        
        // 取消之前的查词任务
        lookupTask?.cancel()
        
        // 创建新的查词任务
        lookupTask = Task {
            // 异步查找单词定义
            _ = await performWordLookup(word)
            
            // 在主线程更新UI
            await MainActor.run {
                if !Task.isCancelled {
                    self.showingWordDefinition = true
                }
            }
            
            // 异步记录查词行为（不阻塞UI）
            await recordWordLookupAsync(word: word)
        }
    }
    
    /// 异步执行单词查找
    private func performWordLookup(_ word: String) async -> String {
        // 模拟异步查词
        return "单词定义"
    }
    
    /// 异步记录查词行为
    private func recordWordLookupAsync(word: String) async {
        // 记录查词行为
    }
    
    private var article: Article? {
        viewModel.currentArticle
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if let article = article {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                // 文章标题
                                articleHeader(article)
                                
                                // 文章内容
                                articleContent(article)
                                
                                // 底部间距
                                Spacer(minLength: 100)
                            }
                            .padding(.horizontal, viewModel.settings.readingMargin)
                        }
                        .background(Color.from(string: viewModel.settings.backgroundColor))
                    }
                } else {
                    Text("未选择文章")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        viewModel.stopReading()
                    }) {
                        Image(systemName: "chevron.left")
                            .fontWeight(.medium)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            isShowingSettings = true
                        }) {
                            Image(systemName: "textformat")
                        }
                        
                        if let article = article {
                            Menu {
                                Button(action: {
                                    Task {
                                        await viewModel.toggleBookmark(article)
                                    }
                                }) {
                                    Label(
                                        article.isBookmarked ? "取消收藏" : "收藏文章",
                                        systemImage: article.isBookmarked ? "bookmark.fill" : "bookmark"
                                    )
                                }
                                
                                Button(action: {
                                    Task {
                                        await viewModel.markAsCompleted(article)
                                    }
                                }) {
                                    Label(
                                        article.isCompleted ? "标记为未完成" : "标记为已完成",
                                        systemImage: article.isCompleted ? "checkmark.circle" : "checkmark.circle.fill"
                                    )
                                }
                                
                                Button(action: {
                                    viewModel.shareArticle(article)
                                }) {
                                    Label("分享文章", systemImage: "square.and.arrow.up")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingWordDefinition) {
            if let word = selectedWord {
                WordDefinitionSheet(viewModel: viewModel, word: word)
            }
        }
        .sheet(isPresented: $showingSentenceTranslation) {
            if let sentence = selectedSentence {
                SentenceTranslationSheet(sentence: sentence)
            }
        }
        .sheet(isPresented: $showingParagraphTranslation) {
            if let paragraph = selectedParagraph {
                ParagraphTranslationSheet(paragraph: paragraph)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            ReadingSettingsSheet(viewModel: viewModel)
        }
        .onAppear {
            // 避免重复初始化
            if !isInitialized {
                readingStartTime = Date()
                isInitialized = true
            }
        }
        .onDisappear {
            if article != nil {
                let readingTime = Date().timeIntervalSince(readingStartTime)
                viewModel.addReadingTime(readingTime / 60.0)
            }
        }
    }
    
    // MARK: - 文章标题
    
    private func articleHeader(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 文章元信息
            HStack {
                Text("\(article.year)年")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(article.examType)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(article.difficulty.displayName)
                    .font(.caption)
                    .foregroundColor(article.difficulty.color)
                
                Spacer()
                
                Text("\(article.wordCount)词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 文章标题
            Text(article.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(nil)
            
            // 阅读进度
            if article.readingProgress > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("阅读进度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(article.readingProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    SwiftUI.ProgressView(value: article.readingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
            
            Divider()
        }
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - 文章内容
    
    private func articleContent(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: viewModel.settings.paragraphSpacing) {
            ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                paragraphView(paragraph, index: index)
            }
        }
    }
    
    private func paragraphView(_ paragraph: ArticleParagraph, index: Int) -> some View {
        VStack(alignment: .leading, spacing: viewModel.settings.lineSpacing) {
            ForEach(Array(paragraph.sentences.enumerated()), id: \.offset) { sentenceIndex, sentence in
                sentenceView(sentence.text, paragraphIndex: index, sentenceIndex: sentenceIndex)
            }
        }
        .onTapGesture {
            selectedParagraph = paragraph.text
            showingParagraphTranslation = true
        }
    }
    
    private func sentenceView(_ sentence: String, paragraphIndex: Int, sentenceIndex: Int) -> some View {
        Text(attributedSentence(sentence))
            .font(.system(size: viewModel.settings.fontSize, design: .default))
            .lineSpacing(viewModel.settings.lineSpacing)
            .foregroundColor(Color.from(string: viewModel.settings.textColor))
            .textSelection(.enabled)
            .onTapGesture {
                selectedSentence = sentence
                showingSentenceTranslation = true
            }
    }
    
    private func attributedSentence(_ sentence: String) -> AttributedString {
        var attributedString = AttributedString(sentence)
        
        // 分词并添加点击事件
        let words = viewModel.textProcessor.tokenize(sentence)
        var currentIndex = attributedString.startIndex
        
        for word in words {
            if let range = attributedString[currentIndex...].range(of: word) {
                // 检查是否为单词（非标点符号）
                if word.rangeOfCharacter(from: .letters) != nil {
                    attributedString[range].foregroundColor = Color.from(string: viewModel.settings.linkColor)
                    attributedString[range].underlineStyle = .single
                    // Note: underlineColor is not available in AttributedString on all platforms
                    // attributedString[range].underlineColor = Color(viewModel.settings.linkColor).opacity(0.3)
                }
                currentIndex = range.upperBound
            }
        }
        
        return attributedString
    }
}

// MARK: - 单词定义弹窗

struct WordDefinitionSheet: View {
    @ObservedObject var viewModel: ReadingViewModel
    @Environment(\.dismiss) private var dismiss
    let word: String
    @State private var definitions: [DictionaryWord] = []
    @State private var selectedDefinition: WordDefinition?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    SwiftUI.ProgressView("查找释义...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if definitions.isEmpty {
                    emptyStateView
                } else {
                    definitionsList
                }
            }
            .navigationTitle(word)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadDefinitions()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("未找到释义")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("词典中没有找到 \"\(word)\" 的释义")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("添加到生词本") {
                viewModel.addUnknownWord(word)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var definitionsList: some View {
        List {
            ForEach(definitions) { dictWord in
                ForEach(dictWord.definitions, id: \.id) { definition in
                    DefinitionRow(
                        definition: definition,
                        isSelected: selectedDefinition?.id == definition.id
                    ) {
                        selectedDefinition = definition
                        viewModel.recordWordLookup(
                            word: dictWord.word,
                            definition: definition,
                            context: viewModel.currentReadingContext
                        )
                        dismiss()
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    @MainActor
    private func loadDefinitions() {
        Task {
            let results = await viewModel.lookupWord(word)
            await MainActor.run {
                definitions = results
                isLoading = false
            }
        }
    }
}

struct DefinitionRow: View {
    let definition: WordDefinition
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(definition.partOfSpeech.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(definition.partOfSpeech.color))
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                Text(definition.meaning)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if let englishMeaning = definition.englishMeaning, !englishMeaning.isEmpty {
                    Text(englishMeaning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                if !definition.examples.isEmpty {
                    Text(definition.examples.first ?? "")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 句子翻译弹窗

struct SentenceTranslationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sentence: String
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
    @ObservedObject var viewModel: ReadingViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("字体设置") {
                    HStack {
                        Text("字体大小")
                        Spacer()
                        Text("\(Int(viewModel.settings.fontSize))")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { viewModel.settings.fontSize },
                            set: { viewModel.settings.fontSize = $0 }
                        ),
                        in: 12...24,
                        step: 1
                    )
                    
                    HStack {
                        Text("行间距")
                        Spacer()
                        Text("\(Int(viewModel.settings.lineSpacing))")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { viewModel.settings.lineSpacing },
                            set: { viewModel.settings.lineSpacing = $0 }
                        ),
                        in: 4...12,
                        step: 1
                    )
                }
                
                Section("主题设置") {
                    Picker("主题", selection: Binding(
                        get: { 
                            AppColorScheme(rawValue: viewModel.settings.colorScheme) ?? .auto
                        },
                        set: { 
                            viewModel.settings.colorScheme = $0.rawValue
                        }
                    )) {
                        ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                            Text(scheme.displayName).tag(scheme)
                        }
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
    let mockArticleService = MockArticleService()
    let mockUserProgressService = MockUserProgressService()
    let mockDictionaryService = MockDictionaryService()
    let mockTextProcessor = TextProcessor()
    let mockErrorHandler = MockErrorHandler()
    
    let viewModel = ReadingViewModel(
        articleService: mockArticleService,
        userProgressService: mockUserProgressService,
        dictionaryService: mockDictionaryService,
        textProcessor: mockTextProcessor,
        errorHandler: mockErrorHandler
    )
    
    ArticleReaderView(viewModel: viewModel)
}