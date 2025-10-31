//
//  TestConfigurationManager.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import Foundation
import Combine
import OSLog

/// 测试配置管理器 - 专门管理词汇量测试的配置
@MainActor
class TestConfigurationManager: ObservableObject {
    // MARK: - Published Properties
    
    /// 可用词典列表
    @Published var availableDictionaries: [DictionaryInfo] = []
    
    /// 当前选中的词典
    @Published var selectedDictionary: DictionaryInfo?
    
    /// 可用分组列表
    @Published var availableGroups: [String] = []
    
    /// 选中的分组
    @Published var selectedGroups: Set<String> = []
    
    /// 测试模式
    @Published var testMode: TestMode = .adaptive
    
    /// 测试大小
    @Published var testSize: TestSize = .medium
    
    /// 是否包含已测试单词
    @Published var includeTestedWords: Bool = false
    
    /// 是否随机顺序
    @Published var randomOrder: Bool = true
    
    /// 是否启用时间限制
    @Published var enableTimeLimit: Bool = false
    
    /// 每题时间限制（秒）
    @Published var timeLimitPerQuestion: Int = 30
    
    /// 是否启用音频
    @Published var enableAudio: Bool = true
    
    /// 是否显示提示
    @Published var showHints: Bool = true
    
    /// 难度级别
    @Published var difficultyLevel: DifficultyLevel = .intermediate
    
    // MARK: - Private Properties
    
    /// 词典服务
    private let dictionaryService: DictionaryService
    
    /// OSLog 日志器
    private let logger = Logger(subsystem: "com.en01.viewmodels", category: "TestConfigurationManager")
    
    /// 缓存的词典数据
    private var dictionaryCache: [String: [Word]] = [:]
    
    /// 缓存过期时间
    private let cacheExpirationTime: TimeInterval = 300 // 5分钟
    
    /// 缓存时间戳
    private var cacheTimestamp: [String: Date] = [:]
    
    // MARK: - Computed Properties
    
    /// 是否可以开始测试
    var canStartTest: Bool {
        guard selectedDictionary != nil else { return false }
        if case .all = testSize { return true }
        return !selectedGroups.isEmpty
    }
    
    /// 预估测试时间（分钟）
    var estimatedTestTime: Int {
        let wordsCount = estimatedWordsCount
        let timePerWord = enableTimeLimit ? timeLimitPerQuestion : 15 // 默认15秒每题
        return (wordsCount * timePerWord) / 60
    }
    
    /// 预估单词数量
    var estimatedWordsCount: Int {
        switch testSize {
        case .small:
            return 20
        case .medium:
            return 50
        case .large:
            return 100
        case .all:
            return 1000 // 预估全部单词数量
        case .custom(let count):
            return count
        }
    }
    
    /// 配置摘要
    var configurationSummary: String {
        var summary: [String] = []
        
        if let dictionary = selectedDictionary {
            summary.append("词典: \(dictionary.name)")
        }
        
        if !selectedGroups.isEmpty {
            summary.append("分组: \(selectedGroups.joined(separator: ", "))")
        }
        
        summary.append("模式: \(testMode.displayName)")
        summary.append("大小: \(testSize.displayName)")
        
        if enableTimeLimit {
            summary.append("时限: \(timeLimitPerQuestion)秒/题")
        }
        
        return summary.joined(separator: " | ")
    }
    
    // MARK: - Initialization
    
    init(dictionaryService: DictionaryService, isRetestMode: Bool = false, retestConfig: RetestConfig? = nil) {
        self.dictionaryService = dictionaryService
        
        print("✅ [TestConfigurationManager] 初始化完成 - 重测模式: \(isRetestMode)")
        
        // 如果是重测模式，应用重测配置
        if isRetestMode, let config = retestConfig {
            applyRetestConfiguration(config)
        }
        
        // 异步加载词典
        Task {
            await loadAvailableDictionaries()
        }
    }
    
    // MARK: - Retest Configuration
    
    /// 应用重测配置
    private func applyRetestConfiguration(_ config: RetestConfig) {
        // 根据重测配置设置测试参数
        if let testSize = config.testSize {
            self.testSize = testSize
        } else if let wordCount = config.wordCount {
            // 根据单词数量设置测试大小
            switch wordCount {
            case 0..<20:
                self.testSize = .small
            case 20..<50:
                self.testSize = .medium
            case 50..<100:
                self.testSize = .large
            default:
                self.testSize = .custom(wordCount)
            }
        }
        
        if let includeTestedWords = config.includeTestedWords {
            self.includeTestedWords = includeTestedWords
        }
        
        if let randomOrder = config.randomOrder {
            self.randomOrder = randomOrder
        }
        
        print("📝 [TestConfigurationManager] 应用重测配置: 测试大小(\(testSize)), 包含已测试单词(\(includeTestedWords)), 随机顺序(\(randomOrder))")
    }
    
    // MARK: - Dictionary Management
    
    /// 加载可用词典
    func loadAvailableDictionaries() async {
        do {
            let dictionariesPublisher = dictionaryService.getAvailableDictionaries()
            let dictionaries = try await dictionariesPublisher.values.first(where: { _ in true }) ?? []
            await MainActor.run {
                self.availableDictionaries = dictionaries
                self.logger.info("✅ [TestConfigurationManager] 加载了 \(dictionaries.count) 个词典")
            }
        } catch {
            await MainActor.run {
                self.logger.error("❌ [TestConfigurationManager] 加载词典失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 选择词典
    func selectDictionary(_ dictionary: DictionaryInfo) async {
        selectedDictionary = dictionary
        selectedGroups.removeAll()
        
        // 加载该词典的分组（等待完成）
        await loadAvailableGroups()
        
        logger.info("✅ [TestConfigurationManager] 选择词典: \(dictionary.name)")
    }
    
    /// 加载可用分组
    private func loadAvailableGroups() async {
        guard let dictionary = selectedDictionary else {
            availableGroups = []
            return
        }
        
        do {
            let wordsPublisher = dictionaryService.loadDictionary(fileName: dictionary.fileName)
            let words = try await wordsPublisher.values.first(where: { _ in true }) ?? []
            let groups = Set(words.compactMap { word in word.categories }.flatMap { categories in categories })
            
            self.availableGroups = Array(groups).sorted()
            self.logger.info("✅ [TestConfigurationManager] 加载了 \(groups.count) 个分组")
        } catch {
            self.availableGroups = []
            self.logger.error("❌ [TestConfigurationManager] 加载分组失败: \(String(describing: error))")
        }
    }
    
    // MARK: - Group Management
    
    /// 切换分组选择状态
    func toggleGroupSelection(_ group: String) {
        if selectedGroups.contains(group) {
            selectedGroups.remove(group)
        } else {
            selectedGroups.insert(group)
        }
        
        logger.info("✅ [TestConfigurationManager] 分组选择更新: \(selectedGroups)")
    }
    
    /// 选择所有分组
    func selectAllGroups() {
        selectedGroups = Set(availableGroups)
        logger.info("✅ [TestConfigurationManager] 选择所有分组")
    }
    
    /// 清除所有分组选择
    func clearGroupSelection() {
        selectedGroups.removeAll()
        logger.info("✅ [TestConfigurationManager] 清除分组选择")
    }
    
    // MARK: - Configuration Methods
    
    /// 设置测试模式
    func setTestMode(_ mode: TestMode) {
        testMode = mode
        logger.info("✅ [TestConfigurationManager] 设置测试模式: \(mode.displayName)")
    }
    
    /// 设置测试大小
    func setTestSize(_ size: TestSize) {
        testSize = size
        logger.info("✅ [TestConfigurationManager] 设置测试大小: \(size.displayName)")
    }
    
    /// 设置难度级别
    func setDifficultyLevel(_ level: DifficultyLevel) {
        difficultyLevel = level
        logger.info("✅ [TestConfigurationManager] 设置难度级别: \(level.displayName)")
    }
    
    /// 重置配置为默认值
    func resetToDefaults() {
        testMode = .adaptive
        testSize = .medium
        includeTestedWords = false
        randomOrder = true
        enableTimeLimit = false
        timeLimitPerQuestion = 30
        enableAudio = true
        showHints = true
        difficultyLevel = DifficultyLevel.intermediate
        
        logger.info("🔄 [TestConfigurationManager] 配置已重置为默认值")
    }
    
    /// 验证配置
    func validateConfiguration() -> ConfigurationValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // 检查必需配置
        if selectedDictionary == nil {
            errors.append("请选择一个词典")
        }
        
        // “全部测试”不强制要求分组；其余模式需至少选择一组
        if case .all = testSize {
            // 跳过分组必选校验
        } else if selectedGroups.isEmpty {
            errors.append("请至少选择一个分组")
        }
        
        // 检查时间限制
        if enableTimeLimit && timeLimitPerQuestion < 5 {
            warnings.append("时间限制过短，可能影响测试体验")
        }
        
        // 检查测试大小
        if case .custom(let count) = testSize, count <= 0 {
            errors.append("自定义测试大小必须大于0")
        }
        
        return ConfigurationValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Cache Management
    
    /// 获取缓存的词典数据
    func getCachedDictionaryWords(_ fileName: String) -> [Word]? {
        guard let timestamp = cacheTimestamp[fileName],
              Date().timeIntervalSince(timestamp) < cacheExpirationTime else {
            return nil
        }
        
        return dictionaryCache[fileName]
    }
    
    /// 缓存词典数据
    func cacheDictionaryWords(_ fileName: String, words: [Word]) {
        dictionaryCache[fileName] = words
        cacheTimestamp[fileName] = Date()
    }
    
    /// 清除缓存
    func clearCache() {
        dictionaryCache.removeAll()
        cacheTimestamp.removeAll()
        print("🗑️ [TestConfigurationManager] 缓存已清除")
    }
}

// MARK: - Supporting Types

/// 测试模式
enum TestMode: String, CaseIterable {
    case adaptive = "adaptive"
    case sequential = "sequential"
    case random = "random"
    case review = "review"
    
    var displayName: String {
        switch self {
        case .adaptive:
            return "自适应"
        case .sequential:
            return "顺序"
        case .random:
            return "随机"
        case .review:
            return "复习"
        }
    }
    
    var description: String {
        switch self {
        case .adaptive:
            return "根据掌握程度智能调整"
        case .sequential:
            return "按词典顺序进行测试"
        case .random:
            return "随机选择单词测试"
        case .review:
            return "重点复习薄弱单词"
        }
    }
}

/// 测试大小
enum TestSize: Equatable {
    case small
    case medium
    case large
    case all
    case custom(Int)
    
    var displayName: String {
        switch self {
        case .small:
            return "小 (20词)"
        case .medium:
            return "中 (50词)"
        case .large:
            return "大 (100词)"
        case .all:
            return "全部"
        case .custom(let count):
            return "自定义 (\(count)词)"
        }
    }
    
    var wordCount: Int {
        switch self {
        case .small:
            return 20
        case .medium:
            return 50
        case .large:
            return 100
        case .all:
            return -1 // 表示全部单词
        case .custom(let count):
            return count
        }
    }
}



/// 配置验证结果
struct ConfigurationValidationResult {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
    
    var allMessages: [String] {
        return errors + warnings
    }
}