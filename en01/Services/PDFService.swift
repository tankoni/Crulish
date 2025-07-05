import Foundation
import PDFKit

class PDFService {
    // 从 PDF 文件中提取文本内容
    func extractText(from url: URL) -> String? {
        guard let pdfDocument = PDFDocument(url: url) else {
            print("[ERROR] 无法加载 PDF 文件: \(url.lastPathComponent)")
            return nil
        }
        
        return pdfDocument.string
    }
    
    // 将 PDF 文件转换为 Article 对象
    func convertPDFToArticle(from url: URL) -> Article? {
        guard let content = extractText(from: url) else {
            return nil
        }
        
        // 从文件名中提取标题、年份、考试类型等信息
        let fileName = url.deletingPathExtension().lastPathComponent
        let components = fileName.components(separatedBy: "-")
        
        guard components.count >= 3 else {
            print("[ERROR] PDF 文件名格式不正确: \(fileName)")
            return nil
        }
        
        let year = Int(components[0]) ?? 0
        let examType = components[1]
        let title = components.dropFirst(2).joined(separator: "-")
        
        // 示例：根据文件名或内容分析难度和主题
        let difficulty = analyzeDifficulty(from: content)
        let topic = analyzeTopic(from: content)
        
        return Article(
            title: title,
            content: content,
            year: year,
            examType: examType,
            difficulty: difficulty,
            topic: topic,
            imageName: "default_article_image" // 默认图片
        )
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
    private func analyzeTopic(from content: String) -> String {
        // 这里可以实现更复杂的主题分析逻辑
        if content.lowercased().contains("technology") {
            return "科技"
        } else if content.lowercased().contains("economy") {
            return "经济"
        } else {
            return "综合"
        }
    }
}