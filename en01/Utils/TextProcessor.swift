//
//  TextProcessor.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import NaturalLanguage
import SwiftUI

class TextProcessor: TextProcessorProtocol, ObservableObject {
    private let tokenizer = NLTokenizer(unit: .word)
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
    
    // 缓存机制以提高性能
    private var stemCache: [String: CacheEntry<String>] = [:]
    private var keywordCache: [String: CacheEntry<[String]>] = [:]
    private var similarityCache: [String: CacheEntry<Double>] = [:]
    
    // 线程安全队列用于各种缓存
    private let stemCacheQueue = DispatchQueue(label: "com.en01.textprocessor.stemCache", attributes: .concurrent)
    private let keywordCacheQueue = DispatchQueue(label: "com.en01.textprocessor.keywordCache", attributes: .concurrent)
    private let similarityCacheQueue = DispatchQueue(label: "com.en01.textprocessor.similarityCache", attributes: .concurrent)
    
    private let maxCacheSize = 1000
    private let memoryPressureThreshold = 50 * 1024 * 1024 // 50MB
    
    // 初始化方法
    init() {
        // 初始化时清理所有缓存，确保类型安全
        clearAllCaches()
    }
    
    // 缓存条目结构
    private struct CacheEntry<T> {
        let value: T
        let timestamp: Date
        var accessCount: Int
        var lastAccessed: Date
        
        init(value: T) {
            self.value = value
            self.timestamp = Date()
            self.accessCount = 1
            self.lastAccessed = Date()
        }
        
        mutating func accessed() {
            self.accessCount += 1
            self.lastAccessed = Date()
        }
        
        var priority: Double {
            // 基于访问频率和最近访问时间计算优先级
            let recency = 1.0 / (Date().timeIntervalSince(lastAccessed) + 1)
            let frequency = Double(accessCount)
            return recency * frequency
        }
    }
    
    // MARK: - 文本清理
    
    // 清理单词（移除标点符号等）
    func cleanWord(_ word: String) -> String {
        let cleanedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
        
        // 过滤中文字符和其他非英文字符
        return filterEnglishOnly(cleanedWord)
    }
    
    // 清理文本
    func cleanText(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\n+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    // MARK: - 文本分词
    
    // 将文本分词（别名方法）
    func tokenize(_ text: String) -> [String] {
        return tokenizeText(text)
    }
    
    // 将文本分词
    func tokenizeText(_ text: String) -> [String] {
        tokenizer.string = text
        var tokens: [String] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange])
            if !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                tokens.append(token)
            }
            return true
        }
        
        return tokens
    }
    
    // 提取单词（过滤标点符号）
    func extractWords(_ text: String) -> [String] {
        let tokens = tokenizeText(text)
        return tokens.filter { token in
            !token.trimmingCharacters(in: .punctuationCharacters).isEmpty &&
            token.rangeOfCharacter(from: .letters) != nil &&
            isValidEnglishWord(token)
        }.map { cleanWord($0) }
    }
    
    // MARK: - 关键词提取
    
    /// 提取关键词（带缓存优化）
    /// - Parameters:
    ///   - text: 要分析的文本
    ///   - limit: 返回关键词的最大数量
    /// - Returns: 关键词数组
    func extractKeywords(from text: String, limit: Int = 10) -> [String] {
        let cacheKey = "\(text.hashValue)_\(limit)"
        
        return keywordCacheQueue.sync {
            // 检查缓存
            if let cachedEntry = keywordCache[cacheKey] {
                var entry = cachedEntry
                entry.accessed()
                keywordCache[cacheKey] = entry
                return entry.value
            }
            
            // 提取关键词
            let result = performKeywordExtraction(text, limit: limit)
            
            // 缓存结果，使用安全的缓存操作
            let newEntry = CacheEntry(value: result)
            keywordCache[cacheKey] = newEntry
            
            // 安全检查内存压力
            DispatchQueue.main.async { [weak self] in
                self?.checkMemoryPressure()
            }
            
            return result
        }
    }
    
    /// 执行实际的关键词提取
    private func performKeywordExtraction(_ text: String, limit: Int) -> [String] {
        let words = extractWords(text)
        let filteredWords = words.filter { word in
            word.count > 2 && !isStopWord(word)
        }
        
        // 计算词频
        var wordFrequency: [String: Int] = [:]
        for word in filteredWords {
            let stem = stemWord(word)
            wordFrequency[stem, default: 0] += 1
        }
        
        // 按频率排序并返回前N个
        return Array(wordFrequency.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key })
    }
    
    // 检查是否为停用词
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = Set([
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "up", "about", "into", "through", "during",
            "before", "after", "above", "below", "between", "among", "throughout",
            "is", "are", "was", "were", "be", "been", "being", "have", "has", "had",
            "do", "does", "did", "will", "would", "could", "should", "may", "might",
            "must", "can", "shall", "this", "that", "these", "those", "i", "you",
            "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
            "my", "your", "his", "her", "its", "our", "their", "mine", "yours",
            "hers", "ours", "theirs", "myself", "yourself", "himself", "herself",
            "itself", "ourselves", "yourselves", "themselves", "what", "which",
            "who", "whom", "whose", "where", "when", "why", "how", "all", "any",
            "both", "each", "few", "more", "most", "other", "some", "such",
            "no", "nor", "not", "only", "own", "same", "so", "than", "too",
            "very", "just", "now", "here", "there", "then", "once", "again",
            "also", "however", "therefore", "thus", "moreover", "furthermore",
            "nevertheless", "nonetheless", "meanwhile", "otherwise", "instead"
        ])
        
        return stopWords.contains(word.lowercased())
    }
    
    // MARK: - 词形还原
    
    /// 获取词根/词干（带缓存优化）
    /// - Parameter word: 要处理的单词
    /// - Returns: 词根或词干
    func stemWord(_ word: String) -> String {
        let lowercaseWord = word.lowercased()
        
        return stemCacheQueue.sync {
            // 检查缓存
            if let cachedEntry = stemCache[lowercaseWord] {
                var entry = cachedEntry
                entry.accessed()
                stemCache[lowercaseWord] = entry
                return entry.value
            }
            
            // 计算词干
            let result = performStemming(lowercaseWord)
            
            // 缓存结果，使用安全的缓存操作
            let newEntry = CacheEntry(value: result)
            stemCache[lowercaseWord] = newEntry
            
            // 安全检查内存压力
            DispatchQueue.main.async { [weak self] in
                self?.checkMemoryPressure()
            }
            
            return result
        }
    }
    
    /// 执行实际的词干提取
    private func performStemming(_ word: String) -> String {
        // 使用NLTagger进行词干提取
        tagger.string = word
        let _ = word.startIndex..<word.endIndex
        
        if let lemma = tagger.tag(at: word.startIndex, unit: .word, scheme: .lemma).0?.rawValue {
            return lemma.lowercased()
        }
        
        // 如果NLTagger失败，使用简单的词干提取
        return simpleStem(word)
    }
    
    /// 检查内存压力并清理缓存
    private func checkMemoryPressure() {
        // 使用各自的并发队列同步读取缓存大小，避免并发读写造成崩溃
        let stemCacheSize = getSafeCacheSize(stemCache, queue: stemCacheQueue)
        let _ = getSafeCacheSize(keywordCache, queue: keywordCacheQueue)
        let _ = getSafeCacheSize(similarityCache, queue: similarityCacheQueue)

        if stemCacheSize > maxCacheSize {
            clearOldCache()
        }

        // 定期验证缓存完整性
        if stemCacheSize % 100 == 0 {
            validateAndCleanCache()
        }
    }
    
    /// 安全获取缓存大小（在线程安全的队列中读取），避免并发迭代
    private func getSafeCacheSize<T>(_ cache: [String: CacheEntry<T>], queue: DispatchQueue) -> Int {
        return queue.sync { cache.count }
    }
    
    /// 清理无效的缓存条目（使用队列屏障，保证并发安全）
    private func cleanInvalidCacheEntries() {
        print("🧹 [TextProcessor] 开始清理无效缓存条目")

        let group = DispatchGroup()
        var oldStemCacheSize = 0
        var oldKeywordCacheSize = 0
        var oldSimilarityCacheSize = 0

        group.enter()
        stemCacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { group.leave(); return }
            oldStemCacheSize = self.stemCache.count
            self.stemCache.removeAll()
            group.leave()
        }

        group.enter()
        keywordCacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { group.leave(); return }
            oldKeywordCacheSize = self.keywordCache.count
            self.keywordCache.removeAll()
            group.leave()
        }

        group.enter()
        similarityCacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { group.leave(); return }
            oldSimilarityCacheSize = self.similarityCache.count
            self.similarityCache.removeAll()
            group.leave()
        }

        group.notify(queue: .main) {
            print("✅ [TextProcessor] 缓存清理完成")
            print("   - stemCache: \(oldStemCacheSize) -> 0")
            print("   - keywordCache: \(oldKeywordCacheSize) -> 0")
            print("   - similarityCache: \(oldSimilarityCacheSize) -> 0")
        }
    }
    
    /// 清理旧缓存以控制内存使用
    private func clearOldCache() {
        // 清理stemCache - 保留优先级最高的条目
        stemCacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.stemCache.count > self.maxCacheSize {
                let sortedEntries = self.stemCache.sorted { $0.value.priority > $1.value.priority }
                let toKeep = Int(Double(self.maxCacheSize) * 0.7) // 保留70%
                self.stemCache.removeAll()
                for (key, entry) in sortedEntries.prefix(toKeep) {
                    self.stemCache[key] = entry
                }
            }
        }
        
        // 清理keywordCache
        keywordCacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.keywordCache.count > self.maxCacheSize {
                let sortedEntries = self.keywordCache.sorted { $0.value.priority > $1.value.priority }
                let toKeep = Int(Double(self.maxCacheSize) * 0.7)
                self.keywordCache.removeAll()
                for (key, entry) in sortedEntries.prefix(toKeep) {
                    self.keywordCache[key] = entry
                }
            }
        }
        
        // 清理similarityCache
        similarityCacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.similarityCache.count > self.maxCacheSize {
                let sortedEntries = self.similarityCache.sorted { $0.value.priority > $1.value.priority }
                let toKeep = Int(Double(self.maxCacheSize) * 0.7)
                self.similarityCache.removeAll()
                for (key, entry) in sortedEntries.prefix(toKeep) {
                    self.similarityCache[key] = entry
                }
            }
        }
    }
    
    /// 验证并清理无效的缓存条目
    private func validateAndCleanCache() {
        // 验证stemCache
        stemCacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            var invalidKeys: [String] = []
            for (key, value) in self.stemCache {
                // 由于stemCache的类型是[String: CacheEntry<String>]，所有值都应该是CacheEntry<String>类型
                // 这个检查实际上总是为true，但保留用于调试目的
                if type(of: value) != CacheEntry<String>.self {
                    invalidKeys.append(key)
                    print("⚠️ [TextProcessor] 发现无效stemCache条目: \(key)")
                }
            }
            for key in invalidKeys {
                self.stemCache.removeValue(forKey: key)
            }
        }
        
        // 验证keywordCache
        keywordCacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            var invalidKeys: [String] = []
            for (key, value) in self.keywordCache {
                // 由于keywordCache的类型是[String: CacheEntry<[String]>]，所有值都应该是CacheEntry<[String]>类型
                if type(of: value) != CacheEntry<[String]>.self {
                    invalidKeys.append(key)
                    print("⚠️ [TextProcessor] 发现无效keywordCache条目: \(key)")
                }
            }
            for key in invalidKeys {
                self.keywordCache.removeValue(forKey: key)
            }
        }
        
        // 验证similarityCache
        similarityCacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            var invalidKeys: [String] = []
            for (key, value) in self.similarityCache {
                // 由于similarityCache的类型是[String: CacheEntry<Double>]，所有值都应该是CacheEntry<Double>类型
                if type(of: value) != CacheEntry<Double>.self {
                    invalidKeys.append(key)
                    print("⚠️ [TextProcessor] 发现无效similarityCache条目: \(key)")
                }
            }
            for key in invalidKeys {
                self.similarityCache.removeValue(forKey: key)
            }
            
            print("✅ [TextProcessor] 缓存验证完成，清理了 \(invalidKeys.count) 个无效条目")
        }
    }
    
    /// 强制清理所有缓存
    func clearAllCaches() {
        let group = DispatchGroup()
        
        group.enter()
        stemCacheQueue.async(flags: .barrier) { [weak self] in
            self?.stemCache.removeAll()
            group.leave()
        }
        
        group.enter()
        keywordCacheQueue.async(flags: .barrier) { [weak self] in
            self?.keywordCache.removeAll()
            group.leave()
        }
        
        group.enter()
        similarityCacheQueue.async(flags: .barrier) { [weak self] in
            self?.similarityCache.removeAll()
            group.leave()
        }
        
        group.notify(queue: .main) {
            print("✅ [TextProcessor] 已清理所有缓存")
        }
    }
    
    // 简单词干提取
    private func simpleStem(_ word: String) -> String {
        let lowercaseWord = word.lowercased()
        
        // 移除常见后缀
        let suffixes = ["ing", "ed", "er", "est", "ly", "tion", "sion", "ness", "ment", "able", "ible", "ful", "less"]
        
        for suffix in suffixes.sorted(by: { $0.count > $1.count }) {
            if lowercaseWord.hasSuffix(suffix) && lowercaseWord.count > suffix.count + 2 {
                return String(lowercaseWord.dropLast(suffix.count))
            }
        }
        
        return lowercaseWord
    }
    
    // MARK: - 英文单词过滤
    
    /// 过滤只保留英文字符
    private func filterEnglishOnly(_ word: String) -> String {
        return String(word.filter { char in
            char.isLetter && char.isASCII
        })
    }
    
    /// 检查是否为有效的英文单词
    private func isValidEnglishWord(_ word: String) -> Bool {
        // 检查是否为空或太短
        guard !word.isEmpty && word.count > 1 else {
            return false
        }
        
        // 检查是否包含中文字符
        let chineseCharacterSet = CharacterSet(charactersIn: "\u{4e00}-\u{9fff}")
        if word.rangeOfCharacter(from: chineseCharacterSet) != nil {
            return false
        }
        
        // 检查是否包含其他非英文字符（如日文、韩文等）
        let nonEnglishCount = word.filter { char in
            !char.isASCII || (!char.isLetter && !char.isNumber)
        }.count
        
        // 如果非英文字符超过一半，则认为不是有效英文单词
        if nonEnglishCount > word.count / 2 {
            return false
        }
        
        // 检查是否为纯数字
        if word.allSatisfy({ $0.isNumber }) {
            return false
        }
        
        return true
    }
    
    // MARK: - 句子提取
    
    /// 从文本中提取包含指定单词的句子
    /// - Parameters:
    ///   - word: 要查找的单词
    ///   - text: 源文本
    /// - Returns: 包含该单词的句子，如果未找到则返回nil
    func extractSentence(containing word: String, from text: String) -> String? {
        let sentences = splitIntoSentences(text)
        let cleanWord = cleanWord(word)
        
        for sentence in sentences {
            let sentenceWords = extractWords(sentence)
            if sentenceWords.contains(cleanWord) {
                return sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    /// 将文本分割为句子
    /// - Parameter text: 要分割的文本
    /// - Returns: 句子数组
    func splitIntoSentences(_ text: String) -> [String] {
        let cleanedText = cleanText(text)
        
        // 改进的句子分割逻辑，处理缩写和特殊情况
        var sentences: [String] = []
        var currentSentence = ""
        var i = cleanedText.startIndex
        
        while i < cleanedText.endIndex {
            let char = cleanedText[i]
            currentSentence.append(char)
            
            // 检查是否是句子结束符
            if char == "." || char == "!" || char == "?" {
                // 检查下一个字符是否是空格或文本结束
                let nextIndex = cleanedText.index(after: i)
                if nextIndex >= cleanedText.endIndex || cleanedText[nextIndex].isWhitespace {
                    // 检查是否是常见缩写（如 Mr., Dr., etc.）
                    if !isCommonAbbreviation(currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        let trimmedSentence = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedSentence.isEmpty {
                            sentences.append(trimmedSentence)
                        }
                        currentSentence = ""
                    }
                }
            }
            
            i = cleanedText.index(after: i)
        }
        
        // 添加最后一个句子（如果有）
        let finalSentence = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalSentence.isEmpty {
            sentences.append(finalSentence)
        }
        
        return sentences
    }
    
    /// 检查是否是常见缩写
    private func isCommonAbbreviation(_ text: String) -> Bool {
        let commonAbbreviations = ["Mr.", "Mrs.", "Dr.", "Prof.", "vs.", "etc.", "i.e.", "e.g.", "Inc.", "Ltd.", "Co."]
        let lowercaseText = text.lowercased()
        return commonAbbreviations.contains { lowercaseText.hasSuffix($0.lowercased()) }
    }
    
    /// 根据字符位置提取句子
    func extractSentenceAtPosition(_ position: Int, from text: String) -> String? {
        let sentences = splitIntoSentences(text)
        var currentPosition = 0
        
        for sentence in sentences {
            let sentenceLength = sentence.count
            if position >= currentPosition && position <= currentPosition + sentenceLength {
                return sentence
            }
            currentPosition += sentenceLength + 1 // +1 for sentence separator
        }
        
        return sentences.first // 如果无法确定，返回第一个句子
    }
    
    // MARK: - 相似度计算
    
    /// 计算字符串相似度（Levenshtein距离，带缓存优化）
    /// - Parameters:
    ///   - string1: 第一个字符串
    ///   - string2: 第二个字符串
    /// - Returns: 相似度（0-1之间）
    func calculateSimilarity(_ string1: String, _ string2: String) -> Double {
        let cacheKey = "\(string1)|\(string2)"
        
        return similarityCacheQueue.sync {
            // 检查缓存
            if let cachedEntry = similarityCache[cacheKey] {
                var entry = cachedEntry
                entry.accessed()
                similarityCache[cacheKey] = entry
                return entry.value
            }
            
            // 计算相似度
            let result = calculateLevenshteinSimilarity(string1, string2)
            
            // 缓存结果，使用安全的缓存操作
            let newEntry = CacheEntry(value: result)
            similarityCache[cacheKey] = newEntry
            
            // 安全检查内存压力
            DispatchQueue.main.async { [weak self] in
                self?.checkMemoryPressure()
            }
            
            return result
        }
    }
    
    /// 计算Levenshtein相似度
    private func calculateLevenshteinSimilarity(_ string1: String, _ string2: String) -> Double {
        let distance = levenshteinDistance(string1, string2)
        let maxLength = max(string1.count, string2.count)
        
        if maxLength == 0 {
            return 1.0
        }
        
        return 1.0 - Double(distance) / Double(maxLength)
    }
    
    // Levenshtein距离算法
    private func levenshteinDistance(_ string1: String, _ string2: String) -> Int {
        let s1 = Array(string1)
        let s2 = Array(string2)
        let m = s1.count
        let n = s2.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        // 初始化第一行和第一列
        for i in 0...m {
            matrix[i][0] = i
        }
        for j in 0...n {
            matrix[0][j] = j
        }
        
        // 填充矩阵
        for i in 1...m {
            for j in 1...n {
                let cost = s1[i-1] == s2[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // 删除
                    matrix[i][j-1] + 1,      // 插入
                    matrix[i-1][j-1] + cost  // 替换
                )
            }
        }
        
        return matrix[m][n]
    }
    
    // MARK: - 句子分析
    

    
    // 获取单词在文本中的上下文
    func getWordContext(_ word: String, in text: String, contextLength: Int = 50) -> String {
        let cleanWord = cleanWord(word)
        let lowercaseText = text.lowercased()
        
        guard let range = lowercaseText.range(of: cleanWord) else {
            return ""
        }
        
        let startIndex = max(lowercaseText.startIndex, lowercaseText.index(range.lowerBound, offsetBy: -contextLength, limitedBy: lowercaseText.startIndex) ?? lowercaseText.startIndex)
        let endIndex = min(lowercaseText.endIndex, lowercaseText.index(range.upperBound, offsetBy: contextLength, limitedBy: lowercaseText.endIndex) ?? lowercaseText.endIndex)
        
        let _ = startIndex..<endIndex // contextRange未使用，保留以备将来使用
        let originalStartIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: startIndex))
        let originalEndIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: endIndex))
        
        return String(text[originalStartIndex..<originalEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 获取包含单词的完整句子
    func getSentenceContaining(_ word: String, in text: String) -> String? {
        let sentences = splitIntoSentences(text)
        let cleanWord = cleanWord(word)
        
        for sentence in sentences {
            let sentenceWords = extractWords(sentence)
            if sentenceWords.contains(cleanWord) {
                return sentence
            }
        }
        
        return nil
    }
    
    // MARK: - 词性标注
    
    // 获取单词的词性
    func getPartOfSpeech(_ word: String) -> PartOfSpeech? {
        tagger.string = word
        let _ = word.startIndex..<word.endIndex
        
        guard let tag = tagger.tag(at: word.startIndex, unit: .word, scheme: .lexicalClass).0 else {
            return nil
        }
        
        return mapNLTagToPartOfSpeech(tag)
    }
    
    // 将NLTag映射到PartOfSpeech
    private func mapNLTagToPartOfSpeech(_ tag: NLTag) -> PartOfSpeech? {
        switch tag {
        case .noun:
            return .noun
        case .verb:
            return .verb
        case .adjective:
            return .adjective
        case .adverb:
            return .adverb
        case .preposition:
            return .preposition
        case .conjunction:
            return .conjunction
        case .pronoun:
            return .pronoun
        case .interjection:
            return .interjection
        default:
            return nil
        }
    }
    
    // MARK: - 文本统计
    
    // 计算文本的阅读难度（基于句子长度和词汇复杂度）
    func calculateReadingDifficulty(_ text: String) -> Double {
        let sentences = splitIntoSentences(text)
        let words = extractWords(text)
        
        guard !sentences.isEmpty && !words.isEmpty else { return 0.0 }
        
        // 平均句子长度
        let averageSentenceLength = Double(words.count) / Double(sentences.count)
        
        // 复杂词汇比例（长度大于6的单词）
        let complexWords = words.filter { $0.count > 6 }
        let complexWordRatio = Double(complexWords.count) / Double(words.count)
        
        // Flesch Reading Ease的简化版本
        let difficulty = 206.835 - (1.015 * averageSentenceLength) - (84.6 * complexWordRatio)
        
        // 归一化到0-1范围
        return max(0.0, min(1.0, (100.0 - difficulty) / 100.0))
    }
    
    // 计算词汇密度
    func calculateVocabularyDensity(_ text: String) -> Double {
        let words = extractWords(text)
        let uniqueWords = Set(words)
        
        guard !words.isEmpty else { return 0.0 }
        
        return Double(uniqueWords.count) / Double(words.count)
    }
    
    // 获取文本统计信息
    func getTextStatistics(_ text: String) -> TextStatistics {
        let sentences = splitIntoSentences(text)
        let words = extractWords(text)
        let characters = text.count
        let charactersNoSpaces = text.replacingOccurrences(of: " ", with: "").count
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        let averageWordsPerSentence = sentences.isEmpty ? 0.0 : Double(words.count) / Double(sentences.count)
        let averageCharactersPerWord = words.isEmpty ? 0.0 : Double(charactersNoSpaces) / Double(words.count)
        
        let readingDifficulty = calculateReadingDifficulty(text)
        let vocabularyDensity = calculateVocabularyDensity(text)
        
        // 估算阅读时间（假设每分钟200词）
        let estimatedReadingTime = Double(words.count) / 200.0
        
        return TextStatistics(
            characterCount: characters,
            characterCountNoSpaces: charactersNoSpaces,
            wordCount: words.count,
            sentenceCount: sentences.count,
            paragraphCount: paragraphs.count,
            averageWordsPerSentence: averageWordsPerSentence,
            averageCharactersPerWord: averageCharactersPerWord,
            readingDifficulty: readingDifficulty,
            vocabularyDensity: vocabularyDensity,
            estimatedReadingTime: estimatedReadingTime
        )
    }
    
    // MARK: - 文本高亮
    
    // 在文本中高亮显示特定单词
    func highlightWord(_ word: String, in text: String) -> [(range: Range<String.Index>, isHighlighted: Bool)] {
        let cleanWord = cleanWord(word)
        let lowercaseText = text.lowercased()
        var results: [(range: Range<String.Index>, isHighlighted: Bool)] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            if let range = lowercaseText.range(of: cleanWord, range: currentIndex..<text.endIndex) {
                // 添加高亮前的文本
                if currentIndex < range.lowerBound {
                    let beforeRange = currentIndex..<range.lowerBound
                    results.append((range: beforeRange, isHighlighted: false))
                }
                
                // 添加高亮的单词
                let originalRange = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound))..<text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound))
                results.append((range: originalRange, isHighlighted: true))
                
                currentIndex = range.upperBound
            } else {
                // 添加剩余文本
                if currentIndex < text.endIndex {
                    let remainingRange = currentIndex..<text.endIndex
                    results.append((range: remainingRange, isHighlighted: false))
                }
                break
            }
        }
        
        return results
    }
}

// MARK: - 数据结构

// 文本统计信息
struct TextStatistics {
    let characterCount: Int
    let characterCountNoSpaces: Int
    let wordCount: Int
    let sentenceCount: Int
    let paragraphCount: Int
    let averageWordsPerSentence: Double
    let averageCharactersPerWord: Double
    let readingDifficulty: Double // 0.0 (简单) - 1.0 (困难)
    let vocabularyDensity: Double // 0.0 (重复性高) - 1.0 (词汇丰富)
    let estimatedReadingTime: Double // 分钟
    
    var formattedReadingTime: String {
        let minutes = Int(estimatedReadingTime)
        let seconds = Int((estimatedReadingTime - Double(minutes)) * 60)
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    var difficultyDescription: String {
        switch readingDifficulty {
        case 0.0..<0.3:
            return "简单"
        case 0.3..<0.6:
            return "中等"
        case 0.6..<0.8:
            return "困难"
        default:
            return "很困难"
        }
    }
}

// MARK: - 扩展

extension TextProcessor {
    // 检查文本是否包含特定单词
    func containsWord(_ word: String, in text: String) -> Bool {
        let cleanWord = cleanWord(word)
        let words = extractWords(text)
        return words.contains(cleanWord)
    }
    
    // 计算单词在文本中的出现次数
    func countOccurrences(of word: String, in text: String) -> Int {
        let cleanWord = cleanWord(word)
        let words = extractWords(text)
        return words.filter { $0 == cleanWord }.count
    }
    
    // 获取文本中最常见的单词
    func getMostFrequentWords(in text: String, count: Int = 10) -> [(word: String, frequency: Int)] {
        let words = extractWords(text).filter { !isStopWord($0) }
        let wordFrequency = Dictionary(grouping: words, by: { $0 })
            .mapValues { $0.count }
        
        return wordFrequency.sorted { $0.value > $1.value }
            .prefix(count)
            .map { (word: $0.key, frequency: $0.value) }
    }
    
    // 检查两个文本的相似度
    func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(extractWords(text1))
        let words2 = Set(extractWords(text2))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        guard !union.isEmpty else { return 0.0 }
        
        return Double(intersection.count) / Double(union.count)
    }
}