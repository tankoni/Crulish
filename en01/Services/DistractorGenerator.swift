//
//  DistractorGenerator.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import Foundation

/// 智能干扰项生成器
class DistractorGenerator {
    private let dictionaryService: DictionaryServiceProtocol
    
    init(dictionaryService: DictionaryServiceProtocol) {
        self.dictionaryService = dictionaryService
    }
    
    /// 为英译中模式生成干扰项
    /// - Parameters:
    ///   - targetWord: 目标单词
    ///   - correctDefinition: 正确释义
    ///   - allWords: 词典中的所有单词
    ///   - count: 需要生成的干扰项数量
    /// - Returns: 干扰项数组
    func generateEnglishToChineseDistractors(
        targetWord: TestWord,
        correctDefinition: String,
        allWords: [DictionaryWord],
        count: Int = 3
    ) -> [String] {
        var distractors: [String] = []
        let correctDef = correctDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 从其他单词的释义中选择相似但不同的释义
        let otherDefinitions = allWords
            .filter { $0.word != targetWord.word } // 排除目标单词
            .flatMap { $0.definitions }
            .map { $0.meaning }
            .filter { !$0.isEmpty && $0 != correctDef } // 排除空释义和正确答案
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // 2. 选择语义相关的干扰项
        let semanticDistractors = selectSemanticDistractors(
            correctDefinition: correctDef,
            candidateDefinitions: otherDefinitions,
            count: count
        )
        distractors.append(contentsOf: semanticDistractors)
        
        // 3. 如果语义相关的干扰项不足，随机选择其他释义
        if distractors.count < count {
            let remainingCount = count - distractors.count
            let randomDistractors = otherDefinitions
                .filter { !distractors.contains($0) }
                .shuffled()
                .prefix(remainingCount)
            distractors.append(contentsOf: randomDistractors)
        }
        
        // 4. 如果仍然不足，使用默认干扰项
        if distractors.count < count {
            let defaultDistractors = [
                "错误释义选项",
                "其他含义",
                "不相关释义",
                "干扰项选项",
                "无关含义"
            ]
            
            let remainingCount = count - distractors.count
            let additionalDistractors = defaultDistractors
                .filter { !distractors.contains($0) }
                .prefix(remainingCount)
            distractors.append(contentsOf: additionalDistractors)
        }
        
        return Array(distractors.prefix(count))
    }
    
    /// 为中译英模式生成干扰项
    /// - Parameters:
    ///   - targetWord: 目标单词
    ///   - correctWord: 正确单词
    ///   - allWords: 词典中的所有单词
    ///   - count: 需要生成的干扰项数量
    /// - Returns: 干扰项数组
    func generateChineseToEnglishDistractors(
        targetWord: TestWord,
        correctWord: String,
        allWords: [DictionaryWord],
        count: Int = 3
    ) -> [String] {
        var distractors: [String] = []
        let correctWordLower = correctWord.lowercased()
        
        // 1. 选择拼写相似的单词
        let spellingDistractors = selectSpellingSimilarWords(
            targetWord: correctWordLower,
            allWords: allWords,
            count: count
        )
        distractors.append(contentsOf: spellingDistractors)
        
        // 2. 如果拼写相似的单词不足，选择长度相近的单词
        if distractors.count < count {
            let lengthDistractors = selectLengthSimilarWords(
                targetWord: correctWordLower,
                allWords: allWords,
                excludeWords: Set(distractors + [correctWordLower]),
                count: count - distractors.count
            )
            distractors.append(contentsOf: lengthDistractors)
        }
        
        // 3. 如果仍然不足，随机选择其他单词
        if distractors.count < count {
            let randomDistractors = allWords
                .map { $0.word }
                .filter { word in
                    let wordLower = word.lowercased()
                    return wordLower != correctWordLower && !distractors.contains(wordLower)
                }
                .shuffled()
                .prefix(count - distractors.count)
            distractors.append(contentsOf: randomDistractors)
        }
        
        // 4. 如果仍然不足，使用默认干扰项
        if distractors.count < count {
            let defaultDistractors = [
                "option1",
                "option2", 
                "option3",
                "word1",
                "word2"
            ]
            
            let remainingCount = count - distractors.count
            let additionalDistractors = defaultDistractors
                .filter { !distractors.contains($0) && $0 != correctWordLower }
                .prefix(remainingCount)
            distractors.append(contentsOf: additionalDistractors)
        }
        
        return Array(distractors.prefix(count))
    }
    
    // MARK: - Private Helper Methods
    
    /// 选择语义相关的干扰项
    private func selectSemanticDistractors(
        correctDefinition: String,
        candidateDefinitions: [String],
        count: Int
    ) -> [String] {
        let correctWords = extractKeywords(from: correctDefinition)
        
        // 计算每个候选释义与正确释义的相似度
        let scoredDefinitions = candidateDefinitions.map { definition in
            let similarity = calculateSemanticSimilarity(
                correctWords: correctWords,
                candidateDefinition: definition
            )
            return (definition: definition, similarity: similarity)
        }
        
        // 选择相似度适中的释义作为干扰项（不能太相似，也不能完全无关）
        return scoredDefinitions
            .filter { $0.similarity > 0.1 && $0.similarity < 0.8 } // 相似度在0.1-0.8之间
            .sorted { $0.similarity > $1.similarity } // 按相似度降序排列
            .prefix(count)
            .map { $0.definition }
    }
    
    /// 选择拼写相似的单词
    private func selectSpellingSimilarWords(
        targetWord: String,
        allWords: [DictionaryWord],
        count: Int
    ) -> [String] {
        let targetLength = targetWord.count
        
        // 计算编辑距离并选择相似的单词
        let similarWords = allWords
            .map { $0.word.lowercased() }
            .filter { word in
                word != targetWord &&
                abs(word.count - targetLength) <= 2 && // 长度差不超过2
                editDistance(targetWord, word) <= max(2, targetLength / 3) // 编辑距离合理
            }
            .sorted { word1, word2 in
                editDistance(targetWord, word1) < editDistance(targetWord, word2)
            }
        
        return Array(similarWords.prefix(count))
    }
    
    /// 选择长度相近的单词
    private func selectLengthSimilarWords(
        targetWord: String,
        allWords: [DictionaryWord],
        excludeWords: Set<String>,
        count: Int
    ) -> [String] {
        let targetLength = targetWord.count
        
        return allWords
            .map { $0.word.lowercased() }
            .filter { word in
                !excludeWords.contains(word) &&
                abs(word.count - targetLength) <= 1 // 长度差不超过1
            }
            .shuffled()
            .prefix(count)
            .map { $0 }
    }
    
    /// 从释义中提取关键词
    private func extractKeywords(from definition: String) -> Set<String> {
        let cleanDefinition = definition
            .lowercased()
            .replacingOccurrences(of: "[^\u{4e00}-\u{9fa5}a-z0-9\\s]", with: "", options: .regularExpression)
        
        let words = cleanDefinition.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.count > 1 }
        
        return Set(words)
    }
    
    /// 计算语义相似度
    private func calculateSemanticSimilarity(
        correctWords: Set<String>,
        candidateDefinition: String
    ) -> Double {
        let candidateWords = extractKeywords(from: candidateDefinition)
        
        guard !correctWords.isEmpty && !candidateWords.isEmpty else {
            return 0.0
        }
        
        let intersection = correctWords.intersection(candidateWords)
        let union = correctWords.union(candidateWords)
        
        return Double(intersection.count) / Double(union.count)
    }
    
    /// 计算编辑距离（Levenshtein距离）
    private func editDistance(_ str1: String, _ str2: String) -> Int {
        let s1 = Array(str1)
        let s2 = Array(str2)
        let m = s1.count
        let n = s2.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        
        for j in 0...n {
            dp[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if s1[i-1] == s2[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]) + 1
                }
            }
        }
        
        return dp[m][n]
    }
}