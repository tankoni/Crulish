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
    @Published var selectedWord = ""
    @Published var selectedWordPosition: CGPoint = .zero
    
    // MARK: - Dependencies
    private let dictionaryService: DictionaryServiceProtocol
    let wordDefinitionViewModel: WordDefinitionViewModel
    
    // MARK: - 防重复查询
    private var lastTappedWord: String = ""
    private var lastTapTime: Date = Date.distantPast
    private let tapDebounceInterval: TimeInterval = 0.5 // 500ms防抖间隔
    
    // MARK: - Initialization
    init(dictionaryService: DictionaryServiceProtocol) {
        self.dictionaryService = dictionaryService
        self.wordDefinitionViewModel = WordDefinitionViewModel(dictionaryService: dictionaryService)
    }
    
    // MARK: - Word Interaction Methods
    
    /// 处理单词点击事件
    func handleWordTap(_ word: String, at position: CGPoint = .zero) {
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
            showTooltip = true
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
    
    /// 重置所有状态
    func reset() {
        showTooltip = false
        showDetailedSheet = false
        selectedWord = ""
        selectedWordPosition = .zero
        lastTappedWord = ""
        lastTapTime = Date.distantPast
        wordDefinitionViewModel.reset()
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