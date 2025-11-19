//
//  DictionaryService.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData
import NaturalLanguage
import Combine // 添加以支持ObservableObject

// MARK: - Dictionary Service Errors
enum DictionaryServiceError: Error {
    case dictionaryNotFound
    case fileNotFound
    case decodingError
    case loadingTimeout
}

// MARK: - Dictionary File Format
// Note: DictionaryFileFormat is defined in DictionaryLoader.swift

class DictionaryService: BaseService, DictionaryServiceProtocol { // 移除冗余的ObservableObject
    // 添加@Published属性以支持观察，例如：
    @Published var dictionaryWords: [String: DictionaryWord] = [:] // 使dictionaryWords可观察
    
    // 添加词典加载状态跟踪
    @Published var isBaseDictionaryLoaded: Bool = false
    @Published var isKaoyanDictionaryLoaded: Bool = false
    @Published var kaoyanDictionaryLoadingProgress: Double = 0.0
    
    private let textProcessor = TextProcessor()
    private let dictionaryLoader = DictionaryLoader()
    private let youdaoParser = YoudaoDictionaryParser()
    
    // 同步触发器管理器
    private weak var syncTriggerManager: SyncTriggerManager?
    
    // 分批加载配置
    private let batchSize = 1000 // 每批加载1000个单词
    private let maxLoadTime: TimeInterval = 3.0 // 最大加载时间3秒
    
    // 考研词典缓存
    private var kaoyanWordsCache: [KaoyanWord] = []
    private var kaoyanCacheLastUpdated: Date?
    private let kaoyanCacheValidityDuration: TimeInterval = 300 // 5分钟缓存有效期
    private var generalUserWordsCache: ([UserWord], Date)?
    private let generalUserWordsCacheTTL: TimeInterval = 300
    private var lastGeneralCacheLogAt: Date?
    
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
        Task { @MainActor in
            await loadDictionary()
        }
    }
    
    // MARK: - 同步触发器管理
    
    /// 设置同步触发器管理器
    func setSyncTriggerManager(_ manager: SyncTriggerManager) {
        self.syncTriggerManager = manager
    }
    
    // MARK: - 词典状态管理
    
    /// 检查基础词典是否已加载
    func isBaseDictionaryReady() -> Bool {
        return isBaseDictionaryLoaded && !dictionaryWords.isEmpty
    }
    
    /// 检查考研词典是否已加载
    func isKaoyanDictionaryReady() -> Bool {
        return isKaoyanDictionaryLoaded
    }
    
    /// 获取考研词典加载进度
    func getKaoyanDictionaryProgress() -> Double {
        return kaoyanDictionaryLoadingProgress
    }
    
    /// 等待考研词典加载完成（最多等待指定时间）
    func waitForKaoyanDictionary(timeout: TimeInterval = 10.0) async throws -> Bool {
        let startTime = Date()
        
        while !isKaoyanDictionaryLoaded {
            if Date().timeIntervalSince(startTime) > timeout {
                logger.warning("[DictionaryService] 等待考研词典加载超时: \(timeout)秒")
                throw DictionaryServiceError.loadingTimeout
            }
            
            // 每100ms检查一次
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        logger.info("[DictionaryService] 考研词典加载完成，等待时间: \(Date().timeIntervalSince(startTime))秒")
        return true
    }
    
    /// 刷新考研词典缓存
    private func refreshKaoyanCache() {
        do {
            let descriptor = FetchDescriptor<KaoyanWord>()
            kaoyanWordsCache = try modelContext.fetch(descriptor)
            kaoyanCacheLastUpdated = Date()
            logger.info("[DictionaryService] 考研词典缓存已刷新，共 \(kaoyanWordsCache.count) 个单词")
        } catch {
            logger.error("[DictionaryService] 刷新考研词典缓存失败: \(error.localizedDescription)")
            kaoyanWordsCache = []
        }
    }
    
    /// 检查考研词典缓存是否有效
    private func isKaoyanCacheValid() -> Bool {
        guard let lastUpdated = kaoyanCacheLastUpdated else { return false }
        return Date().timeIntervalSince(lastUpdated) < kaoyanCacheValidityDuration
    }

    /// 获取可用词典列表
    func getAvailableDictionaries() -> AnyPublisher<[DictionaryInfo], Error> {
        return Future { [weak self] promise in
            Task {
                do {
                    let existingInfos = self?.dictionaryLoader.getDictionaryInfos() ?? []
                    if existingInfos.isEmpty {
                        try await self?.dictionaryLoader.loadDictionaryInfosOnly()
                    }
                    var dictionaries = self?.dictionaryLoader.getDictionaryInfos() ?? []
                    
                    // 添加"我的学习记录"虚拟词典
                    if let strongSelf = self {
                        let totalUserWords = strongSelf.getGeneralUserWordRecords().count
                        let myLearningRecords = DictionaryInfo.myLearningRecords(totalWords: totalUserWords)
                        dictionaries.insert(myLearningRecords, at: 0) // 插入到列表开头
                    }
                    
                    self?.logger.info("[DictionaryService] Infos-only dictionaries ready: \(dictionaries.count)")
                    promise(.success(dictionaries))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 加载指定词典的单词（支持分批加载）
    func loadDictionary(fileName: String) -> AnyPublisher<[DictionaryWord], Error> {
        return Future { [weak self] promise in
            Task {
                await self?.loadDictionaryWithBatching(fileName: fileName, promise: promise)
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 分批加载词典实现
    private func loadDictionaryWithBatching(fileName: String, promise: @escaping (Result<[DictionaryWord], Error>) -> Void) async {
        let startTime = Date()
        
        do {
            // 获取词典信息
            guard let dictionaryInfo = dictionaryLoader.getDictionaryInfos().first(where: { $0.fileName == fileName }) else {
                promise(.failure(DictionaryServiceError.dictionaryNotFound))
                return
            }
            
            // 如果词典较小，直接加载
            if dictionaryInfo.totalWords <= batchSize {
                let words = try await dictionaryLoader.loadWords(for: fileName)
                logger.info("[DictionaryService] Loaded full dictionary via cache: \(fileName) -> \(words.count) words")
                promise(.success(words))
                return
            }
            
            // 大词典分批加载
            let allWords = try await dictionaryLoader.loadWords(for: fileName)
            let totalBatches = (allWords.count + batchSize - 1) / batchSize
            
            for batchIndex in 0..<totalBatches {
                // 检查是否超时
                if Date().timeIntervalSince(startTime) > maxLoadTime {
                    logger.warning("Dictionary loading timeout, prepared \(allWords.count) words")
                    break
                }
                
                let offset = batchIndex * batchSize
                guard offset < allWords.count else { break }
                let endIndex = min(offset + batchSize, allWords.count)
                _ = Array(allWords[offset..<endIndex]) // 触发分批分片但不立即返回，累计到末尾一次性返回
                
                // 添加小延迟以避免阻塞主线程
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            logger.info("[DictionaryService] Prepared \(allWords.count) words from \(fileName) in \(Date().timeIntervalSince(startTime))s")
            promise(.success(allWords))
            
        } catch {
            logger.error("Failed to load dictionary with batching: \(error.localizedDescription)")
            promise(.failure(error))
        }
    }
    
    /// 加载完整词典（小词典）
    private func loadFullDictionary(fileName: String) async throws -> [DictionaryWord] {
        // 改为复用 DictionaryLoader 的缓存与解析逻辑
        let words = try await dictionaryLoader.loadWords(for: fileName)
        logger.info("[DictionaryService] loadFullDictionary via loader: \(fileName) -> \(words.count) words")
        return words
    }
    
    /// 加载词典批次
    private func loadDictionaryBatch(fileName: String, offset: Int, limit: Int) async throws -> [DictionaryWord] {
        // 复用已解析的结果，避免重复解析耗时与内存占用
        let allWords = try await dictionaryLoader.loadWords(for: fileName)
        let endIndex = min(offset + limit, allWords.count)
        guard offset < allWords.count else { return [] }
        let batchWords = Array(allWords[offset..<endIndex])
        logger.info("[DictionaryService] Loaded batch via cache \(offset)-\(endIndex-1) from \(fileName): \(batchWords.count) words")
        return batchWords
    }
    
    // 加载词典数据
    private func loadDictionary() async {
        await loadDictionaryFromJSON()
        await MainActor.run {
            self.isBaseDictionaryLoaded = true
            self.logger.info("[DictionaryService] 基础词典加载完成，共 \(self.dictionaryWords.count) 个单词")
        }
    }
    
    /// 从JSON文件加载词典数据
    /// 使用异步加载以避免阻塞主线程
    private func loadDictionaryFromJSON() async {
        guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "json") else {
            print("[WARNING] 找不到词典文件，使用示例数据")
            await MainActor.run {
                initializeSampleDictionary()
            }
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
                            tags: wordData.tags,
                            categories: wordData.categories
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
        
        // 尝试词形变化匹配
        if let morphMatch = findByMorphology(cleanWord) {
            return morphMatch
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
    
    // 词形变化匹配
    private func findByMorphology(_ word: String) -> DictionaryWord? {
        let morphologyProcessor = WordMorphologyProcessor.shared
        let possibleForms = morphologyProcessor.getAllPossibleForms(for: word)
        
        // 检查所有可能的词形
        for form in possibleForms {
            let lowercaseForm = form.lowercased()
            if let match = self.dictionaryWords[lowercaseForm] {
                return match
            }
        }
        
        // 反向匹配：检查词典中的词是否是查询词的变形
        for (key, dictionaryWord) in self.dictionaryWords {
            let wordForms = morphologyProcessor.getAllPossibleForms(for: key)
            if wordForms.contains(where: { $0.lowercased() == word.lowercased() }) {
                return dictionaryWord
            }
        }
        
        return nil
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
    
    
    // 获取需要复习的单词
    
    
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
        let result = self.performSafeOperation("记录查词") {
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
        
        // 触发查词同步 - 使用测试记录触发器，因为查词也是一种学习行为
        if let userWord = result {
            // 创建临时的TestedWord记录用于触发同步
            let tempTestedWord = TestedWord(
                word: userWord.word,
                dictionaryName: userWord.testSource ?? "General",
                dictionaryFileName: "",
                masteryLevel: userWord.masteryLevel
            )
            
            // 触发同步
            await syncTriggerManager?.triggerAfterTestRecord(
                word: userWord.word,
                dictionaryFileName: userWord.testSource ?? "General",
                testRecord: tempTestedWord
            )
        }
    }
    
    // 获取用户词汇记录
    private func normalizeWordKey(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix("- ") { s = String(s.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines) }
        while s.hasPrefix("* ") { s = String(s.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines) }
        while s.hasPrefix("• ") { s = String(s.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines) }
        var idx = s.startIndex
        var digitsCount = 0
        while idx < s.endIndex, s[idx].isNumber { digitsCount += 1; idx = s.index(after: idx) }
        if digitsCount > 0, idx < s.endIndex, s[idx] == "." {
            let nextIdx = s.index(after: idx)
            if nextIdx < s.endIndex, s[nextIdx] == " " {
                s = String(s[nextIdx...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if let start = s.range(of: "**"), let end = s.range(of: "**", range: start.upperBound..<s.endIndex) {
            s = String(s[start.upperBound..<end.lowerBound])
        }
        return s.trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    func getUserWordRecords() -> [UserWord] {
        return self.performSafeOperation("获取用户词汇记录") {
            // 获取查词记录的UserWord
            let userWordDescriptor = FetchDescriptor<UserWord>(
                sortBy: [SortDescriptor(\UserWord.lastLookupDate, order: .reverse)]
            )
            let userWords = self.safeFetch(userWordDescriptor, operation: "获取用户词汇列表")
            print("✅ [DictionaryService] 获取到 \(userWords.count) 个查词记录")
            
            // 获取测试记录的TestedWord
            let testedWordDescriptor = FetchDescriptor<TestedWord>(
                sortBy: [SortDescriptor(\TestedWord.testedAt, order: .reverse)]
            )
            let testedWords = self.safeFetch(testedWordDescriptor, operation: "获取测试词汇列表")
            print("✅ [DictionaryService] 获取到 \(testedWords.count) 个测试记录")
            
            // 创建词汇映射表，避免重复查找
            var wordMap: [String: UserWord] = [:]
            
            // 首先添加所有查词记录
            for userWord in userWords {
                wordMap[normalizeWordKey(userWord.word)] = userWord
            }
            
            // 处理测试记录
            var newWordsFromTest = 0
            var updatedExistingWords = 0
            
            for testedWord in testedWords {
                let wordKey = normalizeWordKey(testedWord.word)
                
                if let existingWord = wordMap[wordKey] {
                    var assignedDefinition: WordDefinition? = nil
                    if existingWord.selectedDefinition == nil {
                        assignedDefinition = self.lookupWord(testedWord.word, context: "词汇量测试")?.definitions.first
                    }
                    if Thread.isMainThread {
                        existingWord.isFromTest = true
                        existingWord.testID = testedWord.testSessionId?.uuidString
                        existingWord.testSource = testedWord.dictionaryName
                        existingWord.masteryLevel = testedWord.masteryLevelEnum
                        if existingWord.selectedDefinition == nil, let def = assignedDefinition {
                            existingWord.selectedDefinition = def
                        }
                    } else {
                        DispatchQueue.main.sync {
                            existingWord.isFromTest = true
                            existingWord.testID = testedWord.testSessionId?.uuidString
                            existingWord.testSource = testedWord.dictionaryName
                            existingWord.masteryLevel = testedWord.masteryLevelEnum
                            if existingWord.selectedDefinition == nil, let def = assignedDefinition {
                                existingWord.selectedDefinition = def
                            }
                        }
                    }
                    updatedExistingWords += 1
                } else {
                    // 创建新的UserWord（来自测试）
                    let dictWord = self.lookupWord(testedWord.word, context: "词汇量测试")
                    let definition = dictWord?.definitions.first ?? WordDefinition(
                        partOfSpeech: .noun,
                        meaning: testedWord.dictionaryName.isEmpty ? "测试词条" : "来自\(testedWord.dictionaryName)的测试词条"
                    )
                    
                    let userWord = UserWord(
                        word: normalizeWordKey(testedWord.word),
                        context: "词汇量测试",
                        sentence: "来自词汇量测试的单词",
                        selectedDefinition: definition
                    )
                    
                    // 设置测试相关属性
                    userWord.masteryLevel = testedWord.masteryLevelEnum
                    userWord.firstLookupDate = testedWord.testedAt
                    userWord.lastLookupDate = testedWord.testedAt
                    userWord.isFromTest = true
                    userWord.testID = testedWord.testSessionId?.uuidString
                    userWord.testSource = testedWord.dictionaryName
                    
                    wordMap[wordKey] = userWord
                    newWordsFromTest += 1
                }
            }
            
            print("✅ [DictionaryService] 从测试记录新增 \(newWordsFromTest) 个单词")
            print("✅ [DictionaryService] 更新了 \(updatedExistingWords) 个现有单词的测试信息")
            
            // 转换为数组并排序
            let allWords = Array(wordMap.values).sorted { word1, word2 in
                return word1.lastLookupDate > word2.lastLookupDate
            }
            
            print("✅ [DictionaryService] 最终返回 \(allWords.count) 个词汇记录")
            return allWords
        } ?? []
    }
    
    // MARK: - 词典专属记录管理
    
    /// 获取词典专属的用户词汇记录
    func getDictionarySpecificUserWordRecords(for dictionaryId: UUID) -> [UserWord] {
        return self.performSafeOperation("获取词典专属用户词汇记录") {
            // 获取查词记录的UserWord
            let userWordDescriptor = FetchDescriptor<UserWord>(
                sortBy: [SortDescriptor(\UserWord.lastLookupDate, order: .reverse)]
            )
            let userWords = self.safeFetch(userWordDescriptor, operation: "获取用户词汇列表")
            
            // 获取词典专属测试记录的TestedWord
            let testedWordDescriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate { testedWord in
                    testedWord.testSessionId != nil
                },
                sortBy: [SortDescriptor(\TestedWord.testedAt, order: .reverse)]
            )
            let allTestedWords = self.safeFetch(testedWordDescriptor, operation: "获取测试词汇列表")
            
            // 通过testSessionId查找对应的VocabularyTest，筛选词典专属记录
            let vocabularyTestDescriptor = FetchDescriptor<VocabularyTest>(
                predicate: #Predicate { test in
                    test.dictionaryId == dictionaryId && test.isDictionarySpecific == true
                }
            )
            let dictionaryTests = self.safeFetch(vocabularyTestDescriptor, operation: "获取词典专属测试")
            let dictionaryTestIds = Set(dictionaryTests.map { $0.id })
            
            // 筛选属于该词典的测试记录
            let dictionaryTestedWords = allTestedWords.filter { testedWord in
                guard let testSessionId = testedWord.testSessionId else { return false }
                return dictionaryTestIds.contains(testSessionId)
            }
            
            print("✅ [DictionaryService] 获取到 \(userWords.count) 个查词记录")
            print("✅ [DictionaryService] 获取到 \(dictionaryTestedWords.count) 个词典专属测试记录")
            
            // 创建词汇映射表
            var wordMap: [String: UserWord] = [:]
            
            // 添加查词记录
            for userWord in userWords {
                wordMap[normalizeWordKey(userWord.word)] = userWord
            }
            
            // 处理词典专属测试记录
            var newWordsFromTest = 0
            var updatedExistingWords = 0
            
            for testedWord in dictionaryTestedWords {
                let wordKey = normalizeWordKey(testedWord.word)
                
                if let existingWord = wordMap[wordKey] {
                    var assignedDefinition: WordDefinition? = nil
                    if existingWord.selectedDefinition == nil {
                        assignedDefinition = self.lookupWord(testedWord.word, context: "词汇量测试")?.definitions.first
                    }
                    if Thread.isMainThread {
                        existingWord.isFromTest = true
                        existingWord.testID = testedWord.testSessionId?.uuidString
                        existingWord.testSource = testedWord.dictionaryName
                        existingWord.masteryLevel = testedWord.masteryLevelEnum
                        if existingWord.selectedDefinition == nil, let def = assignedDefinition {
                            existingWord.selectedDefinition = def
                        }
                    } else {
                        DispatchQueue.main.sync {
                            existingWord.isFromTest = true
                            existingWord.testID = testedWord.testSessionId?.uuidString
                            existingWord.testSource = testedWord.dictionaryName
                            existingWord.masteryLevel = testedWord.masteryLevelEnum
                            if existingWord.selectedDefinition == nil, let def = assignedDefinition {
                                existingWord.selectedDefinition = def
                            }
                        }
                    }
                    updatedExistingWords += 1
                } else {
                    // 创建新的UserWord（来自词典专属测试）
                    let dictWord = self.lookupWord(testedWord.word, context: "词汇量测试")
                    let definition = dictWord?.definitions.first ?? WordDefinition(
                        partOfSpeech: .noun,
                        meaning: testedWord.dictionaryName.isEmpty ? "测试词条" : "来自\(testedWord.dictionaryName)的测试词条"
                    )
                    
                    let userWord = UserWord(
                        word: normalizeWordKey(testedWord.word),
                        context: "词汇量测试",
                        sentence: "来自词汇量测试的单词",
                        selectedDefinition: definition
                    )
                    
                    // 设置测试相关属性
                    userWord.masteryLevel = testedWord.masteryLevelEnum
                    userWord.firstLookupDate = testedWord.testedAt
                    userWord.lastLookupDate = testedWord.testedAt
                    userWord.isFromTest = true
                    userWord.testID = testedWord.testSessionId?.uuidString
                    userWord.testSource = testedWord.dictionaryName
                    
                    wordMap[wordKey] = userWord
                    newWordsFromTest += 1
                }
            }
            
            print("✅ [DictionaryService] 从词典专属测试记录新增 \(newWordsFromTest) 个单词")
            print("✅ [DictionaryService] 更新了 \(updatedExistingWords) 个现有单词的测试信息")
            
            // 转换为数组并排序
            let allWords = Array(wordMap.values).sorted { word1, word2 in
                return word1.lastLookupDate > word2.lastLookupDate
            }
            
            print("✅ [DictionaryService] 最终返回 \(allWords.count) 个词典专属词汇记录")
            return allWords
        } ?? []
    }
    
    /// 获取总记录（非词典专属）的用户词汇记录
    func getGeneralUserWordRecords() -> [UserWord] {
        if let cache = generalUserWordsCache, Date().timeIntervalSince(cache.1) < generalUserWordsCacheTTL {
            if shouldLogGeneralCacheHit() {
                lastGeneralCacheLogAt = Date()
                print("[DEBUG][DictionaryService] [DictionaryService] 总用户词汇记录缓存命中: \(cache.0.count)")
            }
            return cache.0
        }
        return self.performSafeOperation("获取总用户词汇记录") {
            // 获取查词记录的UserWord
            let userWordDescriptor = FetchDescriptor<UserWord>(
                sortBy: [SortDescriptor(\UserWord.lastLookupDate, order: .reverse)]
            )
            let userWords = self.safeFetch(userWordDescriptor, operation: "获取用户词汇列表")
            
            // 获取总测试记录的TestedWord
            let testedWordDescriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate { testedWord in
                    testedWord.testSessionId != nil
                },
                sortBy: [SortDescriptor(\TestedWord.testedAt, order: .reverse)]
            )
            let allTestedWords = self.safeFetch(testedWordDescriptor, operation: "获取测试词汇列表")
            
            // 通过testSessionId查找对应的VocabularyTest，筛选总记录
            let vocabularyTestDescriptor = FetchDescriptor<VocabularyTest>(
                predicate: #Predicate { test in
                    test.isDictionarySpecific == false
                }
            )
            let generalTests = self.safeFetch(vocabularyTestDescriptor, operation: "获取总测试记录")
            let generalTestIds = Set(generalTests.map { $0.id })
            
            // 筛选属于总记录的测试记录
            let generalTestedWords = allTestedWords.filter { testedWord in
                guard let testSessionId = testedWord.testSessionId else { return false }
                return generalTestIds.contains(testSessionId)
            }
            
            print("✅ [DictionaryService] 获取到 \(userWords.count) 个查词记录")
            print("✅ [DictionaryService] 获取到 \(generalTestedWords.count) 个总测试记录")
            
            // 创建词汇映射表
            var wordMap: [String: UserWord] = [:]
            
            // 添加查词记录
            for userWord in userWords {
                wordMap[normalizeWordKey(userWord.word)] = userWord
            }
            
            // 处理总测试记录
            var newWordsFromTest = 0
            var updatedExistingWords = 0
            
            for testedWord in generalTestedWords {
                let wordKey = normalizeWordKey(testedWord.word)
                
                if let existingWord = wordMap[wordKey] {
                    var assignedDefinition: WordDefinition? = nil
                    if existingWord.selectedDefinition == nil {
                        assignedDefinition = self.lookupWord(testedWord.word, context: "词汇量测试")?.definitions.first
                    }
                    if Thread.isMainThread {
                        existingWord.isFromTest = true
                        existingWord.testID = testedWord.testSessionId?.uuidString
                        existingWord.testSource = testedWord.dictionaryName
                        existingWord.masteryLevel = testedWord.masteryLevelEnum
                        if existingWord.selectedDefinition == nil, let def = assignedDefinition {
                            existingWord.selectedDefinition = def
                        }
                    } else {
                        DispatchQueue.main.sync {
                            existingWord.isFromTest = true
                            existingWord.testID = testedWord.testSessionId?.uuidString
                            existingWord.testSource = testedWord.dictionaryName
                            existingWord.masteryLevel = testedWord.masteryLevelEnum
                            if existingWord.selectedDefinition == nil, let def = assignedDefinition {
                                existingWord.selectedDefinition = def
                            }
                        }
                    }
                    updatedExistingWords += 1
                } else {
                    // 创建新的UserWord（来自总测试）
                    let dictWord = self.lookupWord(testedWord.word, context: "词汇量测试")
                    let definition = dictWord?.definitions.first ?? WordDefinition(
                        partOfSpeech: .noun,
                        meaning: testedWord.dictionaryName.isEmpty ? "测试词条" : "来自\(testedWord.dictionaryName)的测试词条"
                    )
                    
                    let userWord = UserWord(
                        word: normalizeWordKey(testedWord.word),
                        context: "词汇量测试",
                        sentence: "来自词汇量测试的单词",
                        selectedDefinition: definition
                    )
                    
                    // 设置测试相关属性
                    userWord.masteryLevel = testedWord.masteryLevelEnum
                    userWord.firstLookupDate = testedWord.testedAt
                    userWord.lastLookupDate = testedWord.testedAt
                    userWord.isFromTest = true
                    userWord.testID = testedWord.testSessionId?.uuidString
                    userWord.testSource = testedWord.dictionaryName
                    
                    wordMap[wordKey] = userWord
                    newWordsFromTest += 1
                }
            }
            
            print("✅ [DictionaryService] 从总测试记录新增 \(newWordsFromTest) 个单词")
            print("✅ [DictionaryService] 更新了 \(updatedExistingWords) 个现有单词的测试信息")
            
            // 转换为数组并排序
            let allWords = Array(wordMap.values).sorted { word1, word2 in
                return word1.lastLookupDate > word2.lastLookupDate
            }
            
            print("✅ [DictionaryService] 最终返回 \(allWords.count) 个总词汇记录")
            self.generalUserWordsCache = (allWords, Date())
            return allWords
        } ?? []
    }
    
    private func shouldLogGeneralCacheHit() -> Bool {
        guard let last = lastGeneralCacheLogAt else { return true }
        return Date().timeIntervalSince(last) > generalUserWordsCacheTTL
    }
    
    func clearGeneralUserWordsCache() {
        generalUserWordsCache = nil
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
    func getVocabularyStats() -> VocabularyStats {
        let userRecords = getGeneralUserWordRecords()
        let totalWords = userRecords.count
        let masteredWords = userRecords.filter { $0.masteryLevel == .mastered }.count
        let familiarWords = userRecords.filter { $0.masteryLevel == .familiar }.count
        let unfamiliarWords = userRecords.filter { $0.masteryLevel == .unfamiliar }.count

        let today = Calendar.current.startOfDay(for: Date())
        let todayLookups = userRecords.filter {
            Calendar.current.isDate($0.lastLookupDate, inSameDayAs: today)
        }.count

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let weeklyLookups = userRecords.filter { $0.lastLookupDate >= weekAgo }.count

        let studyDays = userRecords.isEmpty ? 1 : max(1, Calendar.current.dateComponents([.day], from: userRecords.last?.firstLookupDate ?? Date(), to: Date()).day!)
        let averageLookupPerDay = Double(totalWords) / Double(studyDays)

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
                tags: ["高频词", "科技"],
                categories: ["科技", "计算机"]
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
                tags: ["高频词", "核心词汇"],
                categories: ["核心", "认知"]
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
                tags: wordData.tags,
                categories: wordData.categories
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
    let categories: [String]?
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
    
    // 设置模型上下文
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
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
    
    // MARK: - 考研词典功能
    
    /// 查找考研词典中的单词
    func lookupKaoyanWord(_ word: String) -> KaoyanWord? {
        let cleanWord = self.textProcessor.cleanWord(word)
        
        // 输入验证
        guard !cleanWord.isEmpty else { return nil }
        
        // 检查考研词典是否已加载
        guard isKaoyanDictionaryLoaded else {
            logger.warning("[DictionaryService] 考研词典尚未加载完成，无法查找单词: \(cleanWord)")
            return nil
        }
        
        // 检查并刷新缓存
        if !isKaoyanCacheValid() {
            refreshKaoyanCache()
        }
        
        // 使用缓存进行查找，避免重复数据库查询
        if !kaoyanWordsCache.isEmpty {
            // 精确匹配（大小写敏感）
            if let exactMatch = kaoyanWordsCache.first(where: { $0.headWord == cleanWord }) {
                return exactMatch
            }
            
            // 大小写不敏感的精确匹配
            if let caseInsensitiveMatch = kaoyanWordsCache.first(where: { $0.headWord.caseInsensitiveCompare(cleanWord) == .orderedSame }) {
                return caseInsensitiveMatch
            }
            
            // 词形变化匹配
            let morphologyProcessor = WordMorphologyProcessor.shared
            let possibleForms = morphologyProcessor.getAllPossibleForms(for: cleanWord)
            
            for form in possibleForms {
                if let morphMatch = kaoyanWordsCache.first(where: { $0.headWord.caseInsensitiveCompare(form) == .orderedSame }) {
                    return morphMatch
                }
            }
            
            // 反向词形匹配（检查数据库中的词是否是查询词的变形）
            for kaoyanWord in kaoyanWordsCache {
                let wordForms = morphologyProcessor.getAllPossibleForms(for: kaoyanWord.headWord)
                if wordForms.contains(where: { $0.caseInsensitiveCompare(cleanWord) == .orderedSame }) {
                    return kaoyanWord
                }
            }
            
            // 模糊匹配
            if let fuzzyMatch = kaoyanWordsCache.first(where: { $0.headWord.contains(cleanWord) || cleanWord.contains($0.headWord) }) {
                return fuzzyMatch
            }
            
            return nil
        }
        
        // 如果缓存为空，回退到数据库查询
        do {
            // 精确匹配（大小写敏感，使用 Predicate）
            let exactPredicate = #Predicate<KaoyanWord> { $0.headWord == cleanWord }
            let exactDescriptor = FetchDescriptor<KaoyanWord>(predicate: exactPredicate)
            if let exactMatch = try modelContext.fetch(exactDescriptor).first {
                return exactMatch
            }
            
            // 获取所有单词用于内存过滤
            let allWordsDescriptor = FetchDescriptor<KaoyanWord>()
            let allWords = try modelContext.fetch(allWordsDescriptor)
            
            // 大小写不敏感的精确匹配（内存过滤）
            if let caseInsensitiveMatch = allWords.first(where: { $0.headWord.caseInsensitiveCompare(cleanWord) == .orderedSame }) {
                return caseInsensitiveMatch
            }
            
            // 词形变化匹配
            let morphologyProcessor = WordMorphologyProcessor.shared
            let possibleForms = morphologyProcessor.getAllPossibleForms(for: cleanWord)
            
            for form in possibleForms {
                if let morphMatch = allWords.first(where: { $0.headWord.caseInsensitiveCompare(form) == .orderedSame }) {
                    return morphMatch
                }
            }
            
            // 反向词形匹配（检查数据库中的词是否是查询词的变形）
            for kaoyanWord in allWords {
                let wordForms = morphologyProcessor.getAllPossibleForms(for: kaoyanWord.headWord)
                if wordForms.contains(where: { $0.caseInsensitiveCompare(cleanWord) == .orderedSame }) {
                    return kaoyanWord
                }
            }
            
            // 模糊匹配（内存过滤）
            if let fuzzyMatch = allWords.first(where: { $0.headWord.contains(cleanWord) || cleanWord.contains($0.headWord) }) {
                return fuzzyMatch
            }
            
            return nil
        } catch {
            logger.error("[DictionaryService] 查找考研单词失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 获取考研单词的详细信息（包含释义、例句等）
    func getKaoyanWordDetails(_ word: String) -> KaoyanWordDetails? {
        guard let kaoyanWord = lookupKaoyanWord(word) else { return nil }
        
        return KaoyanWordDetails(
            word: kaoyanWord.headWord,
            wordRank: kaoyanWord.wordRank,
            bookId: kaoyanWord.bookId,
            usPhone: kaoyanWord.usPhone,
            ukPhone: kaoyanWord.ukPhone,
            translations: kaoyanWord.translations.map { translation in
                KaoyanWordTranslation(
                    pos: translation.pos,
                    tranCn: translation.tranCn,
                    tranOther: translation.tranOther
                )
            },
            sentences: kaoyanWord.sentences.map { sentence in
                KaoyanWordSentence(
                    sContent: sentence.sContent,
                    sCn: sentence.sCn
                )
            },
            synonyms: kaoyanWord.synonyms.map { synonym in
                KaoyanWordSynonym(
                    pos: synonym.pos,
                    tran: synonym.tran,
                    synonymWords: synonym.synonymWords
                )
            },
            phrases: kaoyanWord.phrases.map { phrase in
                KaoyanWordPhrase(
                    pContent: phrase.pContent,
                    pCn: phrase.pCn
                )
            },
            relatedWords: kaoyanWord.relatedWords.map { relWord in
                KaoyanWordRelated(
                    pos: relWord.pos,
                    hwd: relWord.hwd,
                    tran: relWord.tran
                )
            }
        )
    }
    
    /// 初始化考研词典数据
    @MainActor
    func initializeKaoyanDictionary() async {
        print("[INFO][DictionaryService] 开始初始化考研词典数据...")
        kaoyanDictionaryLoadingProgress = 0.0
        
        let importer = KaoyanDictionaryImporter(modelContext: modelContext)
        
        do {
            kaoyanDictionaryLoadingProgress = 0.1
            let needsImport = try await importer.needsImport()
            print("[INFO][DictionaryService] 检查是否需要导入: \(needsImport)")
            
            if needsImport {
                print("[INFO][DictionaryService] 开始导入考研词典数据...")
                kaoyanDictionaryLoadingProgress = 0.2
                
                try await importer.importAllDictionaries()
                kaoyanDictionaryLoadingProgress = 0.8
                
                print("[INFO][DictionaryService] 考研词典数据导入完成")
                
                // 验证导入结果
                let descriptor = FetchDescriptor<KaoyanWord>()
                let count = try modelContext.fetchCount(descriptor)
                print("[INFO][DictionaryService] 导入后数据库中共有 \(count) 个考研单词")
                kaoyanDictionaryLoadingProgress = 0.9
            } else {
                print("[INFO][DictionaryService] 考研词典数据已存在，跳过导入")
                kaoyanDictionaryLoadingProgress = 0.8
                
                // 显示现有数据统计
                let descriptor = FetchDescriptor<KaoyanWord>()
                let count = try modelContext.fetchCount(descriptor)
                print("[INFO][DictionaryService] 数据库中现有 \(count) 个考研单词")
            }
            
            // 初始化缓存
            refreshKaoyanCache()
            kaoyanDictionaryLoadingProgress = 1.0
            isKaoyanDictionaryLoaded = true
            
            logger.info("[DictionaryService] 考研词典初始化完成")
        } catch {
            print("[ERROR][DictionaryService] 导入考研词典失败: \(error.localizedDescription)")
            if let importError = error as? ImportError {
                print("[ERROR][DictionaryService] 详细错误: \(importError.errorDescription ?? "未知错误")")
            }
            
            // 重置状态
            kaoyanDictionaryLoadingProgress = 0.0
            isKaoyanDictionaryLoaded = false
            logger.error("[DictionaryService] 考研词典初始化失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取发音URL
    func getPronunciationURL(for word: String, type: PronunciationType) -> URL? {
        let typeParam = type == .uk ? "1" : "2"
        let urlString = "https://dict.youdao.com/dictvoice?audio=\(word)&type=\(typeParam)"
        return URL(string: urlString)
    }
}

// MARK: - 考研词典数据结构
// 注意：考研词典相关的数据结构已移动到 DetailedWordDefinition.swift 文件中

/// 发音类型
enum PronunciationType {
    case uk // 英音
    case us // 美音
}
