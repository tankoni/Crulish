//
//  CompositeRankingViewModel.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
class CompositeRankingViewModel: ObservableObject {
    // MARK: - Dependencies
    private let compositeRankingService: CompositeRankingService
    private let intelligentRankingService: IntelligentRankingService
    private let errorHandler: ErrorHandlerProtocol
    private let dictionaryService: DictionaryServiceProtocol
    
    // MARK: - Published Properties
    @Published var rankedArticles: [CompositeRankedArticle] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var config: CompositeRankingConfig = CompositeRankingConfig.default
    @Published var selectedPreset: SortPreset = .balanced
    @Published var availableDictionaries: [DictionaryInfo] = []
    @Published var availableTests: [VocabularyTest] = []
    @Published var statistics: CompositeRankingStatistics = CompositeRankingStatistics(
        totalArticles: 0,
        averageScore: 0.0,
        enabledCriteriaCount: 0,
        useDictionaryIntegration: false,
        useTestResults: false
    )
    
    
    // MARK: - Computed Properties
    var hasValidConfig: Bool {
        !config.criteria.isEmpty
    }
    
    var configSummary: String {
        var parts: [String] = []
        
        if !config.criteria.isEmpty {
            parts.append("\(config.criteria.count) 个排序条件")
        }
        
        if config.useDictionaryIntegration, let dictionary = selectedDictionary {
            parts.append("词典: \(dictionary.name)")
        }
        
        if config.useTestResults, let test = selectedTest {
            parts.append("测试: \(test.dictionaryName)")
        }
        
        return parts.isEmpty ? "未配置" : parts.joined(separator: " • ")
    }
    
    var selectedDictionary: DictionaryInfo? {
        guard let id = config.selectedDictionaryId else { return nil }
        return availableDictionaries.first { $0.id == id }
    }
    
    var selectedTest: VocabularyTest? {
        guard let id = config.selectedTestId else { return nil }
        return availableTests.first { $0.id == id }
    }
    
    // MARK: - Initialization
    init(compositeRankingService: CompositeRankingService,
         intelligentRankingService: IntelligentRankingService,
         errorHandler: ErrorHandlerProtocol,
         dictionaryService: DictionaryServiceProtocol) {
        self.compositeRankingService = compositeRankingService
        self.intelligentRankingService = intelligentRankingService
        self.errorHandler = errorHandler
        self.dictionaryService = dictionaryService
        
        setupBindings()
        Task {
            await loadResources()
        }
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // 监听配置变化，自动重新排序
        $config
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.performRanking()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    // MARK: - Public Methods
    func performRanking() async {
        guard hasValidConfig else {
            rankedArticles = []
            return
        }
        
        isLoading = true
        
        do {
            // 这里需要从适当的数据源获取文章和用户词汇
            let articles: [Article] = [] // TODO: 从数据源获取文章
            let userVocabulary: [UserWord] = [] // TODO: 从数据源获取用户词汇
            
            let results = try await compositeRankingService.performCompositeRanking(
                articles: articles,
                userVocabulary: userVocabulary
            )
            rankedArticles = results
            updateStatistics()
            print("✅ 组合排序完成: \(results.count) 篇文章")
        } catch {
            print("❌ 组合排序失败: \(error.localizedDescription)")
            if let appError = error as? AppError {
                errorHandler.handle(appError)
            } else {
                errorHandler.handle(AppError.unknown(error))
            }
            rankedArticles = []
        }
        
        isLoading = false
    }
    
    func updateConfig(_ newConfig: CompositeRankingConfig) {
        config = newConfig
    }
    
    func selectDictionary(_ dictionary: DictionaryInfo?) {
        config.selectedDictionaryId = dictionary?.id
        config.useDictionaryIntegration = dictionary != nil
    }
    
    func selectTest(_ test: VocabularyTest?) {
        config.selectedTestId = test?.id
        config.useTestResults = test != nil
    }
    
    func addSortCriteria(_ option: RankingSortOption, direction: SortDirection = .descending, weight: Double = 1.0) {
        let criteria = SortCriteria(option: option, direction: CompositeRankingSortDirection(rawValue: direction.rawValue) ?? .descending, weight: weight)
        config.criteria.append(criteria)
    }
    
    func removeSortCriteria(_ option: RankingSortOption) {
        config.criteria.removeAll { $0.option == option }
    }
    
    func updateCriteriaWeight(_ option: RankingSortOption, weight: Double) {
        if let index = config.criteria.firstIndex(where: { $0.option == option }) {
            config.criteria[index].weight = weight
        }
    }
    
    func updateCriteriaDirection(_ option: RankingSortOption, direction: SortDirection) {
        if let index = config.criteria.firstIndex(where: { $0.option == option }) {
            config.criteria[index] = SortCriteria(
                option: option,
                direction: CompositeRankingSortDirection(rawValue: direction.rawValue) ?? .descending,
                weight: config.criteria[index].weight
            )
        }
    }
    
    func applyPreset(_ preset: SortPreset) {
        selectedPreset = preset
        config = preset.config
    }
    
    func resetConfig() {
        config = CompositeRankingConfig()
        selectedPreset = .balanced
        rankedArticles = []
    }
    
    func refreshResources() {
        Task {
            await loadResources()
            await performRanking()
        }
    }
    
    // MARK: - Private Methods
    private func loadResources() async {
        do {
            let dictionaries = try await withCheckedThrowingContinuation { continuation in
                _ = dictionaryService.getAvailableDictionaries()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { dictionaries in
                            continuation.resume(returning: dictionaries)
                        }
                    )
            }
            
            await MainActor.run {
                self.availableDictionaries = dictionaries
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "加载词典失败: \(error.localizedDescription)"
            }
            print("❌ 加载词典失败: \(error.localizedDescription)")
        }
    }
    

    
    // MARK: - Statistics
    
    private func updateStatistics() {
        statistics = CompositeRankingStatistics(
            totalArticles: rankedArticles.count,
            averageScore: calculateAverageScore(),
            enabledCriteriaCount: config.criteria.count,
            useDictionaryIntegration: config.useDictionaryIntegration,
            useTestResults: config.useTestResults
        )
    }
    
    // MARK: - Cache Management
    // MARK: - Cache Management
    private var lastRankingTime: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟
    
    // MARK: - Helper Methods
    private func calculateAverageScore() -> Double {
        guard !rankedArticles.isEmpty else { return 0.0 }
        return rankedArticles.reduce(0.0) { $0 + $1.compositeScore } / Double(rankedArticles.count)
    }
    
    private func shouldRefreshRanking() -> Bool {
        guard let lastTime = lastRankingTime else { return true }
        return Date().timeIntervalSince(lastTime) > cacheValidityDuration
    }
}

// MARK: - CompositeRankingStatistics
struct CompositeRankingStatistics {
    let totalArticles: Int
    let averageScore: Double
    let enabledCriteriaCount: Int
    let useDictionaryIntegration: Bool
    let useTestResults: Bool
}