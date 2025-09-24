//
//  PDFReaderView.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI
import PDFKit
import UIKit

// MARK: - 完整的PDF阅读器视图（包含导航包装器）
struct PDFReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let pdfURL: URL
    let article: Article
    let viewModel: ProgressViewModel
    
    @State private var showingSettings = false
    
    var body: some View {
        ReaderNavigationWrapper(
            title: article.title,
            standardButtons: [.bookmark, .share, .settings],
            onBack: {
                dismiss()
            },
            onBookmark: {
                article.isBookmarked.toggle()
                try? modelContext.save()
            },
            onShare: {
                shareArticle()
            },
            onSettings: {
                showingSettings = true
            }
        ) {
            PDFContentView(
                pdfURL: pdfURL,
                article: article,
                viewModel: viewModel
            )
        }
        .sheet(isPresented: $showingSettings) {
            ReadingSettingsSheet(
                fontSize: .constant(16),
                lineSpacing: .constant(6),
                colorScheme: .constant(SwiftUI.ColorScheme.light)
            )
        }
    }
    
    private func shareArticle() {
        let activityViewController = UIActivityViewController(
            activityItems: [article.title, pdfURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
}

// MARK: - PDF内容视图（不包含导航包装器）
struct PDFContentView: View {
    let pdfURL: URL
    let article: Article
    let viewModel: ProgressViewModel
    
    @State private var pdfView = PDFView()
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 0
    @State private var selectedText = ""
    @State private var selectedSentence = ""
    @State private var showingSentenceTranslation = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var gestureHandler: PDFGestureHandler?
    @State private var fontSize: CGFloat = 16
    @State private var lineSpacing: CGFloat = 6
    @State private var colorScheme: SwiftUI.ColorScheme = SwiftUI.ColorScheme.light
    
    @EnvironmentObject private var dictionaryService: DictionaryService
    @EnvironmentObject private var wordInteractionCoordinator: WordInteractionCoordinator
    
    var body: some View {
        VStack(spacing: 0) {
            // PDF工具栏
            PDFToolbar(
                currentPage: $currentPage,
                totalPages: totalPages,
                searchText: $searchText,
                isSearching: $isSearching,
                onPreviousPage: previousPage,
                onNextPage: nextPage,
                onSearch: performSearch
            )
            
            // PDF视图
            PDFViewRepresentable(
                pdfView: pdfView,
                pdfURL: pdfURL,
                onTextSelection: handleTextSelection,
                onPageChange: handlePageChange
            )
            .onAppear {
                setupPDFView()
            }
        }
        .background(Color(.systemBackground))
        // PDF模式下的弹窗已移除，统一在HybridReaderView中管理
        .sheet(isPresented: $showingSentenceTranslation) {
            PDFSentenceTranslationSheet(sentence: selectedSentence, viewModel: viewModel) {
                showingSentenceTranslation = false
            }
        }
    }
    
    // MARK: - PDF设置
    private func setupPDFView() {
        guard let document = PDFDocument(url: pdfURL) else { return }
        
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        // 启用文本选择
        pdfView.isUserInteractionEnabled = true
        // 修复上下文菜单警告
        // 配置上下文菜单交互
        if pdfView.interactions.contains(where: { $0 is UIContextMenuInteraction }) {
            // 上下文菜单已配置
        }
        
        totalPages = document.pageCount
        
        // 添加手势识别
        setupGestureRecognizers()
    }
    
    // MARK: - 手势设置
    private func setupGestureRecognizers() {
        gestureHandler = PDFGestureHandler(
            onWordSelection: { word in
                wordInteractionCoordinator.handleWordTap(word, at: CGPoint.zero, context: nil, articleId: article.id)
            },
            onSentenceSelection: { sentence in
                selectedSentence = sentence
                showingSentenceTranslation = true
            }
        )
        
        if let handler = gestureHandler {
            pdfView.addGestureRecognizer(handler.doubleTapGesture)
            pdfView.addGestureRecognizer(handler.longPressGesture)
        }
    }
    
    // MARK: - 事件处理
    private func handleTextSelection(_ text: String) {
        selectedText = text
    }
    
    private func handlePageChange(_ page: Int) {
        currentPage = page
    }
    
    private func previousPage() {
        if currentPage > 1 {
            pdfView.goToPreviousPage(nil)
        }
    }
    
    private func nextPage() {
        if currentPage < totalPages {
            pdfView.goToNextPage(nil)
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        pdfView.document?.beginFindString(searchText, withOptions: .caseInsensitive)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSearching = false
        }
    }
    

    
    
    // MARK: - PDF工具栏
    struct PDFToolbar: View {
        @Binding var currentPage: Int
        let totalPages: Int
        @Binding var searchText: String
        @Binding var isSearching: Bool
        let onPreviousPage: () -> Void
        let onNextPage: () -> Void
        let onSearch: () -> Void
        
        @StateObject private var inputManager = UnifiedInputManager.shared
        
        var body: some View {
            HStack {
                // 页面导航
                Button(action: onPreviousPage) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                .disabled(currentPage <= 1)
                
                Text(totalPages > 0 ? "\(currentPage) / \(totalPages)" : "加载中...")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Button(action: onNextPage) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
                .disabled(currentPage >= totalPages)
                
                Spacer()
                
                // 搜索框
                HStack {
                    TextField("搜索...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onTapGesture {
                            inputManager.beginInputSession(fieldId: "pdf_search")
                        }
                        .onSubmit {
                            inputManager.endInputSession()
                            onSearch()
                        }
                    
                    Button(action: {
                        inputManager.endInputSession()
                        onSearch()
                    }) {
                        if isSearching {
                            SwiftUI.ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .disabled(searchText.isEmpty || isSearching)
                }
                .frame(maxWidth: 200)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .shadow(radius: 1)
        }
    }
    
    // MARK: - PDFView UIKit包装
    struct PDFViewRepresentable: UIViewRepresentable {
        let pdfView: PDFView
        let pdfURL: URL
        let onTextSelection: (String) -> Void
        let onPageChange: (Int) -> Void
        
        func makeUIView(context: Context) -> PDFView {
            return pdfView
        }
        
        func updateUIView(_ uiView: PDFView, context: Context) {
            // 更新PDF文档
            if uiView.document?.documentURL != pdfURL {
                uiView.document = PDFDocument(url: pdfURL)
            }
            // 避免 NaN: 检查文档有效性
            if let doc = uiView.document, doc.pageCount > 0 {
                uiView.autoScales = true
            }
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, PDFViewDelegate {
            let parent: PDFViewRepresentable
            
            init(_ parent: PDFViewRepresentable) {
                self.parent = parent
                super.init()
                parent.pdfView.delegate = self
            }
            
            func pdfViewCurrentPageDidChange(_ sender: PDFView) {
                if let currentPage = sender.currentPage,
                   let document = sender.document {
                    let pageIndex = document.index(for: currentPage) + 1
                    parent.onPageChange(pageIndex)
                }
            }
        }
    }
    
    // MARK: - PDF手势处理器
    class PDFGestureHandler: NSObject {
        let onWordSelection: (String) -> Void
        let onSentenceSelection: (String) -> Void
        
        lazy var doubleTapGesture: UITapGestureRecognizer = {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            gesture.numberOfTapsRequired = 2
            return gesture
        }()
        
        lazy var longPressGesture: UILongPressGestureRecognizer = {
            let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            gesture.minimumPressDuration = 0.5
            return gesture
        }()
        
        init(onWordSelection: @escaping (String) -> Void, onSentenceSelection: @escaping (String) -> Void) {
            self.onWordSelection = onWordSelection
            self.onSentenceSelection = onSentenceSelection
            super.init()
        }
        
        @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }
            
            let point = gesture.location(in: pdfView)
            if let page = pdfView.page(for: point, nearest: true) {
                let pagePoint = pdfView.convert(point, to: page)
                if let word = getWordAt(point: pagePoint, in: page) {
                    onWordSelection(word)
                }
            }
        }
        
        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let pdfView = gesture.view as? PDFView else { return }
            
            let point = gesture.location(in: pdfView)
            if let page = pdfView.page(for: point, nearest: true) {
                let pagePoint = pdfView.convert(point, to: page)
                if let sentence = getSentenceAt(point: pagePoint, in: page) {
                    onSentenceSelection(sentence)
                }
            }
        }
        
        private func getWordAt(point: CGPoint, in page: PDFPage) -> String? {
            // 增强的智能单词边界检测：从小范围开始，逐步扩大
            let searchSizes = [
                CGSize(width: 15, height: 12),  // 超小范围 - 精确点击
                CGSize(width: 25, height: 18),  // 小范围 - 单个字符
                CGSize(width: 40, height: 25),  // 中等范围 - 短单词
                CGSize(width: 60, height: 35),  // 较大范围 - 长单词
                CGSize(width: 80, height: 45)   // 最大范围 - 词组
            ]
            
            var bestWord: String?
            var bestScore = 0.0
            
            for (index, size) in searchSizes.enumerated() {
                let selectionRect = CGRect(
                    x: point.x - size.width/2,
                    y: point.y - size.height/2,
                    width: size.width,
                    height: size.height
                )
                
                if let selection = page.selection(for: selectionRect),
                   let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !text.isEmpty {
                    
                    // 尝试提取最接近点击位置的单词
                    if let word = extractWordNearPoint(from: text, clickPoint: point, selectionRect: selectionRect) {
                        // 计算单词质量分数（优先选择较小范围内找到的单词）
                        let sizeScore = 1.0 - (Double(index) * 0.2) // 范围越小分数越高
                        let lengthScore = min(Double(word.count) / 10.0, 1.0) // 长度适中的单词分数更高
                        let validityScore = isValidWordForLookup(word) ? 1.0 : 0.5
                        
                        let totalScore = sizeScore * lengthScore * validityScore
                        
                        if totalScore > bestScore {
                            bestWord = word
                            bestScore = totalScore
                        }
                        
                        // 如果在最小范围内找到有效单词，直接返回
                        if index == 0 && isValidWordForLookup(word) {
                            return word
                        }
                    }
                }
            }
            
            return bestWord
        }
        
        private func extractWordNearPoint(from text: String, clickPoint: CGPoint, selectionRect: CGRect) -> String? {
            // 清理文本，移除多余的空白字符
            let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
            
            // 如果是单个单词，直接返回
            let singleWordText = cleanedText.trimmingCharacters(in: .punctuationCharacters)
            if !singleWordText.contains(" ") && !singleWordText.isEmpty {
                return isValidWordForLookup(singleWordText) ? singleWordText : nil
            }
            
            // 分割成单词，保留标点符号信息用于更精确的匹配
            let words = cleanedText.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            
            var candidates: [(word: String, score: Double)] = []
            
            for word in words {
                let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                guard isValidWordForLookup(cleanWord) else { continue }
                
                // 计算单词质量分数
                var score = 0.0
                
                // 长度分数：3-12个字符的单词得分最高
                if cleanWord.count >= 3 && cleanWord.count <= 12 {
                    score += 1.0
                } else if cleanWord.count >= 2 {
                    score += 0.7
                } else {
                    score += 0.3
                }
                
                // 字母组成分数：全字母单词得分更高
                if cleanWord.allSatisfy({ $0.isLetter }) {
                    score += 0.5
                }
                
                // 常见词汇分数：避免选择过于简单的词汇
                let commonWords = ["a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"]
                if !commonWords.contains(cleanWord.lowercased()) {
                    score += 0.3
                }
                
                candidates.append((word: cleanWord, score: score))
            }
            
            // 返回得分最高的单词
            return candidates.max(by: { $0.score < $1.score })?.word
        }
        
        private func extractValidWord(from text: String) -> String? {
            // 清理文本，移除标点符号
            let cleanedText = text.trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 如果是单个单词，直接返回
            if !cleanedText.contains(" ") && !cleanedText.isEmpty {
                return isValidWordForLookup(cleanedText) ? cleanedText : nil
            }
            
            // 如果包含多个单词，选择最长的有效单词
            let words = cleanedText.components(separatedBy: CharacterSet.whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { isValidWordForLookup($0) }
            
            // 返回最长的单词
            return words.max(by: { $0.count < $1.count })
        }
        
        private func isValidWordForLookup(_ word: String) -> Bool {
            // 检查是否为空或太短
            guard !word.isEmpty && word.count > 1 else {
                return false
            }
            
            // 检查是否包含字母
            guard word.rangeOfCharacter(from: .letters) != nil else {
                return false
            }
            
            // 检查是否包含中文字符
            let chineseCharacterSet = CharacterSet(charactersIn: "\u{4e00}-\u{9fff}")
            if word.rangeOfCharacter(from: chineseCharacterSet) != nil {
                return false
            }
            
            // 检查是否为纯数字
            if word.rangeOfCharacter(from: .decimalDigits) != nil &&
               word.rangeOfCharacter(from: .letters) == nil {
                return false
            }
            
            // 检查是否包含过多特殊字符
            let specialCharCount = word.filter { !$0.isLetter && !$0.isNumber }.count
            if specialCharCount > word.count / 2 {
                return false
            }
            
            // 检查是否只包含英文字母
            let nonEnglishCount = word.filter { char in
                !char.isASCII || (!char.isLetter && !char.isNumber)
            }.count
            if nonEnglishCount > 0 {
                return false
            }
            
            return true
        }
        
        private func getSentenceAt(point: CGPoint, in page: PDFPage) -> String? {
            // 使用正确的PDFPage API获取更大范围的文本
            if let selection = page.selection(for: CGRect(x: point.x - 50, y: point.y - 20, width: 100, height: 40)) {
                let text = selection.string?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
                // 简单的句子提取逻辑
                return text.isEmpty ? nil : text
            }
            return nil
        }
    }
    
    // MARK: - Sheet Views

    
    struct PDFSentenceTranslationSheet: View {
        let sentence: String
        let viewModel: ProgressViewModel
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
            }
            .onAppear {
                loadTranslation()
            }
        }
        
        private func loadTranslation() {
            // 模拟加载翻译
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒延迟
                translation = "这是句子的翻译示例"
                isLoading = false
            }
        }
    }
    
    // MARK: - 预览
    struct PDFReaderView_Previews: PreviewProvider {
        static var previews: some View {
            if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf") {
                PDFReaderView(
                    pdfURL: url,
                    article: Article(
                        title: "Sample PDF",
                        content: "Sample content",
                        year: 2024,
                        examType: "考研一",
                        difficulty: .medium,
                        topic: "Reading",
                        imageName: "sample"
                    ),
                    viewModel: ProgressViewModel(
                        userProgressService: MockUserProgressService(),
                        articleService: MockArticleService(),
                        errorHandler: MockErrorHandler()
                    )
                )
            } else {
                Text("PDF not found")
            }
        }
    }
}
