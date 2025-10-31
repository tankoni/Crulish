//
//  TestResultManager.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import SwiftData
import Foundation
import Combine
import CryptoKit

/// 测试结果管理器 - 专门管理词汇量测试的结果和统计
@MainActor
class TestResultManager: ObservableObject {
    // MARK: - Published Properties
    
    /// 测试结果
    @Published var testResults: [WordTestResult] = []
    
    /// 测试统计
    @Published var testStatistics: TestStatistics?
    
    /// 测试历史
    @Published var testHistory: [VocabularyTest] = []
    
    /// 是否正在加载历史
    @Published var isLoadingHistory: Bool = false
    
    /// 是否正在导出
    @Published var isExporting: Bool = false
    
    /// 导出进度
    @Published var exportProgress: Double = 0.0
    
    /// 词汇掌握度分布
    @Published var masteryDistribution: WordMasteryDistribution?
    
    /// 学习建议
    @Published var learningRecommendations: [LearningRecommendation] = []
    
    // MARK: - Private Properties
    
    /// 词汇测试服务
    private let vocabularyTestService: VocabularyTestServiceProtocol
    
    /// 学习跟踪服务
    private let learningTrackingService: LearningTrackingService
    
    /// 导出服务
    private let exportService: TestResultExportService
    
    /// 模型上下文
    private let modelContext: ModelContext
    
    /// 统计更新任务
    private var statisticsUpdateTask: Task<Void, Never>?
    
    /// 防抖定时器
    private var debounceTimer: Timer?
    
    /// 缓存的统计数据
    private var cachedStatistics: (statistics: TestStatistics, timestamp: Date)?
    
    /// 缓存有效期（秒）
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟
    
    /// Combine取消令牌集合
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// 总测试次数
    var totalTestCount: Int {
        return testHistory.count
    }
    
    /// 平均正确率
    var averageAccuracy: Double {
        guard !testHistory.isEmpty else { return 0.0 }
        
        let totalAccuracy = testHistory.compactMap { $0.accuracy }.reduce(0.0, +)
        return totalAccuracy / Double(testHistory.count)
    }
    
    /// 最近测试的正确率
    var recentAccuracy: Double {
        return testHistory.first?.accuracy ?? 0.0
    }
    
    /// 词汇掌握总数
    var totalMasteredWords: Int {
        return masteryDistribution?.masteredWords ?? 0
    }
    
    /// 需要复习的单词数
    var wordsNeedingReview: Int {
        return masteryDistribution?.unfamiliarWords ?? 0
    }
    
    /// 是否有测试结果
    var hasTestResults: Bool {
        return !testResults.isEmpty
    }
    
    /// 是否有测试历史
    var hasTestHistory: Bool {
        return !testHistory.isEmpty
    }
    
    // MARK: - Published Statistics Properties
    
    /// 掌握的单词数量
    @Published var masteredCount: Int = 0
    
    /// 眼熟的单词数量
    @Published var familiarCount: Int = 0
    
    /// 陌生的单词数量
    @Published var unfamiliarCount: Int = 0
    
    // MARK: - Statistics Helper Methods
    
    /// 计算掌握的单词数量
    private func calculateMasteredCount() -> Int {
        do {
            let descriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.masteryLevel == "掌握"
                }
            )
            let masteredWords = try modelContext.fetch(descriptor)
            return masteredWords.count
        } catch {
            print("❌ [TestResultManager] 获取已掌握单词数量失败: \(error)")
            return 0
        }
    }
    
    /// 计算眼熟的单词数量
    private func calculateFamiliarCount() -> Int {
        do {
            let descriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.masteryLevel == "熟悉"
                }
            )
            let familiarWords = try modelContext.fetch(descriptor)
            return familiarWords.count
        } catch {
            print("❌ [TestResultManager] 获取熟悉单词数量失败: \(error)")
            return 0
        }
    }
    
    /// 计算陌生的单词数量
    private func calculateUnfamiliarCount() -> Int {
        do {
            let descriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.masteryLevel == "生疏"
                }
            )
            let unfamiliarWords = try modelContext.fetch(descriptor)
            return unfamiliarWords.count
        } catch {
            print("❌ [TestResultManager] 获取不熟悉单词数量失败: \(error)")
            return 0
        }
    }
    
    /// 刷新统计数据
    func refreshStatistics() {
        masteredCount = calculateMasteredCount()
        familiarCount = calculateFamiliarCount()
        unfamiliarCount = calculateUnfamiliarCount()
        print("📊 [TestResultManager] 统计数据已刷新: 掌握(\(masteredCount)) 熟悉(\(familiarCount)) 陌生(\(unfamiliarCount))")
    }
    
    /// 恢复会话统计数据
    func restoreSessionStats(masteredCount: Int, familiarCount: Int, unfamiliarCount: Int) {
        self.masteredCount = masteredCount
        self.familiarCount = familiarCount
        self.unfamiliarCount = unfamiliarCount
        print("📊 [TestResultManager] 恢复会话统计数据: 掌握(\(masteredCount)) 熟悉(\(familiarCount)) 陌生(\(unfamiliarCount))")
    }
    
    // MARK: - Initialization
    
    init(
        vocabularyTestService: VocabularyTestServiceProtocol,
        learningTrackingService: LearningTrackingService,
        exportService: TestResultExportService,
        modelContext: ModelContext,
        isRetestMode: Bool = false,
        retestConfig: RetestConfig? = nil
    ) {
        self.vocabularyTestService = vocabularyTestService
        self.learningTrackingService = learningTrackingService
        self.exportService = exportService
        self.modelContext = modelContext
        
        // 初始化统计数据
        refreshStatistics()
        
        print("✅ [TestResultManager] 初始化完成 - 重测模式: \(isRetestMode)")
    }
    
    // MARK: - Result Management
    
    /// 添加测试结果
    func addTestResult(_ result: WordTestResult) {
        testResults.append(result)
        
        // 延迟更新统计，避免频繁计算
        scheduleStatisticsUpdate()
        
        // 刷新统计数据
        refreshStatistics()
        
        print("✅ [TestResultManager] 添加测试结果: \(result.word)")
    }
    
    /// 批量添加测试结果
    func addTestResults(_ results: [WordTestResult]) {
        testResults.append(contentsOf: results)
        
        // 延迟更新统计
        scheduleStatisticsUpdate()
        
        // 刷新统计数据
        refreshStatistics()
        
        print("✅ [TestResultManager] 批量添加测试结果: \(results.count) 个")
    }
    
    /// 记录单词掌握度
    func recordWordMastery(word: String, mastery: MasteryLevel, responseTime: TimeInterval, testId: UUID? = nil) {
        let result = WordTestResult(
            word: word,
            isKnown: mastery != .unfamiliar,
            timestamp: Date()
        )
        addTestResult(result)
        
        // 如果没有提供testId，则跳过服务层记录（仅更新本地统计）
        guard let actualTestId = testId else {
            print("⚠️ [TestResultManager] 未提供测试ID，跳过服务层记录: \(word) - \(mastery)")
            Task { @MainActor in
                self.refreshStatistics()
            }
            return
        }
        
        // 记录到服务层
        vocabularyTestService.recordWordMastery(
            testId: actualTestId,
            word: word,
            masteryLevel: mastery,
            responseTime: responseTime
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ [TestResultManager] 记录单词掌握度失败: \(error)")
                }
            },
            receiveValue: { _ in
                print("✅ [TestResultManager] 记录单词掌握度: \(word) - \(mastery)")
                // 记录成功后刷新统计数据
                Task { @MainActor in
                    self.refreshStatistics()
                }
            }
        )
        .store(in: &cancellables)
    }
    
    /// 清除测试结果
    func clearTestResults() {
        testResults.removeAll()
        testStatistics = nil
        learningRecommendations.removeAll()
        
        // 重置统计数据
        masteredCount = 0
        familiarCount = 0
        unfamiliarCount = 0
        
        // 清除缓存
        cachedStatistics = nil
        
        print("🗑️ [TestResultManager] 测试结果已清除")
        print("📊 [TestResultManager] 统计数据已重置: 掌握(0) 熟悉(0) 陌生(0)")
    }
    
    /// 保存测试结果
    func saveTestResults(for test: VocabularyTest) async throws {
        guard !testResults.isEmpty else {
            throw TestResultError.noResultsToSave
        }
        
        do {
            // 将 WordTestResult 转换为 VocabularyTestResult
            let vocabularyTestResults = testResults.map { result in
                VocabularyTestResult(
                    word: result.word,
                    isKnown: result.isKnown,
                    responseTime: 2.0, // 默认响应时间，因为 WordTestResult 没有这个字段
                    difficulty: .medium, // 默认难度，因为 WordTestResult 没有这个字段
                    frequency: 100 // 默认频率，因为 WordTestResult 没有这个字段
                )
            }
            
            // 保存测试结果到 VocabularyTest.testResultsData
            let mutableTest = test
            mutableTest.saveTestResults(vocabularyTestResults)
            
            // 保存到服务层
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                vocabularyTestService.saveTestResult(mutableTest)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                continuation.resume(returning: ())
                            case .failure(let error):
                                print("❌ [TestResultManager] 保存失败: \(error)")
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { _ in
                            print("✅ [TestResultManager] 测试结果已保存")
                        }
                    )
                    .store(in: &cancellables)
            }
            
            // 更新学习跟踪
            await updateLearningTracking()
            
            // 重新加载历史
            await loadTestHistory()
            
            print("✅ [TestResultManager] 测试结果已保存，共 \(vocabularyTestResults.count) 个结果")
        } catch {
            print("❌ [TestResultManager] 保存测试结果失败: \(error)")
            throw error
        }
    }
    
    // MARK: - Statistics Management
    
    /// 计算测试统计
    func calculateStatistics() {
        // 检查缓存
        if let cached = cachedStatistics,
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
            testStatistics = cached.statistics
            return
        }
        
        guard !testResults.isEmpty else {
            testStatistics = nil
            return
        }
        
        let totalWords = testResults.count
        let correctAnswers = testResults.filter { $0.isKnown }.count
        let accuracy = Double(correctAnswers) / Double(totalWords) * 100
        
        let masteredWords = testResults.filter { $0.isKnown }.count
        let _ = testResults.count - masteredWords  // familiarWords 计算但不使用
        let _ = testResults.filter { !$0.isKnown }.count  // unfamiliarWords 计算但不使用
        
        let statistics = TestStatistics(
            totalTests: 1,
            averageScore: accuracy,
            bestScore: Int(accuracy),
            improvementRate: 0.0
        )
        
        // 缓存统计数据
        cachedStatistics = (statistics, Date())
        testStatistics = statistics
        
        // 生成学习建议
        generateLearningRecommendations(from: statistics)
        
        print("📊 [TestResultManager] 统计已更新: 正确率 \(String(format: "%.1f", accuracy))%")
    }
    
    /// 延迟更新统计
    private func scheduleStatisticsUpdate() {
        // 取消之前的定时器
        debounceTimer?.invalidate()
        
        // 设置新的定时器
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.calculateStatistics()
            }
        }
    }
    
    /// 计算测试持续时间
    private func calculateTestDuration() -> TimeInterval {
        guard let firstResult = testResults.first,
              let lastResult = testResults.last else {
            return 0
        }
        
        return lastResult.timestamp.timeIntervalSince(firstResult.timestamp)
    }
    
    // MARK: - Test History Management
    
    /// 加载测试历史（总记录）
    func loadTestHistory() async {
        await MainActor.run {
            isLoadingHistory = true
        }
        
        do {
            let history = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[VocabularyTest], Error>) in
                vocabularyTestService.getGeneralTestHistory(limit: 100)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { history in
                            continuation.resume(returning: history)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            await MainActor.run {
                self.testHistory = history
                self.isLoadingHistory = false
            }
            print("✅ [TestResultManager] 加载总测试历史成功: \(history.count) 条记录")
        } catch {
            await MainActor.run {
                self.isLoadingHistory = false
            }
            print("❌ [TestResultManager] 加载总测试历史失败: \(error)")
        }
    }
    
    /// 加载指定词典的专属测试历史
    func loadTestHistory(for dictionaryFileName: String) async {
        await MainActor.run {
            isLoadingHistory = true
        }
        
        do {
            // 将文件名转换为稳定的UUID
            let dictionaryId = generateStableID(fileName: dictionaryFileName)
            let history = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[VocabularyTest], Error>) in
                var cancellable: AnyCancellable?
                cancellable = vocabularyTestService.getDictionarySpecificTestHistory(for: dictionaryId, limit: 100)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { history in
                            continuation.resume(returning: history)
                            cancellable?.cancel()
                        }
                    )
            }
            
            await MainActor.run {
                self.testHistory = history
                self.isLoadingHistory = false
            }
            print("✅ [TestResultManager] 加载词典 \(dictionaryFileName) 的专属测试历史成功: \(history.count) 条记录")
        } catch {
            await MainActor.run {
                self.isLoadingHistory = false
            }
            print("❌ [TestResultManager] 加载词典 \(dictionaryFileName) 的专属测试历史失败: \(error)")
        }
    }
    
    /// 基于文件名生成稳定的UUID（与DictionaryInfo保持一致）
    private func generateStableID(fileName: String) -> UUID {
        // 使用与DictionaryInfo相同的ID生成逻辑
        let data = fileName.data(using: .utf8) ?? Data()
        let hash = Insecure.SHA1.hash(data: data)
        
        // 将哈希值转换为UUID格式
        let hashBytes = Array(hash)
        
        // 构造UUID字节数组（16字节）
        var uuidBytes: [UInt8] = Array(hashBytes.prefix(16))
        
        // 设置版本号为5（基于名称的UUID）
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x50
        // 设置变体位
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        
        // 创建UUID
        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }
    
    /// 选择测试继续
    func selectTestForContinuation(_ test: VocabularyTest) {
        // 这里可以添加选择测试的逻辑
        print("✅ [TestResultManager] 选择测试继续: \(test.dictionaryName)")
    }
    
    /// 从历史中删除测试
    func deleteTestFromHistory(_ test: VocabularyTest) {
        Task {
            do {
                try await deleteTestHistory(test)
                print("✅ [TestResultManager] 删除测试历史成功")
            } catch {
                print("❌ [TestResultManager] 删除测试历史失败: \(error)")
            }
        }
    }
    
    /// 删除测试历史
    func deleteTestHistory(_ test: VocabularyTest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            vocabularyTestService.deleteTestRecord(test)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            print("✅ [TestResultManager] 删除测试历史成功: \(test.dictionaryName)")
                            continuation.resume(returning: ())
                        case .failure(let error):
                            print("❌ [TestResultManager] 删除测试历史失败: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
        
        await MainActor.run {
            self.testHistory.removeAll { $0.id == test.id }
            print("🗑️ [TestResultManager] 删除测试历史: \(test.dictionaryName)")
        }
    }
    
    // MARK: - Export Management
    
    /// 导出测试结果
    func exportTestResults(format: ExportFormat, includeStatistics: Bool = true) async throws -> URL {
        isExporting = true
        exportProgress = 0.0
        
        do {
            // 模拟导出进度
            for progress in stride(from: 0.1, through: 0.9, by: 0.1) {
                exportProgress = progress
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
            
            // 使用默认词典名称进行导出
            let dictionaryName = testHistory.first?.dictionaryName ?? "默认词典"
            let url = try await exportService.exportTestResults(for: dictionaryName, format: format)
            
            await MainActor.run {
                self.exportProgress = 1.0
                self.isExporting = false
                print("✅ [TestResultManager] 导出完成: \(url.lastPathComponent)")
            }
            
            return url
        } catch {
            await MainActor.run {
                self.isExporting = false
                self.exportProgress = 0.0
                print("❌ [TestResultManager] 导出失败: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    // MARK: - Learning Recommendations
    
    /// 生成学习建议
    private func generateLearningRecommendations(from statistics: TestStatistics) {
        var recommendations: [LearningRecommendation] = []
        
        // 基于正确率的建议
        if statistics.averageScore < 60 {
            recommendations.append(
                LearningRecommendation(
                    type: .reviewWeakWords,
                    priority: .high,
                    title: "重点复习薄弱单词",
                    description: "您的正确率较低，建议重点复习答错的单词",
                    actionText: "开始复习"
                )
            )
        } else if statistics.averageScore < 80 {
            recommendations.append(
                LearningRecommendation(
                    type: .practiceMore,
                    priority: .medium,
                    title: "增加练习频率",
                    description: "继续练习以提高词汇掌握度",
                    actionText: "继续练习"
                )
            )
        }
        
        // 基于掌握度分布的建议
        let unfamiliarWords = testResults.filter { !$0.isKnown }.count
        if unfamiliarWords > testResults.count / 2 {
            recommendations.append(
                LearningRecommendation(
                    type: .focusOnBasics,
                    priority: .high,
                    title: "加强基础词汇",
                    description: "建议先掌握基础词汇再进行高级学习",
                    actionText: "学习基础词汇"
                )
            )
        }
        
        // 积极反馈
        if statistics.averageScore >= 90 {
            recommendations.append(
                LearningRecommendation(
                    type: .excellentProgress,
                    priority: .low,
                    title: "表现优秀！",
                    description: "您的词汇掌握度很高，可以尝试更高难度的内容",
                    actionText: "挑战高级词汇"
                )
            )
        }
        
        learningRecommendations = recommendations
        print("💡 [TestResultManager] 生成了 \(recommendations.count) 条学习建议")
    }
    
    // MARK: - Learning Tracking
    
    /// 更新学习跟踪
    private func updateLearningTracking() async {
        for result in testResults {
            let masteryLevel: MasteryLevel = result.isKnown ? .familiar : .unfamiliar
            learningTrackingService.updateWordMastery(
                word: result.word,
                masteryLevel: masteryLevel,
                source: "vocabulary_test"
            )
        }
        
        print("📚 [TestResultManager] 学习跟踪已更新，共 \(testResults.count) 个单词")
    }
    
    // MARK: - Cleanup
    
    deinit {
        statisticsUpdateTask?.cancel()
        debounceTimer?.invalidate()
    }
    
    // MARK: - Supporting Types
    
    /// 学习建议
    struct LearningRecommendation {
        let type: RecommendationType
        let priority: Priority
        let title: String
        let description: String
        let actionText: String
        
        enum RecommendationType {
            case reviewWeakWords
            case practiceMore
            case focusOnBasics
            case improveSpeed
            case excellentProgress
        }
        
        enum Priority {
            case high
            case medium
            case low
        }
    }
}

// MARK: - Supporting Types

/// 测试导出数据
struct TestExportData {
    let results: [WordTestResult]
    let statistics: TestStatistics?
    let masteryDistribution: WordMasteryDistribution?
    let exportDate: Date
}

// MARK: - Enums

/// 问题类型
enum QuestionType {
    case multipleChoice
    case fillInBlank
    case matching
    case trueFalse
}

/// 测试结果错误
enum TestResultError: LocalizedError {
    case noResultsToSave
    case exportFailed(String)
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .noResultsToSave:
            return "没有测试结果可保存"
        case .exportFailed(let reason):
            return "导出失败: \(reason)"
        case .invalidFormat:
            return "无效的导出格式"
        }
    }
}