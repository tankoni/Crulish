//
//  ArticleService.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData
import PDFKit

/// 文章服务实现
class ArticleService: BaseService, ArticleServiceProtocol {
    private let pdfService: PDFServiceProtocol
    
    // 缓存键
    private enum CacheKeys {
        static let allArticles = "articles_all"
        static let articlesByYear = "articles_year_"
        static let articlesByDifficulty = "articles_difficulty_"
        static let articlesByExamType = "articles_exam_"
        static let recentArticles = "articles_recent"
        static let recommendedArticles = "articles_recommended"
        static let articleStats = "article_stats"
        static let availableYears = "available_years"
        static let availableTopics = "available_topics"
        static let availableExamTypes = "available_exam_types"
    }
    
    init(
        modelContext: ModelContext,
        cacheManager: CacheManagerProtocol,
        errorHandler: ErrorHandlerProtocol,
        pdfService: PDFServiceProtocol
    ) {
        self.pdfService = pdfService
        super.init(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler,
            subsystem: "com.en01.services",
            category: "ArticleService"
        )
    }
    
    // MARK: - 文章管理
    
    // MARK: - 文章获取
    
    func getAllArticles() -> [Article] {
        return getCachedOrFetchModel(
            key: CacheKeys.allArticles,
            expiration: 300,
            operation: "获取所有文章"
        ) {
            let descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\Article.year, order: .reverse)])
            return safeFetch(descriptor, operation: "获取所有文章")
        } ?? []
    }
    
    func getArticlesByYear(_ year: Int) -> [Article] {
        let cacheKey = CacheKeys.articlesByYear + "\(year)"
        return getCachedOrFetchModel(
            key: cacheKey,
            expiration: 600,
            operation: "获取\(year)年文章"
        ) {
            let predicate = #Predicate<Article> { article in
                article.year == year
            }
            let descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: [SortDescriptor(\Article.title)])
            return safeFetch(descriptor, operation: "获取\(year)年文章")
        } ?? []
    }
    
    func getArticlesByDifficulty(_ difficulty: ArticleDifficulty) -> [Article] {
        let cacheKey = CacheKeys.articlesByDifficulty + difficulty.rawValue
        return getCachedOrFetchModel(
            key: cacheKey,
            expiration: 600,
            operation: "获取\(difficulty.rawValue)难度文章"
        ) {
            let predicate = #Predicate<Article> { article in
                article.difficulty == difficulty
            }
            let descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: [SortDescriptor(\Article.title)])
            return safeFetch(descriptor, operation: "获取\(difficulty.rawValue)难度文章")
        } ?? []
    }
    
    // 根据主题获取文章
    func getArticlesByTopic(_ topic: String) -> [Article] {
        let cacheKey = "articles_topic_" + topic
        return getCachedOrFetchModel(
            key: cacheKey,
            expiration: 600,
            operation: "获取主题\(topic)文章"
        ) {
            let predicate = #Predicate<Article> { article in
                article.topic == topic
            }
            let descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: [SortDescriptor(\Article.title)])
            return safeFetch(descriptor, operation: "获取主题\(topic)文章")
        } ?? []
    }
    
    // 获取未完成的文章
    func getUnfinishedArticles() -> [Article] {
        return getCachedOrFetchModel(
            key: "articles_unfinished",
            expiration: 300,
            operation: "获取未完成文章"
        ) {
            let predicate = #Predicate<Article> { article in
                !article.isCompleted
            }
            let descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: [SortDescriptor(\Article.lastReadDate, order: .reverse)])
            return safeFetch(descriptor, operation: "获取未完成文章")
        } ?? []
    }
    
    // 获取最近阅读的文章
    func getRecentlyReadArticles(limit: Int = 10) -> [Article] {
        let cacheKey = "articles_recently_read_\(limit)"
        return getCachedOrFetchModel(
            key: cacheKey,
            expiration: 300,
            operation: "获取最近阅读文章"
        ) {
            let predicate = #Predicate<Article> { article in
                article.lastReadDate != nil
            }
            var descriptor = FetchDescriptor<Article>(
                predicate: predicate,
                sortBy: [SortDescriptor(\Article.lastReadDate, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            return safeFetch(descriptor, operation: "获取最近阅读文章")
        } ?? []
    }
    
    func searchArticles(_ query: String) -> [Article] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let cacheKey = "search_results_" + query.lowercased()
        return getCachedOrFetchModel(
            key: cacheKey,
            expiration: 300,
            operation: "搜索文章: \(query)"
        ) {
            let searchQuery = query.lowercased()
            let descriptor = FetchDescriptor<Article>(
                predicate: #Predicate { article in
                    article.title.localizedStandardContains(searchQuery) ||
                    article.content.localizedStandardContains(searchQuery) ||
                    article.topic.localizedStandardContains(searchQuery)
                },
                sortBy: [SortDescriptor(\.title)]
            )
            return safeFetch(descriptor, operation: "搜索文章: \(query)")
        } ?? []
    }
    
    // MARK: - 文章操作
    
    // 添加文章
    func addArticle(_ article: Article) {
        performSafeOperation("添加文章") {
            modelContext.insert(article)
            safeSave(operation: "保存新文章")
        }
        invalidateArticleCaches()
    }
    
    func updateArticleProgress(_ article: Article, progress: Double) {
        performSafeOperation("更新文章进度") {
            let clampedProgress = max(0.0, min(1.0, progress))
            article.readingProgress = clampedProgress
            article.lastReadDate = Date()
            
            if clampedProgress >= 1.0 {
                article.isCompleted = true
                article.completedDate = Date()
                article.readingProgress = 1.0
            }
            
            safeSave(operation: "更新文章")
            invalidateArticleCaches()
        }
    }
    
    func addReadingTime(to article: Article, time: Double) {
        performSafeOperation("添加阅读时间") {
            article.readingTime += time
            article.lastReadDate = Date()
            try modelContext.save()
            invalidateArticleCaches()
        }
    }
    
    func markArticleAsCompleted(_ article: Article) {
        performSafeOperation("标记文章完成") {
            article.isCompleted = true
            article.completedDate = Date()
            article.readingProgress = 1.0
            try modelContext.save()
            invalidateArticleCaches()
        }
    }
    
    func updateArticle(_ article: Article) {
        performSafeOperation("更新文章") {
            try modelContext.save()
            invalidateArticleCaches()
        }
    }
    
    // 删除文章
    func deleteArticle(_ article: Article) {
        performSafeOperation("删除文章") {
            modelContext.delete(article)
            safeSave(operation: "删除文章")
        }
        invalidateArticleCaches()
    }
    
    /// 清除所有文章数据（用于重新导入）
    func clearAllArticles() {
        performSafeOperation("清除所有文章") {
            let descriptor = FetchDescriptor<Article>()
            let allArticles = safeFetch(descriptor, operation: "获取所有文章") ?? []
            
            for article in allArticles {
                modelContext.delete(article)
            }
            
            safeSave(operation: "清除所有文章")
            print("[INFO] 已清除 \(allArticles.count) 篇文章")
        }
        invalidateArticleCaches()
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
    
    func getArticlesByExamType(_ examType: String) -> [Article] {
        let cacheKey = CacheKeys.articlesByExamType + examType
        return getCachedOrFetchModel(
            key: cacheKey,
            expiration: 600,
            operation: "获取\(examType)考试类型文章"
        ) {
            let predicate = #Predicate<Article> { article in
                article.examType == examType
            }
            let descriptor = FetchDescriptor<Article>(predicate: predicate, sortBy: [SortDescriptor(\Article.title)])
            return safeFetch(descriptor, operation: "获取\(examType)考试类型文章")
        } ?? []
    }
    
    func getRecentArticles(limit: Int = 10) -> [Article] {
        let cacheKey = CacheKeys.recentArticles + "_\(limit)"
        return getCachedOrFetchModel(
            key: cacheKey,
            expiration: 180,
            operation: "获取最近文章"
        ) {
            // 简化查询以避免SwiftData崩溃
            let descriptor = FetchDescriptor<Article>(
                sortBy: [SortDescriptor(\Article.createdDate, order: .reverse)]
            )
            let allArticles = safeFetch(descriptor, operation: "获取最近文章")
            
            // 在内存中过滤有阅读记录的文章并限制数量
            let recentArticles = allArticles.filter { $0.lastReadDate != nil }
                .sorted { ($0.lastReadDate ?? Date.distantPast) > ($1.lastReadDate ?? Date.distantPast) }
            return Array(recentArticles.prefix(limit))
        } ?? []
    }
    
    // 获取推荐文章
    func getRecommendedArticles(limit: Int = 5) -> [Article] {
        let cacheKey = CacheKeys.recommendedArticles + "_\(limit)"
        return getCachedOrFetchModel(
            key: cacheKey,
            expiration: 300,
            operation: "获取推荐文章"
        ) {
            // 简化查询以避免SwiftData崩溃
            let descriptor = FetchDescriptor<Article>(
                sortBy: [
                    SortDescriptor(\Article.readingProgress, order: .reverse),
                    SortDescriptor(\Article.createdDate, order: .reverse)
                ]
            )
            let allArticles = safeFetch(descriptor, operation: "获取推荐文章")
            
            // 在内存中过滤未完成的文章并限制数量
            let incompleteArticles = allArticles.filter { !$0.isCompleted }
            return Array(incompleteArticles.prefix(limit))
        } ?? []
    }
    
    // MARK: - 数据导入

    // MARK: - Protocol Required Methods
    
    func importArticlesFromJSON() async throws {
        // Implementation for protocol conformance
        importArticlesFromJSON(fileName: "articles")
    }
    
    func getReadingStatistics() async throws -> ReadingStatistics {
        // Implementation for protocol conformance
        let stats = getArticleStats()
        return ReadingStatistics(
            completedArticles: Int(stats.completedArticles),
            inProgressArticles: Int(stats.inProgressArticles),
            bookmarkedArticles: 0,
            averageReadingTime: TimeInterval(stats.averageReadingTimePerArticle),
            favoriteTopics: Array(stats.topicStats.keys.prefix(5)),
            difficultyDistribution: Dictionary(uniqueKeysWithValues: stats.difficultyStats.map { (key, value) in (key.rawValue, Int(value.total)) }),
            yearDistribution: Dictionary(uniqueKeysWithValues: stats.yearStats.map { (key, value) in (String(key), Int(value.total)) })
        )
    }

    /// 从PDF文件异步导入文章
    func importArticlesFromPDFs() {
        performSafeOperation("导入PDF文章") {
            // 获取项目的Resources文件夹路径
            let fileManager = FileManager.default
            
            // 尝试多个可能的Resources路径
            var resourcesPaths: [String] = []
            
            // 1. Bundle中的Resources文件夹
            if let bundlePath = Bundle.main.resourcePath {
                resourcesPaths.append("\(bundlePath)")
            }
            
            // 2. 当前工作目录下的Resources文件夹
            let currentDir = fileManager.currentDirectoryPath
            resourcesPaths.append("\(currentDir)/Resources")
            
            // 3. 用户文档目录下的en01/Resources
            if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                resourcesPaths.append("\(documentsPath.path)/en01/Resources")
            }
            
            // 4. iCloud Drive中的en01/Resources
            if let iCloudPath = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/xcode/Crulish/en01/Resources") {
                resourcesPaths.append(iCloudPath.path)
            }
            
            // 5. 直接指定的路径（基于用户提供的信息）
            resourcesPaths.append("/Users/tankonitk/Library/Mobile Documents/com~apple~CloudDocs/xcode/Crulish/en01/Resources")
            
            var foundResourcesPath: String?
            
            // 查找存在的Resources文件夹
            for path in resourcesPaths {
                if fileManager.fileExists(atPath: path) {
                    foundResourcesPath = path
                    print("[INFO] 找到Resources文件夹: \(path)")
                    break
                }
            }
            
            guard let resourcesPath = foundResourcesPath else {
                print("[ERROR] 找不到Resources文件夹，尝试的路径:")
                for path in resourcesPaths {
                    print("  - \(path)")
                }
                return
            }
        
            // 读取Resources文件夹中的PDF文件
            do {
                let resourcesURL = URL(fileURLWithPath: resourcesPath)
                let fileURLs = try fileManager.contentsOfDirectory(at: resourcesURL, includingPropertiesForKeys: nil)
                let pdfURLs = fileURLs.filter { $0.pathExtension == "pdf" }
                
                print("[INFO] 在Resources文件夹中找到\(pdfURLs.count)个PDF文件")
                
                var importedCount = 0
                var skippedCount = 0
                var failedCount = 0
                
                for url in pdfURLs {
                    print("[INFO] 正在处理PDF文件: \(url.lastPathComponent)")
                    
                    if let article = pdfService.convertPDFToArticle(from: url) {
                        // 检查是否已存在相同标题的文章
                        let existingArticles = self.getAllArticles()
                        if !existingArticles.contains(where: { $0.title == article.title }) {
                            addArticle(article)
                            importedCount += 1
                            print("[SUCCESS] 成功导入PDF文章: \(article.title)")
                        } else {
                            skippedCount += 1
                            print("[INFO] PDF文章已存在，跳过: \(article.title)")
                        }
                    } else {
                        failedCount += 1
                        print("[ERROR] 无法转换PDF文件: \(url.lastPathComponent)")
                    }
                }
                
                print("[SUMMARY] PDF导入完成 - 成功: \(importedCount), 跳过: \(skippedCount), 失败: \(failedCount)")
                
                // 清除缓存以确保新数据生效
                invalidateArticleCaches()
                
            } catch {
                print("[ERROR] 无法读取Resources目录: \(error)")
            }
        }
    }

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
            // 检查是否已存在相同标题的文章
            let existingArticles = self.getAllArticles()
            if !existingArticles.contains(where: { $0.title == articleData.title }) {
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
    }
    
    // MARK: - 私有方法
    
    private func saveContext() {
        safeSave(operation: "保存文章上下文")
    }
    
    private func invalidateArticleCaches() {
        cacheManager.remove(CacheKeys.allArticles)
        cacheManager.removeByPrefix(CacheKeys.articlesByYear)
        cacheManager.removeByPrefix(CacheKeys.articlesByDifficulty)
        cacheManager.removeByPrefix(CacheKeys.articlesByExamType)
        cacheManager.remove(CacheKeys.recentArticles)
        cacheManager.remove(CacheKeys.recommendedArticles)
        cacheManager.remove(CacheKeys.articleStats)
        cacheManager.removeByPrefix("articles_topic_")
        cacheManager.remove("articles_unfinished")
        cacheManager.removeByPrefix("articles_recently_read_")
        cacheManager.removeByPrefix("search_results_")
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