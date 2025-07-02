//
//  DictionaryService.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData
import NaturalLanguage

@Observable
class DictionaryService {
    private var modelContext: ModelContext?
    private var dictionaryWords: [String: DictionaryWord] = [:]
    private let textProcessor = TextProcessor()
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        loadDictionary()
    }
    
    // MARK: - 词典管理
    
    // 加载词典数据
    private func loadDictionary() {
        // 从本地JSON文件加载词典数据
        loadDictionaryFromJSON()
        
        // 从数据库加载用户自定义词汇
        loadUserDictionary()
    }
    
    // 从JSON文件加载词典
    private func loadDictionaryFromJSON() {
        guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "json") else {
            print("找不到词典文件")
            initializeSampleDictionary()
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let dictionaryData = try JSONDecoder().decode([DictionaryWordData].self, from: data)
            
            for wordData in dictionaryData {
                let word = DictionaryWord(
                    word: wordData.word,
                    phonetic: wordData.phonetic,
                    definitions: wordData.definitions,
                    frequency: wordData.frequency,
                    difficulty: wordData.difficulty,
                    tags: wordData.tags
                )
                dictionaryWords[wordData.word.lowercased()] = word
            }
            
            print("成功加载\(dictionaryData.count)个词汇")
        } catch {
            print("加载词典失败: \(error)")
            initializeSampleDictionary()
        }
    }
    
    // 从数据库加载用户词典
    private func loadUserDictionary() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<DictionaryWord>()
        
        do {
            let userWords = try context.fetch(descriptor)
            for word in userWords {
                dictionaryWords[word.word.lowercased()] = word
            }
        } catch {
            print("加载用户词典失败: \(error)")
        }
    }
    
    // MARK: - 词汇查询
    
    // 查找单词定义
    func lookupWord(_ word: String, context: String = "") -> DictionaryWord? {
        let cleanWord = textProcessor.cleanWord(word)
        
        // 首先尝试精确匹配
        if let exactMatch = dictionaryWords[cleanWord.lowercased()] {
            return exactMatch
        }
        
        // 尝试词根匹配
        if let stemMatch = findByStem(cleanWord) {
            return stemMatch
        }
        
        // 尝试模糊匹配
        if let fuzzyMatch = findByFuzzyMatch(cleanWord) {
            return fuzzyMatch
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
        
        let contextWords = textProcessor.extractKeywords(from: context)
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
        let definitionWords = textProcessor.extractKeywords(from: definition.meaning)
        for word in contextWords {
            if definitionWords.contains(word) {
                score += 1.0
            }
        }
        
        // 检查例句中的关键词
        for example in definition.examples {
            let exampleWords = textProcessor.extractKeywords(from: example)
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
        let stem = textProcessor.stemWord(word)
        
        for (key, dictionaryWord) in dictionaryWords {
            if textProcessor.stemWord(key) == stem {
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
        
        for (key, dictionaryWord) in dictionaryWords {
            let similarity = textProcessor.calculateSimilarity(word, key)
            if similarity > threshold && similarity > bestSimilarity {
                bestSimilarity = similarity
                bestMatch = dictionaryWord
            }
        }
        
        return bestMatch
    }
    
    // MARK: - 用户词汇记录
    
    // 记录用户查词
    func recordWordLookup(word: String, context: String, sentence: String, article: Article?) -> UserWordRecord? {
        guard let context = modelContext else { return nil }
        
        let cleanWord = textProcessor.cleanWord(word)
        
        // 检查是否已存在记录
        let lowercaseWord = cleanWord.lowercased()
        let predicate = #Predicate<UserWordRecord> { record in
            record.word == lowercaseWord
        }
        
        let descriptor = FetchDescriptor<UserWordRecord>(predicate: predicate)
        
        do {
            let existingRecords = try context.fetch(descriptor)
            
            if let existingRecord = existingRecords.first {
                // 更新现有记录
                existingRecord.incrementLookupCount()
                existingRecord.context = sentence
                existingRecord.sentence = sentence
                existingRecord.article = article
                
                try context.save()
                return existingRecord
            } else {
                // 创建新记录
                let definition = getContextualDefinition(for: cleanWord, in: sentence)
                let newRecord = UserWordRecord(
                    word: cleanWord,
                    context: sentence,
                    sentence: sentence,
                    selectedDefinition: definition
                )
                newRecord.article = article
                
                context.insert(newRecord)
                try context.save()
                
                return newRecord
            }
        } catch {
            print("记录查词失败: \(error)")
            return nil
        }
    }
    
    // 获取用户词汇记录
    func getUserWordRecords() -> [UserWordRecord] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<UserWordRecord>(
            sortBy: [SortDescriptor(\UserWordRecord.lastLookupDate, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取用户词汇记录失败: \(error)")
            return []
        }
    }
    
    // 获取需要复习的单词
    func getWordsForReview() -> [UserWordRecord] {
        let allRecords = getUserWordRecords()
        return allRecords.filter { $0.needsReview }
    }
    
    // 根据掌握程度获取单词
    func getWordsByMastery(_ mastery: MasteryLevel) -> [UserWordRecord] {
        let allRecords = getUserWordRecords()
        return allRecords.filter { $0.masteryLevel == mastery }
    }
    
    // 更新单词掌握程度
    func updateWordMastery(_ record: UserWordRecord, level: MasteryLevel) {
        record.updateMasteryLevel(level)
        saveContext()
    }
    
    // 标记单词需要复习
    func markForReview(_ record: UserWordRecord) {
        record.isMarkedForReview = true
        record.nextReviewDate = Date()
        saveContext()
    }
    
    // 添加单词笔记
    func addNote(_ record: UserWordRecord, note: String) {
        record.notes = note
        saveContext()
    }
    
    // MARK: - 搜索功能
    
    // 搜索词汇
    func searchWords(query: String) -> [DictionaryWord] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let lowercaseQuery = query.lowercased()
        var results: [DictionaryWord] = []
        
        for (key, word) in dictionaryWords {
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
    func getVocabularyStats() -> VocabularyStats {
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
        guard let context = modelContext else { return }
        
        dictionaryWords[word.word.lowercased()] = word
        context.insert(word)
        
        do {
            try context.save()
        } catch {
            print("添加自定义词汇失败: \(error)")
        }
    }
    
    // 删除用户词汇记录
    func deleteUserWordRecord(_ record: UserWordRecord) {
        guard let context = modelContext else { return }
        
        context.delete(record)
        
        do {
            try context.save()
        } catch {
            print("删除词汇记录失败: \(error)")
        }
    }
    
    func deleteWordRecord(_ record: UserWordRecord) {
        deleteUserWordRecord(record)
    }
    
    func toggleReviewFlag(for record: UserWordRecord) {
        record.isMarkedForReview.toggle()
        if record.isMarkedForReview {
            record.nextReviewDate = Date()
        } else {
            record.nextReviewDate = nil
        }
        saveContext()
    }
    
    func clearAllRecords() {
        guard let modelContext = modelContext else { return }
        
        do {
            // 删除所有用户词汇记录
            try modelContext.delete(model: UserWordRecord.self)
            saveContext()
        } catch {
            print("清除词汇记录失败: \(error)")
        }
    }
    
    // 初始化示例词典
    func initializeSampleDictionary() {
        let sampleWords = [
            DictionaryWordData(
                word: "artificial",
                phonetic: "/ˌɑːrtɪˈfɪʃl/",
                definitions: [
                    WordDefinition(
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
                    WordDefinition(
                        partOfSpeech: .noun,
                        meaning: "智力，智能",
                        englishMeaning: "the ability to learn and understand",
                        examples: ["human intelligence", "artificial intelligence"],
                        contextKeywords: ["brain", "mind", "smart", "cognitive"]
                    ),
                    WordDefinition(
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
                    WordDefinition(
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
            let word = DictionaryWord(
                word: wordData.word,
                phonetic: wordData.phonetic,
                definitions: wordData.definitions,
                frequency: wordData.frequency,
                difficulty: wordData.difficulty,
                tags: wordData.tags
            )
            dictionaryWords[wordData.word.lowercased()] = word
        }
    }
    
    // MARK: - 私有方法
    
    private func saveContext() {
        guard let context = modelContext else { return }
        
        do {
            try context.save()
        } catch {
            print("保存上下文失败: \(error)")
        }
    }
}

// MARK: - 数据结构

// 词典数据结构（用于JSON导入）
struct DictionaryWordData: Codable {
    let word: String
    let phonetic: String?
    let definitions: [WordDefinition]
    let frequency: Int
    let difficulty: WordDifficulty
    let tags: [String]
}

// MARK: - 扩展

extension DictionaryService {
    // 设置模型上下文
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadUserDictionary()
    }
    
    // 获取词典大小
    var dictionarySize: Int {
        return dictionaryWords.count
    }
    
    // 检查单词是否存在
    func wordExists(_ word: String) -> Bool {
        let cleanWord = textProcessor.cleanWord(word)
        return dictionaryWords[cleanWord.lowercased()] != nil
    }
    
    // 获取随机单词（用于学习）
    func getRandomWords(count: Int = 10) -> [DictionaryWord] {
        let allWords = Array(dictionaryWords.values)
        return Array(allWords.shuffled().prefix(count))
    }
    
    // 根据难度获取单词
    func getWordsByDifficulty(_ difficulty: WordDifficulty, limit: Int = 50) -> [DictionaryWord] {
        let filteredWords = dictionaryWords.values.filter { $0.difficulty == difficulty }
        return Array(filteredWords.prefix(limit))
    }
    
    // 根据标签获取单词
    func getWordsByTag(_ tag: String) -> [DictionaryWord] {
        return dictionaryWords.values.filter { $0.tags.contains(tag) }
    }
}