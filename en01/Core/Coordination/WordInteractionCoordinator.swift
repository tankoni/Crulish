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
class WordInteractionCoordinator: ObservableObject {
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
    
    // MARK: - Dependencies
    private var settings: AppSettings?
    
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
    private var lastTappedWord: String = ""
    private var lastTapTime: Date = Date.distantPast
    private let tapDebounceInterval: TimeInterval = 0.5 // 500ms防抖间隔
    
    // MARK: - 缓存管理
    private var lastCacheCleanupTime: Date = Date.distantPast
    private let cacheCleanupInterval: TimeInterval = 300 // 5分钟清理一次无效缓存
    
    // MARK: - Initialization
    init(dictionaryService: DictionaryServiceProtocol, translationService: TranslationServiceProtocol? = nil, settings: AppSettings? = nil) {
        self.dictionaryService = dictionaryService
        self.translationService = translationService
        self.settings = settings
        self.wordDefinitionViewModel = WordDefinitionViewModel(dictionaryService: dictionaryService)
    }
    
    // MARK: - Word Interaction Methods
    
    /// 设置当前交互模式
    func setInteractionMode(_ mode: InteractionMode) {
        currentInteractionMode = mode
    }
    
    /// 设置翻译模式
    func setTranslationMode(_ mode: TranslationMode) {
        currentTranslationMode = mode
    }
    
    /// 处理单词点击事件
    func handleWordTap(_ word: String, at position: CGPoint = .zero) {
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
        
        // 添加触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 加载简单定义用于tooltip显示
        Task {
            await wordDefinitionViewModel.loadDefinition(for: word)
            await MainActor.run {
                showTooltip = true
            }
        }
    }
    
    /// 显示详细单词定义
    func showDetailedDefinition() {
        showTooltip = false
        
        Task {
            await wordDefinitionViewModel.loadDetailedDefinition(for: selectedWord)
            showDetailedSheet = true
        }
    }
    
    /// 隐藏tooltip
    func hideTooltip() {
        showTooltip = false
    }
    
    /// 隐藏详细弹窗
    func hideDetailedSheet() {
        showDetailedSheet = false
        wordDefinitionViewModel.reset()
    }
    
    /// 处理单词翻译
    func handleWordTranslation(_ word: String, context: String = "") {
        guard let translationService = translationService else {
            translationError = "翻译服务不可用"
            return
        }
        
        // 定期清理无效缓存
        performCacheCleanupIfNeeded()
        
        isTranslating = true
        translationError = nil
        
        Task {
            do {
                let translation: Translation?
                
                switch currentTranslationMode {
                case .word:
                    // 智能识别：优先查询本地数据库
                    translation = await handleSmartWordTranslation(word, context: context)
                case .sentence:
                    // 句段翻译：直接使用AI翻译
                    translation = try await translationService.translateSentence(context.isEmpty ? word : context)
                }
                
                await MainActor.run {
                    if let translation = translation, self.isValidTranslationResult(translation) {
                        self.currentTranslation = translation
                        self.showTranslation = true
                    } else {
                        // 根据翻译模式提供不同的错误信息
                        if currentTranslationMode == .sentence {
                            self.translationError = "句段翻译暂时不可用，请检查网络连接后重试"
                        } else {
                            self.translationError = "单词翻译暂时不可用，请检查网络连接后重试"
                        }
                    }
                    self.isTranslating = false
                }
            } catch {
                await MainActor.run {
                    // 提供更友好的错误信息
                    let errorMessage = self.getFriendlyErrorMessage(from: error)
                    self.translationError = errorMessage
                    self.isTranslating = false
                }
            }
        }
    }
    
    /// 智能单词翻译：优先本地数据库，否则AI翻译
    private func handleSmartWordTranslation(_ word: String, context: String) async -> Translation? {
        // 始终使用AI进行精准上下文翻译
        do {
            if let aiTranslation = try await translationService?.translateWord(word, context: context) {
                // 检查本地数据库是否有该单词，用于学习记录标记
                let databaseResults = dictionaryService.searchWords(word)
                let hasLocalRecord = databaseResults.first(where: { $0.word.lowercased() == word.lowercased() }) != nil
                
                // 创建AI翻译结果，包含数据库状态信息
                var modifiedTranslation = aiTranslation
                if var grammarAnalysis = modifiedTranslation.grammarAnalysis {
                    let sourceInfo = hasLocalRecord ? "AI精准翻译（已收录）" : "AI精准翻译"
                    grammarAnalysis = GrammarAnalysis(
                        sentenceStructure: "\(sourceInfo)：\(word)\n\n" + grammarAnalysis.sentenceStructure,
                        keyPhrases: grammarAnalysis.keyPhrases,
                        grammarPoints: grammarAnalysis.grammarPoints,
                        partOfSpeech: grammarAnalysis.partOfSpeech,
                        wordForm: grammarAnalysis.wordForm
                    )
                    // 创建新的Translation实例，包含语法分析
                    let newTranslation = Translation(
                        originalText: modifiedTranslation.originalText,
                        translatedText: modifiedTranslation.translatedText,
                        sourceLanguage: modifiedTranslation.sourceLanguage,
                        targetLanguage: modifiedTranslation.targetLanguage,
                        confidence: modifiedTranslation.confidence,
                        provider: .openai, // 标记为AI翻译
                        contextualMeaning: modifiedTranslation.contextualMeaning,
                        grammarAnalysis: grammarAnalysis
                    )
                    modifiedTranslation = newTranslation
                }
                
                // 如果本地数据库有记录，标记学习状态
                if hasLocalRecord {
                    // 这里可以添加学习记录标记逻辑
                    print("[DEBUG] 单词 \(word) 已在数据库中，标记学习记录")
                }
                
                return modifiedTranslation
            }
        } catch {
            print("AI翻译失败: \(error)")
        }
        
        // 如果AI翻译失败，尝试本地数据库查询
        let databaseResults = dictionaryService.searchWords(word)
        if let localResult = databaseResults.first(where: { $0.word.lowercased() == word.lowercased() }) {
            // 使用本地数据库结果
            let definition = localResult.definitions.first ?? WordDefinition(partOfSpeech: .noun, meaning: "暂无释义", examples: [])
            return Translation(
                originalText: word,
                translatedText: definition.meaning,
                confidence: 0.8,
                provider: .local,
                contextualMeaning: "本地词典：\(definition.meaning)",
                grammarAnalysis: GrammarAnalysis(
                    sentenceStructure: "词性：\(definition.partOfSpeech.rawValue)\n释义：\(definition.meaning)",
                    keyPhrases: [],
                    grammarPoints: [],
                    partOfSpeech: definition.partOfSpeech.rawValue,
                    wordForm: nil
                )
            )
        }
        
        // 如果本地数据库也没有，返回nil而不是无效的翻译结果
        return nil
    }
    
    /// 根据上下文选择最合适的释义
    private func selectBestDefinition(from definitions: [WordDefinition], context: String) -> WordDefinition {
        // 如果只有一个释义，直接返回
        guard definitions.count > 1 else {
            return definitions.first ?? WordDefinition(partOfSpeech: .noun, meaning: "暂无释义", examples: [])
        }
        
        // 简单的上下文匹配逻辑
        let contextWords = context.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        for definition in definitions {
            // 检查释义中是否包含上下文相关词汇
            let meaningWords = definition.meaning.lowercased().components(separatedBy: .whitespacesAndNewlines)
            let exampleWords = definition.examples.joined(separator: " ").lowercased().components(separatedBy: .whitespacesAndNewlines)
            
            let allDefinitionWords = Set(meaningWords + exampleWords)
            let contextWordSet = Set(contextWords)
            
            // 如果有交集，认为这个释义更合适
            if !allDefinitionWords.intersection(contextWordSet).isEmpty {
                return definition
            }
        }
        
        // 如果没有找到匹配的，返回第一个释义
        return definitions.first!
    }
    
    /// 隐藏翻译弹窗
    func hideTranslation() {
        showTranslation = false
        currentTranslation = nil
        translationError = nil
    }
    
    /// 重置所有状态
    func reset() {
        showTooltip = false
        showDetailedSheet = false
        showTranslation = false
        selectedWord = ""
        selectedWordPosition = .zero
        currentTranslation = nil
        isTranslating = false
        translationError = nil
        lastTappedWord = ""
        lastTapTime = Date.distantPast
        wordDefinitionViewModel.reset()
    }
    
    /// 清理翻译缓存
    func clearTranslationCache() {
        if let translationService = translationService {
            translationService.clearTranslationCache()
            print("[DEBUG] 翻译缓存已清理")
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// 验证翻译结果是否有效
    private func isValidTranslationResult(_ translation: Translation) -> Bool {
        // 检查翻译文本不为空且不是纯空白字符
        let trimmedTranslation = translation.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranslation.isEmpty else {
            return false
        }
        
        // 检查翻译结果不是错误信息
        let errorKeywords = ["翻译失败", "翻译服务暂时不可用", "未找到该单词的释义", "translation failed", "service unavailable"]
        let lowercaseTranslation = trimmedTranslation.lowercased()
        for keyword in errorKeywords {
            if lowercaseTranslation.contains(keyword.lowercased()) {
                return false
            }
        }
        
        return true
    }
    
    /// 获取友好的错误信息
    private func getFriendlyErrorMessage(from error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("network") || errorDescription.contains("internet") {
            return "网络连接异常，请检查网络设置后重试"
        } else if errorDescription.contains("timeout") {
            return "请求超时，请稍后重试"
        } else if errorDescription.contains("unauthorized") || errorDescription.contains("authentication") {
            return "翻译服务认证失败，请检查API配置"
        } else if errorDescription.contains("quota") || errorDescription.contains("limit") {
            return "翻译服务配额已用完，请稍后重试"
        } else {
            return "翻译服务暂时不可用，请稍后重试"
        }
    }
    
    /// 定期清理无效缓存
    private func performCacheCleanupIfNeeded() {
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastCacheCleanupTime) > cacheCleanupInterval {
            lastCacheCleanupTime = currentTime
            
            // 异步清理缓存，避免阻塞UI
            if let translationService = self.translationService {
                translationService.clearTranslationCache()
                print("[DEBUG] 已清理无效的翻译缓存条目")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var isLoading: Bool {
        wordDefinitionViewModel.isLoading
    }
    
    var simpleDefinition: String {
        wordDefinitionViewModel.simpleDefinition
    }
    
    var simplePhonetic: String? {
        wordDefinitionViewModel.simplePhonetic
    }
    
    var detailedDefinition: DetailedWordDefinition? {
        wordDefinitionViewModel.detailedDefinition
    }
    
    var errorMessage: String? {
        wordDefinitionViewModel.errorMessage
    }
}