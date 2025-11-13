//
//  VocabularyTestViewModel.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import SwiftData
import Combine
import Foundation
import OSLog

/// 测试大小模式
enum TestSizeMode: String, CaseIterable {
    case all = "全部测试"
    case grouped = "分组测试"
    
    var description: String {
        return self.rawValue
    }
}

/// 重构后的词汇量测试视图模型 - 主要负责协调各个管理器
@MainActor
class VocabularyTestViewModel: ObservableObject {
    
    // MARK: - Manager Dependencies
    
    /// 测试状态管理器
    @Published var testStateManager: TestStateManager
    
    /// 测试配置管理器
    @Published var configurationManager: TestConfigurationManager
    
    /// 测试结果管理器
    @Published var resultManager: TestResultManager
    
    // MARK: - Retest Mode Support
    
    /// 是否为重测模式
    let isRetestMode: Bool
    
    /// 重测配置
    let retestConfig: RetestConfig?
    
    // MARK: - Core Published Properties
    
    /// 是否正在加载
    @Published var isLoading: Bool = false
    
    /// 错误消息
    @Published var errorMessage: String?
    
    /// 当前测试问题
    @Published var currentQuestion: TestQuestion?
    
    /// 选中的答案
    @Published var selectedAnswer: TestOption?
    
    /// 是否显示结果
    @Published var showResult: Bool = false
    
    /// 选中的测试模式
    @Published var selectedTestMode: VocabularyTestMode = .englishToChinese
    
    // MARK: - Delegated Properties
    
    /// 可用词典列表
    var availableDictionaries: [DictionaryInfo] {
        configurationManager.availableDictionaries
    }
    
    /// 当前选中的词典
    var selectedDictionary: DictionaryInfo? {
        configurationManager.selectedDictionary
    }
    
    /// 可用分组列表
    var availableGroups: [String] {
        configurationManager.availableGroups
    }
    
    /// 选中的分组集合
    var selectedGroups: Set<String> {
        configurationManager.selectedGroups
    }
    
    /// 测试历史记录
    var testHistory: [VocabularyTest] {
        resultManager.testHistory
    }
    
    // MARK: - Additional Delegated Properties
    
    /// 是否有测试历史记录
    var hasTestHistory: Bool {
        !resultManager.testHistory.isEmpty
    }
    
    /// 测试大小模式
    var testSizeMode: TestSizeMode {
        get {
            switch configurationManager.testSize {
            case .all:
                return .all
            case .small, .medium, .large, .custom(_):
                return .grouped
            }
        }
        set {
            switch newValue {
            case .all:
                configurationManager.setTestSize(.all)
            case .grouped:
                configurationManager.setTestSize(.medium)
            }
        }
    }
    
    /// 总分组数
    var totalGroups: Int {
        configurationManager.availableGroups.count
    }
    
    /// 是否全选分组
    var isAllGroupsSelected: Bool {
        !configurationManager.availableGroups.isEmpty && 
        configurationManager.selectedGroups.count == configurationManager.availableGroups.count
    }
    
    /// 当前分组索引
    var currentGroupIndex: Int {
        testStateManager.currentWordIndex / 50 // 假设每组50个单词
    }
    
    /// 当前单词索引
    var currentWordIndex: Int {
        testStateManager.currentWordIndex
    }
    
    /// 测试单词列表
    var testWords: [TestWord] {
        testStateManager.testWords
    }
    
    /// 是否可以移动到上一个单词
    var canMoveToPrevious: Bool {
        testStateManager.currentWordIndex > 0
    }
    
    /// 是否可以移动到下一个单词
    var canMoveToNext: Bool {
        testStateManager.currentWordIndex < testStateManager.testWords.count - 1
    }
    
    // MARK: - 测试进度管理
    
    /// 是否存在未完成的测试
    @Published var hasIncompleteTest: Bool = false
    
    /// 未完成的测试记录
    @Published var incompleteTest: VocabularyTest?
    
    /// 检查是否存在未完成的测试
    private func checkForIncompleteTest(dictionaryFileName: String) {
        vocabularyTestService.getIncompleteTest(for: dictionaryFileName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.hasIncompleteTest = false
                        self?.incompleteTest = nil
                        self?.logger.error("❌ [VocabularyTestViewModel] 检查未完成测试失败: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] test in
                    guard let self = self else { return }
                    if let t = test {
                        if t.totalWords <= 0 || t.currentWordIndex == 0 || self.isRetestMode {
                            self.hasIncompleteTest = false
                            self.incompleteTest = nil
                            self.vocabularyTestService.deleteTestRecord(t)
                                .sink(
                                    receiveCompletion: { _ in },
                                    receiveValue: { _ in }
                                )
                                .store(in: &self.cancellables)
                            return
                        }
                        self.incompleteTest = t
                        self.hasIncompleteTest = true
                    } else {
                        self.hasIncompleteTest = false
                        self.incompleteTest = nil
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// 继续未完成的测试
    func continueIncompleteTest() {
        guard let test = incompleteTest else {
            logger.warning("⚠️ [VocabularyTestViewModel] 没有未完成的测试可以继续")
            errorMessage = "未找到可继续的未完成测试，请重新开始。"
            testStateManager.showTestContinuationAlert = false
            return
        }
        
        Task {
            await continueSelectedTest(test)
        }
    }
    
    /// 开始新测试（忽略未完成的测试）
    func startNewTest() {
        hasIncompleteTest = false
        incompleteTest = nil
        testStateManager.showTestContinuationAlert = false
        
        // 清理测试结果数据和统计信息
        resultManager.clearTestResults()
        
        // 会话隔离：标记为新测试会话，确保统计数据从零开始
        logger.info("🔄 [VocabularyTestViewModel] 开始新测试会话，启用会话隔离")
        
        startNewTestDirectly()
    }
    
    /// 自动保存测试进度
    private func saveTestProgress() async {
        guard let currentTest = testStateManager.currentTest else {
            logger.warning("⚠️ [VocabularyTestViewModel] 无法保存进度：当前测试为空")
            return
        }
        
        // 更新测试进度
        currentTest.currentWordIndex = testStateManager.currentWordIndex
        
        // 更新会话统计数据
        currentTest.sessionMasteredCount = resultManager.masteredCount
        currentTest.sessionFamiliarCount = resultManager.familiarCount
        currentTest.sessionUnfamiliarCount = resultManager.unfamiliarCount
        
        // 通过服务层保存到数据库
        do {
            try await withCheckedThrowingContinuation { continuation in
                vocabularyTestService.updateTestInDatabase(currentTest)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                continuation.resume(returning: ())
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { _ in
                            // 更新成功
                        }
                    )
                    .store(in: &cancellables)
            }
            logger.info("✅ [VocabularyTestViewModel] 测试进度已保存到数据库: \(testStateManager.currentWordIndex)/\(currentTest.totalWords), 会话统计: 掌握(\(currentTest.sessionMasteredCount)) 熟悉(\(currentTest.sessionFamiliarCount)) 陌生(\(currentTest.sessionUnfamiliarCount))")
        } catch {
            logger.error("❌ [VocabularyTestViewModel] 保存测试进度失败: \(error.localizedDescription)")
        }
    }
    
    /// 词汇测试服务
    private let vocabularyTestService: VocabularyTestServiceProtocol
    
    /// 词典服务
    private let dictionaryService: DictionaryServiceProtocol
    
    /// 错误处理器
    private let errorHandler: ErrorHandlerProtocol
    
    /// 学习跟踪服务
    private let learningTrackingService: LearningTrackingService?
    
    /// 干扰项生成器
    private let distractorGenerator: DistractorGenerator
    
    /// 导出服务
    private var _exportService: TestResultExportService?
    
    /// 导出服务（公开访问）
    var exportService: TestResultExportService? {
        return _exportService
    }
    
    /// 取消令牌集合
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.en01.viewmodels", category: "VocabularyTestViewModel")
    
    /// 当前测试任务
    private var currentTestTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    /// 是否可以开始测试
    var canStartTest: Bool {
        let baseCanStart = configurationManager.canStartTest && !testStateManager.isTestActive
        
        // 重测模式额外检查
        if isRetestMode {
            guard let retestConfig = retestConfig else { return false }
            return baseCanStart && !retestConfig.masteryLevels.isEmpty
        }
        
        return baseCanStart
    }
    
    /// 测试进度
    var testProgress: Double {
        return testStateManager.testProgress
    }
    
    /// 当前单词
    var currentWord: TestWord? {
        return testStateManager.currentWord
    }
    
    /// 是否测试激活
    var isTestActive: Bool {
        return testStateManager.isTestActive
    }
    
    /// 是否暂停
    var isPaused: Bool {
        return testStateManager.isPaused
    }
    
    /// 进度百分比文本
    var progressPercentage: String {
        let progress = testProgress * 100
        return String(format: "%.1f%%", progress)
    }
    
    /// 掌握的单词数
    var masteredCount: Int {
        return resultManager.masteredCount
    }
    
    /// 熟悉的单词数
    var familiarCount: Int {
        return resultManager.familiarCount
    }
    
    /// 不熟悉的单词数
    var unfamiliarCount: Int {
        return resultManager.unfamiliarCount
    }
    
    // MARK: - Initialization

    init(
        vocabularyTestService: VocabularyTestServiceProtocol,
        dictionaryService: DictionaryServiceProtocol,
        errorHandler: ErrorHandlerProtocol,
        learningTrackingService: LearningTrackingService? = nil,
        testResultExportService: TestResultExportService,
        appCoordinator: AppCoordinator? = nil,
        isRetestMode: Bool = false,
        retestConfig: RetestConfig? = nil
    ) {
        print("🚀 [VocabularyTestViewModel] 开始初始化")
        
        self.vocabularyTestService = vocabularyTestService
        self.dictionaryService = dictionaryService
        self.errorHandler = errorHandler
        self.learningTrackingService = learningTrackingService
        self.distractorGenerator = DistractorGenerator(dictionaryService: dictionaryService)
        self._exportService = testResultExportService
        
        // 重测模式支持
        self.isRetestMode = isRetestMode
        self.retestConfig = retestConfig
        
        // 初始化管理器
        self.testStateManager = TestStateManager()
        self.configurationManager = TestConfigurationManager(
            dictionaryService: dictionaryService as! DictionaryService,
            isRetestMode: isRetestMode,
            retestConfig: retestConfig
        )
        self.resultManager = TestResultManager(
            vocabularyTestService: vocabularyTestService as! VocabularyTestService,
            learningTrackingService: learningTrackingService ?? appCoordinator?.getLearningTrackingService() ?? Self.createDefaultLearningTrackingService(),
            exportService: testResultExportService,
            modelContext: (vocabularyTestService as! VocabularyTestService).modelContext,
            isRetestMode: isRetestMode
        )
        
        // 设置初始数据
        setupInitialData()
        // 桥接子管理器的发布事件到 ViewModel
        setupBindings()
        
        print("✅ [VocabularyTestViewModel] 初始化完成")
    }
    
    // MARK: - Setup Methods
    
    /// 设置初始数据
    private func setupInitialData() {
        // 仅在尚未加载词典时触发加载，避免重复
        isLoading = true
        Task {
            if self.availableDictionaries.isEmpty {
                await configurationManager.loadAvailableDictionaries()
            }
            await resultManager.loadTestHistory()
            await MainActor.run {
                self.isLoading = false
                self.logger.info("🔄 [VocabularyTestViewModel] 初始数据加载完成: 词典 \(self.availableDictionaries.count) 个, 历史 \(self.testHistory.count) 条")
            }
        }
    }
    
    /// 绑定子管理器的变更到 ViewModel，确保UI及时刷新
    private func setupBindings() {
        configurationManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        testStateManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        resultManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Test Management
    
    /// 开始测试
    func startTest() {
        guard canStartTest else {
            errorMessage = "无法开始测试，请检查配置"
            return
        }
        
        // 检查是否存在未完成的测试
        guard let selectedDictionary = configurationManager.selectedDictionary else {
            errorMessage = "请先选择词典"
            return
        }
        
        if isRetestMode {
            startNewTestDirectly()
            return
        }

        // 先检查未完成的测试
        checkForIncompleteTest(dictionaryFileName: selectedDictionary.fileName)
        
        // 如果有未完成的测试，显示选择对话框
        if hasIncompleteTest {
            testStateManager.showTestContinuationAlert = true
            return
        }
        
        // 没有未完成的测试，直接开始新测试
        startNewTestDirectly()
    }
    
    /// 直接开始新测试（内部方法）
    private func startNewTestDirectly() {
        currentTestTask?.cancel()
        currentTestTask = Task {
            await performStartTest()
        }
    }
    
    /// 执行开始测试
    private func performStartTest() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 验证配置
            let validationResult = configurationManager.validateConfiguration()
            guard validationResult.isValid else {
                throw TestError.invalidConfiguration(validationResult.errors.joined(separator: ", "))
            }
            
            // 创建测试实例（新测试）
            let test = try await createVocabularyTest()
            test.isNewSession = true  // 标记为新会话
            
            // 加载测试单词
            let testWords = try await loadTestWords()
            
            // 根据历史记录更新单词掌握状态（会话隔离：新测试跳过历史加载）
            await updateWordMasteryFromHistoryForNewTest(testWords: testWords, skipHistoryLoading: true)
            
            // 重置会话统计（新测试从0开始）
            resultManager.clearTestResults()
            
            // 开始测试
            testStateManager.startTest(with: testWords, test: test)
            
            // 生成第一个问题
            await generateCurrentQuestion()
            
            isLoading = false
            logger.info("✅ [VocabularyTestViewModel] 新测试开始成功")
            
        } catch {
            isLoading = false
            errorMessage = "开始测试失败: \(error.localizedDescription)"
            errorHandler.handle(AppError.unknown(error), context: "VocabularyTestViewModel.startTest")
            logger.error("❌ [VocabularyTestViewModel] 开始测试失败: \(error)")
        }
    }
    
    /// 为新测试根据历史记录更新单词掌握状态
    /// - Parameters:
    ///   - testWords: 测试单词列表
    ///   - skipHistoryLoading: 是否跳过历史记录加载（用于会话隔离）
    private func updateWordMasteryFromHistoryForNewTest(testWords: [TestWord], skipHistoryLoading: Bool = false) async {
        // 会话隔离：如果跳过历史加载，则不从历史记录更新掌握状态
        if skipHistoryLoading {
            logger.info("🔄 [VocabularyTestViewModel] 会话隔离模式：跳过历史记录加载，新测试统计数据从零开始")
            return
        }
        
        guard let selectedDictionary = configurationManager.selectedDictionary else {
            logger.warning("⚠️ [VocabularyTestViewModel] 没有选中的词典，跳过历史记录更新")
            return
        }
        
        do {
            let testedWords = try await withCheckedThrowingContinuation { continuation in
                vocabularyTestService.getTestedWords(for: selectedDictionary.fileName)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { testedWords in
                            continuation.resume(returning: testedWords)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            // 更新每个单词的掌握状态
            for word in testWords {
                let wordHistory = testedWords.filter { $0.word == word.word }
                if let latestRecord = wordHistory.max(by: { $0.testedAt < $1.testedAt }) {
                    // 根据最新的测试记录更新掌握状态
                    let masteryLevel = latestRecord.masteryLevelEnum
                    recordWordMastery(word: word, masteryLevel: masteryLevel)
                    logger.info("📊 [VocabularyTestViewModel] 新测试从历史记录更新单词掌握状态: \(word.word) -> \(masteryLevel)")
                }
            }
            
        } catch {
            logger.error("❌ [VocabularyTestViewModel] 新测试更新单词掌握状态失败: \(error.localizedDescription)")
        }
    }
    
    /// 创建词汇测试实例
    private func createVocabularyTest() async throws -> VocabularyTest {
        guard let dictionary = configurationManager.selectedDictionary else {
            throw TestError.noDictionarySelected
        }
        
        // 重测模式：创建重测实例
        if isRetestMode, let retestConfig = retestConfig {
            return try await withCheckedThrowingContinuation { continuation in
                vocabularyTestService.startRetestVocabularyTest(
                    dictionary: dictionary,
                    masteryLevels: Array(retestConfig.masteryLevels),
                    sampleSize: configurationManager.testSize.wordCount
                )
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { test in
                        continuation.resume(returning: test)
                    }
                )
                .store(in: &cancellables)
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: configurationManager.testSize.wordCount)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { test in
                        continuation.resume(returning: test)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    /// 加载测试单词
    private func loadTestWords() async throws -> [TestWord] {
        guard let dictionary = configurationManager.selectedDictionary else {
            throw TestError.noDictionarySelected
        }
        
        // 重测模式：只加载指定掌握度的单词
        if isRetestMode, let retestConfig = retestConfig {
            return try await loadRetestWords(dictionary: dictionary, masteryLevels: retestConfig.masteryLevels)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            vocabularyTestService.loadDictionaryWords(from: dictionary)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { words in
                        let testWords = words.map { word in
                            TestWord(
                                word: word.word,
                                pronunciation: word.phonetic,
                                definitions: word.definitions.map { $0.meaning },
                                examples: word.definitions.flatMap { $0.examples },
                                difficulty: word.difficulty,
                                frequency: word.frequency
                            )
                        }
                        continuation.resume(returning: testWords)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    /// 加载重测单词
    private func loadRetestWords(dictionary: DictionaryInfo, masteryLevels: Set<MasteryLevel>) async throws -> [TestWord] {
        return try await withCheckedThrowingContinuation { continuation in
            vocabularyTestService.loadWordsForRetest(dictionary: dictionary, masteryLevels: Array(masteryLevels), sampleSize: 100)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { words in
                        let testWords = words.map { word in
                            TestWord(
                                word: word.word,
                                pronunciation: word.phonetic,
                                definitions: word.definitions.map { $0.meaning },
                                examples: word.definitions.flatMap { $0.examples },
                                difficulty: word.difficulty,
                                frequency: word.frequency
                            )
                        }
                        continuation.resume(returning: testWords)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    /// 暂停测试
    func pauseTest() {
        testStateManager.pauseTest()
        print("⏸️ [VocabularyTestViewModel] 测试已暂停")
    }
    
    /// 恢复测试
    func resumeTest() {
        testStateManager.resumeTest()
        print("▶️ [VocabularyTestViewModel] 测试已恢复")
    }
    
    /// 停止测试
    func stopTest() {
        currentTestTask?.cancel()
        testStateManager.stopTest()
        currentQuestion = nil
        selectedAnswer = nil
        showResult = false
        print("🛑 [VocabularyTestViewModel] 测试已停止")
    }
    
    /// 完成测试
    func finishTest() {
        guard testStateManager.completeTest() else { return }
        
        Task {
            await saveTestResults()
        }
    }
    
    // MARK: - Question Management
    
    /// 生成当前问题
    private func generateCurrentQuestion() async {
        guard let currentWord = testStateManager.currentWord else { return }
        
        do {
            let question = try await generateQuestion(for: currentWord)
            await MainActor.run {
                self.currentQuestion = question
                self.selectedAnswer = nil
                self.showResult = false
            }
        } catch {
            errorMessage = "生成问题失败: \(error.localizedDescription)"
            print("❌ [VocabularyTestViewModel] 生成问题失败: \(error)")
        }
    }
    
    /// 生成问题
    private func generateQuestion(for word: TestWord) async throws -> TestQuestion {
        // 获取所有词典单词用于生成干扰项
        guard let dictionary = configurationManager.selectedDictionary else {
            throw TestError.noDictionarySelected
        }
        
        let allWords = try await withCheckedThrowingContinuation { continuation in
            vocabularyTestService.loadDictionaryWords(from: dictionary)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { words in
                        continuation.resume(returning: words)
                    }
                )
                .store(in: &cancellables)
        }
        
        let correctAnswer = getCorrectAnswer(for: word, mode: selectedTestMode)
        
        // 根据测试模式生成干扰项
        let distractors: [String]
        switch selectedTestMode {
        case .englishToChinese:
            distractors = distractorGenerator.generateEnglishToChineseDistractors(
                targetWord: word,
                correctDefinition: correctAnswer,
                allWords: allWords,
                count: 3
            )
        case .chineseToEnglish:
            distractors = distractorGenerator.generateChineseToEnglishDistractors(
                targetWord: word,
                correctWord: correctAnswer,
                allWords: allWords,
                count: 3
            )
        }
        
        let _ = createTestOptions(for: word, with: distractors)
        
        return TestQuestion(
            word: word,
            mode: selectedTestMode,
            distractors: distractors
        )
    }
    
    /// 创建测试选项
    private func createTestOptions(for word: TestWord, with distractors: [String]) -> [TestOption] {
        let correctAnswer = getCorrectAnswer(for: word, mode: selectedTestMode)
        var allOptions = distractors + [correctAnswer]
        allOptions.shuffle()
        
        return allOptions.enumerated().map { index, text in
            TestOption(text: text, isCorrect: text == correctAnswer)
        }
    }
    
    /// 获取正确答案
    private func getCorrectAnswer(for word: TestWord, mode: VocabularyTestMode) -> String {
        switch mode {
        case .englishToChinese:
            return word.primaryDefinition
        case .chineseToEnglish:
            return word.word
        }
    }
    
    // MARK: - Answer Management
    
    /// 选择答案
    func selectAnswer(_ option: TestOption) {
        selectedAnswer = option
        showResult = true
        
        // 记录测试结果
        recordTestResult(option)
        
        // 延迟移动到下一题
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.moveToNextQuestion()
        }
    }
    
    /// 记录测试结果
    private func recordTestResult(_ selectedOption: TestOption) {
        guard let currentWord = testStateManager.currentWord,
              let _ = currentQuestion else { return }
        
        let result = WordTestResult(
            word: currentWord.word,
            isKnown: selectedOption.isCorrect
        )
        
        resultManager.addTestResult(result)
        
        // 记录到服务层
        recordWordMastery(word: currentWord, isCorrect: selectedOption.isCorrect)
        
        // 自动保存测试进度
        Task {
            await saveTestProgress()
        }
    }
    
    /// 记录单词掌握度
    private func recordWordMastery(word: TestWord, isCorrect: Bool) {
        // 获取当前单词的掌握度，如果没有记录则默认为unfamiliar
        let currentMastery = getCurrentWordMastery(word: word.word)
        let masteryLevel = calculateNewMastery(currentMastery, correct: isCorrect)
        
        // 获取当前测试ID
        let testId = testStateManager.currentTest?.id
        
        // 统一通过 TestResultManager 处理，确保测试ID正确传递
        resultManager.recordWordMastery(word: word.word, mastery: masteryLevel, responseTime: 0.0, testId: testId)
        
        print("✅ [VocabularyTestViewModel] 单词掌握度记录: \(word.word) -> \(masteryLevel)")
    }
    
    /// 获取当前单词的掌握度
    private func getCurrentWordMastery(word: String) -> MasteryLevel {
        // 从结果管理器中查找该单词的历史掌握度
        // 如果没有记录，默认为unfamiliar
        return .unfamiliar // 简化实现，实际应该查询历史记录
    }
    
    /// 根据答案正确性计算新的掌握度
    /// 简化逻辑：答对=掌握，答错=陌生
    private func calculateNewMastery(_ currentMastery: MasteryLevel, correct: Bool) -> MasteryLevel {
        if correct {
            return .mastered  // 答对设为掌握
        } else {
            return .unfamiliar  // 答错设为陌生
        }
    }
    
    /// 移动到下一个问题
    private func moveToNextQuestion() {
        if testStateManager.moveToNextWord() {
            Task {
                await generateCurrentQuestion()
            }
        } else {
            // 测试完成
            finishTest()
        }
    }
    
    // MARK: - Result Management
    
    /// 保存测试结果
    private func saveTestResults() async {
        guard let currentTest = testStateManager.currentTest else { return }
        
        do {
            try await resultManager.saveTestResults(for: currentTest)
            print("✅ [VocabularyTestViewModel] 测试结果保存成功")
        } catch {
            errorMessage = "保存测试结果失败: \(error.localizedDescription)"
            print("❌ [VocabularyTestViewModel] 保存测试结果失败: \(error)")
        }
    }
    
    /// 公开的保存测试结果方法
    func saveTestResult(_ testResult: VocabularyTest, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                try await resultManager.saveTestResults(for: testResult)
                await MainActor.run {
                    completion(true)
                }
                print("✅ [VocabularyTestViewModel] 测试结果保存成功")
            } catch {
                await MainActor.run {
                    completion(false)
                    self.errorMessage = "保存测试结果失败: \(error.localizedDescription)"
                }
                print("❌ [VocabularyTestViewModel] 保存测试结果失败: \(error)")
            }
        }
    }
    
    // MARK: - Test History Management
    
    /// 选择测试继续
    func selectTestForContinuation(_ test: VocabularyTest) {
        // 检查测试是否真的未完成
        if test.isCompleted {
            logger.warning("⚠️ [VocabularyTestViewModel] 选择的测试已完成，无法继续: \(test.dictionaryName)")
            errorMessage = "该测试已完成，无法继续"
            return
        }
        
        // 设置选中的测试
        resultManager.selectTestForContinuation(test)
        
        // 加载测试数据并继续
        Task {
            await continueSelectedTest(test)
        }
    }
    
    /// 继续选中的测试
    private func continueSelectedTest(_ test: VocabularyTest) async {
        do {
            // 首先设置词典配置
            if let dictionary = configurationManager.availableDictionaries.first(where: { $0.fileName == test.dictionaryFileName }) {
                await configurationManager.selectDictionary(dictionary)
                
                // 确保使用当前有效的测试记录
                let currentTest = try await withCheckedThrowingContinuation { continuation in
                    vocabularyTestService.getCurrentTestForDictionary(test.dictionaryFileName)
                        .sink(
                            receiveCompletion: { completion in
                                switch completion {
                                case .finished:
                                    break
                                case .failure(let error):
                                    continuation.resume(throwing: error)
                                }
                            },
                            receiveValue: { currentTest in
                                continuation.resume(returning: currentTest)
                            }
                        )
                        .store(in: &cancellables)
                }
                
                // 使用当前有效的测试记录，如果没有则使用传入的测试记录
                let testToUse = currentTest ?? test
                
                // 重新加载测试单词
                let testWords = try await loadTestWords()
                
                // 重新加载测试状态
                testStateManager.loadTestState(from: testToUse)
                
                // 设置测试单词
                testStateManager.setTestWords(testWords)
                
                // 恢复会话统计数据到ResultManager
                resultManager.restoreSessionStats(
                    masteredCount: testToUse.sessionMasteredCount,
                    familiarCount: testToUse.sessionFamiliarCount,
                    unfamiliarCount: testToUse.sessionUnfamiliarCount
                )
                
                // 继续测试时不重新加载历史记录，保持当前会话状态
                logger.info("📊 [VocabularyTestViewModel] 继续测试，恢复会话状态 - 掌握:\(testToUse.sessionMasteredCount), 熟悉:\(testToUse.sessionFamiliarCount), 不熟悉:\(testToUse.sessionUnfamiliarCount)")
                
                // 生成当前问题
                await generateCurrentQuestion()
                
                logger.info("✅ [VocabularyTestViewModel] 继续测试: \(testToUse.dictionaryName), 当前进度: \(testStateManager.currentWordIndex)/\(testWords.count)")
            }
        } catch {
            errorMessage = "继续测试失败: \(error.localizedDescription)"
            errorHandler.handle(AppError.unknown(error))
        }
    }
    
    /// 根据历史记录更新单词掌握状态
    private func updateWordMasteryFromHistory(test: VocabularyTest, testWords: [TestWord]) async {
        // 获取该测试的历史记录
        do {
            let testedWords = try await withCheckedThrowingContinuation { continuation in
                vocabularyTestService.getTestedWords(for: test.dictionaryFileName)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { testedWords in
                            continuation.resume(returning: testedWords)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            // 更新每个单词的掌握状态
            for word in testWords {
                let wordHistory = testedWords.filter { $0.word == word.word }
                if let latestRecord = wordHistory.max(by: { $0.testedAt < $1.testedAt }) {
                    // 根据最新的测试记录更新掌握状态
                    let masteryLevel = latestRecord.masteryLevelEnum
                    recordWordMastery(word: word, masteryLevel: masteryLevel)
                    logger.info("📊 [VocabularyTestViewModel] 从历史记录更新单词掌握状态: \(word.word) -> \(masteryLevel)")
                }
            }
            
        } catch {
            logger.error("❌ [VocabularyTestViewModel] 更新单词掌握状态失败: \(error.localizedDescription)")
        }
    }
    
    /// 加载测试历史
    func loadTestHistory() {
        Task {
            await resultManager.loadTestHistory()
        }
    }
    
    /// 从历史中删除测试
    func deleteTestFromHistory(_ test: VocabularyTest) {
        resultManager.deleteTestFromHistory(test)
    }
    
    // MARK: - Dictionary Management (Delegated)
    
    /// 选择词典
    func selectDictionary(_ dictionary: DictionaryInfo) {
        isLoading = true
        Task {
            // 词典切换时重置所有测试相关状态
            await resetTestStateForDictionarySwitch()
            
            await configurationManager.selectDictionary(dictionary)
            
            // 为新词典加载专属的测试历史记录
            await loadTestHistoryForDictionary(dictionary.fileName)
            
            // 检查是否存在未完成的测试
            checkForIncompleteTest(dictionaryFileName: dictionary.fileName)
            
            await MainActor.run {
                self.isLoading = false
                self.logger.info("✅ [VocabularyTestViewModel] 词典选择完成: \(dictionary.name), 分组 \(self.availableGroups.count) 个")
            }
        }
    }
    
    /// 词典切换时重置测试状态
    private func resetTestStateForDictionarySwitch() async {
        await MainActor.run {
            // 停止当前测试
            if testStateManager.isTestActive {
                testStateManager.stopTest()
            }
            
            // 重置测试状态
            testStateManager.reset()
            
            // 清除当前问题和答案
            currentQuestion = nil
            selectedAnswer = nil
            showResult = false
            
            // 重置未完成测试状态
            hasIncompleteTest = false
            incompleteTest = nil
            
            // 清除错误消息
            errorMessage = nil
            
            logger.info("🔄 [VocabularyTestViewModel] 词典切换时已重置测试状态")
        }
    }
    
    /// 为指定词典加载专属的测试历史记录
    private func loadTestHistoryForDictionary(_ dictionaryFileName: String) async {
        await resultManager.loadTestHistory(for: dictionaryFileName)
        await MainActor.run {
            logger.info("✅ [VocabularyTestViewModel] 已加载词典 \(dictionaryFileName) 的测试历史记录: \(self.testHistory.count) 条")
        }
    }
    
    /// 切换分组选择
    func toggleGroupSelection(_ group: String) {
        configurationManager.toggleGroupSelection(group)
    }
    
    /// 设置测试模式
    func setTestMode(_ mode: TestMode) {
        configurationManager.setTestMode(mode)
    }
    
    /// 设置测试大小
    func setTestSize(_ size: TestSize) {
        configurationManager.setTestSize(size)
    }
    
    // MARK: - Export Management (Delegated)
    
    /// 设置导出服务
    func setExportService(_ service: TestResultExportService) {
        self._exportService = service
    }
    
    /// 导出测试结果
    func exportTestResults(format: ExportFormat) async throws -> URL {
        return try await resultManager.exportTestResults(format: format)
    }
    
    /// 导出词汇测试单词
    func exportVocabularyTestWords(format: ExportFormat) {
        Task {
            do {
                guard let exportService = _exportService else {
                    print("❌ 导出服务未初始化")
                    return
                }
                
                let dictionaryName = selectedDictionary?.name ?? "Unknown"
                let _ = try await exportService.exportTestResults(for: dictionaryName, format: format)
                print("✅ 导出成功")
            } catch {
                print("❌ 导出失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 检查是否有可导出的数据
    func hasExportableData(for dictionaryName: String) -> Bool {
        return !testHistory.filter { $0.dictionaryName == dictionaryName }.isEmpty
    }
    
    /// 导出状态
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var exportError: String?
    
    /// 清除导出错误
    func clearExportError() {
        exportError = nil
    }
    
    /// 清除一般错误
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Bridge Methods
    
    /// 加载可用词典
    func loadAvailableDictionaries() {
        // 幂等控制：如果已有数据则跳过，避免多处触发导致 UI 一直加载
        if !availableDictionaries.isEmpty {
            logger.info("↩️ [VocabularyTestViewModel] 跳过重复加载词典（已有数据）")
            return
        }
        isLoading = true
        Task {
            await configurationManager.loadAvailableDictionaries()
            await MainActor.run {
                self.isLoading = false
                self.logger.info("📚 [VocabularyTestViewModel] 可用词典加载完成: \(self.availableDictionaries.count)")
            }
        }
    }
    
    /// 取消所有任务
    func cancelAllTasks() {
        currentTestTask?.cancel()
        testStateManager.cancelAllTasks()
    }
    
    /// 选择测试模式
    func selectTestMode(_ mode: VocabularyTestMode) {
        selectedTestMode = mode
        let testMode: TestMode = .sequential
        configurationManager.setTestMode(testMode)
    }
    
    /// 切换全选分组
    func toggleAllGroups() {
        if isAllGroupsSelected {
            configurationManager.clearGroupSelection()
        } else {
            configurationManager.selectAllGroups()
        }
    }
    
    /// 选择测试大小模式
    func selectTestSizeMode(_ mode: TestSizeMode) {
        testSizeMode = mode
    }
    
    /// 选择测试大小
    func selectTestSize(_ size: Int) {
        configurationManager.setTestSize(.custom(size))
    }
    
    /// 提交答案
    func submitAnswer() {
        guard let selectedOption = selectedAnswer else { return }
        testStateManager.submitAnswer(selectedOption)
        selectedAnswer = nil
    }
    
    /// 移动到上一个单词
    func moveToPreviousWord() {
        // 检查是否可以回退
        guard testStateManager.canMoveToPrevious else {
            logger.info("⚠️ [VocabularyTestViewModel] 无法回退：已经是第一个单词")
            return
        }
        
        // 保存当前单词的测试状态
        testStateManager.saveCurrentWordState()
        
        // 移动到上一个单词
        if testStateManager.moveToPreviousWord() {
            logger.info("🔄 [VocabularyTestViewModel] 回退到上一个单词，索引: \(testStateManager.currentWordIndex)")
            
            // 尝试恢复上一个单词的测试状态
            if let previousState = testStateManager.restoreWordState(for: testStateManager.currentWordIndex) {
                // 恢复之前的测试状态
                currentQuestion = previousState.question
                selectedAnswer = previousState.selectedAnswer
                showResult = previousState.showResult
                
                logger.info("✅ [VocabularyTestViewModel] 恢复了上一个单词的测试状态")
            } else {
                // 如果没有保存的状态，重新生成问题
                currentQuestion = nil
                selectedAnswer = nil
                showResult = false
                
                Task {
                    await generateCurrentQuestion()
                }
                
                logger.info("🔄 [VocabularyTestViewModel] 为上一个单词重新生成问题")
            }
        }
    }
    
    /// 手动移动到下一个单词
    func moveToNextWordManually() {
        if testStateManager.moveToNextWordManually() {
            // 移动成功后重新生成问题
            Task {
                await generateCurrentQuestion()
            }
        }
    }
    
    /// 移动到下一个单词
    func moveToNextWord() {
        // 在移动到下一个单词前，将当前单词标记为陌生
        if let currentWord = testStateManager.currentWord {
            recordWordMastery(word: currentWord, masteryLevel: .unfamiliar)
            logger.info("📝 [VocabularyTestViewModel] 通过'下一个'按钮将单词标记为陌生: \(currentWord.word)")
        }
        
        if testStateManager.moveToNextWord() {
            // 移动成功后重新生成问题
            Task {
                await generateCurrentQuestion()
            }
        }
    }
    
    /// 选择掌握程度
    func selectMasteryLevel(_ mastery: MasteryLevel) {
        guard let currentWord = testStateManager.currentWord else { return }
        
        // 记录掌握程度
        recordWordMastery(word: currentWord, masteryLevel: mastery)
        
        // 移动到下一个单词
        moveToNextQuestion()
    }
    

    
    /// 记录单词掌握程度
    private func recordWordMastery(word: TestWord, masteryLevel: MasteryLevel) {
        // 获取当前测试ID
        let testId = testStateManager.currentTest?.id
        
        // 更新结果管理器，传递测试ID
        resultManager.recordWordMastery(word: word.word, mastery: masteryLevel, responseTime: 0.0, testId: testId)
        
        // 如果有学习跟踪服务，记录学习数据
        if let trackingService = learningTrackingService {
            Task {
                trackingService.recordWordMastery(
                    word: word.word,
                    mastery: masteryLevel,
                    responseTime: 0.0
                )
                print("✅ [VocabularyTestViewModel] 学习跟踪记录成功")
            }
        }
    }

    // MARK: - Helper Methods
    
    /// 创建默认的 LearningTrackingService
    private static func createDefaultLearningTrackingService() -> LearningTrackingService {
        // 创建临时的 ModelContainer 和 ModelContext
        let container = try! ModelContainer(for: UserWord.self, LearningRecord.self)
        let context = ModelContext(container)
        
        // 创建默认的依赖
        let cacheManager = CacheManager()
        let errorHandler = ErrorHandler()
        
        return LearningTrackingService(
            modelContext: context,
            cacheManager: cacheManager,
            errorHandler: errorHandler
        )
    }
    
    // MARK: - Cleanup
    
    deinit {
        currentTestTask?.cancel()
        cancellables.removeAll()
        print("🔄 [VocabularyTestViewModel] 已清理")
    }
}

// MARK: - Supporting Types

/// 重测配置
struct RetestConfig {
    let masteryLevels: Set<MasteryLevel>
    let selectedDictionaries: Set<String>?
    let wordCount: Int?
    let randomOrder: Bool?
    let testSize: TestSize?
    let includeTestedWords: Bool?
    
    init(
        masteryLevels: Set<MasteryLevel>,
        selectedDictionaries: Set<String>? = nil,
        wordCount: Int? = nil,
        randomOrder: Bool? = nil,
        testSize: TestSize? = nil,
        includeTestedWords: Bool? = nil
    ) {
        self.masteryLevels = masteryLevels
        self.selectedDictionaries = selectedDictionaries
        self.wordCount = wordCount
        self.randomOrder = randomOrder
        self.testSize = testSize
        self.includeTestedWords = includeTestedWords
    }
}

/// 测试错误
enum TestError: LocalizedError {
    case noDictionarySelected
    case invalidConfiguration(String)
    case noWordsAvailable
    case testAlreadyActive
    case retestConfigurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .noDictionarySelected:
            return "请先选择一个词典"
        case .invalidConfiguration(let message):
            return "配置无效: \(message)"
        case .noWordsAvailable:
            return "没有可用的测试单词"
        case .testAlreadyActive:
            return "测试已经在进行中"
        case .retestConfigurationError(let message):
            return "重测配置错误: \(message)"
        }
    }
}

// MARK: - Notification Extensions
// 注释掉重复的通知定义，使用 NotificationNames.swift 中的定义
// extension Notification.Name {
//     static let statisticsDataUpdated = Notification.Name("statisticsDataUpdated")
// }
