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

/// 词汇量测试ViewModel，负责词汇量测试功能
@MainActor
class VocabularyTestViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var availableDictionaries: [DictionaryInfo] = []
    @Published var selectedDictionary: DictionaryInfo?
    @Published var isLoading: Bool = false
    @Published var isLoadingDictionaries: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Test State
    @Published var isTestActive: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentWord: TestWord?
    @Published var currentWordIndex: Int = 0
    @Published var testWords: [TestWord] = []
    @Published var testProgress: Double = 0.0
    
    // MARK: - Test Mode
    @Published var selectedTestMode: VocabularyTestMode = .englishToChinese
    @Published var currentQuestion: TestQuestion?
    @Published var selectedAnswer: TestOption?
    @Published var showResult: Bool = false
    
    // MARK: - Group Selection
    @Published var availableGroups: [String] = []
    @Published var selectedGroups: Set<String> = []
    @Published var isAllGroupsSelected: Bool = true
    
    // MARK: - Test Results
    @Published var masteredCount: Int = 0
    @Published var familiarCount: Int = 0
    @Published var unfamiliarCount: Int = 0
    @Published var totalTestedCount: Int = 0
    
    // MARK: - Test History
    @Published var testHistory: [VocabularyTest] = []
    @Published var currentTest: VocabularyTest?
    
    // 存储测试过程中的单词掌握程度数据
    private var wordMasteryResults: [String: MasteryLevel] = [:]
    
    // MARK: - Services
    private let vocabularyTestService: VocabularyTestServiceProtocol
    private let dictionaryService: DictionaryServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    private let distractorGenerator: DistractorGenerator
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Cached Data
    private var allDictionaryWords: [DictionaryWord] = []
    
    // MARK: - Constants
    private let batchSize = 50 // 分批加载大小
    // 移除单词数量限制，允许测试所有单词
    // private let maxTestWords = 200 // 最大测试单词数
    
    // MARK: - Initialization
    init(
        vocabularyTestService: VocabularyTestServiceProtocol,
        dictionaryService: DictionaryServiceProtocol,
        errorHandler: ErrorHandlerProtocol
    ) {
        self.vocabularyTestService = vocabularyTestService
        self.dictionaryService = dictionaryService
        self.errorHandler = errorHandler
        self.distractorGenerator = DistractorGenerator(dictionaryService: dictionaryService)
        
        loadAvailableDictionaries()
        loadTestHistory()
    }
    
    // MARK: - Dictionary Management
    func loadAvailableDictionaries() {
        isLoadingDictionaries = true
        errorMessage = nil
        
        dictionaryService.getAvailableDictionaries()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] (completion: Subscribers.Completion<Error>) in
                    self?.isLoadingDictionaries = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = "加载词典失败"
                        self?.errorHandler.handle(error, context: "VocabularyTestViewModel.loadAvailableDictionaries")
                    }
                },
                receiveValue: { [weak self] (dictionaries: [DictionaryInfo]) in
                    self?.availableDictionaries = dictionaries
                    self?.errorHandler.logSuccess("成功加载 \(dictionaries.count) 个词典")
                }
            )
            .store(in: &cancellables)
    }
    
    func selectDictionary(_ dictionary: DictionaryInfo) {
        selectedDictionary = dictionary
        loadAvailableGroups(for: dictionary)
        errorHandler.logSuccess("选择词典: \(dictionary.name)")
    }
    
    func selectTestMode(_ mode: VocabularyTestMode) {
        selectedTestMode = mode
        errorHandler.logSuccess("选择测试模式: \(mode.displayName)")
    }
    
    // MARK: - Group Management
    private func loadAvailableGroups(for dictionary: DictionaryInfo) {
        // 从词典的categories属性中获取可用分组
        availableGroups = dictionary.categories
        
        // 默认选择所有分组
        selectedGroups = Set(dictionary.categories)
        isAllGroupsSelected = true
        
        errorHandler.logSuccess("加载词典分组: \(dictionary.categories.joined(separator: ", "))")
    }
    
    func toggleGroupSelection(_ group: String) {
        if selectedGroups.contains(group) {
            selectedGroups.remove(group)
        } else {
            selectedGroups.insert(group)
        }
        updateAllGroupsSelection()
        errorHandler.logSuccess("切换分组选择: \(group)")
    }
    
    func toggleAllGroups() {
        if isAllGroupsSelected {
            selectedGroups.removeAll()
        } else {
            selectedGroups = Set(availableGroups)
        }
        updateAllGroupsSelection()
        errorHandler.logSuccess("切换全部分组选择: \(isAllGroupsSelected ? "取消全选" : "全选")")
    }
    
    private func updateAllGroupsSelection() {
        isAllGroupsSelected = selectedGroups.count == availableGroups.count && !availableGroups.isEmpty
    }
    
    // MARK: - Test Management
    func startTest(with dictionary: DictionaryInfo? = nil, sampleSize: Int? = nil, completion: ((Bool) -> Void)? = nil) {
        let targetDictionary = dictionary ?? selectedDictionary
        guard let targetDictionary = targetDictionary else {
            errorMessage = "请先选择词典"
            completion?(false)
            return
        }
        
        let testSampleSize = sampleSize ?? targetDictionary.totalWords
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 创建新的测试记录
                let test = VocabularyTest(
                    dictionaryName: targetDictionary.name,
                    sampleSize: testSampleSize,
                    difficultyRange: "1-4"
                )
                test.dictionaryFileName = targetDictionary.fileName
                test.totalWords = targetDictionary.totalWords
                
                // 检查是否有已测试的单词，优先从未测试的单词开始
                let words = try await loadUntestedWords(from: targetDictionary, sampleSize: testSampleSize)
                
                // 加载已测试单词的统计信息
                let testedWordsPublisher = vocabularyTestService.getTestedWords(for: targetDictionary.fileName)
                let testedWords = try await withCheckedThrowingContinuation { continuation in
                    testedWordsPublisher
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
                let masteredWords = testedWords.filter { $0.masteryLevel == MasteryLevel.mastered.rawValue }
                let familiarWords = testedWords.filter { $0.masteryLevel == MasteryLevel.familiar.rawValue }
                let unfamiliarWords = testedWords.filter { $0.masteryLevel == MasteryLevel.unfamiliar.rawValue }
                
                await MainActor.run {
                    self.currentTest = test
                    self.testWords = words
                    self.currentWordIndex = 0
                    self.currentWord = words.first
                    self.generateCurrentQuestion()
                    self.isTestActive = true
                    self.isPaused = false
                    
                    // 恢复已测试单词的统计信息
                    self.masteredCount = masteredWords.count
                    self.familiarCount = familiarWords.count
                    self.unfamiliarCount = unfamiliarWords.count
                    self.totalTestedCount = testedWords.count
                    
                    self.updateProgress()
                    self.isLoading = false
                }
                
                completion?(true)
                let totalWords = words.count + testedWords.count
                errorHandler.logSuccess("开始词汇量测试，共 \(totalWords) 个单词，其中 \(testedWords.count) 个已测试，\(words.count) 个未测试")
            } catch {
                await MainActor.run {
                    self.errorMessage = "开始测试失败"
                    self.isLoading = false
                }
                completion?(false)
                errorHandler.handle(error, context: "VocabularyTestViewModel.startTest")
            }
        }
    }
    
    private func loadUntestedWords(from dictionary: DictionaryInfo, sampleSize: Int) async throws -> [TestWord] {
        // 获取未测试的单词
        let untestedWords = try await withCheckedThrowingContinuation { continuation in
            vocabularyTestService.getUntestedWords(from: dictionary)
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
        
        // 缓存所有词典单词供干扰项生成使用
        let allWords = try await loadDictionaryWords(from: dictionary)
        await MainActor.run {
            self.allDictionaryWords = allWords
        }
        
        // 如果没有未测试的单词，返回空数组
        guard !untestedWords.isEmpty else {
            return []
        }
        
        // 随机打乱未测试单词顺序并取样
        let testWords = untestedWords.shuffled().prefix(sampleSize).map { word in
            TestWord(
                word: word.word,
                pronunciation: word.phonetic ?? "",
                definitions: word.definitions.map { $0.meaning },
                examples: word.definitions.flatMap { $0.examples },
                difficulty: word.difficulty,
                frequency: word.frequency
            )
        }
        
        return Array(testWords)
    }
    
    private func loadTestWords(from dictionary: DictionaryInfo, sampleSize: Int) async throws -> [TestWord] {
        // 直接使用async/await模式，避免在Publisher中使用continuation导致死锁
        let allWords = try await loadDictionaryWords(from: dictionary)
        
        // 缓存所有词典单词供干扰项生成使用
        await MainActor.run {
            self.allDictionaryWords = allWords
        }
        
        // 根据选择的分组过滤单词
        let filteredWords: [DictionaryWord]
        if selectedGroups.isEmpty {
            // 如果没有选择分组，使用所有单词
            filteredWords = allWords
        } else {
            // 根据选择的分组过滤单词
            filteredWords = allWords.filter { word in
                // 检查单词是否属于任何选中的分组
                selectedGroups.contains { groupName in
                    word.categories?.contains(groupName) ?? false
                }
            }
        }
        
        // 随机打乱单词顺序并取样
        let testWords = filteredWords.shuffled().prefix(sampleSize).map { word in
            TestWord(
                word: word.word,
                pronunciation: word.phonetic ?? "",
                definitions: word.definitions.map { $0.meaning },
                examples: word.definitions.flatMap { $0.examples },
                difficulty: word.difficulty,
                frequency: word.frequency
            )
        }
        
        return Array(testWords)
    }
    
    // 辅助方法：简化异步逻辑，避免死锁
    private func loadDictionaryWords(from dictionary: DictionaryInfo) async throws -> [DictionaryWord] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[DictionaryWord], Error>) in
            var cancellable: AnyCancellable?
            var isCompleted = false
            
            cancellable = dictionaryService.loadDictionary(fileName: dictionary.fileName)
                .timeout(.seconds(30), scheduler: DispatchQueue.global())
                .sink(
                    receiveCompletion: { completion in
                        guard !isCompleted else { return }
                        isCompleted = true
                        
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { allWords in
                        guard !isCompleted else { return }
                        isCompleted = true
                        
                        continuation.resume(returning: allWords)
                        cancellable?.cancel()
                    }
                )
        }
    }
    
    func pauseTest() {
        guard isTestActive else { return }
        isPaused = true
        errorHandler.logSuccess("暂停词汇量测试")
    }
    
    func resumeTest() {
        guard isTestActive && isPaused else { return }
        isPaused = false
        errorHandler.logSuccess("恢复词汇量测试")
    }
    
    func stopTest() {
        guard isTestActive else { return }
        
        Task {
            if let test = currentTest {
                vocabularyTestService.completeTest(testId: test.id)
                    .receive(on: DispatchQueue.main)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                self.errorHandler.logSuccess("测试完成")
                            case .failure(let error):
                                self.errorHandler.handle(error, context: "完成测试")
                            }
                        },
                        receiveValue: { _ in
                            // 测试完成处理
                        }
                    )
                    .store(in: &cancellables)
            }
            
            await MainActor.run {
                self.finishTest()
            }
            
            errorHandler.logSuccess("结束词汇量测试")
        }
    }
    
    private func finishTest() {
        isTestActive = false
        isPaused = false
        loadTestHistory() // 刷新历史记录
    }
    
    // MARK: - Question Generation
    private func generateCurrentQuestion() {
        guard let word = currentWord else {
            currentQuestion = nil
            return
        }
        
        // 生成智能干扰项
        let distractors: [String]
        switch selectedTestMode {
        case .englishToChinese:
            let correctDefinition = word.definitions.first ?? ""
            distractors = distractorGenerator.generateEnglishToChineseDistractors(
                targetWord: word,
                correctDefinition: correctDefinition,
                allWords: allDictionaryWords,
                count: 3
            )
        case .chineseToEnglish:
            distractors = distractorGenerator.generateChineseToEnglishDistractors(
                targetWord: word,
                correctWord: word.word,
                allWords: allDictionaryWords,
                count: 3
            )
        }
        
        currentQuestion = TestQuestion(word: word, mode: selectedTestMode, distractors: distractors)
        selectedAnswer = nil
    }
    
    func selectAnswer(_ option: TestOption) {
        selectedAnswer = option
    }
    
    func submitAnswer() {
        guard let _ = currentQuestion,
              let answer = selectedAnswer else {
            errorHandler.handle(VocabularyTestError.invalidTestData, context: "提交答案时缺少必要数据")
            return
        }
        
        // 显示答案结果
        showResult = true
        
        // 2秒后自动进入下一题
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            // 根据答案正确性确定掌握程度
            let isCorrect = answer.isCorrect
            let masteryLevel: MasteryLevel = isCorrect ? .mastered : .unfamiliar
            
            // 隐藏结果并进入下一题
            self.showResult = false
            self.selectMasteryLevel(masteryLevel)
        }
    }
    
    // MARK: - Word Testing
    func selectMasteryLevel(_ level: MasteryLevel) {
        guard let word = currentWord, let test = currentTest else {
            errorHandler.handle(VocabularyTestError.invalidTestData, context: "选择掌握程度时缺少必要数据")
            return
        }
        
        // 防止重复选择
        guard !isLoading else { return }
        
        // 立即更新UI状态
        isLoading = true
        
        // 立即更新统计和移动到下一个单词，不等待异步操作
        updateTestResults(for: level)
        
        // 阶段性保存已测试单词
        Task {
            do {
                // 将TestWord转换为DictionaryWord
                let wordDefinitions = word.definitions.map { definition in
                    WordDefinition(
                        partOfSpeech: .noun, // 默认词性，实际应用中可能需要更智能的判断
                        meaning: definition,
                        englishMeaning: nil,
                        examples: word.examples ?? [],
                        contextKeywords: []
                    )
                }
                
                let dictionaryWord = DictionaryWord(
                    word: word.word,
                    phonetic: word.pronunciation,
                    definitions: wordDefinitions,
                    frequency: word.frequency,
                    difficulty: word.difficulty,
                    tags: [],
                    categories: nil
                )
                
                // 使用VocabularyTestService的saveTestedWord方法
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    vocabularyTestService.saveTestedWord(
                        dictionaryWord,
                        mastery: level,
                        dictionaryName: test.dictionaryName,
                        dictionaryFileName: test.dictionaryFileName,
                        testSessionId: test.id
                    )
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: ())
                            }
                        },
                        receiveValue: { _ in
                            // 保存成功
                        }
                    )
                    .store(in: &cancellables)
                }
                
                await MainActor.run {
                    self.errorHandler.logSuccess("保存已测试单词: \(word.word)")
                }
                
                // 发送学习进度更新通知
                if let userWord = try? await self.dictionaryService.lookupWord(word.word) {
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("WordLearningProgressUpdated"),
                            object: userWord
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorHandler.handle(error, context: "保存已测试单词")
                }
            }
        }
        
        let testEnded = moveToNextWord()
        
        // 立即重置loading状态，避免UI卡死
        isLoading = false
        
        // 如果测试结束，直接返回
        if testEnded {
            return
        }
        
        // 异步记录单词点击（不阻塞UI，也不影响loading状态）
        vocabularyTestService.recordWordClick(word: word.word, testId: test.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    switch completion {
                    case .finished:
                        self.errorHandler.logSuccess("记录单词点击: \(word.word)")
                    case .failure(let error):
                        self.errorHandler.handle(error, context: "记录单词点击")
                    }
                },
                receiveValue: { _ in
                    // 记录成功，无需额外操作
                }
            )
            .store(in: &cancellables)
    }
    
    private func updateTestResults(for level: MasteryLevel) {
        // 记录当前单词的掌握程度
        if let word = currentWord {
            wordMasteryResults[word.word] = level
        }
        
        switch level {
        case .mastered:
            masteredCount += 1
        case .familiar:
            familiarCount += 1
        case .unfamiliar:
            unfamiliarCount += 1
        }
        totalTestedCount += 1
    }
    
    private func moveToNextWord() -> Bool {
        currentWordIndex += 1
        
        if currentWordIndex < testWords.count {
            currentWord = testWords[currentWordIndex]
            generateCurrentQuestion()
            updateProgress()
            return false // 测试未结束
        } else {
            // 测试完成，先保存测试结果再停止测试
            completeTestWithResults()
            return true // 测试已结束
        }
    }
    
    private func completeTestWithResults() {
        guard let test = currentTest else {
            finishTest()
            return
        }
        
        // 创建测试结果
        let testResult = VocabularyTest(
            id: test.id,
            dictionaryName: test.dictionaryName,
            dictionaryFileName: test.dictionaryFileName,
            totalWords: testWords.count,
            masteredCount: masteredCount,
            familiarCount: familiarCount,
            unfamiliarCount: unfamiliarCount,
            currentWordIndex: currentWordIndex,
            isCompleted: true,
            isPaused: false,
            createdAt: test.createdAt,
            completedAt: Date(),
            estimatedVocabularySize: masteredCount + familiarCount,
            accuracyPercentage: Double(masteredCount + familiarCount) / Double(testWords.count) * 100
        )
        
        // 同步更新单词掌握程度到词汇表
        syncTestResultsToVocabulary()
        
        // 保存测试结果
        vocabularyTestService.saveTestResult(testResult)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    switch completion {
                    case .finished:
                        self.errorHandler.logSuccess("测试结果保存成功")
                    case .failure(let error):
                        self.errorHandler.handle(error, context: "保存测试结果")
                    }
                    
                    // 无论保存成功与否，都完成测试
                    self.finishTest()
                },
                receiveValue: { _ in
                    // 保存成功
                }
            )
            .store(in: &cancellables)
    }
    
    private func updateProgress() {
        guard !testWords.isEmpty else { return }
        testProgress = Double(currentWordIndex) / Double(testWords.count)
    }
    
    private func resetTestResults() {
        masteredCount = 0
        familiarCount = 0
        unfamiliarCount = 0
        totalTestedCount = 0
        testProgress = 0.0
        wordMasteryResults.removeAll()
    }
    
    // MARK: - Data Synchronization
    private func syncTestResultsToVocabulary() {
        // 通过DictionaryService更新单词掌握程度
        Task {
            for (word, masteryLevel) in wordMasteryResults {
                if let userWord = try? await dictionaryService.lookupWord(word) {
                    dictionaryService.updateWordMastery(userWord, level: masteryLevel)
                }
            }
            
            // 通知其他ViewModel刷新数据
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("VocabularyTestCompleted"),
                    object: nil,
                    userInfo: [
                        "masteredCount": masteredCount,
                        "familiarCount": familiarCount,
                        "unfamiliarCount": unfamiliarCount,
                        "totalWords": testWords.count
                    ]
                )
            }
            
            errorHandler.logSuccess("测试结果已同步到词汇表，共更新 \(wordMasteryResults.count) 个单词")
        }
    }
    
    // MARK: - Test History
    func loadTestHistory() {
        vocabularyTestService.getTestHistory(limit: 20)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to load test history: \(error)")
                    }
                },
                receiveValue: { [weak self] (tests: [VocabularyTest]) in
                    self?.testHistory = tests
                }
            )
            .store(in: &cancellables)
    }
    
    func deleteTestFromHistory(_ test: VocabularyTest) {
        vocabularyTestService.deleteTest(testId: test.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to delete test: \(error)")
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadTestHistory() // 重新加载历史记录
                }
            )
            .store(in: &cancellables)
    }
    
    func saveTestResult(_ testResult: VocabularyTest, completion: @escaping (Bool) -> Void) {
        vocabularyTestService.saveTestResult(testResult)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] publisherCompletion in
                    guard let self = self else { return }
                    switch publisherCompletion {
                    case .finished:
                        self.errorHandler.logSuccess("保存测试结果成功")
                    case .failure(let error):
                        self.errorHandler.handle(error, context: "保存测试结果")
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self = self else { return }
                    // 更新历史记录
                    if !self.testHistory.contains(where: { $0.id == testResult.id }) {
                        self.testHistory.insert(testResult, at: 0)
                    }
                    completion(true)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Progressive Test Management
    func clearTestProgress(for dictionary: DictionaryInfo) {
        vocabularyTestService.clearTestedWords(for: dictionary.fileName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    switch completion {
                    case .finished:
                        self.errorHandler.logSuccess("已清除词典 \(dictionary.name) 的测试记录")
                        
                        // 如果当前选择的词典被清除，重置统计信息
                        if self.selectedDictionary?.fileName == dictionary.fileName {
                            self.masteredCount = 0
                            self.familiarCount = 0
                            self.unfamiliarCount = 0
                            self.totalTestedCount = 0
                        }
                    case .failure(let error):
                        self.errorHandler.handle(error, context: "清除测试记录")
                    }
                },
                receiveValue: { _ in
                    // 清除成功
                }
            )
            .store(in: &cancellables)
    }
    
    func getTestProgress(for dictionary: DictionaryInfo) {
        vocabularyTestService.getTestProgress(for: dictionary.fileName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorHandler.handle(error, context: "获取测试进度")
                    }
                },
                receiveValue: { [weak self] progress in
                    // 处理获取到的测试进度
                    self?.errorHandler.logSuccess("获取测试进度成功: \(progress.testedWords)/\(progress.totalWords)")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    var progressPercentage: String {
        return String(format: "%.1f%%", testProgress * 100)
    }
    
    var estimatedVocabularySize: Int {
        guard totalTestedCount > 0 else { return 0 }
        let masteryRate = Double(masteredCount + familiarCount) / Double(totalTestedCount)
        let totalWords = selectedDictionary?.totalWords ?? 0
        return Int(Double(totalWords) * masteryRate)
    }
    
    var canStartTest: Bool {
        selectedDictionary != nil && !isTestActive && !isLoading && !selectedGroups.isEmpty
    }
    
    var hasTestHistory: Bool {
        !testHistory.isEmpty
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Supporting Types

// DictionaryInfo 已在 Models/DictionaryInfo.swift 中定义