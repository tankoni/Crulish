import Foundation
import PDFKit
import SwiftData
import OSLog

class PDFService: BaseService, PDFServiceProtocol {
    
    init(
        modelContext: ModelContext,
        cacheManager: CacheManagerProtocol,
        errorHandler: ErrorHandlerProtocol
    ) {
        super.init(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler,
            subsystem: "com.en01.services",
            category: "PDFService"
        )
    }
    // 从 PDF 文件中提取文本内容
    func extractText(from url: URL) -> String? {
        return performSafeOperation("提取PDF文本") {
            guard let pdfDocument = PDFDocument(url: url) else {
                throw ServiceError.notFound("无法加载 PDF 文件")
            }
            
            guard let text = pdfDocument.string else {
                throw ServiceError.validationError("PDF文件中没有可提取的文本内容")
            }
            
            return text
        }
    }
    
    // 将 PDF 文件转换为 Article 对象
    func convertPDFToArticle(from url: URL) -> Article? {
        return performSafeOperation("转换PDF为文章") {
            guard let content = extractText(from: url) else {
                throw ServiceError.validationError("无法提取PDF文本内容")
            }
            
            // 从文件名中提取标题、年份、考试类型等信息
            let fileName = url.deletingPathExtension().lastPathComponent
            let components = fileName.components(separatedBy: "-")
            
            logger.debug("解析PDF文件名: \(fileName), 组件: \(components)")
            
            guard components.count >= 3 else {
                throw ServiceError.validationError("PDF 文件名格式不正确: \(fileName)，期望格式：年份范围-考试类型-描述")
            }
            
            // 解析年份范围（如\"10到22\"表示2010-2022年）
            let yearRange = components[0]
            let year = parseYearFromRange(yearRange)
            
            // 解析考试类型
            let examType = ExamType.from(string: parseExamType(components[1]))
            
            // 生成标题
            let title = generateTitle(yearRange: yearRange, examType: examType.rawValue, description: components.dropFirst(2).joined(separator: "-"))
            
            // 根据文件名或内容分析难度和主题
            let difficulty = analyzeDifficulty(from: content)
            let topic = analyzeTopic(from: content, examType: examType.rawValue)
            
            logger.info("创建文章: 标题=\(title), 年份=\(year), 考试类型=\(examType)")
            
            return Article(
                title: title,
                content: content,
                year: year,
                examType: examType.rawValue,
                difficulty: difficulty,
                topic: topic,
                imageName: ""  // PDF文章暂时不设置图片
            )
        }
    }
    
    /// 批量转换PDF文件为文章
    func convertPDFsToArticles(from urls: [URL]) -> [Article] {
        return performSafeOperation("批量转换PDF文件") {
            var articles: [Article] = []
            
            for url in urls {
                if let article = convertPDFToArticle(from: url) {
                    articles.append(article)
                }
            }
            
            logger.info("批量转换完成，成功转换 \(articles.count)/\(urls.count) 个PDF文件")
            return articles
        } ?? []
    }
    
    /// 解析PDF元数据信息
    func parsePDFMetadata(from url: URL) -> PDFMetadata? {
        return performSafeOperation("解析PDF元数据") {
            guard let pdfDocument = PDFDocument(url: url) else {
                throw ServiceError.processingFailed("无法打开PDF文档")
            }
            
            let fileName = url.lastPathComponent
            let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            
            // 解析年份和考试类型
            let components = fileName.components(separatedBy: "-")
            let yearRange = components.first ?? ""
            let examTypeRaw = components.count > 1 ? components[1] : ""
            
            let year = parseYearFromRange(yearRange)
            let examType = parseExamType(examTypeRaw)
            
            // 生成标题
            let title = generateTitle(yearRange: yearRange, examType: ExamType.from(string: examType).rawValue, description: components.dropFirst(2).joined(separator: "-"))
            
            let metadata = PDFMetadata(
                fileName: fileName,
                year: year,
                examType: ExamType.from(string: examType),
                title: title,
                pageCount: pdfDocument.pageCount,
                fileSize: fileAttributes?[.size] as? Int64,
                creationDate: fileAttributes?[.creationDate] as? Date,
                modificationDate: fileAttributes?[.modificationDate] as? Date
            )
            
            logger.debug("解析PDF元数据: \(fileName)")
            return metadata
        }
    }
    
    // MARK: - Private Helper Methods
    
    // 解析年份范围
    private func parseYearFromRange(_ yearRange: String) -> Int {
        // 处理"10到22"这样的格式
        if yearRange.contains("到") {
            let parts = yearRange.components(separatedBy: "到")
            if let endYear = parts.last, let year = Int(endYear) {
                // 假设是21世纪的年份
                return year < 50 ? 2000 + year : 1900 + year
            }
        }
        // 处理"98到09"这样的格式
        else if let year = Int(yearRange.prefix(2)) {
            return year < 50 ? 2000 + year : 1900 + year
        }
        
        return 2023 // 默认年份
    }
    
    // 解析考试类型
    private func parseExamType(_ examType: String) -> String {
        switch examType {
        case "考研英语一":
            return "考研一"
        case "考研英语二":
            return "考研二"
        case "通用英语":
            return "考研通用"
        default:
            return examType
        }
    }
    
    // 生成标题
    private func generateTitle(yearRange: String, examType: String, description: String) -> String {
        return "\(yearRange)年\(examType)\(description)"
    }
    
    // 示例：根据内容分析难度
    private func analyzeDifficulty(from content: String) -> ArticleDifficulty {
        // 这里可以实现更复杂的难度分析逻辑
        if content.count > 2000 {
            return .hard
        } else if content.count > 1000 {
            return .medium
        } else {
            return .easy
        }
    }
    
    // 示例：根据内容分析主题
    private func analyzeTopic(from content: String, examType: String) -> String {
        // 根据考试类型设置主题
        switch examType {
        case "考研一":
            return "考研英语一真题"
        case "考研二":
            return "考研英语二真题"
        case "考研通用":
            return "考研英语通用真题"
        default:
            // 根据内容分析主题
            if content.lowercased().contains("technology") {
                return "科技"
            } else if content.lowercased().contains("economy") {
                return "经济"
            } else {
                return "综合"
            }
        }
    }
}