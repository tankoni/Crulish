//
//  TextProcessor.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import NaturalLanguage

class TextProcessor {
    private let tokenizer = NLTokenizer(unit: .word)
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
    
    // 缓存机制以提高性能
    private var stemCache: [String: String] = [:]
    private var keywordCache: [String: [String]] = [:]
    private var similarityCache: [String: Double] = [:]
    
    // 缓存大小限制
    private let maxCacheSize = 1000
    
    // MARK: - 文本清理
    
    // 清理单词（移除标点符号等）
    func cleanWord(_ word: String) -> String {
        let cleanedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
        
        return cleanedWord
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
            token.rangeOfCharacter(from: .letters) != nil
        }.map { cleanWord($0) }
    }
    
    // MARK: - 关键词提取
    
    /// 提取关键词（带缓存优化）
    /// - Parameters:
    ///   - text: 要分析的文本
    ///   - limit: 返回关键词的最大数量
    /// - Returns: 关键词数组
    func extractKeywords(from text: String, limit: Int = 10) -> [String] {
        let cacheKey = "\(text.prefix(100))_\(limit)" // 使用文本前100字符作为缓存键
        
        // 检查缓存
        if let cachedKeywords = keywordCache[cacheKey] {
            return cachedKeywords
        }
        
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
        let result = Array(wordFrequency.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key })
        
        // 缓存结果
        if keywordCache.count < maxCacheSize {
            keywordCache[cacheKey] = result
        }
        
        return result
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
        
        // 检查缓存
        if let cachedStem = stemCache[lowercaseWord] {
            return cachedStem
        }
        
        tagger.string = word
        let _ = word.startIndex..<word.endIndex
        
        var result: String
        if let lemma = tagger.tag(at: word.startIndex, unit: .word, scheme: .lemma).0?.rawValue {
            result = lemma.lowercased()
        } else {
            // 如果无法获取词根，使用简单的词干提取
            result = simpleStem(word)
        }
        
        // 缓存结果（控制缓存大小）
        if stemCache.count < maxCacheSize {
            stemCache[lowercaseWord] = result
        } else if stemCache.count >= maxCacheSize {
            // 清理部分缓存
            clearOldCache()
            stemCache[lowercaseWord] = result
        }
        
        return result
    }
    
    /// 清理旧缓存以控制内存使用
    private func clearOldCache() {
        let keysToRemove = Array(stemCache.keys.prefix(maxCacheSize / 2))
        for key in keysToRemove {
            stemCache.removeValue(forKey: key)
        }
        
        let keywordKeysToRemove = Array(keywordCache.keys.prefix(maxCacheSize / 2))
        for key in keywordKeysToRemove {
            keywordCache.removeValue(forKey: key)
        }
        
        similarityCache.removeAll()
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
    
    // MARK: - 相似度计算
    
    /// 计算字符串相似度（Levenshtein距离，带缓存优化）
    /// - Parameters:
    ///   - string1: 第一个字符串
    ///   - string2: 第二个字符串
    /// - Returns: 相似度（0-1之间）
    func calculateSimilarity(_ string1: String, _ string2: String) -> Double {
        let cacheKey = "\(string1)_\(string2)"
        
        // 检查缓存
        if let cachedSimilarity = similarityCache[cacheKey] {
            return cachedSimilarity
        }
        
        let distance = levenshteinDistance(string1, string2)
        let maxLength = max(string1.count, string2.count)
        
        guard maxLength > 0 else { return 1.0 }
        
        let result = 1.0 - Double(distance) / Double(maxLength)
        
        // 缓存结果
        if similarityCache.count < maxCacheSize {
            similarityCache[cacheKey] = result
        }
        
        return result
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
    
    // 分割句子
    func splitIntoSentences(_ text: String) -> [String] {
        let cleanedText = cleanText(text)
        
        // 使用正则表达式分割句子
        let _ = "[.!?]+\\s+" // sentencePattern未使用，保留以备将来使用
        let sentences = cleanedText.components(separatedBy: .init(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return sentences
    }
    
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