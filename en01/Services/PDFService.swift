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
    
    // 提取带有格式信息的结构化文本
    func extractTextWithLayout(from url: URL) -> StructuredText? {
        return performSafeOperation("提取PDF结构化文本") {
            guard let pdfDocument = PDFDocument(url: url) else {
                throw ServiceError.notFound("无法加载 PDF 文件")
            }
            
            var structuredPages: [StructuredPage] = []
            var totalWordCount = 0
            
            // 添加超时机制
            let timeoutQueue = DispatchQueue(label: "pdf.extraction.timeout")
            let extractionGroup = DispatchGroup()
            
            for pageIndex in 0..<pdfDocument.pageCount {
                extractionGroup.enter()
                timeoutQueue.asyncAfter(deadline: .now() + 0.25) {
                    if extractionGroup.wait(timeout: .now()) == .timedOut {
                        self.logger.error("页面 \(pageIndex + 1) 提取超时")
                    }
                }
                
                guard let page = pdfDocument.page(at: pageIndex) else {
                    extractionGroup.leave()
                    continue
                }
                
                let pageElements = extractElementsFromPage(page, pageNumber: pageIndex + 1)
                let structuredPage = StructuredPage(
                    pageNumber: pageIndex + 1,
                    elements: pageElements,
                    bounds: page.bounds(for: .mediaBox)
                )
                
                structuredPages.append(structuredPage)
                totalWordCount += pageElements.reduce(0) { $0 + $1.content.components(separatedBy: .whitespacesAndNewlines).count }
                extractionGroup.leave()
            }
            
            if extractionGroup.wait(timeout: .now() + 1.0) == .timedOut {
                throw ServiceError.processingFailed("提取超时")
            }
            
            let metadata = TextMetadata(
                totalPages: pdfDocument.pageCount,
                extractionDate: Date(),
                sourceURL: url,
                language: detectLanguage(from: structuredPages),
                wordCount: totalWordCount
            )
            
            return StructuredText(pages: structuredPages, metadata: metadata)
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
            
            // 获取相对于Bundle资源目录的路径
            let relativePath: String
            if let resourcePath = Bundle.main.resourcePath {
                let resourceURL = URL(fileURLWithPath: resourcePath)
                relativePath = url.path.replacingOccurrences(of: resourceURL.path + "/", with: "")
            } else {
                relativePath = url.lastPathComponent
            }
            
            return Article(
                title: title,
                content: content,
                year: year,
                examType: examType.rawValue,
                difficulty: difficulty,
                topic: topic,
                imageName: "",  // PDF文章暂时不设置图片
                pdfPath: relativePath  // 设置相对PDF文件路径
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
    
    // MARK: - Structured Text Extraction Helper Methods
    
    /// 从PDF页面提取文本元素（增强版）
    private func extractElementsFromPage(_ page: PDFPage, pageNumber: Int) -> [TextElement] {
        var elements: [TextElement] = []
        
        // 获取页面的所有文本选择区域
        guard let pageString = page.string else { return elements }
        
        // 尝试获取更精确的文本位置信息
        let pageRect = page.bounds(for: .mediaBox)
        
        // 使用更智能的文本分割方法
        let textBlocks = extractTextBlocks(from: pageString, pageRect: pageRect)
        
        for (index, textBlock) in textBlocks.enumerated() {
            let trimmedText = textBlock.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { continue }
            
            // 增强的文本类型分析
            let elementType = analyzeElementTypeEnhanced(trimmedText, index: index, position: textBlock.bounds)
            let fontInfo = analyzeFontInfoEnhanced(trimmedText, elementType: elementType, bounds: textBlock.bounds)
            
            let element = TextElement(
                content: trimmedText,
                type: elementType,
                bounds: textBlock.bounds,
                fontInfo: fontInfo,
                level: getElementLevel(elementType)
            )
            
            elements.append(element)
        }
        
        // 按Y坐标排序，确保阅读顺序正确
        elements.sort { $0.bounds.maxY > $1.bounds.maxY }
        
        return elements
    }
    
    /// 提取文本块信息
    private func extractTextBlocks(from pageString: String, pageRect: CGRect) -> [(content: String, bounds: CGRect)] {
        var textBlocks: [(content: String, bounds: CGRect)] = []
        
        // 按段落分割文本
        let paragraphs = pageString.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        var currentY: CGFloat = pageRect.maxY - 50 // 从页面顶部开始，留出边距
        let baseLineHeight: CGFloat = 20.0
        let paragraphSpacing: CGFloat = 10.0
        
        for paragraph in paragraphs {
            let trimmedParagraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedParagraph.isEmpty else { continue }
            
            // 根据文本长度估算行数
            let charactersPerLine = Int(pageRect.width / 8.0) // 假设每个字符8点宽
            let estimatedLines = max(1, trimmedParagraph.count / charactersPerLine + 1)
            let blockHeight = CGFloat(estimatedLines) * baseLineHeight
            
            // 计算文本块边界
            let bounds = CGRect(
                x: 40, // 左边距
                y: currentY - blockHeight,
                width: pageRect.width - 80, // 左右边距
                height: blockHeight
            )
            
            textBlocks.append((content: trimmedParagraph, bounds: bounds))
            currentY -= blockHeight + paragraphSpacing
        }
        
        return textBlocks
    }
    
    /// 增强的文本元素类型分析
    private func analyzeElementTypeEnhanced(_ text: String, index: Int, position: CGRect) -> ElementType {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 基于位置的标题检测（页面顶部的短文本）
        if position.maxY > position.minY + 400 && trimmedText.count < 100 {
            if trimmedText.contains("Section") || trimmedText.contains("Part") || 
               trimmedText.contains("章") || trimmedText.contains("节") ||
               trimmedText.matches("^[A-Z][A-Z\\s]+$") { // 全大写标题
                return .title
            }
        }
        
        // 检查是否为副标题（居中或特殊格式）
        if trimmedText.count < 120 {
            if trimmedText.contains(":") || trimmedText.hasSuffix("?") ||
               trimmedText.matches("^[0-9]+\\.[0-9]+") || // 编号格式如 1.1
               (trimmedText.count < 50 && position.minX > 100) { // 可能居中的短文本
                return .subtitle
            }
        }
        
        // 增强的列表项检测
        if trimmedText.hasPrefix("•") || trimmedText.hasPrefix("-") || 
           trimmedText.hasPrefix("*") || trimmedText.hasPrefix("○") ||
           trimmedText.matches("^[0-9]+\\.") || trimmedText.matches("^\\([a-z]\\)") ||
           trimmedText.matches("^[A-Z]\\.") {
            return .list
        }
        
        // 引用检测（包括多种引用格式）
        if (trimmedText.hasPrefix("\"") && trimmedText.hasSuffix("\"")) ||
           (trimmedText.hasPrefix("'") && trimmedText.hasSuffix("'")) ||
           trimmedText.hasPrefix(">") || // Markdown引用格式
           (trimmedText.hasPrefix("[") && trimmedText.hasSuffix("]")) ||
           trimmedText.contains("引用") || trimmedText.contains("Quote") {
            return .quote
        }
        
        // 检测特殊段落（如注释、脚注等）
        if trimmedText.matches("^\\*.*\\*$") || // 星号包围的文本
           trimmedText.matches("^\\[.*\\]$") || // 方括号包围的文本
           (trimmedText.count < 30 && position.minY < 100) { // 页面底部的短文本（可能是脚注）
            return .other
        }
        
        // 默认为段落
        return .paragraph
    }
    
    /// 保持原有方法的兼容性
    private func analyzeElementType(_ text: String, index: Int) -> ElementType {
        return analyzeElementTypeEnhanced(text, index: index, position: CGRect.zero)
    }
    
    /// 增强的字体信息分析
    private func analyzeFontInfoEnhanced(_ text: String, elementType: ElementType, bounds: CGRect) -> FontInfo {
        let size: CGFloat
        let weight: FontWeight
        let isBold: Bool
        let isItalic: Bool
        
        // 基于元素类型和位置的字体分析
        switch elementType {
        case .title:
            size = bounds.height > 25 ? 20.0 : 18.0 // 根据边界高度调整
            weight = .bold
            isBold = true
            isItalic = false
        case .subtitle:
            size = 16.0
            weight = .semibold
            isBold = true
            isItalic = false
        case .list:
            size = 14.0
            weight = .regular
            isBold = false
            isItalic = false
        case .quote:
            size = 14.0
            weight = .medium
            isBold = false
            isItalic = true // 引用通常使用斜体
        case .other:
            size = 12.0 // 注释等使用较小字体
            weight = .light
            isBold = false
            isItalic = true
        default: // paragraph
            size = 14.0
            weight = .regular
            isBold = false
            isItalic = false
        }
        
        // 检测文本中的格式标记
        let hasItalicMarkers = text.contains("*") && !text.hasPrefix("*") // 不是列表项的星号
        let hasBoldMarkers = text.contains("**") || text.matches(".*[A-Z]{3,}.*") // 连续大写可能表示强调
        
        return FontInfo(
            size: size,
            weight: hasBoldMarkers ? .bold : weight,
            isItalic: hasItalicMarkers || isItalic,
            isBold: hasBoldMarkers || isBold
        )
    }
    
    /// 保持原有方法的兼容性
    private func analyzeFontInfo(_ text: String, elementType: ElementType) -> FontInfo {
        return analyzeFontInfoEnhanced(text, elementType: elementType, bounds: CGRect.zero)
    }
    
    /// 获取元素层级
    private func getElementLevel(_ elementType: ElementType) -> Int? {
        switch elementType {
        case .title:
            return 1
        case .subtitle:
            return 2
        default:
            return nil
        }
    }
    
    /// 检测文本语言
    private func detectLanguage(from pages: [StructuredPage]) -> String? {
        let allText = pages.flatMap { $0.elements }.map { $0.content }.joined(separator: " ")
        
        // 简单的语言检测逻辑
        let chineseCharacterCount = allText.filter { $0.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF } }.count
        let totalCharacterCount = allText.count
        
        if chineseCharacterCount > totalCharacterCount / 4 {
            return "zh-CN"
        } else {
            return "en-US"
        }
    }
}

// MARK: - String Extension for Regex

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}