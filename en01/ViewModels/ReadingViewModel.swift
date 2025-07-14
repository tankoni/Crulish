//
//  ReadingViewModel.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI
import SwiftData
import Combine

/// 阅读ViewModel，负责文章阅读、进度跟踪和词汇查询功能
@MainActor
class ReadingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentArticle: Article?
    @Published var isReading: Bool = false
    @Published var readingProgress: Double = 0.0
    @Published var readingStartTime: Date?
    @Published var totalReadingTime: TimeInterval = 0
    @Published var selectedText: String = ""
    @Published var selectedSentence: String = ""
    @Published var lookupResult: UserWord?
    @Published var isLookingUp: Bool = false
    @Published var errorMessage: String?
    @Published var settings: ReadingSettings = ReadingSettings()
    
    // MARK: - Reading State
    @Published var isPaused: Bool = false
    @Published var bookmarked: Bool = false
    @Published var completed: Bool = false
    
    // MARK: - Services
    let articleService: ArticleServiceProtocol
    private let userProgressService: UserProgressServiceProtocol
    private let dictionaryService: DictionaryServiceProtocol
    let textProcessor: TextProcessor
    private let errorHandler: ErrorHandlerProtocol
    
    // MARK: - Timers
    private var readingTimer: Timer?
    private var progressUpdateTimer: Timer?
    
    // MARK: - Callbacks
    var onReadingStarted: ((Article) -> Void)?
    var onReadingFinished: (() -> Void)?
    var onWordAdded: ((UserWord) -> Void)?
    var onProgressUpdated: (() -> Void)?
    
    // MARK: - Cache
    private var wordLookupCache: [String: UserWord] = [:]
    private let maxCacheSize = 100
    
    // MARK: - Initialization
    init(
        articleService: ArticleServiceProtocol,
        userProgressService: UserProgressServiceProtocol,
        dictionaryService: DictionaryServiceProtocol,
        textProcessor: TextProcessor,
        errorHandler: ErrorHandlerProtocol
    ) {
        self.articleService = articleService
        self.userProgressService = userProgressService
        self.dictionaryService = dictionaryService
        self.textProcessor = textProcessor
        self.errorHandler = errorHandler
    }
    
    // MARK: - Reading Control
    func startReading(_ article: Article) {
        currentArticle = article
        isReading = true
        isPaused = false
        readingStartTime = Date()
        readingProgress = 0.0
        
        // 检查是否已收藏
        checkBookmarkStatus()
        
        // 检查是否已完成
        checkCompletionStatus()
        
        // 开始计时
        startReadingTimer()
        
        // 通知协调器
        onReadingStarted?(article)
        
        errorHandler.logSuccess("开始阅读文章: \(article.title)")
    }
    
    func pauseReading() {
        guard isReading && !isPaused else { return }
        
        isPaused = true
        stopReadingTimer()
        
        // 保存当前进度
        saveReadingProgress()
        
        errorHandler.logSuccess("暂停阅读")
    }
    
    func resumeReading() {
        guard isReading && isPaused else { return }
        
        isPaused = false
        readingStartTime = Date()
        startReadingTimer()
        
        errorHandler.logSuccess("恢复阅读")
    }
    
    func stopReading() {
        guard isReading else { return }
        
        isReading = false
        isPaused = false
        stopReadingTimer()
        
        // 保存最终进度
        saveReadingProgress()
        
        // 清理状态
        currentArticle = nil
        readingProgress = 0.0
        readingStartTime = nil
        selectedText = ""
        selectedSentence = ""
        lookupResult = nil
        
        // 通知协调器
        onReadingFinished?()
        
        errorHandler.logSuccess("结束阅读")
    }
    
    func finishReading() {
        guard let article = currentArticle else { return }
        
        // 标记为已完成
        markAsCompleted()
        
        // 保存完整阅读记录
        // TODO: Implement article completion logic
        self.completed = true
        self.onProgressUpdated?()
        errorHandler.logSuccess("完成文章阅读: \(article.title)")
    }
    
    // MARK: - Progress Management
    func updateReadingProgress(_ progress: Double) {
        readingProgress = max(0, min(1, progress))
        saveReadingProgress()
        onProgressUpdated?()
    }
    
    private func saveReadingProgress() {
        guard currentArticle != nil else { return }
        
        // TODO: Implement progress saving

    }
    
    // MARK: - Word Lookup
    func lookupWord(_ word: String) async -> [DictionaryWord] {
        guard !word.isEmpty else { return [] }
        
        isLookingUp = true
        
        do {
            let result = try await dictionaryService.lookupWord(word)
            
            await MainActor.run {
                self.lookupResult = result
                self.wordLookupCache[word.lowercased()] = result
                self.userProgressService.addWordLookup()
                self.onWordAdded?(result)
                self.isLookingUp = false
            }
            
            // Convert UserWord to DictionaryWord array
            if let definitions = result.selectedDefinition {
                let dictWord = DictionaryWord(
                    word: word,
                    definitions: [definitions]
                )
                return [dictWord]
            }
            return []
        } catch {
            await MainActor.run {
                self.isLookingUp = false
                self.errorHandler.handle(error, context: "ReadingViewModel.lookupWord")
            }
            return []
        }
    }
    
    func addUnknownWord(_ word: String) {
        guard let currentWord = lookupResult else { return }
        
        Task {
            do {
                // 创建新的UserWord实例，包含context和sentence
                let context = selectedText.isEmpty ? word : selectedText
                let sentence = selectedSentence.isEmpty ? context : selectedSentence
                let newWord = UserWord(word: word, context: context, sentence: sentence, selectedDefinition: currentWord.selectedDefinition)
                
                try await dictionaryService.addUnknownWord(newWord)
                
                await MainActor.run {
                    self.onWordAdded?(newWord)
                }
                
                errorHandler.logSuccess("添加生词: \(word)")
            } catch {
                await MainActor.run {
                    self.errorMessage = "添加生词失败"
                }
                errorHandler.handle(error, context: "ReadingViewModel.addUnknownWord")
            }
        }
    }
    
    private func cacheWordLookup(_ word: String, _ result: UserWord) {
        // 限制缓存大小
        if wordLookupCache.count >= maxCacheSize {
            if let firstKey = wordLookupCache.keys.first {
                wordLookupCache.removeValue(forKey: firstKey)
            }
        }
        
        wordLookupCache[word.lowercased()] = result
    }
    
    func recordWordLookup(word: String, definition: WordDefinition, context: String) {
        guard let article = currentArticle else { return }
        
        Task {
            do {
                try await userProgressService.recordWordLookup(
                    word: word,
                    articleId: article.id.uuidString
                )
            } catch {
                errorHandler.handle(error, context: "ReadingViewModel.recordWordLookup")
            }
        }
    }
    
    private func recordWordLookup(_ word: UserWord) {
        guard let article = currentArticle else { return }
        
        Task {
            do {
                try await userProgressService.recordWordLookup(
                    word: word.word,
                    articleId: article.id.uuidString
                )
            } catch {
                errorHandler.handle(error, context: "ReadingViewModel.recordWordLookup")
            }
        }
    }
    
    // MARK: - Text Selection
    func selectText(_ text: String) {
        selectedText = text
        
        // 提取句子
        if let sentence = textProcessor.extractSentence(containing: text, from: currentArticle?.content ?? "") {
            selectedSentence = sentence
        }
    }
    
    func clearSelection() {
        selectedText = ""
        selectedSentence = ""
        lookupResult = nil
    }
    
    // MARK: - Bookmark Management
    func toggleBookmark() {
        guard let article = currentArticle else { return }
        
        Task {
            do {
                if bookmarked {
                    try await userProgressService.removeBookmark(articleId: article.id.uuidString)
                } else {
                    try await userProgressService.addBookmark(articleId: article.id.uuidString)
                }
                
                await MainActor.run {
                    self.bookmarked.toggle()
                }
                
                let action = bookmarked ? "添加" : "移除"
                errorHandler.logSuccess("\(action)收藏: \(article.title)")
            } catch {
                errorHandler.handle(error, context: "ReadingViewModel.toggleBookmark")
            }
        }
    }
    
    private func checkBookmarkStatus() {
        guard let article = currentArticle else { return }
        
        Task {
            do {
                let isBookmarked = try await userProgressService.isBookmarked(articleId: article.id.uuidString)
                await MainActor.run {
                    self.bookmarked = isBookmarked
                }
            } catch {
                errorHandler.handle(error, context: "ReadingViewModel.checkBookmarkStatus")
            }
        }
    }
    
    // MARK: - Completion Management
    private func markAsCompleted() {
        guard let article = currentArticle else { return }
        
        Task {
            do {
                try await userProgressService.markArticleAsCompleted(articleId: article.id.uuidString)
                await MainActor.run {
                    self.completed = true
                }
            } catch {
                errorHandler.handle(error, context: "ReadingViewModel.markAsCompleted")
            }
        }
    }
    
    private func checkCompletionStatus() {
        guard let article = currentArticle else { return }
        
        Task {
            do {
                let isCompleted = try await userProgressService.isCompleted(articleId: article.id.uuidString)
                await MainActor.run {
                    self.completed = isCompleted
                }
            } catch {
                errorHandler.handle(error, context: "ReadingViewModel.checkCompletionStatus")
            }
        }
    }
    
    // MARK: - Timer Management
    private func startReadingTimer() {
        readingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateReadingTime()
            }
        }
    }
    
    private func stopReadingTimer() {
        readingTimer?.invalidate()
        readingTimer = nil
    }
    
    private func updateReadingTime() {
        guard let startTime = readingStartTime else { return }
        totalReadingTime += Date().timeIntervalSince(startTime)
        readingStartTime = Date()
    }
    
    // MARK: - Reading Time Management
    func addReadingTime(_ minutes: Double) {
        totalReadingTime += minutes * 60.0
        userProgressService.addReadingTime(minutes)
        errorHandler.logSuccess("记录阅读时间: \(String(format: "%.1f", minutes))分钟")
    }
    
    // MARK: - Article Actions
    func toggleBookmark(_ article: Article) async {
        do {
            if article.isBookmarked {
                try await userProgressService.removeBookmark(articleId: article.id.uuidString)
            } else {
                try await userProgressService.addBookmark(articleId: article.id.uuidString)
            }
            
            await MainActor.run {
                self.bookmarked.toggle()
            }
            
            let action = bookmarked ? "添加" : "移除"
            errorHandler.logSuccess("\(action)收藏: \(article.title)")
        } catch {
            errorHandler.handle(error, context: "ReadingViewModel.toggleBookmark")
        }
    }
    
    func markAsCompleted(_ article: Article) async {
        do {
            try await userProgressService.markArticleAsCompleted(articleId: article.id.uuidString)
            await MainActor.run {
                self.completed = true
            }
            errorHandler.logSuccess("标记文章已完成: \(article.title)")
        } catch {
            errorHandler.handle(error, context: "ReadingViewModel.markAsCompleted")
        }
    }
    
    func shareArticle(_ article: Article) {
        // 实现文章分享功能
        let shareText = "我正在阅读《\(article.title)》，这是一篇很棒的英语文章！"
        
        #if os(iOS)
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
        #endif
        
        errorHandler.logSuccess("分享文章: \(article.title)")
    }
    
    // MARK: - Data Management
    func clearCache() {
        wordLookupCache.removeAll()
    }
    
    func refreshSettings() {
        // 刷新阅读相关设置
        clearCache()
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Cleanup
    deinit {
        readingTimer?.invalidate()
        readingTimer = nil
    }
}

// MARK: - Computed Properties
extension ReadingViewModel {
    var canPause: Bool {
        isReading && !isPaused
    }
    
    var canResume: Bool {
        isReading && isPaused
    }
    
    var canFinish: Bool {
        isReading && readingProgress > 0.8 // 阅读进度超过80%才能完成
    }
    
    var hasSelectedText: Bool {
        !selectedText.isEmpty
    }
    
    var readingTimeFormatted: String {
        let minutes = Int(totalReadingTime) / 60
        let seconds = Int(totalReadingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var progressPercentage: String {
        return String(format: "%.1f%%", readingProgress * 100)
    }
    
    var currentReadingContext: String {
        return selectedText.isEmpty ? (currentArticle?.title ?? "") : selectedText
    }
}