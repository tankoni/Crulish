#!/usr/bin/env swift

import Foundation

// 简化的性能测试数据结构
struct SimpleTestArticle {
    let id: String
    let title: String
    let content: String
    let difficulty: Double
    let wordCount: Int
}

struct SimpleTestUserWord {
    let word: String
    let masteryLevel: Double
    let frequency: Int
}

struct SimplePerformanceMetrics {
    let testName: String
    let executionTime: TimeInterval
    let itemsProcessed: Int
    let throughput: Double
    
    var description: String {
        return """
        测试: \(testName)
        执行时间: \(String(format: "%.3f", executionTime))ms
        处理项目: \(itemsProcessed)
        吞吐量: \(String(format: "%.1f", throughput)) items/ms
        """
    }
}

class SimplePerformanceTest {
    
    // MARK: - 测试数据生成
    
    private func generateTestArticles(count: Int) -> [SimpleTestArticle] {
        let titles = ["Technology", "Science", "History", "Literature", "Economics"]
        let contents = [
            "This is a simple article about technology and innovation.",
            "Science has made tremendous progress in recent years.",
            "History teaches us valuable lessons about human nature.",
            "Literature reflects the culture and values of society.",
            "Economics plays a crucial role in modern life."
        ]
        
        return (0..<count).map { index in
            SimpleTestArticle(
                id: "article_\(index)",
                title: titles[index % titles.count],
                content: contents[index % contents.count],
                difficulty: Double.random(in: 1.0...10.0),
                wordCount: Int.random(in: 50...500)
            )
        }
    }
    
    private func generateTestUserVocabulary(count: Int) -> [SimpleTestUserWord] {
        let words = ["the", "and", "to", "of", "a", "in", "is", "it", "you", "that", 
                    "technology", "science", "history", "literature", "economics"]
        
        return (0..<count).map { index in
            SimpleTestUserWord(
                word: words[index % words.count] + "_\(index)",
                masteryLevel: Double.random(in: 0.0...1.0),
                frequency: Int.random(in: 1...100)
            )
        }
    }
    
    // MARK: - 核心性能测试
    
    func runPerformanceTests() {
        print("🚀 开始智能排序性能测试")
        print(String(repeating: "=", count: 50))
        
        var results: [SimplePerformanceMetrics] = []
        
        // 测试1: 基础排序性能
        results.append(testBasicSorting())
        
        // 测试2: 可扩展性测试
        results.append(testScalability())
        
        // 测试3: 复杂计算性能
        results.append(testComplexCalculations())
        
        // 测试4: 并发处理性能
        results.append(testConcurrentProcessing())
        
        // 输出测试结果
        printTestResults(results)
    }
    
    private func testBasicSorting() -> SimplePerformanceMetrics {
        print("\n📊 测试1: 基础排序性能")
        
        let articles = generateTestArticles(count: 100)
        let userVocab = generateTestUserVocabulary(count: 50)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 执行基础排序
        let sortedArticles = performBasicSorting(articles: articles, userVocab: userVocab)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000 // 转换为毫秒
        
        let metrics = SimplePerformanceMetrics(
            testName: "基础排序",
            executionTime: executionTime,
            itemsProcessed: articles.count,
            throughput: Double(articles.count) / executionTime
        )
        
        print("✅ 排序完成，处理了 \(sortedArticles.count) 篇文章")
        print("⏱️ 执行时间: \(String(format: "%.3f", executionTime))ms")
        
        return metrics
    }
    
    private func testScalability() -> SimplePerformanceMetrics {
        print("\n📈 测试2: 可扩展性测试")
        
        let articleCounts = [50, 100, 200, 500]
        var totalTime: TimeInterval = 0
        var totalItems = 0
        
        for count in articleCounts {
            let articles = generateTestArticles(count: count)
            let userVocab = generateTestUserVocabulary(count: count / 2)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let _ = performBasicSorting(articles: articles, userVocab: userVocab)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            let time = (endTime - startTime) * 1000
            totalTime += time
            totalItems += count
            
            print("📝 \(count) 篇文章: \(String(format: "%.3f", time))ms")
        }
        
        return SimplePerformanceMetrics(
            testName: "可扩展性",
            executionTime: totalTime,
            itemsProcessed: totalItems,
            throughput: Double(totalItems) / totalTime
        )
    }
    
    private func testComplexCalculations() -> SimplePerformanceMetrics {
        print("\n🧮 测试3: 复杂计算性能")
        
        let articles = generateTestArticles(count: 100)
        let userVocab = generateTestUserVocabulary(count: 100)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 执行复杂的匹配度计算
        var totalScore: Double = 0
        for article in articles {
            let score = calculateComplexScore(article: article, userVocab: userVocab)
            totalScore += score
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000
        
        print("✅ 计算完成，总分: \(String(format: "%.2f", totalScore))")
        
        return SimplePerformanceMetrics(
            testName: "复杂计算",
            executionTime: executionTime,
            itemsProcessed: articles.count,
            throughput: Double(articles.count) / executionTime
        )
    }
    
    private func testConcurrentProcessing() -> SimplePerformanceMetrics {
        print("\n⚡ 测试4: 并发处理性能")
        
        let articles = generateTestArticles(count: 200)
        let userVocab = generateTestUserVocabulary(count: 100)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 使用并发队列处理
        let group = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "performance.test", attributes: .concurrent)
        var results: [Double] = Array(repeating: 0.0, count: articles.count)
        
        for (index, article) in articles.enumerated() {
            group.enter()
            concurrentQueue.async {
                results[index] = self.calculateComplexScore(article: article, userVocab: userVocab)
                group.leave()
            }
        }
        
        group.wait()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = (endTime - startTime) * 1000
        
        print("✅ 并发处理完成，处理了 \(results.count) 个任务")
        
        return SimplePerformanceMetrics(
            testName: "并发处理",
            executionTime: executionTime,
            itemsProcessed: articles.count,
            throughput: Double(articles.count) / executionTime
        )
    }
    
    // MARK: - 辅助方法
    
    private func performBasicSorting(articles: [SimpleTestArticle], userVocab: [SimpleTestUserWord]) -> [SimpleTestArticle] {
        return articles.sorted { article1, article2 in
            let score1 = calculateBasicScore(article: article1, userVocab: userVocab)
            let score2 = calculateBasicScore(article: article2, userVocab: userVocab)
            return score1 > score2
        }
    }
    
    private func calculateBasicScore(article: SimpleTestArticle, userVocab: [SimpleTestUserWord]) -> Double {
        // 基础评分算法
        let difficultyScore = (10.0 - article.difficulty) / 10.0
        let lengthScore = min(Double(article.wordCount) / 300.0, 1.0)
        
        // 词汇匹配度
        let vocabScore = userVocab.reduce(0.0) { total, word in
            if article.content.lowercased().contains(word.word.lowercased()) {
                return total + word.masteryLevel
            }
            return total
        } / Double(userVocab.count)
        
        return (difficultyScore * 0.4) + (lengthScore * 0.3) + (vocabScore * 0.3)
    }
    
    private func calculateComplexScore(article: SimpleTestArticle, userVocab: [SimpleTestUserWord]) -> Double {
        // 复杂评分算法，包含更多计算
        var score = calculateBasicScore(article: article, userVocab: userVocab)
        
        // 添加复杂的权重计算
        let words = article.content.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            for vocabWord in userVocab {
                if word.lowercased() == vocabWord.word.lowercased() {
                    score += vocabWord.masteryLevel * 0.1
                }
            }
        }
        
        // 添加一些数学运算来增加计算复杂度
        score *= sin(article.difficulty) + cos(Double(article.wordCount))
        score = abs(score)
        
        return score
    }
    
    private func printTestResults(_ results: [SimplePerformanceMetrics]) {
        print("\n" + String(repeating: "=", count: 50))
        print("📊 性能测试结果汇总")
        print(String(repeating: "=", count: 50))
        
        for result in results {
            print("\n" + result.description)
        }
        
        // 计算总体统计
        let totalTime = results.reduce(0.0) { $0 + $1.executionTime }
        let totalItems = results.reduce(0) { $0 + $1.itemsProcessed }
        let avgThroughput = results.reduce(0.0) { $0 + $1.throughput } / Double(results.count)
        
        print("\n" + String(repeating: "-", count: 30))
        print("📈 总体性能指标:")
        print("总执行时间: \(String(format: "%.3f", totalTime))ms")
        print("总处理项目: \(totalItems)")
        print("平均吞吐量: \(String(format: "%.1f", avgThroughput)) items/ms")
        
        // 性能评估
        print("\n🎯 性能评估:")
        if avgThroughput > 1.0 {
            print("✅ 性能优秀 - 吞吐量超过 1.0 items/ms")
        } else if avgThroughput > 0.5 {
            print("⚠️ 性能良好 - 吞吐量在 0.5-1.0 items/ms")
        } else {
            print("❌ 性能需要优化 - 吞吐量低于 0.5 items/ms")
        }
        
        print(String(repeating: "=", count: 50))
    }
}

// MARK: - 主程序入口

let performanceTest = SimplePerformanceTest()
performanceTest.runPerformanceTests()

print("\n🎉 智能排序性能测试完成!")