//
//  DictionaryService.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData
import NaturalLanguage

class DictionaryService: BaseService, DictionaryServiceProtocol {
    func getWordsForReview(filter: ReviewFilter) -> [UserWord] {
        return []
    }
    
    func getWordsByMastery(level: MasteryLevel) -> [UserWord] {
        return []
    }
    
    func getWordHistory(limit: Int) -> [UserWord] {
        return []
    }
    
    func getVocabularyStats() -> VocabularyStats {
        return VocabularyStats(
            totalWords: 0,
            unfamiliarWords: 0,
            familiarWords: 0,
            masteredWords: 0,
            todayLookups: 0,
            weeklyLookups: 0,
            averageLookupPerDay: 0.0,
            mostLookedUpWords: []
        )
    }
    
    func clearWordHistory() {
        
    }
    
    private var dictionaryWords: [String: DictionaryWord] = [:]
    private let textProcessor = TextProcessor()
    
    init(
        modelContext: ModelContext,
        cacheManager: CacheManagerProtocol,
        errorHandler: ErrorHandlerProtocol
    ) {
        super.init(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler,
            subsystem: "com.en01.services",
            category: "DictionaryService"
        )
        Task {
            await loadDictionary()
        }
    }
    
    // MARK: - 词典管理
    
    // 加载词典数据
    private func loadDictionary() async {
        // 从本地JSON文件加载词典数据
        await loadDictionaryFromJSON()
        
        // 从数据库加载用户自定义词汇
        loadUserDictionary()
    }
    
    /// 从JSON文件加载词典数据
    /// 使用异步加载以避免阻塞主线程
    private func loadDictionaryFromJSON() async {
        guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "json") else {
            print("[WARNING] 找不到词典文件，使用示例数据")
            initializeSampleDictionary()
            return
        }
        
        Task {
            do {
                let data = try Data(contentsOf: url)
                let dictionaryData = try JSONDecoder().decode([DictionaryWordData].self, from: data)
                
                // 使用批量操作提高性能
                await MainActor.run {
                    var tempDictionary: [String: DictionaryWord] = [:]
                    tempDictionary.reserveCapacity(dictionaryData.count)
                    
                    for wordData in dictionaryData {
                        // 转换WordDefinitionData为WordDefinition
                        let definitions = wordData.definitions.map { defData in
                            WordDefinition(
                                partOfSpeech: defData.partOfSpeech,
                                meaning: defData.meaning,
                                englishMeaning: defData.englishMeaning,
                                examples: defData.examples,
                                contextKeywords: defData.contextKeywords
                            )
                        }
                        
                        let word = DictionaryWord(
                            word: wordData.word,
                            phonetic: wordData.phonetic,
                            definitions: definitions,
                            frequency: wordData.frequency,
                            difficulty: wordData.difficulty,
                            tags: wordData.tags
                        )
                        tempDictionary[wordData.word.lowercased()] = word
                    }
                    
                    self.dictionaryWords = tempDictionary
                    print("[SUCCESS] 成功加载\(dictionaryData.count)个词汇")
                }
            } catch {
                print("[ERROR] 加载词典失败: \(error.localizedDescription)")
                await MainActor.run {
                    self.initializeSampleDictionary()
                }
            }
        }
    }
    
    // 从数据库加载用户词典
    private func loadUserDictionary() {
        self.performSafeOperation("加载用户词典") {
            let descriptor = FetchDescriptor<DictionaryWord>()
            let userWords = self.safeFetch(descriptor, operation: "获取用户词汇")
            for word in userWords {
                self.dictionaryWords[word.word.lowercased()] = word
            }
            self.logger.info("用户词典加载完成，共 \(userWords.count) 个词汇")
        }
    }
    
    // MARK: - 词汇查询
    
    /// 查找单词定义（带缓存优化）
    /// - Parameters:
    ///   - word: 要查找的单词
    ///   - context: 上下文信息
    /// - Returns: 词典中的单词定义，如果未找到则返回nil
    func lookupWord(_ word: String, context: String = "") -> DictionaryWord? {
        let cleanWord = self.textProcessor.cleanWord(word)
        let lowercaseWord = cleanWord.lowercased()
        
        // 性能优化：首先检查空字符串
        guard !lowercaseWord.isEmpty else { return nil }
        
        // 首先尝试精确匹配（最快）
        if let exactMatch = self.dictionaryWords[lowercaseWord] {
            return exactMatch
        }
        
        // 尝试词根匹配（中等性能消耗）
        if let stemMatch = findByStem(cleanWord) {
            return stemMatch
        }
        
        // 尝试模糊匹配（性能消耗较大，仅在必要时使用）
        if cleanWord.count >= 3 { // 只对长度>=3的单词进行模糊匹配
            if let fuzzyMatch = findByFuzzyMatch(cleanWord) {
                return fuzzyMatch
            }
        }
        
        return nil
    }
    
    // 智能词义匹配（基于上下文）
    func getContextualDefinition(for word: String, in context: String) -> WordDefinition? {
        guard let dictionaryWord = lookupWord(word, context: context) else {
            return nil
        }
        
        // 如果只有一个定义，直接返回
        if dictionaryWord.definitions.count == 1 {
            return dictionaryWord.definitions.first
        }
        
        // 使用上下文分析选择最合适的定义
        return selectBestDefinition(from: dictionaryWord.definitions, context: context)
    }
    
    // 选择最佳定义
    private func selectBestDefinition(from definitions: [WordDefinition], context: String) -> WordDefinition? {
        guard !definitions.isEmpty else { return nil }
        
        let contextWords = self.textProcessor.extractKeywords(from: context)
        var bestDefinition = definitions.first!
        var bestScore = 0.0
        
        for definition in definitions {
            let score = calculateDefinitionScore(definition, contextWords: contextWords)
            if score > bestScore {
                bestScore = score
                bestDefinition = definition
            }
        }
        
        return bestDefinition
    }
    
    // 计算定义匹配分数
    private func calculateDefinitionScore(_ definition: WordDefinition, contextWords: [String]) -> Double {
        var score = 0.0
        
        // 检查上下文关键词匹配
        for keyword in definition.contextKeywords {
            if contextWords.contains(keyword.lowercased()) {
                score += 2.0
            }
        }
        
        // 检查释义中的关键词
        let definitionWords = self.textProcessor.extractKeywords(from: definition.meaning)
        for word in contextWords {
            if definitionWords.contains(word) {
                score += 1.0
            }
        }
        
        // 检查例句中的关键词
        for example in definition.examples {
            let exampleWords = self.textProcessor.extractKeywords(from: example)
            for word in contextWords {
                if exampleWords.contains(word) {
                    score += 0.5
                }
            }
        }
        
        return score
    }
    
    // 词根匹配
    private func findByStem(_ word: String) -> DictionaryWord? {
        let stem = self.textProcessor.stemWord(word)
        
        for (key, dictionaryWord) in self.dictionaryWords {
            if self.textProcessor.stemWord(key) == stem {
                return dictionaryWord
            }
        }
        
        return nil
    }
    
    // 模糊匹配
    private func findByFuzzyMatch(_ word: String) -> DictionaryWord? {
        let threshold = 0.8
        var bestMatch: DictionaryWord?
        var bestSimilarity = 0.0
        
        for (key, dictionaryWord) in self.dictionaryWords {
            let similarity = self.textProcessor.calculateSimilarity(word, key)
            if similarity > threshold && similarity > bestSimilarity {
                bestSimilarity = similarity
                bestMatch = dictionaryWord
            }
        }
        
        return bestMatch
    }
    
    // MARK: - 用户词汇记录
    
    // 记录用户查词 - 协议要求的方法
    func recordWordLookup(word: String, context: String, sentence: String, article: Article) -> UserWord {
        return self.performSafeOperation("记录查词") {
            let cleanWord = self.textProcessor.cleanWord(word)
            let lowercaseWord = cleanWord.lowercased()
            
            // 检查是否已存在记录
            let predicate = #Predicate<UserWord> { record in
                record.word == lowercaseWord
            }
            
            let descriptor = FetchDescriptor<UserWord>(predicate: predicate)
            let existingRecords = self.safeFetch(descriptor, operation: "获取现有词汇记录")
            
            if let existingRecord = existingRecords.first {
                // 更新现有记录
                existingRecord.incrementLookupCount()
                existingRecord.context = context
                existingRecord.sentence = sentence
                
                self.safeSave(operation: "更新词汇记录")
                return existingRecord
            } else {
                // 创建新记录
                let definition = self.getContextualDefinition(for: cleanWord, in: context)
                let newRecord = UserWord(
                    word: cleanWord,
                    context: context,
                    sentence: sentence,
                    selectedDefinition: definition
                )
                newRecord.articleID = article.id.uuidString
                
                self.modelContext.insert(newRecord)
                self.safeSave(operation: "保存新词汇记录")
                
                return newRecord
            }
        } ?? UserWord(word: word, context: context, sentence: sentence, selectedDefinition: nil)
    }
    
    // 协议要求的异步查词方法
    func lookupWord(_ word: String) async throws -> UserWord {
        let cleanWord = self.textProcessor.cleanWord(word)
        let definition = self.getContextualDefinition(for: cleanWord, in: "")
        
        return UserWord(
            word: cleanWord,
            context: "",
            sentence: "",
            selectedDefinition: definition
        )
    }
    
    // 记录用户查词 - 异步版本
    private func recordWordLookupAsync(for word: String, context: String?) async {
        self.performSafeOperation("记录查词") {
            let cleanWord = self.textProcessor.cleanWord(word)

            // 检查是否已存在记录
            let lowercaseWord = cleanWord.lowercased()
            let predicate = #Predicate<UserWord> { record in
                record.word == lowercaseWord
            }

            let descriptor = FetchDescriptor<UserWord>(predicate: predicate)
            let existingRecords = self.safeFetch(descriptor, operation: "获取词汇记录")

            if let existingRecord = existingRecords.first {
                // 更新现有记录
                existingRecord.incrementLookupCount()
                existingRecord.context = context ?? ""

                self.safeSave(operation: "更新词汇复习记录")
                return existingRecord
            } else {
                // 创建新记录
                let definition = self.getContextualDefinition(for: cleanWord, in: context ?? "")
                let newRecord = UserWord(
                    word: cleanWord,
                    context: context ?? "",
                    sentence: context ?? "",
                    selectedDefinition: definition
                )

                self.modelContext.insert(newRecord)
                self.safeSave(operation: "保存新复习记录")

                return newRecord
            }
        }
    }
    
    // 获取用户词汇记录
    func getUserWordRecords() -> [UserWord] {
        return self.performSafeOperation("获取用户词汇记录") {
            let descriptor = FetchDescriptor<UserWord>(
                sortBy: [SortDescriptor(\UserWord.lastLookupDate, order: .reverse)]
            )
            return self.safeFetch(descriptor, operation: "获取用户词汇列表")
        } ?? []
    }
    
    // 获取需要复习的单词
    func getWordsForReview() -> [UserWord] {
        let allRecords = getUserWordRecords()
        return allRecords.filter { $0.needsReview }
    }
    
    // 根据掌握程度获取单词
    func getWordsByMastery(_ mastery: MasteryLevel) -> [UserWord] {
        let allRecords = getUserWordRecords()
        return allRecords.filter { $0.masteryLevel == mastery }
    }
    
    // 更新单词掌握程度
    func updateWordMastery(_ record: UserWord, level: MasteryLevel) {
        record.updateMasteryLevel(level)
        saveContext()
    }
    
    // 标记单词需要复习
    func markForReview(_ record: UserWord) {
        record.isMarkedForReview = true
        record.nextReviewDate = Date()
        saveContext()
    }
    
    // 添加单词笔记
    func addNote(_ record: UserWord, note: String) {
        self.performSafeOperation("添加笔记") {
            if let existingNotes = record.notes, !existingNotes.isEmpty {
                record.notes = existingNotes + "\n" + note
            } else {
                record.notes = note
            }
            self.safeSave(operation: "更新词汇熟练度")
        }
    }

    func addUnknownWord(_ word: UserWord) async throws {
        self.modelContext.insert(word)
            self.safeSave(operation: "保存新词汇")
    }

    func addWord(_ word: UserWord) async throws {
        self.modelContext.insert(word)
        try self.modelContext.save()
    }

    func updateWordMastery(_ record: UserWord, level: MasteryLevel, correct: Bool) {
        
    }

    func toggleReviewFlag(for record: UserWord) {
        record.isMarkedForReview.toggle()
        if record.isMarkedForReview {
            record.nextReviewDate = Date()
        } else {
            record.nextReviewDate = nil
        }
        self.saveContext()
    }

    func deleteWordRecord(_ record: UserWord) {
        self.performSafeOperation("删除词汇记录") {
            self.modelContext.delete(record)
            self.safeSave(operation: "删除词汇记录")
        }
    }

    func clearAllRecords() {
        self.performSafeOperation("清除所有词汇记录") {
            // 删除所有用户词汇记录
            try self.modelContext.delete(model: UserWord.self)
            self.safeSave(operation: "清空词汇记录")
            self.logger.info("成功清除所有词汇记录")
        }
    }

    func updateMasteryLevel(_ record: UserWord, level: MasteryLevel) {
        self.performSafeOperation("更新掌握水平") {
            record.masteryLevel = level
            record.updateReviewDate(basedOn: level)
            self.safeSave(operation: "切换复习标记")
        }
    }

    func initializeDictionary() async throws {
        await loadDictionary()
    }

    // MARK: - 搜索功能
    
    // 搜索词汇
        func searchWords(_ query: String) -> [DictionaryWord] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let lowercaseQuery = query.lowercased()
        var results: [DictionaryWord] = []
        
        for (key, word) in self.dictionaryWords {
            // 精确匹配
            if key.hasPrefix(lowercaseQuery) {
                results.append(word)
            }
            // 包含匹配
            else if key.contains(lowercaseQuery) {
                results.append(word)
            }
            // 释义匹配
            else if word.definitions.contains(where: { $0.meaning.localizedCaseInsensitiveContains(query) }) {
                results.append(word)
            }
        }
        
        // 按相关性排序
        return results.sorted { word1, word2 in
            let score1 = calculateSearchScore(word1, query: lowercaseQuery)
            let score2 = calculateSearchScore(word2, query: lowercaseQuery)
            return score1 > score2
        }
    }
    
    // 计算搜索相关性分数
    private func calculateSearchScore(_ word: DictionaryWord, query: String) -> Double {
        var score = 0.0
        
        // 单词匹配
        if word.word == query {
            score += 100.0
        } else if word.word.hasPrefix(query) {
            score += 50.0
        } else if word.word.contains(query) {
            score += 25.0
        }
        
        // 频率加分
        score += Double(word.frequency) * 0.1
        
        // 难度调整（简单词汇优先）
        score += Double(5 - word.difficulty.level)
        
        return score
    }
    
    // MARK: - 统计功能
    
    // 获取词汇统计
    func getVocabularyStats() -> VocabularyStats? {
        let userRecords = getUserWordRecords()
        
        let totalWords = userRecords.count
        let unfamiliarWords = userRecords.filter { $0.masteryLevel == .unfamiliar }.count
        let familiarWords = userRecords.filter { $0.masteryLevel == .familiar }.count
        let masteredWords = userRecords.filter { $0.masteryLevel == .mastered }.count
        
        // 今日查词数
        let today = Calendar.current.startOfDay(for: Date())
        let todayLookups = userRecords.filter {
            Calendar.current.isDate($0.lastLookupDate, inSameDayAs: today)
        }.count
        
        // 本周查词数
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weeklyLookups = userRecords.filter { $0.lastLookupDate >= weekAgo }.count
        
        // 平均每日查词数
        let studyDays = userRecords.isEmpty ? 1 : max(1, Calendar.current.dateComponents([.day], from: userRecords.last?.firstLookupDate ?? Date(), to: Date()).day ?? 1)
        let averageLookupPerDay = Double(totalWords) / Double(studyDays)
        
        // 最常查询的单词
        let mostLookedUpWords = userRecords.sorted { $0.lookupCount > $1.lookupCount }.prefix(10)
        
        return VocabularyStats(
            totalWords: totalWords,
            unfamiliarWords: unfamiliarWords,
            familiarWords: familiarWords,
            masteredWords: masteredWords,
            todayLookups: todayLookups,
            weeklyLookups: weeklyLookups,
            averageLookupPerDay: averageLookupPerDay,
            mostLookedUpWords: Array(mostLookedUpWords)
        )
    }
    
    // MARK: - 数据管理
    
    // 添加自定义词汇
    func addCustomWord(_ word: DictionaryWord) {
        self.performSafeOperation("添加自定义词汇") {
            self.dictionaryWords[word.word.lowercased()] = word
            self.modelContext.insert(word)
            self.safeSave(operation: "保存词汇")
            self.logger.info("成功添加自定义词汇: \(word.word)")
        }
    }
    

    
    // 初始化示例词典
    func initializeSampleDictionary() {
        let sampleWords = [
            DictionaryWordData(
                word: "artificial",
                phonetic: "/ˌɑːrtɪˈfɪʃl/",
                definitions: [
                    WordDefinitionData(
                        partOfSpeech: .adjective,
                        meaning: "人工的，人造的",
                        englishMeaning: "made by humans, not natural",
                        examples: ["artificial intelligence", "artificial flowers"],
                        contextKeywords: ["technology", "computer", "machine", "synthetic"]
                    )
                ],
                frequency: 85,
                difficulty: .medium,
                tags: ["高频词", "科技"]
            ),
            DictionaryWordData(
                word: "intelligence",
                phonetic: "/ɪnˈtelɪdʒəns/",
                definitions: [
                    WordDefinitionData(
                        partOfSpeech: .noun,
                        meaning: "智力，智能",
                        englishMeaning: "the ability to learn and understand",
                        examples: ["human intelligence", "artificial intelligence"],
                        contextKeywords: ["brain", "mind", "smart", "cognitive"]
                    ),
                    WordDefinitionData(
                        partOfSpeech: .noun,
                        meaning: "情报，信息",
                        englishMeaning: "secret information",
                        examples: ["military intelligence", "intelligence agency"],
                        contextKeywords: ["spy", "secret", "military", "government"]
                    )
                ],
                frequency: 92,
                difficulty: .medium,
                tags: ["高频词", "核心词汇"]
            ),
            DictionaryWordData(
                word: "transform",
                phonetic: "/trænsˈfɔːrm/",
                definitions: [
                    WordDefinitionData(
                        partOfSpeech: .verb,
                        meaning: "转变，改变",
                        englishMeaning: "to change completely",
                        examples: ["transform society", "digital transformation"],
                        contextKeywords: ["change", "convert", "modify", "alter"]
                    )
                ],
                frequency: 78,
                difficulty: .medium,
                tags: ["动词", "变化"]
            )
        ]
        
        for wordData in sampleWords {
            // 转换WordDefinitionData为WordDefinition
            let definitions = wordData.definitions.map { defData in
                WordDefinition(
                    partOfSpeech: defData.partOfSpeech,
                    meaning: defData.meaning,
                    englishMeaning: defData.englishMeaning,
                    examples: defData.examples,
                    contextKeywords: defData.contextKeywords
                )
            }
            
            let word = DictionaryWord(
                word: wordData.word,
                phonetic: wordData.phonetic,
                definitions: definitions,
                frequency: wordData.frequency,
                difficulty: wordData.difficulty,
                tags: wordData.tags
            )
            self.dictionaryWords[wordData.word.lowercased()] = word
        }
    }
    
    // MARK: - 私有方法
     
     private func saveContext() {
         self.safeSave(operation: "保存词典上下文")
     }
}

// MARK: - 数据结构

// 词典数据结构（用于JSON导入）
struct DictionaryWordData: Codable {
    let word: String
    let phonetic: String?
    let definitions: [WordDefinitionData]
    let frequency: Int
    let difficulty: WordDifficulty
    let tags: [String]
}

// 词汇释义数据结构（用于JSON导入）
struct WordDefinitionData: Codable {
    let partOfSpeech: PartOfSpeech
    let meaning: String
    let englishMeaning: String?
    let examples: [String]
    let contextKeywords: [String]
    
    init(partOfSpeech: PartOfSpeech, meaning: String, englishMeaning: String? = nil, examples: [String] = [], contextKeywords: [String] = []) {
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
        self.englishMeaning = englishMeaning
        self.examples = examples
        self.contextKeywords = contextKeywords
    }
}

// MARK: - 扩展

extension DictionaryService {
    
    // 获取词典大小
    var dictionarySize: Int {
        return self.dictionaryWords.count
    }
    
    // 检查单词是否存在
    func wordExists(_ word: String) -> Bool {
        let cleanWord = self.textProcessor.cleanWord(word)
        return self.dictionaryWords[cleanWord.lowercased()] != nil
    }
    
    // 获取随机单词（用于学习）
    func getRandomWords(count: Int = 10) -> [DictionaryWord] {
        let allWords = Array(self.dictionaryWords.values)
        return Array(allWords.shuffled().prefix(count))
    }
    
    // 根据难度获取单词
    func getWordsByDifficulty(_ difficulty: WordDifficulty, limit: Int = 50) -> [DictionaryWord] {
        let filteredWords = self.dictionaryWords.values.filter { $0.difficulty == difficulty }
        return Array(filteredWords.prefix(limit))
    }
    
    // 根据标签获取单词
    func getWordsByTag(_ tag: String) -> [DictionaryWord] {
        return self.dictionaryWords.values.filter { $0.tags.contains(tag) }
    }
}