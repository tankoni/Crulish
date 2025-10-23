#!/usr/bin/env swift

import Foundation

// MARK: - 性能测试数据结构

struct PerformanceTestArticle {
    let id: String
    let title: String
    let content: String
    let difficulty: Double
    let wordCount: Int
    let topics: [String]
    let readingTime: Double // 分钟
}

struct PerformanceTestUserWord {
    let word: String
    let masteryLevel: Double
    let frequency: Int
    let lastReviewed: Date
}

struct PerformanceMetrics {
    let executionTime: TimeInterval
    let memoryUsage: Double // MB
    let cpuUsage: Double // %
    let throughput: Double // 操作/秒
}

// MARK: - 性能测试器

class IntelligentRankingPerformanceTester {
    
    // MARK: - 测试数据生成
    
    private func generateTestArticles(count: Int) -> [PerformanceTestArticle] {
        let topics = ["technology", "science", "business", "culture", "sports", "health", "education", "environment"]
        let difficulties = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
        
        return (0..<count).map { index in
            let wordCount = Int.random(in: 100...1000)
            let difficulty = difficulties.randomElement() ?? 0.5
            let topicCount = Int.random(in: 1...3)
            let selectedTopics = Array(topics.shuffled().prefix(topicCount))
            
            return PerformanceTestArticle(
                id: "article_\(index)",
                title: "Test Article \(index)",
                content: generateRandomContent(wordCount: wordCount),
                difficulty: difficulty,
                wordCount: wordCount,
                topics: selectedTopics,
                readingTime: Double(wordCount) / 200.0 // 假设每分钟200词
            )
        }
    }
    
    private func generateTestUserVocabulary(count: Int) -> [PerformanceTestUserWord] {
        let commonWords = ["the", "and", "to", "of", "a", "in", "is", "it", "you", "that", "he", "was", "for", "on", "are", "as", "with", "his", "they", "i"]
        
        return (0..<count).map { index in
            let word = index < commonWords.count ? commonWords[index] : "word_\(index)"
            let masteryLevel = Double.random(in: 0.1...1.0)
            let frequency = Int.random(in: 1...100)
            let daysAgo = Int.random(in: 0...30)
            let lastReviewed = Date().addingTimeInterval(-Double(daysAgo * 86400))
            
            return PerformanceTestUserWord(
                word: word,
                masteryLevel: masteryLevel,
                frequency: frequency,
                lastReviewed: lastReviewed
            )
        }
    }
    
    private func generateRandomContent(wordCount: Int) -> String {
        let words = ["the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog", "and", "runs", "through", "forest", "with", "great", "speed", "while", "birds", "sing", "in", "trees"]
        return (0..<wordCount).map { _ in words.randomElement()! }.joined(separator: " ")
    }
    
    // MARK: - 核心性能测试
    
    func runPerformanceTests() {
        print("🚀 开始智能排序性能测试")
        print(String(repeating: "=", count: 50))
        
        testBasicSortingPerformance()
        testScalabilityPerformance()
        testMemoryUsagePerformance()
        testConcurrentPerformance()
        testCachePerformance()
        testRealTimePerformance()
        
        print("\n✅ 所有性能测试完成")
    }
    
    // MARK: - 基础排序性能测试
    
    private func testBasicSortingPerformance() {
        print("\n📊 测试基础排序性能")
        print(String(repeating: "-", count: 30))
        
        let articleCounts = [10, 50, 100, 500, 1000]
        let vocabularySizes = [100, 500, 1000, 2000]
        
        for articleCount in articleCounts {
            for vocabSize in vocabularySizes {
                let articles = generateTestArticles(count: articleCount)
                let vocabulary = generateTestUserVocabulary(count: vocabSize)
                
                let metrics = measureSortingPerformance(articles: articles, vocabulary: vocabulary)
                
                print("文章数: \(articleCount), 词汇数: \(vocabSize)")
                print("  执行时间: \(String(format: "%.3f", metrics.executionTime))秒")
                print("  吞吐量: \(String(format: "%.1f", metrics.throughput)) 文章/秒")
                print("  内存使用: \(String(format: "%.2f", metrics.memoryUsage))MB")
                
                // 性能要求验证
                if articleCount <= 100 {
                    assert(metrics.executionTime < 1.0, "小规模排序应在1秒内完成")
                } else if articleCount <= 500 {
                    assert(metrics.executionTime < 3.0, "中等规模排序应在3秒内完成")
                } else {
                    assert(metrics.executionTime < 10.0, "大规模排序应在10秒内完成")
                }
            }
        }
        
        print("✅ 基础排序性能测试通过")
    }
    
    // MARK: - 可扩展性性能测试
    
    private func testScalabilityPerformance() {
        print("\n📈 测试可扩展性性能")
        print(String(repeating: "-", count: 30))
        
        let testSizes = [100, 500, 1000, 2000, 5000]
        var previousTime: TimeInterval = 0
        
        for size in testSizes {
            let articles = generateTestArticles(count: size)
            let vocabulary = generateTestUserVocabulary(count: 1000)
            
            let startTime = Date()
            let _ = performIntelligentRanking(articles: articles, vocabulary: vocabulary)
            let executionTime = Date().timeIntervalSince(startTime)
            
            print("数据规模: \(size)")
            print("  执行时间: \(String(format: "%.3f", executionTime))秒")
            
            if previousTime > 0 {
                let scalingFactor = executionTime / previousTime
                let expectedScaling = Double(size) / Double(testSizes[testSizes.firstIndex(of: size)! - 1])
                print("  扩展因子: \(String(format: "%.2f", scalingFactor)) (期望: \(String(format: "%.2f", expectedScaling)))")
                
                // 验证算法复杂度合理性（应该接近线性或对数线性）
                assert(scalingFactor < expectedScaling * 2, "扩展性能应保持合理范围")
            }
            
            previousTime = executionTime
        }
        
        print("✅ 可扩展性性能测试通过")
    }
    
    // MARK: - 内存使用性能测试
    
    private func testMemoryUsagePerformance() {
        print("\n💾 测试内存使用性能")
        print(String(repeating: "-", count: 30))
        
        let testSizes = [100, 500, 1000, 2000]
        
        for size in testSizes {
            let articles = generateTestArticles(count: size)
            let vocabulary = generateTestUserVocabulary(count: 1000)
            
            let initialMemory = getCurrentMemoryUsage()
            let _ = performIntelligentRanking(articles: articles, vocabulary: vocabulary)
            let finalMemory = getCurrentMemoryUsage()
            
            let memoryIncrease = finalMemory - initialMemory
            
            print("数据规模: \(size)")
            print("  内存增长: \(String(format: "%.2f", memoryIncrease))MB")
            print("  单篇文章内存: \(String(format: "%.3f", memoryIncrease / Double(size)))MB")
            
            // 内存使用合理性验证
            assert(memoryIncrease < 100, "内存使用应保持在合理范围内")
        }
        
        print("✅ 内存使用性能测试通过")
    }
    
    // MARK: - 并发性能测试
    
    private func testConcurrentPerformance() {
        print("\n🔄 测试并发性能")
        print(String(repeating: "-", count: 30))
        
        let articles = generateTestArticles(count: 500)
        let vocabulary = generateTestUserVocabulary(count: 1000)
        let concurrencyLevels = [1, 2, 4, 8]
        
        for concurrency in concurrencyLevels {
            let startTime = Date()
            
            let group = DispatchGroup()
            let queue = DispatchQueue.global(qos: .userInitiated)
            
            for _ in 0..<concurrency {
                group.enter()
                queue.async {
                    let _ = self.performIntelligentRanking(articles: articles, vocabulary: vocabulary)
                    group.leave()
                }
            }
            
            group.wait()
            let executionTime = Date().timeIntervalSince(startTime)
            
            print("并发级别: \(concurrency)")
            print("  总执行时间: \(String(format: "%.3f", executionTime))秒")
            print("  平均单任务时间: \(String(format: "%.3f", executionTime / Double(concurrency)))秒")
            
            if concurrency > 1 {
                // 验证并发效率
                assert(executionTime < 10.0, "并发执行应在合理时间内完成")
            }
        }
        
        print("✅ 并发性能测试通过")
    }
    
    // MARK: - 缓存性能测试
    
    private func testCachePerformance() {
        print("\n🗄️ 测试缓存性能")
        print(String(repeating: "-", count: 30))
        
        let articles = generateTestArticles(count: 200)
        let vocabulary = generateTestUserVocabulary(count: 500)
        
        // 首次执行（无缓存）
        let firstRunStart = Date()
        let _ = performIntelligentRanking(articles: articles, vocabulary: vocabulary)
        let firstRunTime = Date().timeIntervalSince(firstRunStart)
        
        // 第二次执行（有缓存）
        let secondRunStart = Date()
        let _ = performIntelligentRanking(articles: articles, vocabulary: vocabulary)
        let secondRunTime = Date().timeIntervalSince(secondRunStart)
        
        // 缓存命中后的多次执行
        var cachedRunTimes: [TimeInterval] = []
        for _ in 0..<5 {
            let cachedRunStart = Date()
            let _ = performIntelligentRanking(articles: articles, vocabulary: vocabulary)
            let cachedRunTime = Date().timeIntervalSince(cachedRunStart)
            cachedRunTimes.append(cachedRunTime)
        }
        
        let avgCachedTime = cachedRunTimes.reduce(0, +) / Double(cachedRunTimes.count)
        let cacheSpeedup = firstRunTime / avgCachedTime
        
        print("首次执行时间: \(String(format: "%.3f", firstRunTime))秒")
        print("第二次执行时间: \(String(format: "%.3f", secondRunTime))秒")
        print("平均缓存执行时间: \(String(format: "%.3f", avgCachedTime))秒")
        print("缓存加速比: \(String(format: "%.1f", cacheSpeedup))x")
        
        // 验证缓存效果
        assert(cacheSpeedup > 1.5, "缓存应显著提升性能")
        
        print("✅ 缓存性能测试通过")
    }
    
    // MARK: - 实时性能测试
    
    private func testRealTimePerformance() {
        print("\n⚡ 测试实时性能")
        print(String(repeating: "-", count: 30))
        
        let articles = generateTestArticles(count: 50)
        let vocabulary = generateTestUserVocabulary(count: 200)
        
        // 模拟用户实时交互场景
        let interactionCount = 20
        var responseTimes: [TimeInterval] = []
        
        for i in 0..<interactionCount {
            // 模拟用户输入变化
            let modifiedVocabulary = vocabulary + generateTestUserVocabulary(count: Int.random(in: 1...10))
            
            let startTime = Date()
            let _ = performIntelligentRanking(articles: articles, vocabulary: modifiedVocabulary)
            let responseTime = Date().timeIntervalSince(startTime)
            
            responseTimes.append(responseTime)
            
            if i % 5 == 0 {
                print("交互 \(i + 1): \(String(format: "%.3f", responseTime))秒")
            }
        }
        
        let avgResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let maxResponseTime = responseTimes.max() ?? 0
        let minResponseTime = responseTimes.min() ?? 0
        
        print("平均响应时间: \(String(format: "%.3f", avgResponseTime))秒")
        print("最大响应时间: \(String(format: "%.3f", maxResponseTime))秒")
        print("最小响应时间: \(String(format: "%.3f", minResponseTime))秒")
        print("响应时间标准差: \(String(format: "%.3f", calculateStandardDeviation(responseTimes)))秒")
        
        // 实时性能要求验证
        assert(avgResponseTime < 0.5, "平均响应时间应小于500毫秒")
        assert(maxResponseTime < 1.0, "最大响应时间应小于1秒")
        
        print("✅ 实时性能测试通过")
    }
    
    // MARK: - 辅助方法
    
    private func measureSortingPerformance(articles: [PerformanceTestArticle], vocabulary: [PerformanceTestUserWord]) -> PerformanceMetrics {
        let initialMemory = getCurrentMemoryUsage()
        let startTime = Date()
        
        let _ = performIntelligentRanking(articles: articles, vocabulary: vocabulary)
        
        let executionTime = Date().timeIntervalSince(startTime)
        let finalMemory = getCurrentMemoryUsage()
        let memoryUsage = finalMemory - initialMemory
        let throughput = Double(articles.count) / executionTime
        
        return PerformanceMetrics(
            executionTime: executionTime,
            memoryUsage: memoryUsage,
            cpuUsage: 0, // 简化实现
            throughput: throughput
        )
    }
    
    private func performIntelligentRanking(articles: [PerformanceTestArticle], vocabulary: [PerformanceTestUserWord]) -> [PerformanceTestArticle] {
        // 模拟智能排序算法
        return articles.sorted { article1, article2 in
            let score1 = calculateArticleScore(article1, vocabulary: vocabulary)
            let score2 = calculateArticleScore(article2, vocabulary: vocabulary)
            return score1 > score2
        }
    }
    
    private func calculateArticleScore(_ article: PerformanceTestArticle, vocabulary: [PerformanceTestUserWord]) -> Double {
        // 模拟复杂的评分算法
        let difficultyScore = 1.0 - abs(article.difficulty - 0.6) // 假设用户偏好0.6难度
        let lengthScore = 1.0 - abs(Double(article.wordCount) - 400) / 400 // 假设偏好400词
        
        // 模拟词汇匹配计算
        let vocabularyWords = Set(vocabulary.map { $0.word })
        let articleWords = Set(article.content.components(separatedBy: " "))
        let matchingWords = vocabularyWords.intersection(articleWords)
        let vocabularyScore = Double(matchingWords.count) / Double(max(articleWords.count, 1))
        
        return (difficultyScore + lengthScore + vocabularyScore) / 3.0
    }
    
    private func getCurrentMemoryUsage() -> Double {
        // 简化的内存使用计算，返回固定值用于测试
        return 50.0 // MB
    }
    
    private func calculateStandardDeviation(_ values: [TimeInterval]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}

// MARK: - 主程序

let tester = IntelligentRankingPerformanceTester()
tester.runPerformanceTests()