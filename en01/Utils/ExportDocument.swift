//
//  ExportDocument.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - ExportDocument Protocol
protocol ExportDocument: FileDocument {
    var contentType: UTType { get }
    var defaultFilename: String { get }
}

// MARK: - PDF Export Document
struct PDFExportDocument: ExportDocument {
    let data: Data
    
    static var readableContentTypes: [UTType] { [.pdf] }
    
    var contentType: UTType { .pdf }
    var defaultFilename: String { "前10篇推荐文章.pdf" }
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Markdown Export Document
struct MarkdownExportDocument: ExportDocument {
    let content: String
    
    static var readableContentTypes: [UTType] { [.plainText] }
    
    var contentType: UTType { .plainText }
    var defaultFilename: String { "前10篇推荐文章.md" }
    
    init(content: String) {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteFileExists)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Article Export Error
enum ArticleExportError: Error, LocalizedError {
    case resourcePathNotFound
    case pdfMergeFailed
    case markdownMergeFailed
    case pdfFileNotFound(String)
    case pdfLoadFailed(String)
    case pdfDataGenerationFailed
    case bundleResourceAccessFailed
    case noValidPDFFiles
    
    var errorDescription: String? {
        switch self {
        case .resourcePathNotFound:
            return "无法找到应用资源路径"
        case .pdfMergeFailed:
            return "PDF合并失败"
        case .markdownMergeFailed:
            return "Markdown整合失败"
        case .pdfFileNotFound(let path):
            return "PDF文件未找到: \(path)"
        case .pdfLoadFailed(let path):
            return "PDF文件加载失败: \(path)"
        case .pdfDataGenerationFailed:
            return "PDF数据生成失败"
        case .bundleResourceAccessFailed:
            return "Bundle资源访问失败"
        case .noValidPDFFiles:
            return "没有有效的PDF文件可以合并"
        }
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let articleExportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}