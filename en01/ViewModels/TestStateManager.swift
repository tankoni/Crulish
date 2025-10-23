//
//  TestStateManager.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import Foundation
import Combine

/// 测试状态管理器 - 专门管理词汇量测试的状态
@MainActor
class TestStateManager: ObservableObject {
    // MARK: - Published Properties
    
    /// 测试是否激活
    @Published var isTestActive: Bool = false
    
    /// 测试是否暂停
    @Published var isPaused: Bool = false
    
    /// 当前单词
    @Published var currentWord: TestWord?
    
    /// 当前单词索引
    @Published var currentWordIndex: Int = 0
    
    /// 测试单词列表
    @Published var testWords: [TestWord] = []
    
    /// 测试进度 (0.0 - 1.0)
    @Published var testProgress: Double = 0.0
    
    /// 当前测试问题
    @Published var currentQuestion: TestQuestion?
    
    /// 选中的答案
    @Published var selectedAnswer: TestOption?
    
    /// 是否显示结果
    @Published var showResult: Bool = false
    
    /// 当前测试实例
    @Published var currentTest: VocabularyTest?
    
    /// 是否有未完成的测试
    @Published var hasIncompleteTest: Bool = false
    
    /// 是否显示测试继续提醒
    @Published var showTestContinuationAlert: Bool = false
    
    /// 是否显示分组完成提醒
    @Published var showGroupCompletionAlert: Bool = false
    
    // MARK: - Session Management Properties
    
    /// 当前会话标识
    @Published var currentSessionId: UUID?
    
    /// 是否为新会话
    @Published var isNewSession: Bool = true
    
    // MARK: - Private Properties
    
    /// 未完成测试的进度信息
    private(set) var incompleteTestProgress: TestProgress?
    
    /// 防止重复完成测试的标志
    private var isCompletingTest = false
    
    /// 测试是否已完成的全局标志
    private var isTestCompleted = false
    
    /// 单词测试状态历史记录
    private var wordStateHistory: [Int: WordTestState] = [:]
    
    // MARK: - Computed Properties
    
    /// 测试是否可以开始
    var canStartTest: Bool {
        return !isTestActive && !testWords.isEmpty
    }
    
    /// 测试是否可以暂停
    var canPauseTest: Bool {
        return isTestActive && !isPaused
    }
    
    /// 测试是否可以恢复
    var canResumeTest: Bool {
        return isTestActive && isPaused
    }
    
    /// 是否是最后一个单词
    var isLastWord: Bool {
        return currentWordIndex >= testWords.count - 1
    }
    
    /// 是否是第一个单词
    var isFirstWord: Bool {
        return currentWordIndex <= 0
    }
    
    /// 是否可以回退到上一个单词
    var canMoveToPrevious: Bool {
        return currentWordIndex > 0
    }
    
    /// 剩余单词数
    var remainingWords: Int {
        return max(0, testWords.count - currentWordIndex)
    }
    
    /// 已测试单词数
    var testedWords: Int {
        return currentWordIndex
    }
    
    // MARK: - Methods
    
    /// 取消所有任务
    func cancelAllTasks() {
        // 取消当前测试相关的所有异步任务
        // 这里可以添加具体的任务取消逻辑
        print("✅ 已取消所有测试任务")
    }
    
    /// 提交答案
    func submitAnswer(_ answer: TestOption) {
        selectedAnswer = answer
        showResult = true
        print("✅ 已提交答案: \(answer.text)")
    }
    
    /// 手动移动到下一个单词
    func moveToNextWordManually() -> Bool {
        return moveToNextWord()
    }
    
    /// 开始测试
    func startTest(with words: [TestWord], test: VocabularyTest) {
        guard !isTestActive else { return }
        
        self.testWords = words
        self.currentTest = test
        self.currentWordIndex = 0
        self.testProgress = 0.0
        self.isTestActive = true
        self.isPaused = false
        self.isTestCompleted = false
        self.isCompletingTest = false
        
        // 会话管理：设置会话标识和类型
        self.currentSessionId = test.id
        self.isNewSession = test.isNewSession
        
        // 设置第一个单词
        updateCurrentWord()
        
        let sessionType = test.isNewSession ? "新会话" : "继续会话"
        print("✅ [TestStateManager] 测试开始: \(words.count) 个单词 (\(sessionType))")
    }
    
    /// 暂停测试
    func pauseTest() {
        guard canPauseTest else { return }
        isPaused = true
        print("⏸️ [TestStateManager] 测试已暂停")
    }
    
    /// 恢复测试
    func resumeTest() {
        guard canResumeTest else { return }
        isPaused = false
        print("▶️ [TestStateManager] 测试已恢复")
    }
    
    /// 停止测试
    func stopTest() {
        isTestActive = false
        isPaused = false
        currentWord = nil
        currentWordIndex = 0
        testWords = []
        testProgress = 0.0
        currentTest = nil
        isTestCompleted = false
        isCompletingTest = false
        
        print("🛑 [TestStateManager] 测试已停止")
    }
    
    /// 移动到下一个单词
    func moveToNextWord() -> Bool {
        guard isTestActive && !isPaused else { return false }
        guard currentWordIndex < testWords.count - 1 else { return false }
        
        currentWordIndex += 1
        updateCurrentWord()
        updateProgress()
        
        return true
    }
    
    /// 移动到上一个单词
    func moveToPreviousWord() -> Bool {
        guard isTestActive && !isPaused else { return false }
        guard currentWordIndex > 0 else { return false }
        
        // 保存当前状态到历史记录
        saveCurrentWordState()
        
        currentWordIndex -= 1
        updateCurrentWord()
        updateProgress()
        
        return true
    }
    
    /// 保存当前单词的测试状态
    func saveCurrentWordState() {
        let state = WordTestState(
            question: currentQuestion,
            selectedAnswer: selectedAnswer,
            showResult: showResult
        )
        wordStateHistory[currentWordIndex] = state
        print("💾 [TestStateManager] 保存单词状态 - 索引: \(currentWordIndex)")
    }
    
    /// 恢复指定索引单词的测试状态
    /// 恢复单词状态
    func restoreWordState(for index: Int) -> WordTestState? {
        let state = wordStateHistory[index]
        if state != nil {
            print("🔄 [TestStateManager] 恢复单词状态 - 索引: \(index)")
        }
        return state
    }
    
    /// 清除单词状态历史记录
    func clearWordStateHistory() {
        wordStateHistory.removeAll()
        print("🗑️ [TestStateManager] 清除单词状态历史记录")
    }
    
    /// 跳转到指定单词索引
    func jumpToWord(at index: Int) -> Bool {
        guard isTestActive else { return false }
        guard index >= 0 && index < testWords.count else { return false }
        
        currentWordIndex = index
        updateCurrentWord()
        updateProgress()
        
        return true
    }
    
    /// 完成测试
    func completeTest() -> Bool {
        guard isTestActive && !isCompletingTest else { return false }
        
        isCompletingTest = true
        isTestCompleted = true
        isTestActive = false
        isPaused = false
        testProgress = 1.0
        
        // 调用 VocabularyTest 的 completeTest 方法来更新统计数据
        if let test = currentTest {
            test.completeTest()
            print("📊 [TestStateManager] 已更新测试统计数据: 掌握(\(test.masteredCount)) 熟悉(\(test.familiarCount)) 陌生(\(test.unfamiliarCount))")
        }
        
        print("🎉 [TestStateManager] 测试完成")
        return true
    }
    
    /// 设置未完成测试信息
    func setIncompleteTestProgress(_ progress: TestProgress?) {
        self.incompleteTestProgress = progress
        self.hasIncompleteTest = progress != nil
        
        if progress != nil {
            showTestContinuationAlert = true
        }
    }
    
    /// 清除未完成测试信息
    func clearIncompleteTestProgress() {
        self.incompleteTestProgress = nil
        self.hasIncompleteTest = false
        self.showTestContinuationAlert = false
    }
    
    // MARK: - Private Methods
    
    /// 更新当前单词
    private func updateCurrentWord() {
        guard currentWordIndex >= 0 && currentWordIndex < testWords.count else {
            currentWord = nil
            return
        }
        
        currentWord = testWords[currentWordIndex]
    }
    
    /// 更新测试进度
    private func updateProgress() {
        guard !testWords.isEmpty else {
            testProgress = 0.0
            return
        }
        
        let progress = Double(currentWordIndex) / Double(testWords.count)
        testProgress = min(max(progress, 0.0), 1.0)
    }
    
    /// 设置测试单词
    func setTestWords(_ words: [TestWord]) {
        testWords = words
        updateCurrentWord()
        print("✅ [TestStateManager] 设置测试单词: \(words.count) 个")
    }
    /// 从VocabularyTest对象加载测试状态
    func loadTestState(from test: VocabularyTest) {
        print("🔄 [TestStateManager] 开始从测试记录加载状态...")
        
        // 恢复测试状态
        self.isTestActive = !test.isCompleted
        self.isPaused = test.isPaused
        
        // 恢复测试进度
        self.currentWordIndex = test.currentWordIndex
        self.testProgress = test.totalWords > 0 ? Double(test.currentWordIndex) / Double(test.totalWords) : 0.0
        
        // 清空测试单词数组（将在continueSelectedTest中重新加载）
        self.testWords = []
        
        // 设置当前测试
        self.currentTest = test
        
        print("✅ [TestStateManager] 测试状态加载完成 - 当前索引: \(currentWordIndex), 进度: \(testProgress), 已知: \(test.knownWords), 未知: \(test.unknownWords)")
    }
    
    /// 重置状态
    func reset() {
        stopTest()
        clearIncompleteTestProgress()
        clearWordStateHistory()
        showGroupCompletionAlert = false
        showResult = false
        selectedAnswer = nil
        currentQuestion = nil
        
        // 重置会话状态
        currentSessionId = nil
        isNewSession = true
        
        print("🔄 [TestStateManager] 状态已重置")
    }
}

// MARK: - Supporting Types

/// 单词测试状态
struct WordTestState {
    let question: TestQuestion?
    let selectedAnswer: TestOption?
    let showResult: Bool
}