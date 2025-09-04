//
//  ContinuousTextView.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI

struct ContinuousTextView: View {
    let structuredText: StructuredText
    let article: Article
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let onWordTap: (String) -> Void
    let onSentenceLongPress: (String) -> Void
    
    @EnvironmentObject private var wordInteractionCoordinator: WordInteractionCoordinator
    @State private var scrollPosition: CGFloat = 0
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: lineSpacing * 2) {
                    ForEach(Array(structuredText.pages.enumerated()), id: \.offset) { pageIndex, page in
                        PageContentView(
                            page: page,
                            pageIndex: pageIndex,
                            fontSize: fontSize,
                            lineSpacing: lineSpacing,
                            onWordTap: onWordTap,
                            onSentenceLongPress: onSentenceLongPress
                        )
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemBackground))
            .onAppear {
                scrollToSavedPosition(proxy: proxy)
            }
        }
    }
    
    private func scrollToSavedPosition(proxy: ScrollViewProxy) {
        let savedPosition = article.readingProgress
        if savedPosition > 0 {
            let pageIndex = Int(savedPosition * Double(structuredText.pages.count))
            withAnimation(.easeInOut(duration: 0.5)) {
                proxy.scrollTo("page_\(pageIndex)", anchor: UnitPoint.top)
            }
        }
    }
}

// MARK: - PageContentView
struct PageContentView: View {
    let page: StructuredPage
    let pageIndex: Int
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let onWordTap: (String) -> Void
    let onSentenceLongPress: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            // 页码标识
            HStack {
                Text("第 \(pageIndex + 1) 页")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
                Spacer()
            }
            .padding(.bottom, lineSpacing)
            .id("page_\(pageIndex)")
            
            // 页面内容
            ForEach(page.elements, id: \.id) { element in
                ContinuousTextElement(
                    element: element,
                    fontSize: fontSize,
                    lineSpacing: lineSpacing,
                    onWordTap: onWordTap,
                    onSentenceLongPress: onSentenceLongPress
                )
                .id(element.id)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, lineSpacing * 3)
    }
}

// MARK: - ContinuousTextElement
struct ContinuousTextElement: View {
    let element: TextElement
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let onWordTap: (String) -> Void
    let onSentenceLongPress: (String) -> Void
    
    @EnvironmentObject private var wordInteractionCoordinator: WordInteractionCoordinator
    @State private var selectedText: String = ""
    @State private var showingContextMenu = false
    
    private var textProcessor: TextProcessor {
        TextProcessor()
    }
    
    var body: some View {
        Text(element.content)
            .font(fontForElement)
            .foregroundColor(colorForElement)
            .lineSpacing(adjustedLineSpacing)
            .multilineTextAlignment(textAlignmentForElement)
            .frame(maxWidth: .infinity, alignment: frameAlignmentForElement)
            .padding(paddingForElement)
            .background(backgroundForElement)
            .onTapGesture { location in
                handleTapGesture(at: location)
            }
            .onLongPressGesture {
                handleLongPressGesture()
            }
            .contextMenu {
                contextMenuItems
            }
    }
    
    private var fontForElement: Font {
        let weight: Font.Weight
        switch element.type {
        case .title: weight = .bold
        case .subtitle: weight = .semibold
        case .paragraph: weight = .regular
        case .list: weight = .regular
        case .quote: weight = .medium
        case .other: weight = .light
        }
        return .system(size: fontSize, weight: weight, design: .default)
    }
    
    private var colorForElement: Color {
        switch element.type {
        case .title: return .primary
        case .subtitle: return .primary
        case .paragraph: return .primary
        case .list: return .primary
        case .quote: return .secondary
        case .other: return .secondary
        }
    }
    
    private var adjustedLineSpacing: CGFloat {
        switch element.type {
        case .title: return lineSpacing * 1.5
        case .subtitle: return lineSpacing * 1.2
        case .paragraph: return lineSpacing
        case .list: return lineSpacing * 0.9
        case .quote: return lineSpacing * 1.1
        case .other: return lineSpacing * 0.8
        }
    }
    
    private var textAlignmentForElement: SwiftUI.TextAlignment {
        switch element.type {
        case .title: return .center
        case .subtitle: return .leading
        case .paragraph: return .leading
        case .list: return .leading
        case .quote: return .leading
        case .other: return .leading
        }
    }
    
    private var frameAlignmentForElement: Alignment {
        switch element.type {
        case .title: return .center
        case .subtitle: return .leading
        case .paragraph: return .leading
        case .list: return .leading
        case .quote: return .leading
        case .other: return .leading
        }
    }
    
    private var paddingForElement: SwiftUI.EdgeInsets {
        switch element.type {
        case .title: return SwiftUI.EdgeInsets(top: lineSpacing * 2, leading: 0, bottom: lineSpacing * 2, trailing: 0)
        case .subtitle: return SwiftUI.EdgeInsets(top: lineSpacing * 1.5, leading: 0, bottom: lineSpacing, trailing: 0)
        case .paragraph: return SwiftUI.EdgeInsets(top: lineSpacing * 0.5, leading: 0, bottom: lineSpacing * 0.5, trailing: 0)
        case .list: return SwiftUI.EdgeInsets(top: lineSpacing * 0.4, leading: lineSpacing, bottom: lineSpacing * 0.4, trailing: 0)
        case .quote: return SwiftUI.EdgeInsets(top: lineSpacing * 0.6, leading: lineSpacing * 2, bottom: lineSpacing * 0.6, trailing: lineSpacing)
        case .other: return SwiftUI.EdgeInsets(top: lineSpacing * 0.3, leading: 0, bottom: lineSpacing * 0.3, trailing: 0)
        }
    }
    
    private var backgroundForElement: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(highlightColor)
            .opacity(isHighlighted ? 0.3 : 0)
    }
    
    private var highlightColor: Color {
        switch wordInteractionCoordinator.currentTranslationMode {
        case .word: return .yellow
        case .sentence: return .blue
        }
    }
    
    private var isHighlighted: Bool {
        // 简化高亮逻辑，移除对不存在的selectedSentence属性的依赖
        wordInteractionCoordinator.currentTranslationMode == .sentence &&
        selectedText == element.content
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button("翻译句子") {
            let sentence = selectedText.isEmpty ? 
                textProcessor.splitIntoSentences(element.content).first ?? element.content :
                selectedText
            onSentenceLongPress(sentence)
        }
        
        Button("翻译段落") {
            onSentenceLongPress(element.content)
        }
        
        if !selectedText.isEmpty {
            Button("查词典") {
                onWordTap(selectedText)
            }
        }
    }
    
    private func handleTapGesture(at location: CGPoint) {
        // 提取点击位置的单词
        if let word = extractWordFromTap(at: location) {
            onWordTap(word)
        }
    }
    
    private func handleLongPressGesture() {
        // 长按翻译整个元素
        onSentenceLongPress(element.content)
    }
    
    private func extractWordFromTap(at location: CGPoint) -> String? {
        // 简化的单词提取逻辑
        let words = element.content.components(separatedBy: .whitespacesAndNewlines)
        let estimatedCharacterWidth: CGFloat = fontSize * 0.5
        let clickPosition = Int(location.x / estimatedCharacterWidth)
        
        var currentPosition = 0
        for word in words {
            let wordLength = word.count
            if clickPosition >= currentPosition && clickPosition <= currentPosition + wordLength {
                return word.trimmingCharacters(in: .punctuationCharacters)
            }
            currentPosition += wordLength + 1 // +1 for space
        }
        
        return words.first
    }
}

#Preview {
    let sampleElement = TextElement(
        content: "这是一个示例段落，用于展示连续滚动模式的显示效果。用户可以连续滚动阅读所有页面的内容。",
        type: .paragraph,
        bounds: CGRect(x: 0, y: 0, width: 300, height: 50),
        fontInfo: FontInfo(size: 16, weight: .regular, isItalic: false, isBold: false),
        level: nil
    )
    
    let samplePage = StructuredPage(
        pageNumber: 1,
        elements: [sampleElement],
        bounds: CGRect(x: 0, y: 0, width: 400, height: 600)
    )
    
    let sampleStructuredText = StructuredText(
        pages: [samplePage, samplePage], // 重复页面用于演示
        metadata: TextMetadata(
            totalPages: 2,
            extractionDate: Date(),
            sourceURL: nil,
            language: "zh",
            wordCount: 40
        )
    )
    
    ContinuousTextView(
        structuredText: sampleStructuredText,
        article: Article(
            title: "示例文章",
            content: "示例内容",
            year: 2023,
            examType: "考研一",
            difficulty: .medium,
            topic: "阅读理解",
            imageName: "sample"
        ),
        fontSize: 16,
        lineSpacing: 6,
        onWordTap: { word in print("Word tapped: \(word)") },
        onSentenceLongPress: { sentence in print("Sentence long pressed: \(sentence)") }
    )
    .environmentObject(WordInteractionCoordinator(
        dictionaryService: MockDictionaryService(),
        translationService: MockTranslationService()
    ))
}