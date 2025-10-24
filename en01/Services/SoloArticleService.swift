//
//  SoloArticleService.swift
//  en01
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
import SwiftData

/// Solo文章服务，处理solo文件夹中的.md文件
class SoloArticleService: BaseService {
    
    // MARK: - Properties
    
    private let soloDirectoryPath: String
    private var intelligentRankingService: IntelligentRankingService?
    
    // 匹配度缓存
    private var matchResultsCache: [ArticleMatchResult]?
    private var matchCacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟
    
    // 缓存键
    private enum CacheKeys {
        static let allSoloArticles = "solo_articles_all"
        static let soloArticlesByYear = "solo_articles_year_"
        static let soloArticlesByExamType = "solo_articles_exam_"
        static let soloArticleStats = "solo_article_stats"
    }
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        cacheManager: CacheManagerProtocol,
        errorHandler: ErrorHandlerProtocol,
        soloDirectoryPath: String? = nil
    ) {
        // 使用更可靠的路径获取方式
        if let customPath = soloDirectoryPath {
            self.soloDirectoryPath = customPath
        } else {
            // 尝试多种方式获取 solo 文件夹路径
            if let bundlePath = Bundle.main.path(forResource: "solo", ofType: nil) {
                self.soloDirectoryPath = bundlePath
            } else if let resourcePath = Bundle.main.resourcePath {
                self.soloDirectoryPath = (resourcePath as NSString).appendingPathComponent("solo")
            } else {
                // 最后的备用方案
                self.soloDirectoryPath = ""
            }
        }
        
        super.init(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler,
            subsystem: "com.en01.services",
            category: "SoloArticleService"
        )
        
        // 延迟初始化 intelligentRankingService
        Task { @MainActor in
            self.intelligentRankingService = IntelligentRankingService()
        }
        
        // 输出调试信息
        logger.info("SoloArticleService 初始化完成，solo路径: \(self.soloDirectoryPath)")
    }
    
    // MARK: - Public Methods
    
    /// 获取所有solo文章
    func getAllSoloArticles() -> [Article] {
        return getCachedOrFetchModel(
            key: CacheKeys.allSoloArticles,
            expiration: 600,
            operation: "获取所有solo文章"
        ) {
            return loadSoloArticlesFromDirectory()
        } ?? []
    }
    
    /// 根据年份获取solo文章
    func getSoloArticlesByYear(_ year: Int) -> [Article] {
        let cacheKey = CacheKeys.soloArticlesByYear + String(year)
        return getCachedOrFetchModel(
            key: cacheKey,
            expiration: 600,
            operation: "获取\(year)年solo文章"
        ) {
            return loadSoloArticlesFromDirectory().filter { $0.year == year }
        } ?? []
    }
    
    /// 根据考试类型获取solo文章
    func getSoloArticlesByExamType(_ examType: String) -> [Article] {
        let cacheKey = CacheKeys.soloArticlesByExamType + examType
        return getCachedOrFetchModel(
            key: cacheKey,
            expiration: 600,
            operation: "获取\(examType)类型solo文章"
        ) {
            return loadSoloArticlesFromDirectory().filter { $0.examType == examType }
        } ?? []
    }
    
    /// 搜索solo文章
    func searchSoloArticles(_ query: String) -> [Article] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let allArticles = getAllSoloArticles()
        let searchQuery = query.lowercased()
        
        return allArticles.filter { article in
            article.title.localizedStandardContains(searchQuery) ||
            article.content.localizedStandardContains(searchQuery) ||
            article.topic.localizedStandardContains(searchQuery)
        }
    }
    
    /// 获取solo文章统计信息
    func getSoloArticleStats() -> ArticleStats {
        let allArticles = getAllSoloArticles()
        
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
    
    /// 获取可用年份
    func getAvailableYears() -> [Int] {
        let articles = getAllSoloArticles()
        let years = Set(articles.map { $0.year })
        return Array(years).sorted(by: >)
    }
    
    /// 获取可用考试类型
    func getAvailableExamTypes() -> [String] {
        let articles = getAllSoloArticles()
        let examTypes = Set(articles.map { $0.examType })
        return Array(examTypes).sorted()
    }
    
    // MARK: - 智能排序功能
    
    /// 获取带匹配度计算的solo文章列表
    func getRankedSoloArticles(userVocabulary: [UserWord]) async -> [ArticleMatchResult] {
        // 检查匹配结果缓存
        if let cachedResults = matchResultsCache,
           let cacheTime = matchCacheTimestamp,
           Date().timeIntervalSince(cacheTime) < cacheValidityDuration {
            print("✅ 使用缓存的solo文章匹配结果")
            return cachedResults
        }
        
        // 获取solo文章
        let articles = getAllSoloArticles()
        
        // 确保intelligentRankingService已初始化
        if intelligentRankingService == nil {
            await MainActor.run {
                intelligentRankingService = IntelligentRankingService()
            }
        }
        
        // 使用智能排序服务计算匹配度
        let matchResults = await intelligentRankingService!.rankArticles(articles, userVocabulary: userVocabulary)
        
        // 缓存结果
        matchResultsCache = matchResults
        matchCacheTimestamp = Date()
        
        print("✅ 成功计算solo文章匹配度，共\(matchResults.count)篇文章")
        return matchResults
    }
    
    /// 根据排序选项对solo文章进行排序
    @MainActor
    func sortSoloArticles(_ results: [ArticleMatchResult], by option: RankingSortOption) -> [ArticleMatchResult] {
        // 确保intelligentRankingService已初始化
        if intelligentRankingService == nil {
            intelligentRankingService = IntelligentRankingService()
        }
        return intelligentRankingService!.sortResults(results, by: option)
    }
    
    /// 获取solo文章的统计信息
    func getSoloArticleStatistics(matchResults: [ArticleMatchResult]) -> (totalArticles: Int, averageMatchScore: Double, difficultyDistribution: [IntelligentRankingDifficultyLevel: Int]) {
        let totalArticles = matchResults.count
        let averageMatchScore = matchResults.isEmpty ? 0 : matchResults.map { $0.matchScore }.reduce(0, +) / Double(totalArticles)
        
        var difficultyDistribution: [IntelligentRankingDifficultyLevel: Int] = [:]
        for result in matchResults {
            difficultyDistribution[result.difficulty, default: 0] += 1
        }
        
        return (totalArticles, averageMatchScore, difficultyDistribution)
    }
    
    /// 清除匹配度缓存
    @MainActor
    func clearMatchCache() {
        matchResultsCache = nil
        matchCacheTimestamp = nil
        // 确保intelligentRankingService已初始化
        if intelligentRankingService == nil {
            intelligentRankingService = IntelligentRankingService()
        }
        intelligentRankingService!.clearCache()
        print("✅ Solo文章匹配度缓存已清除")
    }
    
    // MARK: - Private Methods
    
    /// 从solo目录加载所有.md文件
    private func loadSoloArticlesFromDirectory() -> [Article] {
        return performSafeOperation("加载solo文章") {
            var articles: [Article] = []
            let fileManager = FileManager.default
    
            // 首先尝试使用明确的目录路径
            if fileManager.fileExists(atPath: soloDirectoryPath) {
                let enumerator = fileManager.enumerator(atPath: soloDirectoryPath)
                while let fileName = enumerator?.nextObject() as? String {
                    if fileName.hasSuffix(".md") && isValidArticleFile(fileName) {
                        let filePath = (soloDirectoryPath as NSString).appendingPathComponent(fileName)
                        if let article = loadArticleFromMarkdownFile(filePath: filePath, relativePath: fileName) {
                            articles.append(article)
                        }
                    }
                }
                logger.info("成功加载 \(articles.count) 篇solo文章")
                return articles
            }
    
            // 目录路径不可用，进行 Bundle 级别的回退扫描
            logger.warning("Solo目录不存在或不可用: \(soloDirectoryPath)，尝试从 Bundle 中回退扫描 .md 文件")
            guard let bundleURL = Bundle.main.bundleURL as URL? else {
                return []
            }
    
            // 优先扫描 bundle 中的 solo 子目录
            let soloSubdirURL = bundleURL.appendingPathComponent("solo", isDirectory: true)
            var mdFileURLs: [URL] = []
            if FileManager.default.fileExists(atPath: soloSubdirURL.path) {
                if let enumerator = FileManager.default.enumerator(at: soloSubdirURL, includingPropertiesForKeys: nil) {
                    for case let url as URL in enumerator {
                        if url.pathExtension.lowercased() == "md" {
                            mdFileURLs.append(url)
                        }
                    }
                }
            } else {
                // 再次回退：扫描整个 bundle
                if let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: nil) {
                    for case let url as URL in enumerator {
                        if url.pathExtension.lowercased() == "md" {
                            mdFileURLs.append(url)
                        }
                    }
                }
            }
    
            for url in mdFileURLs {
                // 过滤掉非标准格式的文件
                if !isValidArticleFile(url.lastPathComponent) {
                    continue
                }
                
                let relativePath: String
                if url.path.contains("/solo/") {
                    // 相对 solo 目录的路径
                    let components = url.path.components(separatedBy: "/solo/")
                    relativePath = components.count > 1 ? components[1] : url.lastPathComponent
                } else {
                    relativePath = url.lastPathComponent
                }
                if let article = loadArticleFromMarkdownFile(filePath: url.path, relativePath: relativePath) {
                    articles.append(article)
                }
            }
    
            logger.info("回退扫描完成，成功加载 \(articles.count) 篇solo文章")
            return articles
        } ?? []
    }
    
    /// 从单个.md文件加载文章
    private func loadArticleFromMarkdownFile(filePath: String, relativePath: String) -> Article? {
        return performSafeOperation("加载markdown文件: \(relativePath)") {
            // 读取文件内容
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
    
            // 尝试从路径解析信息：考试类别/年份/文件名
            let pathComponents = relativePath.components(separatedBy: "/")
            var examCategory: String? = nil
            var year: Int? = nil
            var fileName = (relativePath as NSString).lastPathComponent
    
            if pathComponents.count >= 3 {
                examCategory = pathComponents.first
                let yearString = pathComponents[1]
                year = Int(yearString)
                fileName = pathComponents[2]
            }
    
            let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
    
            // 如果无法从路径拿到年份或考试类别，尝试从文件名模式推断（EN1/EN2 + 年份）
            if year == nil || examCategory == nil {
                let components = fileNameWithoutExtension.components(separatedBy: "_")
                if components.count >= 2 {
                    let prefix = components[0]
                    let yearCandidate = components[1]
                    if let parsedYear = Int(yearCandidate) {
                        year = parsedYear
                    }
                    if prefix.uppercased() == "EN1" {
                        examCategory = "考研英语一"
                    } else if prefix.uppercased() == "EN2" {
                        examCategory = "考研英语二"
                    }
                }
            }
    
            guard let finalYear = year else {
                throw ServiceError.validationError("无法解析年份: \(relativePath)")
            }
            let finalExamCategory = examCategory ?? "通用"
    
            // 解析文件名获取详细信息
            let (title, examType, difficulty, topic) = parseFileName(fileNameWithoutExtension, examCategory: finalExamCategory, year: finalYear)
    
            // 创建Article对象
            let article = Article(
                title: title,
                content: content,
                year: finalYear,
                examType: examType,
                difficulty: difficulty,
                topic: topic,
                imageName: "article_\(Int.random(in: 1...10))"
            )
            return article
        } ?? nil
    }
    
    /// 解析文件名获取文章信息
    private func parseFileName(_ fileName: String, examCategory: String, year: Int) -> (title: String, examType: String, difficulty: ArticleDifficulty, topic: String) {
        // 文件名格式示例: EN1_2015_Section_II_Reading Comprehension_Part A_Text_1
        let components = fileName.components(separatedBy: "_")
        
        var title = fileName
        var examType = examCategory
        var difficulty: ArticleDifficulty = .medium
        var topic = "阅读理解"
        
        if components.count >= 3 {
            // 提取考试类型前缀 (EN1, EN2)
            let examPrefix = components[0]
            if examPrefix == "EN1" {
                examType = "考研英语一"
            } else if examPrefix == "EN2" {
                examType = "考研英语二"
            }
            
            // 生成更友好的标题
            if components.count >= 4 {
                let section = components[2] // Section
                let part = components[3] // II, III, IV等
                
                if components.count >= 5 {
                    let contentType = components[4] // Reading Comprehension, Translation等
                    
                    // 根据内容类型设置主题和难度
                    switch contentType {
                    case "Reading Comprehension", "Reading":
                        topic = "阅读理解"
                        difficulty = .medium
                    case "Translation":
                        topic = "翻译"
                        difficulty = .hard
                    case "Writing":
                        topic = "写作"
                        difficulty = .medium
                    case "Use of English":
                        topic = "英语知识运用"
                        difficulty = .hard
                    default:
                        topic = contentType.replacingOccurrences(of: " ", with: "")
                    }
                    
                    // 构建标题
                    if components.count >= 6 {
                        let subPart = components[5] // Part A, Part B等
                        if components.count >= 7 {
                            let textNumber = components[6] // Text_1, Text_2等
                            title = "\(year)年\(examType) \(topic) \(subPart) \(textNumber.replacingOccurrences(of: "_", with: " "))"
                        } else {
                            title = "\(year)年\(examType) \(topic) \(subPart)"
                        }
                    } else {
                        title = "\(year)年\(examType) \(topic)"
                    }
                } else {
                    title = "\(year)年\(examType) \(section) \(part)"
                }
            }
        }
        
        return (title: title, examType: examType, difficulty: difficulty, topic: topic)
    }
    
    /// 清除缓存
    private func invalidateSoloArticleCaches() {
        cacheManager.remove(CacheKeys.allSoloArticles)
        cacheManager.removeByPrefix(CacheKeys.soloArticlesByYear)
        cacheManager.removeByPrefix(CacheKeys.soloArticlesByExamType)
        cacheManager.remove(CacheKeys.soloArticleStats)
    }
    
    /// 验证文件是否为有效的文章文件
    private func isValidArticleFile(_ fileName: String) -> Bool {
        // 排除非标准格式的文件
        let excludedFiles = [
            "GEMINI_API_GUIDE.md",
            "README.md",
            "CHANGELOG.md",
            "LICENSE.md",
            "CONTRIBUTING.md"
        ]
        
        // 检查是否在排除列表中
        if excludedFiles.contains(fileName) {
            return false
        }
        
        // 检查文件名是否包含年份信息（4位数字）
        let yearPattern = "\\d{4}"
        let yearRegex = try? NSRegularExpression(pattern: yearPattern)
        let range = NSRange(location: 0, length: fileName.count)
        
        // 如果文件名包含年份或者符合EN1/EN2格式，则认为是有效文章
        if yearRegex?.firstMatch(in: fileName, options: [], range: range) != nil {
            return true
        }
        
        // 检查是否符合EN1/EN2格式
        if fileName.uppercased().hasPrefix("EN1") || fileName.uppercased().hasPrefix("EN2") {
            return true
        }
        
        // 其他情况暂时认为无效
        return false
    }
}