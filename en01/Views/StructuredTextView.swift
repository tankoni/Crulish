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
    @EnvironmentObject private var dictionaryService: DictionaryService
    @EnvironmentObject private var wordInteractionCoordinator: WordInteractionCoordinator
    @EnvironmentObject private var textProcessor: TextProcessor
    @State private var selectedSentence = ""
    @State private var selectedParagraph = ""
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
                    ForEach(Array(structuredText.pages.enumerated()), id: \.0) { pageIndex, page in
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
        .sheet(isPresented: $wordInteractionCoordinator.showDetailedSheet) {
            DetailedWordDefinitionView(
                word: wordInteractionCoordinator.selectedWord,
                onDismiss: {
                    wordInteractionCoordinator.hideDetailedSheet()
                }
            )
            .environmentObject(dictionaryService)
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
        .overlay(
            // 轻量级单词提示tooltip - 只在顶层显示一次
            Group {
                if wordInteractionCoordinator.showTooltip {
                    WordTooltipView(
                        word: wordInteractionCoordinator.selectedWord,
                        isLoading: wordInteractionCoordinator.isLoading,
                        phonetic: wordInteractionCoordinator.simplePhonetic,
                        definition: wordInteractionCoordinator.simpleDefinition,
                        wordPosition: wordInteractionCoordinator.selectedWordPosition,
                        onViewMore: {
                            wordInteractionCoordinator.showDetailedDefinition()
                        },
                        onDismiss: {
                            wordInteractionCoordinator.hideTooltip()
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.2), value: wordInteractionCoordinator.showTooltip)
                }
            }
        )
    }
    
    // MARK: - 事件处理
    private func handleWordTap(_ word: String) {
        wordInteractionCoordinator.handleWordTap(word, at: .zero)
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
import SwiftUI

// Add import for DictionaryService if needed
// Assuming it's accessible via environment or global

struct StructuredElementView: View {
    let element: TextElement
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let isHighlighted: Bool
    let onWordTap: (String) -> Void
    let onSentenceLongPress: (String) -> Void
    let onParagraphSelection: (String) -> Void
    
    @EnvironmentObject private var wordInteractionCoordinator: WordInteractionCoordinator
    @EnvironmentObject private var dictionaryService: DictionaryService
    @EnvironmentObject private var textProcessor: TextProcessor
    
    var body: some View {
        Text(element.content)
            .font(fontForElement)
            .foregroundColor(colorForElement)
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHighlighted ? Color.yellow.opacity(0.3) : Color.clear)
            .onTapGesture { location in
                // 使用TextProcessor精确提取单词
                if let word = extractWordFromTap(at: location) {
                    // 验证是否为有效单词（避免点击标题、数字等）
                    if isValidWord(word) {
                        wordInteractionCoordinator.handleWordTap(word, at: location)
                    }
                }
            }
            .onLongPressGesture {
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
            // 移除overlay，WordTooltipView将在StructuredTextView顶层显示
    }

    
    private func extractWords(from text: String) -> [String] {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
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
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
    
    private var colorForElement: Color {
        switch element.type {
        case .title, .subtitle, .paragraph, .list: return .primary
        case .quote: return .secondary
        case .other: return .primary
        }
    }
    
    private func extractWordFromTap(at location: CGPoint) -> String? {
        // 使用TextProcessor提取单词
        let words = textProcessor.extractWords(element.content)
        
        // 如果只有一个单词，直接返回
        if words.count == 1 {
            return words.first
        }
        
        // 根据点击位置智能选择单词
        return selectWordByPosition(words: words, tapLocation: location)
    }
    
    /// 根据点击位置智能选择单词
    private func selectWordByPosition(words: [String], tapLocation: CGPoint) -> String? {
        // 如果没有单词，返回nil
        guard !words.isEmpty else { return nil }
        
        // 创建一个临时的Text视图来测量单词位置
        let content = element.content
        let wordsInContent = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // 估算每个单词的位置
        var currentX: CGFloat = 0
        let lineHeight: CGFloat = 20 // 估算行高
        let spaceWidth: CGFloat = 6 // 估算空格宽度
        
        for (index, wordInContent) in wordsInContent.enumerated() {
            let cleanWord = textProcessor.cleanWord(wordInContent)
            
            // 估算单词宽度（简化计算）
            let wordWidth = CGFloat(cleanWord.count) * 8 // 每个字符约8点宽度
            
            // 检查点击位置是否在这个单词范围内
            if tapLocation.x >= currentX && tapLocation.x <= currentX + wordWidth {
                // 验证这个单词是否在提取的有效单词列表中
                if words.contains(cleanWord) && isValidWord(cleanWord) {
                    return cleanWord
                }
            }
            
            currentX += wordWidth + spaceWidth
        }
        
        // 如果无法精确匹配，返回第一个有效单词
        return words.first { word in
            word.count > 1 && !word.isEmpty && isValidWord(word)
        }
    }
    
    /// 验证是否为有效的可查词单词
    private func isValidWord(_ word: String) -> Bool {
        let cleanedWord = textProcessor.cleanWord(word)
        
        // 检查是否为空或太短
        guard !cleanedWord.isEmpty && cleanedWord.count > 1 else {
            return false
        }
        
        // 检查是否包含字母
        guard cleanedWord.rangeOfCharacter(from: CharacterSet.letters) != nil else {
            return false
        }
        
        // 检查是否包含中文字符
        let chineseCharacterSet = CharacterSet(charactersIn: "\u{4e00}-\u{9fff}")
        if cleanedWord.rangeOfCharacter(from: chineseCharacterSet) != nil {
            return false
        }
        
        // 检查是否为纯数字
        if cleanedWord.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil &&
           cleanedWord.rangeOfCharacter(from: CharacterSet.letters) == nil {
            return false
        }
        
        // 检查是否只包含英文字符
        let nonEnglishCount = cleanedWord.filter { char in
            !char.isASCII || (!char.isLetter && !char.isNumber)
        }.count
        if nonEnglishCount > 0 {
            return false
        }
        
        // 检查是否为标题类型的元素（通常不需要查词）
        if element.type == .title || element.type == .subtitle {
            return false
        }
        
        return true
    }
}

// MARK: - 轻量级单词提示视图
struct WordTooltipView: View {
    let word: String
    let isLoading: Bool
    let phonetic: String?
    let definition: String
    let wordPosition: CGPoint
    let onViewMore: () -> Void
    let onDismiss: () -> Void
    
    @State private var tooltipFrame: CGRect = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 透明背景，点击关闭tooltip
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onDismiss()
                    }
                
                // Tooltip内容 - 按照原型图样式
                VStack(alignment: .leading, spacing: 8) {
                    // 单词和词性
                    HStack(spacing: 8) {
                        Text(word)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                        
                        // 词性标签
                        Text("n.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue)
                            )
                        
                        Spacer()
                    }
                    
                    // 释义
                    if isLoading {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("加载中...")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text(definition.isEmpty ? "未找到释义" : definition)
                            .font(.system(size: 13))
                            .foregroundColor(.black)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // 查看详细按钮
                    Button(action: onViewMore) {
                        Text("查看详细")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(12)
                .frame(minWidth: 180, maxWidth: 280)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
                .position(
                    x: calculateTooltipX(geometry: geometry),
                    y: calculateTooltipY(geometry: geometry)
                )
                .onTapGesture {
                    // 点击tooltip内部不关闭
                }
            }
        }
        .allowsHitTesting(true)
    }
    
    private func calculateTooltipX(geometry: GeometryProxy) -> CGFloat {
        let screenWidth = geometry.size.width
        let tooltipWidth: CGFloat = 250 // 估算tooltip宽度
        let padding: CGFloat = 20
        
        // 基于单词位置计算tooltip位置
        var x = wordPosition.x
        
        // 确保不超出屏幕边界
        if x - tooltipWidth/2 < padding {
            x = padding + tooltipWidth/2
        } else if x + tooltipWidth/2 > screenWidth - padding {
            x = screenWidth - padding - tooltipWidth/2
        }
        
        return x
    }
    
    private func calculateTooltipY(geometry: GeometryProxy) -> CGFloat {
        let tooltipHeight: CGFloat = 120 // 估算tooltip高度
        let padding: CGFloat = 10
        
        // 基于单词位置，优先显示在单词上方
        var y = wordPosition.y - tooltipHeight/2 - 20
        
        // 如果上方空间不够，显示在下方
        if y < tooltipHeight/2 + padding {
            y = wordPosition.y + tooltipHeight/2 + 20
        }
        
        // 确保不超出下边界
        if y + tooltipHeight/2 > geometry.size.height - padding {
            y = geometry.size.height - padding - tooltipHeight/2
        }
        
        return y
    }
}

// MARK: - 自定义单词文本视图
struct WordTextView: View {
    let word: String
    let font: Font
    let color: Color
    let isHighlighted: Bool
    let isSelected: Bool
    let onTap: (CGPoint) -> Void
    
    var body: some View {
        Text(word)
            .font(font)
            .foregroundColor(isSelected ? .blue : color)
            .padding(.horizontal, isSelected ? 4 : 0)
            .padding(.vertical, isSelected ? 2 : 0)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.1))
                    } else if isHighlighted {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.yellow.opacity(0.3))
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                // 添加底部虚线边框，类似原型图
                isSelected ? 
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.blue)
                    .offset(y: 8)
                : nil
            )
            .background(
                 GeometryReader { geometry in
                     Color.clear
                         .onTapGesture {
                             let globalPosition = geometry.frame(in: .global)
                             let tapPosition = CGPoint(
                                 x: globalPosition.midX,
                                 y: globalPosition.midY
                             )
                             onTap(tapPosition)
                         }
                 }
             )
    }
}

// MARK: - 自定义流动布局
struct WordFlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: Content
    
    init(
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        // 使用简单的文本换行布局
        VStack(alignment: alignment, spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
// StructuredWordDefinitionSheet 已被 DetailedWordDefinitionView 替换

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