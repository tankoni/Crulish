//
//  VocabularyViewModel.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI
import SwiftData
import Combine

/// 词汇ViewModel，负责词汇管理、复习和统计功能
@MainActor
class VocabularyViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var vocabulary: [UserWord] = []
    @Published var filteredVocabulary: [UserWord] = []
    @Published var searchText: String = ""
    @Published var selectedMastery: MasteryLevel? = nil
    @Published var selectedTag: String = "全部"
    @Published var sortOption: VocabularySortOption = .dateAdded
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Review Properties
    @Published var reviewWords: [UserWord] = []
    @Published var currentReviewIndex: Int = 0
    @Published var isReviewing: Bool = false
    @Published var reviewProgress: Double = 0.0
    @Published var reviewStats: ReviewStats = ReviewStats()
    
    // MARK: - Statistics
    @Published var vocabularyStats: VocabularyStatistics = VocabularyStatistics()
    
    // MARK: - Cache Properties
    private var vocabularyCache: (words: [UserWord], timestamp: Date)?
    private var statsCache: (stats: VocabularyStatistics, timestamp: Date)?
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟
    
    // MARK: - Services
    private let dictionaryService: DictionaryServiceProtocol
    private let userProgressService: UserProgressServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    
    // MARK: - Debounce
    private var searchCancellable: AnyCancellable?
    
    // MARK: - Callbacks
    var onWordMasteryUpdated: (() -> Void)?
    
    // MARK: - Initialization
    init(
        dictionaryService: DictionaryServiceProtocol,
        userProgressService: UserProgressServiceProtocol,
        errorHandler: ErrorHandlerProtocol
    ) {
        self.dictionaryService = dictionaryService
        self.userProgressService = userProgressService
        self.errorHandler = errorHandler
        
        setupSearchDebounce()
        loadVocabulary()
        loadStatistics()
    }
    
    // MARK: - Setup
    private func setupSearchDebounce() {
        searchCancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.filterVocabulary()
            }
    }
    
    // MARK: - Data Loading
    func loadVocabulary() {
        // 检查缓存
        if let cache = vocabularyCache,
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            self.vocabulary = cache.words
            self.filterVocabulary()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            let words = dictionaryService.getUserWordRecords()
            await MainActor.run {
                self.vocabulary = words
                self.vocabularyCache = (words, Date())
                self.filterVocabulary()
                self.isLoading = false
            }
            errorHandler.logSuccess("成功加载 \(words.count) 个词汇")
        }
    }
    
    func loadStatistics() {
        // 检查缓存
        if let cache = statsCache,
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            self.vocabularyStats = cache.stats
            return
        }
        
        Task {
            let stats = calculateStatistics()
            await MainActor.run {
                self.vocabularyStats = stats
                self.statsCache = (stats, Date())
            }
        }
    }
    
    private func calculateStatistics() -> VocabularyStatistics {
        let totalWords = vocabulary.count
        let unknownWords = vocabulary.filter { $0.masteryLevel == .unfamiliar }.count
        let learningWords = vocabulary.filter { $0.masteryLevel == .familiar }.count
        let familiarWords = vocabulary.filter { $0.masteryLevel == .familiar }.count
        let masteredWords = vocabulary.filter { $0.masteryLevel == .mastered }.count
        let wordsNeedingReview = vocabulary.filter { $0.isMarkedForReview }.count
        let totalLookups = vocabulary.reduce(0) { $0 + $1.lookupCount }
        let averageLookupCount = totalWords > 0 ? Double(totalLookups) / Double(totalWords) : 0
        
        return VocabularyStatistics(
            totalWords: totalWords,
            unknownWords: unknownWords,
            learningWords: learningWords,
            familiarWords: familiarWords,
            masteredWords: masteredWords,
            wordsNeedingReview: wordsNeedingReview,
            averageLookupCount: averageLookupCount,
            totalLookups: totalLookups
        )
    }
    
    // MARK: - Filtering and Sorting
    private func filterVocabulary() {
        var filtered = vocabulary
        
        // 搜索筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { word in
                word.word.localizedCaseInsensitiveContains(searchText) ||
                (word.selectedDefinition?.meaning.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (word.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // 掌握度筛选
        if let mastery = selectedMastery {
            filtered = filtered.filter { $0.masteryLevel == mastery }
        }
        
        // 排序
        filtered = sortWords(filtered, by: sortOption)
        
        filteredVocabulary = filtered
    }
    
    private func sortWords(_ words: [UserWord], by option: VocabularySortOption) -> [UserWord] {
        switch option {
        case .alphabetical:
            return words.sorted { $0.word < $1.word }
        case .dateAdded:
            return words.sorted { $0.firstLookupDate > $1.firstLookupDate }
        case .mastery:
            return words.sorted { $0.masteryLevel.level < $1.masteryLevel.level }
        case .frequency:
            return words.sorted { $0.lookupCount > $1.lookupCount }
        case .recent:
            return words.sorted { $0.lastLookupDate > $1.lastLookupDate }
        }
    }
    
    // MARK: - Filter Actions
    func setMasteryFilter(_ mastery: MasteryLevel?) {
        selectedMastery = mastery
        filterVocabulary()
    }
    
    func setTagFilter(_ tag: String) {
        selectedTag = tag
        filterVocabulary()
    }
    
    func setSortOption(_ option: VocabularySortOption) {
        sortOption = option
        filterVocabulary()
    }
    
    func clearFilters() {
        selectedMastery = nil
        selectedTag = "全部"
        searchText = ""
        sortOption = .dateAdded
        filterVocabulary()
    }
    
    // MARK: - Word Management
    func addWord(word: String, context: String) {
        Task {
            do {
                // 创建新的UserWord对象
                let newWord = UserWord(word: word, context: context, sentence: context)
                try await dictionaryService.addWord(newWord)
                
                await MainActor.run {
                    // 添加到本地数据
                    self.vocabulary.append(newWord)
                    
                    // 清除缓存并重新筛选
                    self.vocabularyCache = nil
                    self.statsCache = nil
                    self.filterVocabulary()
                    self.loadStatistics()
                }
                
                errorHandler.logSuccess("添加单词: \(word)")
            } catch {
                await MainActor.run {
                    self.errorMessage = "添加单词失败"
                }
                errorHandler.handle(error, context: "VocabularyViewModel.addWord")
            }
        }
    }
    
    func updateWordMastery(_ word: UserWord, mastery: MasteryLevel) {
        Task {
            dictionaryService.updateMasteryLevel(word, level: mastery)
            
            await MainActor.run {
                // 更新本地数据
                if let index = self.vocabulary.firstIndex(where: { $0.id == word.id }) {
                    self.vocabulary[index].masteryLevel = mastery
                }
                
                // 清除缓存并重新筛选
                self.vocabularyCache = nil
                self.statsCache = nil
                self.filterVocabulary()
                self.loadStatistics()
                
                // 通知协调器
                self.onWordMasteryUpdated?()
            }
            
            errorHandler.logSuccess("更新单词掌握度: \(word.word) -> \(mastery.rawValue)")
        }
    }
    
    func markWordForReview(_ word: UserWord) {
        Task {
            dictionaryService.toggleReviewFlag(for: word)
            
            await MainActor.run {
                // 更新本地数据
                if let index = self.vocabulary.firstIndex(where: { $0.id == word.id }) {
                    self.vocabulary[index].isMarkedForReview = true
                    self.vocabulary[index].lastLookupDate = Date()
                }
                
                self.filterVocabulary()
            }
            
            errorHandler.logSuccess("标记单词需要复习: \(word.word)")
        }
    }
    
    func addWordNote(_ word: UserWord, note: String) {
        Task {
            dictionaryService.addNote(word, note: note)
            
            await MainActor.run {
                // 更新本地数据
                if let index = self.vocabulary.firstIndex(where: { $0.id == word.id }) {
                    let existingNotes = self.vocabulary[index].notes ?? ""
                    if !existingNotes.isEmpty {
                        self.vocabulary[index].notes = existingNotes + "\n" + note
                    } else {
                        self.vocabulary[index].notes = note
                    }
                }
                
                self.filterVocabulary()
            }
            
            errorHandler.logSuccess("添加单词笔记: \(word.word)")
        }
    }
    
    func deleteWord(_ word: UserWord) {
        Task {
            dictionaryService.deleteWordRecord(word)
            
            await MainActor.run {
                // 从本地数据中移除
                self.vocabulary.removeAll { $0.id == word.id }
                
                // 清除缓存并重新筛选
                self.vocabularyCache = nil
                self.statsCache = nil
                self.filterVocabulary()
                self.loadStatistics()
            }
            
            errorHandler.logSuccess("删除单词: \(word.word)")
        }
    }
    
    // MARK: - Review Management
    func startReview() {
        Task {
            let wordsToReview = vocabulary.filter { $0.isMarkedForReview }
            
            await MainActor.run {
                self.reviewWords = wordsToReview
                self.currentReviewIndex = 0
                self.isReviewing = true
                self.reviewProgress = 0.0
                self.reviewStats = ReviewStats()
            }
            
            errorHandler.logSuccess("开始复习，共 \(wordsToReview.count) 个单词")
        }
    }
    
    func reviewWord(_ word: UserWord, correct: Bool) {
        // 更新复习统计
        if correct {
            reviewStats.correctCount += 1
        } else {
            reviewStats.incorrectCount += 1
        }
        
        // 记录复习结果
        Task {
            do {
                try await userProgressService.recordWordReview(
                    word: word.word,
                    correct: correct
                )
                
                // 根据复习结果调整掌握度
                let newMastery = calculateNewMastery(word.masteryLevel, correct: correct)
                if newMastery != word.masteryLevel {
                    dictionaryService.updateMasteryLevel(word, level: newMastery)
                }
                
            } catch {
                errorHandler.handle(error, context: "VocabularyViewModel.reviewWord")
            }
        }
        
        // 移动到下一个单词
        nextReviewWord()
    }
    
    func nextReviewWord() {
        currentReviewIndex += 1
        updateReviewProgress()
        
        if currentReviewIndex >= reviewWords.count {
            finishReview()
        }
    }
    
    func finishReview() {
        isReviewing = false
        
        // 记录复习会话
        Task {
            do {
                try await userProgressService.recordReviewSession(
                    wordsReviewed: reviewWords.count,
                    correctAnswers: reviewStats.correctCount
                )
                
                await MainActor.run {
                    // 刷新数据
                    self.vocabularyCache = nil
                    self.statsCache = nil
                    self.loadVocabulary()
                    self.loadStatistics()
                }
                
                errorHandler.logSuccess("完成复习会话")
            } catch {
                errorHandler.handle(error, context: "VocabularyViewModel.finishReview")
            }
        }
    }
    
    private func updateReviewProgress() {
        guard !reviewWords.isEmpty else { return }
        reviewProgress = Double(currentReviewIndex) / Double(reviewWords.count)
    }
    
    private func calculateNewMastery(_ currentMastery: MasteryLevel, correct: Bool) -> MasteryLevel {
        switch (currentMastery, correct) {
        case (.unfamiliar, true):
            return .familiar
        case (.familiar, true):
            return .mastered
        case (.mastered, false):
            return .familiar
        case (.familiar, false):
            return .unfamiliar
        default:
            return currentMastery
        }
    }
    
    // MARK: - Data Management
    func refreshVocabulary() {
        vocabularyCache = nil
        statsCache = nil
        loadVocabulary()
        loadStatistics()
    }
    
    func refreshSettings() {
        // 刷新词汇相关设置
        vocabularyCache = nil
        loadVocabulary()
    }
    
    func refreshData() {
        vocabularyCache = nil
        statsCache = nil
        loadVocabulary()
        loadStatistics()
    }
    
    func clearCache() {
        vocabularyCache = nil
        statsCache = nil
    }
    
    // MARK: - Export
    func exportVocabulary() -> Data? {
        do {
            // 创建可编码的导出数据结构
            let exportData = vocabulary.map { word in
                ExportableUserWord(
                    id: word.id,
                    word: word.word,
                    context: word.context,
                    sentence: word.sentence,
                    masteryLevel: word.masteryLevel,
                    lookupCount: word.lookupCount,
                    firstLookupDate: word.firstLookupDate,
                    lastLookupDate: word.lastLookupDate,
                    lastReviewDate: word.lastReviewDate,
                    nextReviewDate: word.nextReviewDate,
                    isMarkedForReview: word.isMarkedForReview,
                    notes: word.notes
                )
            }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(exportData)
        } catch {
            errorHandler.handle(error, context: "VocabularyViewModel.exportVocabulary")
            return nil
        }
    }
    
    // MARK: - Word Actions
    func showWordDetail(_ word: UserWord) {
        // This should be handled by coordinator/navigation
        // For now, we'll just log the action
        errorHandler.logSuccess("显示单词详情: \(word.word)")
    }
    
    func toggleReviewFlag(for word: UserWord) {
        Task {
            dictionaryService.toggleReviewFlag(for: word)
            
            await MainActor.run {
                // 更新本地数据
                if let index = self.vocabulary.firstIndex(where: { $0.id == word.id }) {
                    self.vocabulary[index].isMarkedForReview.toggle()
                }
                self.filterVocabulary()
            }
            
            errorHandler.logSuccess("切换复习标记: \(word.word)")
        }
    }
    
    func deleteWordRecord(_ word: UserWord) {
        deleteWord(word)
    }
    
    func showAllReviewWords() {
        // This should be handled by coordinator/navigation
        // For now, we'll just log the action
        errorHandler.logSuccess("显示所有复习单词")
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Computed Properties
    var availableTags: [String] {
        return ["全部"]
    }
    
    var hasVocabulary: Bool {
        !vocabulary.isEmpty
    }
    
    var hasFilteredResults: Bool {
        !filteredVocabulary.isEmpty
    }
    
    var wordsNeedingReview: [UserWord] {
        vocabulary.filter { $0.isMarkedForReview }
    }
    
    var currentReviewWord: UserWord? {
        guard isReviewing && currentReviewIndex < reviewWords.count else { return nil }
        return reviewWords[currentReviewIndex]
    }
    
    var reviewProgressPercentage: String {
        return String(format: "%.1f%%", reviewProgress * 100)
    }
}

// MARK: - Supporting Types

struct ReviewStats {
    var correctCount: Int = 0
    var incorrectCount: Int = 0
    var startTime: Date = Date()
    
    var totalCount: Int {
        correctCount + incorrectCount
    }
    
    var accuracy: Double {
        guard totalCount > 0 else { return 0 }
        return Double(correctCount) / Double(totalCount)
    }
    
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}

struct VocabularyStatistics {
    var totalWords: Int = 0
    var unknownWords: Int = 0
    var learningWords: Int = 0
    var familiarWords: Int = 0
    var masteredWords: Int = 0
    var wordsNeedingReview: Int = 0
    var averageLookupCount: Double = 0
    var totalLookups: Int = 0
    
    var masteryDistribution: [MasteryLevel: Int] {
        [
            .unfamiliar: unknownWords,
            .familiar: familiarWords,
            .mastered: masteredWords
        ]
    }
    
    var masteryPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords + familiarWords) / Double(totalWords)
    }
}

// 可导出的用户词汇数据结构
struct ExportableUserWord: Codable {
    let id: UUID
    let word: String
    let context: String
    let sentence: String
    let masteryLevel: MasteryLevel
    let lookupCount: Int
    let firstLookupDate: Date
    let lastLookupDate: Date
    let lastReviewDate: Date?
    let nextReviewDate: Date?
    let isMarkedForReview: Bool
    let notes: String?
}