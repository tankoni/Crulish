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
            let allArticles = safeFetch(descriptor, operation: "获取所有文章")
            
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
    
    func importArticlesFromPDFs() {
        // 清除现有文章以避免重复
        clearAllArticles()
        
        // 导入PDF文章
        importPDFsFromDirectory()
        
        // PDF导入成功后不再加载预置文章内容
        // 注释掉示例数据初始化，确保只显示PDF导入的内容
        /*
        let articles = getAllArticles()
        if articles.isEmpty {
            initializeSampleData()
        }
        */
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
    private func importPDFsFromDirectory() {
        Task {
            // 直接使用Bundle内的Resources目录
            guard let resourcePath = Bundle.main.resourcePath else {
                print("[ERROR] 无法获取Bundle资源路径")
                return
            }
            
            let pdfDirectory = URL(fileURLWithPath: resourcePath)
            
            logger.info("[PDF导入] 开始扫描目录: \(pdfDirectory.path)")
            
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: pdfDirectory.path) {
                var allPDFURLs: [URL] = []
                
                // 递归扫描Resources目录及其所有子目录
                func scanDirectory(_ directory: URL) throws {
                    let fileURLs = try fileManager.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )
                    
                    for fileURL in fileURLs {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                        
                        if resourceValues.isDirectory == true {
                            // 如果是目录，递归扫描
                            try scanDirectory(fileURL)
                        } else if fileURL.pathExtension.lowercased() == "pdf" {
                            // 如果是PDF文件，添加到列表
                            allPDFURLs.append(fileURL)
                        }
                    }
                }
                
                do {
                    try scanDirectory(pdfDirectory)
                    print("[INFO] 扫描到 \(allPDFURLs.count) 个PDF文件")
                    
                    var importedCount = 0
                    var skippedCount = 0
                    var failedCount = 0
                    
                    for pdfURL in allPDFURLs {
                        if let article = pdfService.convertPDFToArticle(from: pdfURL) {
                            // 检查是否已存在相同标题的文章
                            let existingArticles = self.getAllArticles()
                            if !existingArticles.contains(where: { $0.title == article.title }) {
                                await MainActor.run {
                                    self.addArticle(article)
                                }
                                importedCount += 1
                                print("[SUCCESS] 导入PDF文章: \(article.title)")
                            } else {
                                skippedCount += 1
                                print("[INFO] 跳过已存在的PDF文章: \(article.title)")
                            }
                        } else {
                            failedCount += 1
                            print("[ERROR] 无法转换PDF文件: \(pdfURL.lastPathComponent)")
                        }
                    }
                    
                    print("[SUMMARY] PDF导入完成 - 成功: \(importedCount), 跳过: \(skippedCount), 失败: \(failedCount)")
                    
                    // 清除缓存以确保新数据生效
                    invalidateArticleCaches()
                    
                    // 添加控制台信息提示
                    let totalFiles = allPDFURLs.count
                    let finalImportedCount = importedCount
                    let finalSkippedCount = skippedCount
                    let finalFailedCount = failedCount
                    
                    await MainActor.run {
                        print("[INFO] PDF文章重新导入完成，共处理 \(totalFiles) 个文件")
                        print("[INFO] 导入结果：成功 \(finalImportedCount) 个，跳过 \(finalSkippedCount) 个，失败 \(finalFailedCount) 个")
                    }
                } catch {
                    print("[ERROR] 扫描PDF目录失败: \(error.localizedDescription)")
                    await MainActor.run {
                        print("[ERROR] PDF文章重新导入失败: \(error.localizedDescription)")
                    }
                }
            } else {
                print("[ERROR] 无法访问PDF资源目录: \(pdfDirectory.path)")
                await MainActor.run {
                    print("[ERROR] 无法访问PDF资源目录，重新导入失败")
                }
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
        // 不再加载预置示例数据，只使用PDF导入的内容
        print("[INFO] 跳过示例数据初始化，仅使用PDF导入的内容")
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