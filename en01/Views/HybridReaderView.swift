//
//  HybridReaderView.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI
import PDFKit

struct HybridReaderView: View {
    let pdfURL: URL
    let structuredText: StructuredText
    let article: Article
    let viewModel: ProgressViewModel
    
    @State private var hybridMode: HybridDisplayMode = .sideBySide
    @State private var currentPage: Int = 1
    @State private var syncScrolling: Bool = true
    @State private var showingSettings = false
    @State private var selectedWord = ""
    @State private var selectedSentence = ""
    @State private var showingWordDefinition = false
    @State private var showingSentenceTranslation = false
    @State private var splitRatio: CGFloat = 0.5
    @State private var fontSize: CGFloat = 16
    @State private var lineSpacing: CGFloat = 6
    
    var body: some View {
            VStack(spacing: 0) {
                // 混合模式工具栏
                HybridToolbar(
                    hybridMode: $hybridMode,
                    currentPage: $currentPage,
                    totalPages: max(structuredText.pages.count, 1),
                    syncScrolling: $syncScrolling,
                    onSettingsTap: { showingSettings = true },
                    onPreviousPage: previousPage,
                    onNextPage: nextPage
                )
            
            // 混合内容视图
            GeometryReader { geometry in
                switch hybridMode {
                case .sideBySide:
                    HStack(spacing: 0) {
                        // PDF视图
                        PDFContentView(
                            pdfURL: pdfURL,
                            article: article,
                            viewModel: viewModel
                        )
                        .frame(width: geometry.size.width * splitRatio)
                        
                        // 分割线
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 1)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newRatio = (value.location.x) / geometry.size.width
                                        splitRatio = max(0.2, min(0.8, newRatio))
                                    }
                            )
                        
                        // 结构化文本视图
                        StructuredTextView(
                            structuredText: structuredText,
                            article: article
                        )
                        .frame(width: geometry.size.width * (1 - splitRatio))
                    }
                    
                case .overlay:
                    ZStack {
                        // PDF作为背景
                        PDFContentView(
                            pdfURL: pdfURL,
                            article: article,
                            viewModel: viewModel
                        )
                        
                        // 文本覆盖层
                        VStack {
                            Spacer()
                            
                            OverlayTextView(
                                structuredText: structuredText,
                                currentPage: currentPage,
                                fontSize: fontSize,
                                lineSpacing: lineSpacing,
                                onWordTap: handleWordTap,
                                onSentenceLongPress: handleSentenceLongPress
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .shadow(radius: 8)
                            )
                            .padding()
                        }
                    }
                    
                case .tabbed:
                    TabView(selection: $currentPage) {
                        ForEach(1...max(structuredText.pages.count, 1), id: \.self) { pageIndex in
                            TabbedPageView(
                                pdfURL: pdfURL,
                                structuredText: structuredText,
                                pageIndex: pageIndex,
                                article: article,
                                fontSize: fontSize,
                                lineSpacing: lineSpacing,
                                onWordTap: handleWordTap,
                                onSentenceLongPress: handleSentenceLongPress,
                                viewModel: self.viewModel
                            )
                            .tag(pageIndex)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showingSettings) {
            HybridSettingsSheet(
                hybridMode: $hybridMode,
                syncScrolling: $syncScrolling,
                fontSize: $fontSize,
                lineSpacing: $lineSpacing,
                splitRatio: $splitRatio
            )
        }
        .sheet(isPresented: $showingWordDefinition) {
            HybridWordDefinitionSheet(
                word: selectedWord,
                onDismiss: { showingWordDefinition = false }
            )
        }
        .sheet(isPresented: $showingSentenceTranslation) {
            HybridSentenceTranslationSheet(
                sentence: selectedSentence,
                onDismiss: { showingSentenceTranslation = false }
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
}

// MARK: - 混合显示模式
enum HybridDisplayMode: String, CaseIterable {
    case sideBySide = "sideBySide"
    case overlay = "overlay"
    case tabbed = "tabbed"
    
    var displayName: String {
        switch self {
        case .sideBySide: return "并排显示"
        case .overlay: return "覆盖显示"
        case .tabbed: return "标签页显示"
        }
    }
    
    var iconName: String {
        switch self {
        case .sideBySide: return "rectangle.split.2x1"
        case .overlay: return "square.stack"
        case .tabbed: return "rectangle.3.group"
        }
    }
}

// MARK: - 混合工具栏
struct HybridToolbar: View {
    @Binding var hybridMode: HybridDisplayMode
    @Binding var currentPage: Int
    let totalPages: Int
    @Binding var syncScrolling: Bool
    let onSettingsTap: () -> Void
    let onPreviousPage: () -> Void
    let onNextPage: () -> Void
    
    var body: some View {
        HStack {
            // 混合模式选择器
            Menu {
                ForEach(HybridDisplayMode.allCases, id: \.self) { mode in
                    Button(action: { hybridMode = mode }) {
                        Label(mode.displayName, systemImage: mode.iconName)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: hybridMode.iconName)
                    Text(hybridMode.displayName)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(6)
            }
            
            Spacer()
            
            // 页面导航
            if hybridMode != .tabbed {
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
            }
            
            Spacer()
            
            // 同步滚动开关
            if hybridMode == .sideBySide {
                Button(action: { syncScrolling.toggle() }) {
                    Image(systemName: syncScrolling ? "link" : "link.badge.plus")
                        .foregroundColor(syncScrolling ? .blue : .gray)
                }
            }
            
            // 设置按钮
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape")
                    .font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
}

// MARK: - 覆盖文本视图
struct OverlayTextView: View {
    let structuredText: StructuredText
    let currentPage: Int
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let onWordTap: (String) -> Void
    let onSentenceLongPress: (String) -> Void
    
    var body: some View {
        ScrollView {
            if currentPage <= structuredText.pages.count {
                let page = structuredText.pages[currentPage - 1]
                
                VStack(alignment: .leading, spacing: lineSpacing) {
                    ForEach(page.elements, id: \.id) { element in
                        Text(element.content)
                            .font(.system(size: fontSize))
                            .lineSpacing(lineSpacing)
                            .onTapGesture {
                                if let word = extractWordFromText(element.content) {
                                    onWordTap(word)
                                }
                            }
                            .onLongPressGesture {
                                onSentenceLongPress(element.content)
                            }
                    }
                }
                .padding()
            }
        }
        .frame(maxHeight: 300)
    }
    
    private func extractWordFromText(_ text: String) -> String? {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.first { !$0.isEmpty }
    }
}

// MARK: - 标签页视图
struct TabbedPageView: View {
    let pdfURL: URL
    let structuredText: StructuredText
    let pageIndex: Int
    let article: Article
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let onWordTap: (String) -> Void
    let onSentenceLongPress: (String) -> Void
    let viewModel: ProgressViewModel
    
    @State private var showPDF = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 切换按钮
            HStack {
                Button(action: { showPDF = true }) {
                    Text("PDF")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showPDF ? Color.blue : Color.clear)
                        .foregroundColor(showPDF ? .white : .blue)
                        .cornerRadius(6)
                }
                
                Button(action: { showPDF = false }) {
                    Text("文本")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(!showPDF ? Color.blue : Color.clear)
                        .foregroundColor(!showPDF ? .white : .blue)
                        .cornerRadius(6)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // 内容视图
            if showPDF {
                PDFContentView(
                    pdfURL: pdfURL,
                    article: article,
                    viewModel: self.viewModel
                )
            } else {
                StructuredTextView(
                    structuredText: structuredText,
                    article: article
                )
            }
        }
    }
}

// MARK: - 混合设置表单
struct HybridSettingsSheet: View {
    @Binding var hybridMode: HybridDisplayMode
    @Binding var syncScrolling: Bool
    @Binding var fontSize: CGFloat
    @Binding var lineSpacing: CGFloat
    @Binding var splitRatio: CGFloat
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("显示模式") {
                    Picker("混合模式", selection: $hybridMode) {
                        ForEach(HybridDisplayMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.iconName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if hybridMode == .sideBySide {
                    Section("并排设置") {
                        Toggle("同步滚动", isOn: $syncScrolling)
                        
                        VStack {
                            HStack {
                                Text("分割比例")
                                Spacer()
                                Text("\(Int(splitRatio * 100))% : \(Int((1 - splitRatio) * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $splitRatio, in: 0.2...0.8, step: 0.1)
                        }
                    }
                }
                
                Section("文本设置") {
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
                    Text("这是一段示例文本，用于预览当前的设置效果。")
                        .font(.system(size: fontSize))
                        .lineSpacing(lineSpacing)
                }
            }
            .navigationTitle("混合模式设置")
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

// MARK: - Sheet组件（重用之前定义的）
struct HybridWordDefinitionSheet: View {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            definition = "\(word): 这里是单词的定义和解释..."
            isLoading = false
        }
    }
}

struct HybridSentenceTranslationSheet: View {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            translation = "这里是句子的中文翻译..."
            isLoading = false
        }
    }
}

// MARK: - 预览
struct HybridReaderView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleElement = TextElement(
            content: "这是一个示例段落，用于展示混合模式的显示效果。",
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
            pages: [samplePage],
            metadata: TextMetadata(
                totalPages: 1,
                extractionDate: Date(),
                sourceURL: nil,
                language: "zh",
                wordCount: 20
            )
        )
        
        if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf") {
            HybridReaderView(
                pdfURL: url,
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
                viewModel: ProgressViewModel(
                    userProgressService: MockUserProgressService(),
                    articleService: MockArticleService(),
                    errorHandler: MockErrorHandler()
                )
            )
        } else {
            Text("无法加载混合视图预览")
        }
    }
}
