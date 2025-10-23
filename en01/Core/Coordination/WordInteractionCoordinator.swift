//
//  WordInteractionCoordinator.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import SwiftUI
import Foundation

/// 统一的单词交互协调器，处理所有单词点击和弹窗逻辑
@MainActor
class WordInteractionCoordinator: ObservableObject, WordInteractionProtocol, LearningTrackingProtocol {
    // MARK: - Published Properties
    @Published var showTooltip = false
    @Published var showDetailedSheet = false
    @Published var showTranslation = false
    @Published var selectedWord = ""
    @Published var selectedWordPosition: CGPoint = .zero
    @Published var currentInteractionMode: InteractionMode = .text
    @Published var currentTranslation: Translation?
    @Published var isTranslating = false
    @Published var translationError: String?
    @Published var currentTranslationMode: TranslationMode = .word
    @Published var isLoading = false
    
    // MARK: - Learning Tracking Properties
    @Published var currentArticleId: UUID?
    @Published var currentReadingSession: ReadingSession?
    
    // MARK: - Computed Properties for UI
    
    /// 简单音标，从WordDefinitionViewModel获取
    var simplePhonetic: String? {
        return wordDefinitionViewModel.simplePhonetic
    }
    
    /// 简单定义，从WordDefinitionViewModel获取
    var simpleDefinition: String {
        return wordDefinitionViewModel.simpleDefinition
    }
    
    // MARK: - Dependencies
    private var settings: AppSettings?
    private let learningTrackingService: LearningTrackingService?
    
    // MARK: - Interaction Mode
    enum InteractionMode {
        case text
        case pdf
    }
    
    // MARK: - Dependencies
    private let dictionaryService: DictionaryServiceProtocol
    private let translationService: TranslationServiceProtocol?
    let wordDefinitionViewModel: WordDefinitionViewModel
    
    // MARK: - 防重复查询
    // 防抖相关属性
    private var lastTappedWord: String = ""
    private var lastTapTime: Date = Date.distantPast
    private let tapDebounceInterval: TimeInterval = 0.2 // 减少到200ms防抖间隔，提升响应速度
    
    // MARK: - 缓存管理
    private var lastCacheCleanupTime: Date = Date.distantPast
    private let cacheCleanupInterval: TimeInterval = 300 // 5分钟清理一次无效缓存
    
    // MARK: - Learning Tracking State
    private var wordViewStartTime: Date?
    private var sessionWordsEncountered: Set<String> = []
    
    // MARK: - Initialization
    init(
        dictionaryService: DictionaryServiceProtocol, 
        translationService: TranslationServiceProtocol? = nil, 
        learningTrackingService: LearningTrackingService? = nil,
        settings: AppSettings? = nil
    ) {
        self.dictionaryService = dictionaryService
        self.translationService = translationService
        self.learningTrackingService = learningTrackingService
        self.settings = settings
        self.wordDefinitionViewModel = WordDefinitionViewModel(dictionaryService: dictionaryService)
    }
    
    // MARK: - Word Interaction Protocol Implementation
    
    func handleWordTap(_ word: String, at position: CGPoint, context: String? = nil, articleId: UUID? = nil) {
        handleWordTapInternal(word, at: position)
        
        // 记录单词点击行为
        if let articleId = articleId ?? currentArticleId {
            Task {
                await trackWordClick(word, context: context ?? "", articleId: articleId, position: Int(position.x + position.y))
            }
        }
    }
    
    func showWordDefinition(_ word: String, at position: CGPoint) {
        selectedWord = word
        selectedWordPosition = position
        showDetailedDefinition()
    }
    
    func hideWordDefinition() {
        hideDetailedSheet()
        
        // 记录单词查看时长
        if let startTime = wordViewStartTime, !selectedWord.isEmpty {
            let viewDuration = Date().timeIntervalSince(startTime)
            if let articleId = currentArticleId {
                Task {
                    await trackWordView(selectedWord, viewDuration: viewDuration, articleId: articleId)
                }
            }
        }
        wordViewStartTime = nil
    }
    
    func updateWordMastery(_ word: String, mastery: MasteryLevel, context: String) {
        // 获取之前的掌握程度
        let previousMastery = getCurrentWordMastery(word)
        
        // 更新掌握程度到学习跟踪服务
        learningTrackingService?.updateWordMastery(
            word: word,
            masteryLevel: mastery,
            source: "interaction"
        )
        
        // 记录掌握程度变化
        if let articleId = currentArticleId {
            Task {
                await trackMasteryChange(word, mastery: mastery, previousMastery: previousMastery, articleId: articleId)
            }
        }
    }
    
    func setCurrentArticle(_ articleId: UUID) {
        currentArticleId = articleId
        
        // 开始新的阅读会话
        currentReadingSession = ReadingSession(
            userId: "default",
            articleId: articleId.uuidString,
            startTime: Date()
        )
        sessionWordsEncountered.removeAll()
    }
    
    // MARK: - Learning Tracking Protocol Implementation
    
    func trackWordClick(_ word: String, context: String, articleId: UUID, position: Int) async {
        learningTrackingService?.recordWordClick(
            word: word,
            context: context,
            articleId: articleId,  // Keep as UUID, no conversion needed
            position: position
        )
        
        // 添加到当前会话遇到的单词
        sessionWordsEncountered.insert(word.lowercased())
    }
    
    func trackWordView(_ word: String, viewDuration: TimeInterval, articleId: UUID) async {
        // 这里可以扩展记录单词查看行为的详细信息
        print("[Learning] 单词查看: \(word), 时长: \(viewDuration)秒")
    }
    
    func trackMasteryChange(_ word: String, mastery: MasteryLevel, previousMastery: MasteryLevel?, articleId: UUID) async {
        // 学习跟踪服务已经在updateWordMastery中处理了记录
        print("[Learning] 掌握程度变化: \(word) \(previousMastery?.rawValue ?? "unknown") -> \(mastery.rawValue)")
    }
    
    
    // MARK: - Enhanced Word Interaction Methods
    
    /// 设置当前交互模式
    func setInteractionMode(_ mode: InteractionMode) {
        currentInteractionMode = mode
    }
    
    /// 设置翻译模式
    func setTranslationMode(_ mode: TranslationMode) {
        currentTranslationMode = mode
    }
    
    /// 处理单词点击事件（增强版）
    func handleWordTapInternal(_ word: String, at position: CGPoint = .zero) {
        // 移除翻译模式限制，允许单词和句子翻译并存
        print("[DEBUG][WordInteractionCoordinator] 处理单词点击: \(word), 当前翻译模式: \(currentTranslationMode)")
        
        let currentTime = Date()
        
        // 防重复查询：检查是否是同一个单词且在防抖间隔内
        if word == lastTappedWord && currentTime.timeIntervalSince(lastTapTime) < tapDebounceInterval {
            print("[DEBUG][WordInteractionCoordinator] 跳过重复点击: \(word)")
            return
        }
        
        // 更新防重复查询状态
        lastTappedWord = word
        lastTapTime = currentTime
        
        selectedWord = word
        selectedWordPosition = position
        
        // 记录单词查看开始时间
        wordViewStartTime = Date()
        
        // 添加触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 记录学习行为
        if let articleId = currentArticleId {
            Task {
                await trackWordClick(word, context: "", articleId: articleId, position: Int(position.x + position.y))
            }
        }
        
        // 加载简单定义用于tooltip显示
        Task {
            await wordDefinitionViewModel.loadDefinition(for: word)
            await MainActor.run {
                isLoading = wordDefinitionViewModel.isLoading
                showTooltip = true
            }
        }
    }
    
    /// 显示详细单词定义
    func showDetailedDefinition() {
        showTooltip = false
        wordViewStartTime = Date() // 重新记录查看时间
        
        Task {
            await wordDefinitionViewModel.loadDetailedDefinition(for: selectedWord)
            showDetailedSheet = true
        }
    }
    
    /// 隐藏tooltip
    func hideTooltip() {
        showTooltip = false
        
        // 记录简短查看
        if let startTime = wordViewStartTime, !selectedWord.isEmpty {
            let viewDuration = Date().timeIntervalSince(startTime)
            if let articleId = currentArticleId {
                Task {
                    await trackWordView(selectedWord, viewDuration: viewDuration, articleId: articleId)
                }
            }
        }
        wordViewStartTime = nil
    }
    
    /// 隐藏详细弹窗
    func hideDetailedSheet() {
        showDetailedSheet = false
        
        // 记录详细查看时长
        if let startTime = wordViewStartTime, !selectedWord.isEmpty {
            let viewDuration = Date().timeIntervalSince(startTime)
            if let articleId = currentArticleId {
                Task {
                    await trackWordView(selectedWord, viewDuration: viewDuration, articleId: articleId)
                }
            }
        }
        wordViewStartTime = nil
        
        wordDefinitionViewModel.reset()
    }
    
    /// 结束阅读会话
    func endReadingSession() {
        guard let session = currentReadingSession else { return }
        
        let readingTime = Date().timeIntervalSince(session.startTime)
        let wordsCount = sessionWordsEncountered.count
        
        guard let articleUUID = currentArticleId else {
            print("[Learning] 警告: 结束阅读会话时缺少 currentArticleId")
            currentReadingSession = nil
            sessionWordsEncountered.removeAll()
            return
        }
        
        Task {
            await trackReadingSession(
                articleId: articleUUID,
                readingTime: readingTime,
                wordsEncountered: wordsCount
            )
        }
        
        currentReadingSession = nil
        sessionWordsEncountered.removeAll()
    }
    
    func trackReadingSession(articleId: UUID, readingTime: TimeInterval, wordsEncountered: Int) async {
        // 移除与协议不一致的实现，保留UUID版本的trackReadingSession
        print("[Learning] 阅读会话结束: 文章ID=\(articleId.uuidString), 阅读时长=\(readingTime)秒, 遇到单词数=\(wordsEncountered)")
        
        // 如果有学习跟踪服务，可以在这里记录阅读会话数据
        if learningTrackingService != nil {
            // 暂时使用日志记录，等待实现专门的阅读会话记录方法
            print("[Learning] 学习跟踪服务记录阅读会话: 文章=\(articleId.uuidString), 时长=\(readingTime), 单词数=\(wordsEncountered)")
            // TODO: 实现专用阅读会话记录方法
        }
    }
    
    // MARK: - Word Interaction Methods (Legacy - to be removed)
    
    func handleWordLongPress(_ word: String, at position: CGPoint, context: String? = nil, articleId: UUID? = nil) {
        // 长按显示详细定义
        selectedWord = word
        selectedWordPosition = position
        showDetailedDefinition()
        
        // 记录长按行为
        if let articleId = articleId ?? currentArticleId {
            Task {
                await trackWordClick(word, context: context ?? "", articleId: articleId, position: 0)
            }
        }
    }
    
    func setWordMastery(_ word: String, mastery: MasteryLevel, context: String? = nil, articleId: UUID? = nil) {
        updateWordMastery(word, mastery: mastery, context: context ?? "")
    }
    
    func showDetailedDefinition(for word: String) {
        selectedWord = word
        showDetailedDefinition()
    }
    
    // MARK: - LearningTrackingProtocol Methods
    
    func getCurrentWordMastery(_ word: String) -> MasteryLevel {
        // 返回当前单词的掌握程度，默认为 unfamiliar
        return .unfamiliar
    }
}