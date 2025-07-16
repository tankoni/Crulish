//
//  StructuredTextView.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI

struct StructuredTextView: View {
    let structuredText: StructuredText
    let article: Article
    @State private var selectedWord = ""
    @State private var selectedSentence = ""
    @State private var selectedParagraph = ""
    @State private var showingWordDefinition = false
    @State private var showingSentenceTranslation = false
    @State private var showingParagraphTranslation = false
    @State private var fontSize: CGFloat = 16
    @State private var lineSpacing: CGFloat = 6
    @State private var currentPage: Int = 1
    @State private var searchText = ""
    @State private var highlightedElements: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 文本工具栏
            TextToolbar(
                currentPage: $currentPage,
                totalPages: structuredText.pages.count,
                fontSize: $fontSize,
                lineSpacing: $lineSpacing,
                searchText: searchText,
                onSearch: performSearch,
                onPreviousPage: previousPage,
                onNextPage: nextPage
            )
            
            // 分页文本内容
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(Array(structuredText.pages.enumerated()), id: \.offset) { pageIndex, page in
                        if pageIndex + 1 == currentPage {
                            StructuredPageView(
                                page: page,
                                fontSize: fontSize,
                                lineSpacing: lineSpacing,
                                highlightedElements: highlightedElements,
                                onWordTap: handleWordTap,
                                onSentenceLongPress: handleSentenceLongPress,
                                onParagraphSelection: handleParagraphSelection
                            )
                            .transition(.slide)
                        }
                    }
                }
                .padding()
            }
            .animation(.easeInOut(duration: 0.3), value: currentPage)
        }
        .sheet(isPresented: $showingWordDefinition) {
            StructuredWordDefinitionSheet(
                word: selectedWord,
                onDismiss: { showingWordDefinition = false }
            )
        }
        .sheet(isPresented: $showingSentenceTranslation) {
            StructuredSentenceTranslationSheet(
            sentence: selectedSentence,
            onDismiss: { showingSentenceTranslation = false }
        )
        }
        .sheet(isPresented: $showingParagraphTranslation) {
            StructuredParagraphTranslationSheet(
            paragraph: selectedParagraph,
            onDismiss: { showingParagraphTranslation = false }
        )
        }
    }
    
    // MARK: - 事件处理
    private func handleWordTap(_ word: String) {
        selectedWord = word
        showingWordDefinition = true
        
        // 添加触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleSentenceLongPress(_ sentence: String) {
        selectedSentence = sentence
        showingSentenceTranslation = true
        
        // 添加触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func handleParagraphSelection(_ paragraph: String) {
        selectedParagraph = paragraph
        showingParagraphTranslation = true
    }
    
    private func previousPage() {
        if currentPage > 1 {
            withAnimation {
                currentPage -= 1
            }
        }
    }
    
    private func nextPage() {
        if currentPage < structuredText.pages.count {
            withAnimation {
                currentPage += 1
            }
        }
    }
    
    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            highlightedElements.removeAll()
            return
        }
        
        var foundElements: Set<String> = []
        
        for page in structuredText.pages {
            for element in page.elements {
                if element.content.localizedCaseInsensitiveContains(query) {
                    foundElements.insert(element.id.uuidString)
                }
            }
        }
        
        highlightedElements = foundElements
    }
}

// MARK: - 文本工具栏
struct TextToolbar: View {
    @Binding var currentPage: Int
    let totalPages: Int
    @Binding var fontSize: CGFloat
    @Binding var lineSpacing: CGFloat
    let searchText: String
    let onSearch: (String) -> Void
    let onPreviousPage: () -> Void
    let onNextPage: () -> Void
    
    @State private var localSearchText = ""
    @State private var showingSettings = false
    
    var body: some View {
        HStack {
            // 页面导航
            Button(action: onPreviousPage) {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .disabled(currentPage <= 1)
            
            Text("\(currentPage) / \(totalPages)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: onNextPage) {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .disabled(currentPage >= totalPages)
            
            Spacer()
            
            // 搜索框
            HStack {
                TextField("搜索...", text: $localSearchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        onSearch(localSearchText)
                    }
                
                Button(action: { onSearch(localSearchText) }) {
                    Image(systemName: "magnifyingglass")
                }
                .disabled(localSearchText.isEmpty)
            }
            .frame(maxWidth: 200)
            
            // 设置按钮
            Button(action: { showingSettings = true }) {
                Image(systemName: "textformat.size")
                    .font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(radius: 1)
        .sheet(isPresented: $showingSettings) {
            TextSettingsSheet(
                fontSize: $fontSize,
                lineSpacing: $lineSpacing
            )
        }
    }
}

// MARK: - 结构化页面视图
struct StructuredPageView: View {
    let page: StructuredPage
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let highlightedElements: Set<String>
    let onWordTap: (String) -> Void
    let onSentenceLongPress: (String) -> Void
    let onParagraphSelection: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(page.elements, id: \.id) { element in
                StructuredElementView(
                    element: element,
                    fontSize: fontSize,
                    lineSpacing: lineSpacing,
                    isHighlighted: highlightedElements.contains(element.id.uuidString),
                    onWordTap: onWordTap,
                    onSentenceLongPress: onSentenceLongPress,
                    onParagraphSelection: onParagraphSelection
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 结构化元素视图
struct StructuredElementView: View {
    let element: TextElement
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let isHighlighted: Bool
    let onWordTap: (String) -> Void
    let onSentenceLongPress: (String) -> Void
    let onParagraphSelection: (String) -> Void
    
    var body: some View {
        Text(element.content)
            .font(fontForElement)
            .foregroundColor(colorForElement)
            .lineSpacing(lineSpacing)
            .background(isHighlighted ? Color.yellow.opacity(0.3) : Color.clear)
            .onTapGesture {
                // 双击查词
                if let word = extractWordFromTap() {
                    onWordTap(word)
                }
            }
            .onLongPressGesture {
                // 长按翻译句子
                onSentenceLongPress(element.content)
            }
            .contextMenu {
                Button("翻译段落") {
                    onParagraphSelection(element.content)
                }
                Button("复制文本") {
                    UIPasteboard.general.string = element.content
                }
            }
    }
    
    private var fontForElement: Font {
        let baseSize = fontSize
        let weight = fontWeightForElement
        
        switch element.type {
        case .title:
            return .system(size: baseSize * 1.5, weight: weight)
        case .subtitle:
            return .system(size: baseSize * 1.1, weight: weight)
        case .paragraph, .list:
            return .system(size: baseSize, weight: weight)
        case .quote:
            return .system(size: baseSize * 0.9, weight: weight)
        case .other:
            return .system(size: baseSize, weight: weight)
        }
    }
    
    private var fontWeightForElement: Font.Weight {
        switch element.fontInfo.weight {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        }
    }
    
    private var colorForElement: Color {
        switch element.type {
        case .title:
            return .primary
        case .subtitle:
            return .primary
        case .paragraph, .list:
            return .primary
        case .quote:
            return .secondary
        case .other:
            return .primary
        }
    }
    
    private func extractWordFromTap() -> String? {
        // 简化的单词提取逻辑
        let words = element.content.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        return words.first { !$0.isEmpty }
    }
}

// MARK: - 文本设置表单
struct TextSettingsSheet: View {
    @Binding var fontSize: CGFloat
    @Binding var lineSpacing: CGFloat
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("字体设置") {
                    VStack {
                        HStack {
                            Text("字体大小")
                            Spacer()
                            Text("\(Int(fontSize))pt")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $fontSize, in: 12...24, step: 1)
                    }
                    
                    VStack {
                        HStack {
                            Text("行间距")
                            Spacer()
                            Text("\(Int(lineSpacing))pt")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $lineSpacing, in: 2...12, step: 1)
                    }
                }
                
                Section("预览") {
                    Text("这是一段示例文本，用于预览当前的字体设置效果。")
                        .font(.system(size: fontSize))
                        .lineSpacing(lineSpacing)
                }
            }
            .navigationTitle("文本设置")
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

// MARK: - Sheet组件
struct StructuredWordDefinitionSheet: View {
    let word: String
    let onDismiss: () -> Void
    @State private var definition = "加载中..."
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(word)
                    .font(.title)
                    .fontWeight(.bold)
                
                if isLoading {
                    SwiftUI.ProgressView("加载定义中...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text(definition)
                        .font(.body)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("词典")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onDismiss()
                    }
                }
            }
            .onAppear {
                loadDefinition()
            }
        }
    }
    
    private func loadDefinition() {
        // 模拟加载定义
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            definition = "\(word): 这里是单词的定义和解释..."
            isLoading = false
        }
    }
}

struct StructuredSentenceTranslationSheet: View {
    let sentence: String
    let onDismiss: () -> Void
    @State private var translation = "翻译中..."
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("原文")
                    .font(.headline)
                
                Text(sentence)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Text("翻译")
                    .font(.headline)
                
                if isLoading {
                    SwiftUI.ProgressView("翻译中...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text(translation)
                        .font(.body)
                        .padding()
                        .background(Color(.systemBlue).opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("句子翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onDismiss()
                    }
                }
            }
            .onAppear {
                loadTranslation()
            }
        }
    }
    
    private func loadTranslation() {
        // 模拟加载翻译
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            translation = "这里是句子的中文翻译..."
            isLoading = false
        }
    }
}

struct StructuredParagraphTranslationSheet: View {
    let paragraph: String
    let onDismiss: () -> Void
    @State private var translation = "翻译中..."
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("原文")
                        .font(.headline)
                    
                    Text(paragraph)
                        .font(.body)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Text("翻译")
                        .font(.headline)
                    
                    if isLoading {
                        SwiftUI.ProgressView("翻译中...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text(translation)
                            .font(.body)
                            .padding()
                            .background(Color(.systemBlue).opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("段落翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onDismiss()
                    }
                }
            }
            .onAppear {
                loadTranslation()
            }
        }
    }
    
    private func loadTranslation() {
        // 模拟加载翻译
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            translation = "这里是段落的中文翻译..."
            isLoading = false
        }
    }
}

// MARK: - 预览
struct StructuredTextView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleElement = TextElement(
            content: "这是一个示例段落，用于展示结构化文本的显示效果。",
            type: .paragraph,
            bounds: CGRect(x: 0, y: 0, width: 300, height: 50),
            fontInfo: FontInfo(size: 16, weight: .regular, isItalic: false, isBold: false),
            level: 0
        )
        
        let samplePage = StructuredPage(
            pageNumber: 1,
            elements: [sampleElement],
            bounds: CGRect(x: 0, y: 0, width: 400, height: 600)
        )
        
        let sampleStructuredText = StructuredText(
            pages: [samplePage],
            metadata: TextMetadata(
                totalPages: 1,
                extractionDate: Date(),
                sourceURL: nil,
                language: "zh",
                wordCount: 20
            )
        )
        
        StructuredTextView(
            structuredText: sampleStructuredText,
            article: Article(
                title: "示例文章",
                content: "示例内容",
                year: 2023,
                examType: "考研一",
                difficulty: .medium,
                topic: "阅读理解",
                imageName: "sample"
            )
        )
    }
}