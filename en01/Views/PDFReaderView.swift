//
//  PDFReaderView.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI
import PDFKit
import UIKit

struct PDFReaderView: View {
    let pdfURL: URL
    let article: Article
    let viewModel: ProgressViewModel
    
    @State private var pdfView = PDFView()
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 0
    @State private var selectedText = ""
    @State private var selectedWord = ""
    @State private var selectedSentence = ""
    @State private var showingWordDefinition = false
    @State private var showingSentenceTranslation = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var gestureHandler: PDFGestureHandler?
    
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
        .sheet(isPresented: $showingWordDefinition) {
            PDFWordDefinitionSheet(word: selectedWord, viewModel: viewModel) {
                showingWordDefinition = false
            }
        }
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
        
        totalPages = document.pageCount
        
        // 添加手势识别
        setupGestureRecognizers()
    }
    
    // MARK: - 手势设置
    private func setupGestureRecognizers() {
        gestureHandler = PDFGestureHandler(
            onWordSelection: { word in
                selectedWord = word
                showingWordDefinition = true
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            },
            onSentenceSelection: { sentence in
                selectedSentence = sentence
                showingSentenceTranslation = true
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
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
                TextField("搜索...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        onSearch()
                    }
                
                Button(action: onSearch) {
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
         // 使用正确的PDFPage API
         if let selection = page.selection(for: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)) {
             let text = selection.string?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
             // 提取单个单词
             let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
             return words.first(where: { !$0.isEmpty })
         }
         return nil
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
struct PDFWordDefinitionSheet: View {
    let word: String
    let viewModel: ProgressViewModel
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
            .navigationTitle("词汇释义")
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
            loadDefinition()
        }
    }
    
    private func loadDefinition() {
        // 模拟加载定义
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            definition = "\(word): 示例定义"
            isLoading = false
        }
    }
}

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
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