//
//  ArticleService.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData

@Observable
class ArticleService {
    private var modelContext: ModelContext?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }
    
    // MARK: - 文章管理
    
    // 获取所有文章
    func getAllArticles() -> [Article] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\Article.year, order: .reverse)])
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取文章失败: \(error)")
            return []
        }
    }
    
    // 根据年份获取文章
    func getArticlesByYear(_ year: Int) -> [Article] {
        guard let context = modelContext else { return [] }
        
        let predicate = #Predicate<Article> { article in
            article.year == year
        }
        
        let descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: [SortDescriptor(\Article.title)])
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取\(year)年文章失败: \(error)")
            return []
        }
    }
    
    // 根据难度获取文章
    func getArticlesByDifficulty(_ difficulty: ArticleDifficulty) -> [Article] {
        guard let context = modelContext else { return [] }
        
        let predicate = #Predicate<Article> { article in
            article.difficulty == difficulty
        }
        
        let descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: [SortDescriptor(\Article.title)])
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取\(difficulty.rawValue)难度文章失败: \(error)")
            return []
        }
    }
    
    // 根据主题获取文章
    func getArticlesByTopic(_ topic: String) -> [Article] {
        guard let context = modelContext else { return [] }
        
        let predicate = #Predicate<Article> { article in
            article.topic == topic
        }
        
        let descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: [SortDescriptor(\Article.title)])
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取\(topic)主题文章失败: \(error)")
            return []
        }
    }
    
    // 获取未完成的文章
    func getUnfinishedArticles() -> [Article] {
        guard let context = modelContext else { return [] }
        
        let predicate = #Predicate<Article> { article in
            !article.isCompleted
        }
        
        let descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: [SortDescriptor(\Article.lastReadDate, order: .reverse)])
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取未完成文章失败: \(error)")
            return []
        }
    }
    
    // 获取最近阅读的文章
    func getRecentlyReadArticles(limit: Int = 10) -> [Article] {
        guard let context = modelContext else { return [] }
        
        let predicate = #Predicate<Article> { article in
            article.lastReadDate != nil
        }
        
        var descriptor = FetchDescriptor<Article>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Article.lastReadDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取最近阅读文章失败: \(error)")
            return []
        }
    }
    
    // 搜索文章
    func searchArticles(query: String) -> [Article] {
        guard let context = modelContext else { return [] }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        
        let lowercaseQuery = query.lowercased()
        
        let predicate = #Predicate<Article> { article in
            article.title.localizedStandardContains(lowercaseQuery) ||
            article.content.localizedStandardContains(lowercaseQuery) ||
            article.topic.localizedStandardContains(lowercaseQuery)
        }
        
        let descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: [SortDescriptor(\Article.year, order: .reverse)])
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("搜索文章失败: \(error)")
            return []
        }
    }
    
    // MARK: - 文章操作
    
    // 添加文章
    func addArticle(_ article: Article) {
        guard let context = modelContext else { return }
        
        context.insert(article)
        
        do {
            try context.save()
        } catch {
            print("添加文章失败: \(error)")
        }
    }
    
    // 更新文章阅读进度
    func updateArticleProgress(_ article: Article, progress: Double) {
        article.updateProgress(progress)
        saveContext()
    }
    
    // 增加文章阅读时间
    func addReadingTime(to article: Article, time: TimeInterval) {
        article.addReadingTime(time)
        saveContext()
    }
    
    // 标记文章为已完成
    func markArticleAsCompleted(_ article: Article) {
        article.isCompleted = true
        article.readingProgress = 1.0
        article.lastReadDate = Date()
        saveContext()
    }
    
    // 更新文章
    func updateArticle(_ article: Article) {
        saveContext()
    }
    
    // 删除文章
    func deleteArticle(_ article: Article) {
        guard let context = modelContext else { return }
        
        context.delete(article)
        
        do {
            try context.save()
        } catch {
            print("删除文章失败: \(error)")
        }
    }
    
    // MARK: - 统计信息
    
    // 获取文章统计信息
    func getArticleStats() -> ArticleStats {
        let allArticles = getAllArticles()
        
        let totalArticles = allArticles.count
        let completedArticles = allArticles.filter { $0.isCompleted }.count
        let inProgressArticles = allArticles.filter { $0.readingProgress > 0 && !$0.isCompleted }.count
        let unreadArticles = allArticles.filter { $0.readingProgress == 0 }.count
        
        let totalReadingTime = allArticles.reduce(0) { $0 + $1.readingTime }
        let averageProgress = totalArticles > 0 ? allArticles.reduce(0) { $0 + $1.readingProgress } / Double(totalArticles) : 0
        
        // 按年份统计
        let yearStats = Dictionary(grouping: allArticles, by: { $0.year })
            .mapValues { articles in
                (total: articles.count, completed: articles.filter { $0.isCompleted }.count)
            }
        
        // 按难度统计
        let difficultyStats = Dictionary(grouping: allArticles, by: { $0.difficulty })
            .mapValues { articles in
                (total: articles.count, completed: articles.filter { $0.isCompleted }.count)
            }
        
        // 按主题统计
        let topicStats = Dictionary(grouping: allArticles, by: { $0.topic })
            .mapValues { articles in
                (total: articles.count, completed: articles.filter { $0.isCompleted }.count)
            }
        
        return ArticleStats(
            totalArticles: totalArticles,
            completedArticles: completedArticles,
            inProgressArticles: inProgressArticles,
            unreadArticles: unreadArticles,
            totalReadingTime: totalReadingTime,
            averageProgress: averageProgress,
            yearStats: yearStats,
            difficultyStats: difficultyStats,
            topicStats: topicStats
        )
    }
    
    // 获取推荐文章
    func getRecommendedArticles(limit: Int = 5) -> [Article] {
        let unfinishedArticles = getUnfinishedArticles()
        
        // 简单的推荐算法：优先推荐有进度但未完成的文章，然后是未开始的文章
        let inProgress = unfinishedArticles.filter { $0.readingProgress > 0 }
        let unread = unfinishedArticles.filter { $0.readingProgress == 0 }
        
        var recommended: [Article] = []
        recommended.append(contentsOf: inProgress.prefix(limit / 2))
        recommended.append(contentsOf: unread.prefix(limit - recommended.count))
        
        return Array(recommended.prefix(limit))
    }
    
    // MARK: - 数据导入
    
    /// 从JSON文件异步导入文章
    /// - Parameter fileName: JSON文件名（不包含扩展名）
    func importArticlesFromJSON(fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("[ERROR] 找不到文件: \(fileName).json")
            return
        }
        
        Task {
            do {
                let data = try Data(contentsOf: url)
                let articleData = try JSONDecoder().decode([ArticleData].self, from: data)
                
                // 批量导入以提高性能
                await MainActor.run {
                    var importedCount = 0
                    
                    for data in articleData {
                        let article = Article(
                            title: data.title,
                            content: data.content,
                            year: data.year,
                            examType: data.examType,
                            difficulty: data.difficulty,
                            topic: data.topic,
                            imageName: "image_\(Int.random(in: 1...10))"
                        )
                        
                        // 检查是否已存在相同标题的文章
                        let existingArticles = self.getAllArticles()
                        if !existingArticles.contains(where: { $0.title == article.title }) {
                            self.addArticle(article)
                            importedCount += 1
                        }
                    }
                    
                    print("[SUCCESS] 成功导入\(importedCount)篇文章（共\(articleData.count)篇）")
                }
            } catch {
                print("[ERROR] 导入文章失败: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    print("[ERROR] 数据格式错误: \(decodingError)")
                }
            }
        }
    }
    
    // 初始化示例数据
    func initializeSampleData() {
        let sampleArticles = [
            ArticleData(
                title: "The Impact of Artificial Intelligence on Modern Society",
                content: """
Artificial Intelligence (AI) is rapidly transforming work, education, and daily lives.

One of the most significant impacts of AI is in the workplace. Automation and AI-powered tools are revolutionizing industries from manufacturing to healthcare.

In education, AI is personalizing learning experiences and providing new opportunities for students to engage with complex subjects.

However, the rise of AI also brings challenges, including concerns about job displacement and the need for new skills in the workforce.

As we move forward, it is crucial to ensure that AI development is guided by ethical principles and serves the benefit of all humanity.
""",
                year: 2023,
                examType: "考研一",
                difficulty: .medium,
                topic: "科技发展"
            ),
            ArticleData(
                title: "Climate Change: Global Challenges and Solutions",
                content: """
Climate change represents one of the most pressing challenges of our time, requiring immediate and coordinated global action.

The effects of climate change are already visible worldwide, from rising sea levels to extreme weather events.

Governments, businesses, and individuals must work together to reduce greenhouse gas emissions and transition to sustainable energy sources.

Innovative technologies such as renewable energy, electric vehicles, and carbon capture are playing crucial roles in addressing this challenge.

Education and awareness are also essential components of the solution, as they help people understand the importance of environmental protection.
""",
                year: 2022,
                examType: "考研一",
                difficulty: .hard,
                topic: "环境保护"
            ),
            ArticleData(
                title: "The Future of Education in the Digital Age",
                content: """
Digital technology is fundamentally changing how we approach education and learning.

Online learning platforms have made education more accessible to people around the world, breaking down geographical and economic barriers.

Virtual reality and augmented reality technologies are creating immersive learning experiences that were previously impossible.

However, the digital divide remains a significant challenge, as not all students have equal access to technology and internet connectivity.

Teachers must adapt their methods to effectively integrate technology while maintaining the human element that is essential to quality education.
""",
                year: 2023,
                examType: "考研二",
                difficulty: .easy,
                topic: "教育发展"
            )
        ]
        
        for articleData in sampleArticles {
            let imageName = "image_\(Int.random(in: 1...10))"
                    let article = Article(
                        title: articleData.title,
                        content: articleData.content,
                        year: articleData.year,
                        examType: articleData.examType,
                        difficulty: articleData.difficulty,
                        topic: articleData.topic,
                        imageName: imageName
                    )
            addArticle(article)
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

// 文章统计信息
struct ArticleStats {
    let totalArticles: Int
    let completedArticles: Int
    let inProgressArticles: Int
    let unreadArticles: Int
    let totalReadingTime: TimeInterval
    let averageProgress: Double
    let yearStats: [Int: (total: Int, completed: Int)]
    let difficultyStats: [ArticleDifficulty: (total: Int, completed: Int)]
    let topicStats: [String: (total: Int, completed: Int)]
    
    var completionRate: Double {
        guard totalArticles > 0 else { return 0 }
        return Double(completedArticles) / Double(totalArticles)
    }
    
    var averageReadingTimePerArticle: TimeInterval {
        guard completedArticles > 0 else { return 0 }
        return totalReadingTime / Double(completedArticles)
    }
}

// 文章数据结构（用于JSON导入）
struct ArticleData: Codable {
    let title: String
    let content: String
    let year: Int
    let examType: String
    let difficulty: ArticleDifficulty
    let topic: String
}

// MARK: - 扩展

extension ArticleService {
    // 设置模型上下文
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // 获取所有可用年份
    func getAvailableYears() -> [Int] {
        let articles = getAllArticles()
        let years = Set(articles.map { $0.year })
        return Array(years).sorted(by: >)
    }
    
    // 获取所有可用主题
    func getAvailableTopics() -> [String] {
        let articles = getAllArticles()
        let topics = Set(articles.map { $0.topic })
        return Array(topics).sorted()
    }
    
    // 获取所有可用考试类型
    func getAvailableExamTypes() -> [String] {
        let articles = getAllArticles()
        let examTypes = Set(articles.map { $0.examType })
        return Array(examTypes).sorted()
    }
}