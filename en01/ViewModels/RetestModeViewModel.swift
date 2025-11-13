//
//  RetestModeViewModel.swift
//  en01
//
//  Created by Assistant on 2025-01-23.
//

import SwiftUI
import SwiftData
import Combine

/// 重测模式视图模型
@MainActor
class RetestModeViewModel: ObservableObject {
    // MARK: - Dependencies
    private let retestModeService: RetestModeService
    private let dictionaryService: DictionaryServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    private let appCoordinator: AppCoordinator
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRetestActive = false
    
    // 词典相关
    @Published var availableDictionaries: [DictionaryInfo] = []
    @Published var selectedDictionaries: Set<UUID> = []
    
    // 掌握程度相关
    @Published var selectedMasteryLevels: Set<MasteryLevel> = []
    @Published var masteryLevelWordCounts: [MasteryLevel: Int] = [:]
    
    // 测试模式
    @Published var selectedTestMode: VocabularyTestMode = .englishToChinese
    
    // 结果覆盖模式
    @Published var selectedOverwriteMode: ResultOverwriteMode = .overwrite
    
    // 重测会话
    @Published var currentRetestSession: RetestSession?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    @Published private(set) var dictionaryWordCounts: [UUID: Int] = [:]
    
    // MARK: - Computed Properties
    
    var isAllDictionariesSelected: Bool {
        !availableDictionaries.isEmpty && selectedDictionaries.count == availableDictionaries.count
    }
    
    var isAllMasteryLevelsSelected: Bool {
        selectedMasteryLevels.count == MasteryLevel.allCases.count
    }
    
    var canStartRetest: Bool {
        !selectedDictionaries.isEmpty &&
        !selectedMasteryLevels.isEmpty &&
        !isLoading &&
        getTotalWordsCount() > 0
    }
    
    // MARK: - Initialization
    
    init(
        retestModeService: RetestModeService,
        dictionaryService: DictionaryServiceProtocol,
        errorHandler: ErrorHandlerProtocol,
        appCoordinator: AppCoordinator
    ) {
        self.retestModeService = retestModeService
        self.dictionaryService = dictionaryService
        self.errorHandler = errorHandler
        self.appCoordinator = appCoordinator
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // 监听词典选择变化，更新掌握程度统计
        $selectedDictionaries
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateMasteryLevelCounts()
                }
            }
            .store(in: &cancellables)
        
        // 监听掌握程度选择变化
        $selectedMasteryLevels
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateMasteryLevelCounts()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 加载可用词典
    func loadAvailableDictionaries() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }

            do {
                let dictionaries = try await retestModeService.getAvailableDictionaries()
                availableDictionaries = dictionaries

                // 加载每个词典的已测试单词数量
                for dictionary in dictionaries {
                    let count = await getTestedWordsCount(for: dictionary.id)
                    dictionaryWordCounts[dictionary.id] = count
                }

                print("✅ 成功加载 \(dictionaries.count) 个词典")
            } catch {
                handleError(error, context: "加载词典列表")
            }
        }
    }
    
    /// 切换词典选择状态
    func toggleDictionarySelection(_ dictionaryId: UUID) {
        if selectedDictionaries.contains(dictionaryId) {
            selectedDictionaries.remove(dictionaryId)
        } else {
            selectedDictionaries.insert(dictionaryId)
        }
    }
    
    /// 切换全选词典
    func toggleAllDictionaries() {
        if isAllDictionariesSelected {
            selectedDictionaries.removeAll()
        } else {
            selectedDictionaries = Set(availableDictionaries.map { $0.id })
        }
    }
    
    /// 切换掌握程度选择状态
    func toggleMasteryLevelSelection(_ masteryLevel: MasteryLevel) {
        if selectedMasteryLevels.contains(masteryLevel) {
            selectedMasteryLevels.remove(masteryLevel)
        } else {
            selectedMasteryLevels.insert(masteryLevel)
        }
    }
    
    /// 切换全选掌握程度
    func toggleAllMasteryLevels() {
        if isAllMasteryLevelsSelected {
            selectedMasteryLevels.removeAll()
        } else {
            selectedMasteryLevels = Set(MasteryLevel.allCases)
        }
    }
    
    /// 选择测试模式
    func selectTestMode(_ mode: VocabularyTestMode) {
        selectedTestMode = mode
    }
    
    /// 选择结果覆盖模式
    func selectOverwriteMode(_ mode: ResultOverwriteMode) {
        selectedOverwriteMode = mode
    }
    
    /// 获取词典的已测试单词数量
    func getTestedWordsCount(for dictionaryId: UUID) -> Int {
        return dictionaryWordCounts[dictionaryId] ?? 0
    }
    
    /// 获取特定掌握程度的单词数量
    func getWordsCount(for masteryLevel: MasteryLevel) -> Int {
        return masteryLevelWordCounts[masteryLevel] ?? 0
    }
    
    /// 获取总单词数量
    func getTotalWordsCount() -> Int {
        return selectedMasteryLevels.reduce(0) { total, level in
            total + getWordsCount(for: level)
        }
    }
    
    /// 开始重测
    func startRetest() {
        guard canStartRetest else {
            showError("无法开始重测，请检查选择条件")
            return
        }
        
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                // 创建重测配置
                let configuration = RetestConfiguration(
                    name: "重测配置-\(Date().formatted(date: .abbreviated, time: .shortened))",
                    selectedDictionaryIds: Array(selectedDictionaries),
                    selectedMasteryLevels: Array(selectedMasteryLevels),
                    testMode: selectedTestMode
                )
                
                // 获取符合条件的单词
                let words = try await retestModeService.getTestedWordsForDictionaries(
                    Array(selectedDictionaries),
                    masteryLevels: Array(selectedMasteryLevels)
                )
                
                // 创建重测会话
                let session = try await retestModeService.createRetestSession(
                    configuration: configuration,
                    words: words
                )
                currentRetestSession = session
                
                print("✅ 成功创建重测会话，包含 \(session.totalWords) 个单词")
                
                // 启动重测界面
                await startRetestInterface(with: session)
                
            } catch {
                handleError(error, context: "创建重测会话")
            }
        }
    }
    
    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// 更新掌握程度统计
    private func updateMasteryLevelCounts() async {
        guard !selectedDictionaries.isEmpty else {
            masteryLevelWordCounts.removeAll()
            return
        }
        
        do {
            let filters = RetestWordFilters(
                dictionaryIds: selectedDictionaries,
                masteryLevels: Set(MasteryLevel.allCases) // 获取所有掌握程度的统计
            )
            
            let words = try await retestModeService.getTestedWordsForDictionaries(
                Array(filters.dictionaryIds),
                masteryLevels: Array(filters.masteryLevels)
            )
            
            // 统计每个掌握程度的单词数量
            var counts: [MasteryLevel: Int] = [:]
            for level in MasteryLevel.allCases {
                counts[level] = words.filter { $0.currentMasteryLevel == level }.count
            }
            
            masteryLevelWordCounts = counts
            
        } catch {
            print("❌ 更新掌握程度统计失败: \(error.localizedDescription)")
        }
    }
    
    /// 异步获取词典的已测试单词数量
    private func getTestedWordsCount(for dictionaryId: UUID) async -> Int {
        do {
            let words = try await retestModeService.getTestedWordsForDictionaries(
                [dictionaryId],
                masteryLevels: Array(MasteryLevel.allCases)
            )
            return words.count
        } catch {
            print("❌ 获取词典 \(dictionaryId) 的已测试单词数量失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// 启动重测界面
    private func startRetestInterface(with session: RetestSession) async {
        // 标记为重测激活
        isRetestActive = true

        // 将当前选择映射为 VocabularyTestView 需要的 RetestConfig
        let retestConfig = RetestConfig(
            masteryLevels: selectedMasteryLevels,
            selectedDictionaries: Set(selectedDictionaries.map { $0.uuidString }),
            wordCount: session.totalWords,
            randomOrder: true
        )

        // 通过协调器触发词汇测试界面（重测模式）
        await MainActor.run {
            appCoordinator.startRetestVocabularyTest(retestConfig: retestConfig)
        }
        
        print("🚀 启动重测界面（复用词汇量测试视图），测试 \(session.totalWords) 个单词")
    }
    
    /// 完成重测会话
    func completeRetestSession(results: [RetestResult]) async {
        guard let session = currentRetestSession else {
            showError("没有活跃的重测会话")
            return
        }
        
        do {
            let statistics = try await retestModeService.completeRetestSession(
                session.id,
                overwriteMode: selectedOverwriteMode
            )
            
            currentRetestSession = nil
            isRetestActive = false
            
            print("✅ 重测会话完成，统计信息: \(statistics)")
            
        } catch {
            handleError(error, context: "完成重测会话")
        }
    }
    
    /// 处理错误
    private func handleError(_ error: Error, context: String) {
        let message = "\(context)失败: \(error.localizedDescription)"
        print("❌ \(message)")
        errorHandler.handle(error, context: context)
        showError(message)
    }
    
    /// 显示错误信息
    private func showError(_ message: String) {
        errorMessage = message
    }
}

// MARK: - Extensions

// MARK: - MasteryLevel Extensions
extension MasteryLevel {
    // 移除重复的属性定义，使用 Word.swift 中的原始定义
}

// VocabularyTestMode 的 displayName 和 description 属性已在 VocabularyTestMode.swift 中定义

// ResultOverwriteMode 的 displayName 属性已在 RetestModels.swift 中定义