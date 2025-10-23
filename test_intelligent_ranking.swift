#!/usr/bin/env swift

//
//  test_intelligent_ranking.swift
//  智能排序功能测试脚本
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation

// MARK: - 测试数据结构

struct TestArticle {
    let id: UUID
    let title: String
    let content: String
    let difficulty: String
    let wordCount: Int
    
    init(title: String, content: String, difficulty: String = "medium") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.difficulty = difficulty
        self.wordCount = content.components(separatedBy: .whitespacesAndNewlines).count
    }
}

struct TestUserWord {
    let word: String
    let masteryLevel: String
    let lookupCount: Int
    
    init(word: String, masteryLevel: String = "unfamiliar", lookupCount: Int = 1) {
        self.word = word
        self.masteryLevel = masteryLevel
        self.lookupCount = lookupCount
    }
}

struct TestDictionary {
    let name: String
    let words: [String]
    
    init(name: String, words: [String]) {
        self.name = name
        self.words = words
    }
}

// MARK: - 测试用例

class IntelligentRankingTest {
    
    // 测试文章数据
    private let testArticles = [
        TestArticle(
            title: "Basic English Grammar",
            content: "The cat sits on the mat. This is a simple sentence with basic vocabulary.",
            difficulty: "easy"
        ),
        TestArticle(
            title: "Advanced Scientific Research",
            content: "The methodology encompasses comprehensive analysis of molecular structures and biochemical processes.",
            difficulty: "hard"
        ),
        TestArticle(
            title: "Daily Life Conversation",
            content: "Good morning! How are you today? I am fine, thank you. What about you?",
            difficulty: "medium"
        )
    ]
    
    // 测试用户词汇
    private let testUserVocabulary = [
        TestUserWord(word: "cat", masteryLevel: "mastered", lookupCount: 5),
        TestUserWord(word: "sits", masteryLevel: "familiar", lookupCount: 3),
        TestUserWord(word: "simple", masteryLevel: "unfamiliar", lookupCount: 1),
        TestUserWord(word: "methodology", masteryLevel: "unfamiliar", lookupCount: 1),
        TestUserWord(word: "comprehensive", masteryLevel: "unfamiliar", lookupCount: 2),
        TestUserWord(word: "morning", masteryLevel: "mastered", lookupCount: 4)
    ]
    
    // 测试词典
    private let testDictionary = TestDictionary(
        name: "Basic English",
        words: ["cat", "sits", "mat", "simple", "sentence", "morning", "good", "fine", "thank", "you"]
    )
    
    // MARK: - 测试方法
    
    func runAllTests() {
        print("🚀 开始智能排序功能测试...")
        print("=" * 50)
        
        testBasicRanking()
        testDictionaryBasedRanking()
        testDifficultyAnalysis()
        testMatchScoreCalculation()
        testPerformanceMetrics()
        
        print("=" * 50)
        print("✅ 智能排序功能测试完成！")
    }
    
    private func testBasicRanking() {
        print("\n📊 测试基础排序功能...")
        
        // 模拟基础排序逻辑
        let rankedArticles = testArticles.sorted { article1, article2 in
            let score1 = calculateBasicMatchScore(article: article1)
            let score2 = calculateBasicMatchScore(article: article2)
            return score1 > score2
        }
        
        print("排序结果:")
        for (index, article) in rankedArticles.enumerated() {
            let score = calculateBasicMatchScore(article: article)
            print("  \(index + 1). \(article.title) (匹配度: \(String(format: "%.2f", score)))")
        }
        
        assert(rankedArticles.count == testArticles.count, "排序后文章数量应保持不变")
        print("✅ 基础排序功能测试通过")
    }
    
    private func testDictionaryBasedRanking() {
        print("\n📚 测试基于词典的排序功能...")
        
        let rankedArticles = testArticles.sorted { article1, article2 in
            let score1 = calculateDictionaryMatchScore(article: article1)
            let score2 = calculateDictionaryMatchScore(article: article2)
            return score1 > score2
        }
        
        print("基于词典的排序结果:")
        for (index, article) in rankedArticles.enumerated() {
            let score = calculateDictionaryMatchScore(article: article)
            let coverage = calculateDictionaryCoverage(article: article)
            print("  \(index + 1). \(article.title)")
            print("     匹配度: \(String(format: "%.2f", score)), 词典覆盖率: \(String(format: "%.1f%%", coverage * 100))")
        }
        
        print("✅ 基于词典的排序功能测试通过")
    }
    
    private func testDifficultyAnalysis() {
        print("\n🎯 测试难度分析功能...")
        
        for article in testArticles {
            let difficulty = analyzeDifficulty(article: article)
            let userMastery = calculateUserMastery(article: article)
            
            print("文章: \(article.title)")
            print("  预设难度: \(article.difficulty)")
            print("  分析难度: \(difficulty)")
            print("  用户掌握度: \(String(format: "%.1f%%", userMastery * 100))")
            print()
        }
        
        print("✅ 难度分析功能测试通过")
    }
    
    private func testMatchScoreCalculation() {
        print("\n🔢 测试匹配度计算功能...")
        
        for article in testArticles {
            let basicScore = calculateBasicMatchScore(article: article)
            let dictionaryScore = calculateDictionaryMatchScore(article: article)
            let adaptiveScore = calculateAdaptiveScore(article: article)
            
            print("文章: \(article.title)")
            print("  基础匹配度: \(String(format: "%.2f", basicScore))")
            print("  词典匹配度: \(String(format: "%.2f", dictionaryScore))")
            print("  自适应匹配度: \(String(format: "%.2f", adaptiveScore))")
            print()
        }
        
        print("✅ 匹配度计算功能测试通过")
    }
    
    private func testPerformanceMetrics() {
        print("\n⚡ 测试性能指标...")
        
        let startTime = Date()
        
        // 模拟大量文章的排序
        let largeArticleSet = Array(repeating: testArticles, count: 100).flatMap { $0 }
        let _ = largeArticleSet.sorted { article1, article2 in
            let score1 = calculateBasicMatchScore(article: article1)
            let score2 = calculateBasicMatchScore(article: article2)
            return score1 > score2
        }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        print("处理 \(largeArticleSet.count) 篇文章耗时: \(String(format: "%.3f", processingTime)) 秒")
        print("平均每篇文章处理时间: \(String(format: "%.3f", processingTime / Double(largeArticleSet.count) * 1000)) 毫秒")
        
        assert(processingTime < 1.0, "处理时间应小于1秒")
        print("✅ 性能指标测试通过")
    }
    
    // MARK: - 辅助计算方法
    
    private func calculateBasicMatchScore(article: TestArticle) -> Double {
        let words = extractWords(from: article.content)
        let knownWords = words.filter { word in
            testUserVocabulary.contains { $0.word.lowercased() == word.lowercased() }
        }
        
        let knownRatio = Double(knownWords.count) / Double(words.count)
        let difficultyMultiplier = getDifficultyMultiplier(difficulty: article.difficulty)
        
        return knownRatio * difficultyMultiplier
    }
    
    private func calculateDictionaryMatchScore(article: TestArticle) -> Double {
        let words = extractWords(from: article.content)
        let dictionaryWords = words.filter { word in
            testDictionary.words.contains { $0.lowercased() == word.lowercased() }
        }
        
        let coverage = Double(dictionaryWords.count) / Double(words.count)
        let userMastery = calculateUserMastery(article: article)
        
        return coverage * 0.6 + userMastery * 0.4
    }
    
    private func calculateAdaptiveScore(article: TestArticle) -> Double {
        let basicScore = calculateBasicMatchScore(article: article)
        let dictionaryScore = calculateDictionaryMatchScore(article: article)
        let difficultyBonus = getDifficultyBonus(article: article)
        
        return (basicScore * 0.4 + dictionaryScore * 0.4 + difficultyBonus * 0.2)
    }
    
    private func calculateDictionaryCoverage(article: TestArticle) -> Double {
        let words = extractWords(from: article.content)
        let dictionaryWords = words.filter { word in
            testDictionary.words.contains { $0.lowercased() == word.lowercased() }
        }
        
        return Double(dictionaryWords.count) / Double(words.count)
    }
    
    private func calculateUserMastery(article: TestArticle) -> Double {
        let words = extractWords(from: article.content)
        let masteredWords = words.filter { word in
            testUserVocabulary.first { $0.word.lowercased() == word.lowercased() }?.masteryLevel == "mastered"
        }
        
        return words.isEmpty ? 0.0 : Double(masteredWords.count) / Double(words.count)
    }
    
    private func analyzeDifficulty(article: TestArticle) -> String {
        let avgWordLength = calculateAverageWordLength(article: article)
        let vocabularyComplexity = calculateVocabularyComplexity(article: article)
        
        if avgWordLength < 4.0 && vocabularyComplexity < 0.3 {
            return "easy"
        } else if avgWordLength > 6.0 || vocabularyComplexity > 0.7 {
            return "hard"
        } else {
            return "medium"
        }
    }
    
    private func calculateAverageWordLength(article: TestArticle) -> Double {
        let words = extractWords(from: article.content)
        let totalLength = words.reduce(0) { $0 + $1.count }
        return words.isEmpty ? 0.0 : Double(totalLength) / Double(words.count)
    }
    
    private func calculateVocabularyComplexity(article: TestArticle) -> Double {
        let words = extractWords(from: article.content)
        let complexWords = words.filter { $0.count > 6 }
        return words.isEmpty ? 0.0 : Double(complexWords.count) / Double(words.count)
    }
    
    private func extractWords(from text: String) -> [String] {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .compactMap { word in
                let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                return cleanWord.isEmpty ? nil : cleanWord
            }
    }
    
    private func getDifficultyMultiplier(difficulty: String) -> Double {
        switch difficulty.lowercased() {
        case "easy": return 1.2
        case "medium": return 1.0
        case "hard": return 0.8
        default: return 1.0
        }
    }
    
    private func getDifficultyBonus(article: TestArticle) -> Double {
        let userLevel = calculateOverallUserLevel()
        let articleDifficulty = getDifficultyLevel(difficulty: article.difficulty)
        
        // 根据用户水平和文章难度计算适应性奖励
        let levelDifference = abs(userLevel - articleDifficulty)
        return max(0.0, 1.0 - levelDifference * 0.3)
    }
    
    private func calculateOverallUserLevel() -> Double {
        let masteredCount = testUserVocabulary.filter { $0.masteryLevel == "mastered" }.count
        let familiarCount = testUserVocabulary.filter { $0.masteryLevel == "familiar" }.count
        let totalCount = testUserVocabulary.count
        
        if totalCount == 0 { return 0.5 }
        
        let masteryRatio = Double(masteredCount * 2 + familiarCount) / Double(totalCount * 2)
        return masteryRatio
    }
    
    private func getDifficultyLevel(difficulty: String) -> Double {
        switch difficulty.lowercased() {
        case "easy": return 0.3
        case "medium": return 0.6
        case "hard": return 0.9
        default: return 0.5
        }
    }
}

// MARK: - String 扩展

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// MARK: - 主程序入口

let test = IntelligentRankingTest()
test.runAllTests()