//
//  DictionarySpecificImportExportService.swift
//  en01
//
//  Created by Assistant on 2024-12-26.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers
import UIKit

/// 词典专属导入导出服务
@MainActor
class DictionarySpecificImportExportService: BaseService {
    
    // MARK: - Properties
    private let dictionaryService: DictionaryServiceProtocol
    private let wordMasteryService: WordMasteryService
    
    // MARK: - Initialization
    init(modelContext: ModelContext, 
         dictionaryService: DictionaryServiceProtocol,
         wordMasteryService: WordMasteryService,
         cacheManager: CacheManager = CacheManager.shared,
         errorHandler: ErrorHandler = ErrorHandler()) {
        self.dictionaryService = dictionaryService
        self.wordMasteryService = wordMasteryService
        super.init(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: errorHandler,
            subsystem: "com.crulish.dictionary",
            category: "import-export"
        )
    }
    
    convenience init(modelContext: ModelContext? = nil) {
        // 创建默认的依赖
        let defaultCacheManager = CacheManager.shared
        let defaultErrorHandler = ErrorHandler()
        
        // 初始化依赖服务
        if let context = modelContext {
            let dictionaryService = DictionaryService(
                modelContext: context,
                cacheManager: defaultCacheManager,
                errorHandler: defaultErrorHandler
            )
            let wordMasteryService = WordMasteryService(
                dictionaryService: dictionaryService,
                modelContext: context,
                cacheManager: defaultCacheManager,
                errorHandler: defaultErrorHandler
            )
            self.init(
                modelContext: context,
                dictionaryService: dictionaryService,
                wordMasteryService: wordMasteryService,
                cacheManager: defaultCacheManager,
                errorHandler: defaultErrorHandler
            )
        } else {
            // 临时初始化，稍后通过 setModelContext 设置
            let tempContainer = try! ModelContainer(for: UserWord.self, TestedWord.self)
            let tempContext = ModelContext(tempContainer)
            
            let dictionaryService = DictionaryService(
                modelContext: tempContext,
                cacheManager: defaultCacheManager,
                errorHandler: defaultErrorHandler
            )
            let wordMasteryService = WordMasteryService(
                dictionaryService: dictionaryService,
                modelContext: tempContext,
                cacheManager: defaultCacheManager,
                errorHandler: defaultErrorHandler
            )
            self.init(
                modelContext: tempContext,
                dictionaryService: dictionaryService,
                wordMasteryService: wordMasteryService,
                cacheManager: defaultCacheManager,
                errorHandler: defaultErrorHandler
            )
        }
    }
    
    /// 设置模型上下文
    func setModelContext(_ context: ModelContext) {
        modelContext = context
        dictionaryService.setModelContext(context)
        wordMasteryService.setModelContext(context)
    }
    
    // MARK: - Import Functions
    
    /// 导入单词列表到指定词典
    func importWordsToSpecificDictionary(
        words: [String],
        dictionaryFileName: String,
        importMode: ImportMode = .merge
    ) async throws -> ImportResult {
        logger.info("[DictionarySpecificImportExportService] 开始导入 \(words.count) 个单词到词典: \(dictionaryFileName)")
        
        var successCount = 0
        var failedWords: [String] = []
        var duplicateWords: [String] = []
        
        // 获取现有的测试记录以检查重复
        let existingWords = try await getExistingWordsForDictionary(dictionaryFileName)
        
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            // 跳过空单词
            guard !cleanWord.isEmpty else { continue }
            
            // 检查重复
            if existingWords.contains(cleanWord) {
                switch importMode {
                case .merge:
                    duplicateWords.append(cleanWord)
                    continue
                case .overwrite:
                    // 删除现有记录
                    try await removeExistingWordRecord(cleanWord, dictionaryFileName: dictionaryFileName)
                case .skip:
                    duplicateWords.append(cleanWord)
                    continue
                }
            }
            
            // 创建测试记录
            do {
                try await createWordTestRecord(
                    word: cleanWord,
                    dictionaryFileName: dictionaryFileName
                )
                successCount += 1
            } catch {
                logger.error("[DictionarySpecificImportExportService] 导入单词失败: \(cleanWord), 错误: \(error.localizedDescription)")
                failedWords.append(cleanWord)
            }
        }
        
        let result = ImportResult(
            totalWords: words.count,
            successCount: successCount,
            duplicateCount: duplicateWords.count,
            failedCount: failedWords.count,
            duplicateWords: duplicateWords,
            failedWords: failedWords
        )
        
        logger.info("[DictionarySpecificImportExportService] 导入完成: 成功 \(successCount), 重复 \(duplicateWords.count), 失败 \(failedWords.count)")
        return result
    }
    
    /// 从文件导入单词到指定词典
    func importWordsFromFile(
        fileURL: URL,
        dictionaryFileName: String,
        importMode: ImportMode = .merge
    ) async throws -> ImportResult {
        logger.info("[DictionarySpecificImportExportService] 从文件导入单词: \(fileURL.lastPathComponent)")
        
        let words = try await parseWordsFromFile(fileURL)
        return try await importWordsToSpecificDictionary(
            words: words,
            dictionaryFileName: dictionaryFileName,
            importMode: importMode
        )
    }
    
    // MARK: - Export Functions
    
    /// 导出指定词典的测试记录
    func exportDictionaryTestRecords(
        dictionaryFileName: String,
        format: ExportFormat = .text
    ) async throws -> ExportResult {
        logger.info("[DictionarySpecificImportExportService] 导出词典测试记录: \(dictionaryFileName)")
        
        // 获取词典专属的测试记录
        let testedWords = try await getDictionarySpecificTestedWords(dictionaryFileName)
        
        let exportData = try await generateExportData(
            testedWords: testedWords,
            dictionaryFileName: dictionaryFileName,
            format: format,
            includeTestResults: true
        )
        
        let fileName = generateExportFileName(dictionaryFileName: dictionaryFileName, format: format)
        
        return ExportResult(
            fileName: fileName,
            data: exportData,
            wordCount: testedWords.count,
            format: format
        )
    }
    
    /// 导出指定词典的测试记录（原有方法保持兼容性）
    func exportDictionarySpecificWords(
        dictionaryFileName: String,
        exportFormat: ExportFormat = .text,
        includeTestResults: Bool = true
    ) async throws -> ExportResult {
        logger.info("[DictionarySpecificImportExportService] 导出词典专属单词: \(dictionaryFileName)")
        
        // 获取词典专属的测试记录
        let testedWords = try await getDictionarySpecificTestedWords(dictionaryFileName)
        
        let exportData = try await generateExportData(
            testedWords: testedWords,
            dictionaryFileName: dictionaryFileName,
            format: exportFormat,
            includeTestResults: includeTestResults
        )
        
        let fileName = generateExportFileName(dictionaryFileName: dictionaryFileName, format: exportFormat)
        
        return ExportResult(
            fileName: fileName,
            data: exportData,
            wordCount: testedWords.count,
            format: exportFormat
        )
    }

    /// 导出指定掌握程度的单词
    func exportWordsByMastery(
        dictionaryFileName: String,
        masteryLevel: MasteryLevel,
        exportFormat: ExportFormat = .text
    ) async throws -> ExportResult {
        logger.info("[DictionarySpecificImportExportService] 导出掌握程度为 \(masteryLevel.rawValue) 的单词")
        
        let testedWords = try await getWordsByMastery(
            dictionaryFileName: dictionaryFileName,
            masteryLevel: masteryLevel
        )
        
        let exportData = try await generateExportData(
            testedWords: testedWords,
            dictionaryFileName: dictionaryFileName,
            format: exportFormat,
            includeTestResults: true
        )
        
        let fileName = generateExportFileName(
            dictionaryFileName: dictionaryFileName,
            format: exportFormat,
            suffix: masteryLevel.displayName
        )
        
        return ExportResult(
            fileName: fileName,
            data: exportData,
            wordCount: testedWords.count,
            format: exportFormat
        )
    }
    
    /// 导出多个掌握程度的单词
    func exportWordsByMastery(
        dictionaryFileName: String,
        masteryLevels: [MasteryLevel],
        format: ExportFormat = .text
    ) async throws -> ExportResult {
        logger.info("[DictionarySpecificImportExportService] 导出多个掌握程度的单词: \(masteryLevels.map { $0.rawValue })")
        
        var allTestedWords: [TestedWord] = []
        
        for masteryLevel in masteryLevels {
            let words = try await getWordsByMastery(
                dictionaryFileName: dictionaryFileName,
                masteryLevel: masteryLevel
            )
            allTestedWords.append(contentsOf: words)
        }
        
        let exportData = try await generateExportData(
            testedWords: allTestedWords,
            dictionaryFileName: dictionaryFileName,
            format: format,
            includeTestResults: true
        )
        
        let masteryNames = masteryLevels.map { $0.displayName }.joined(separator: "_")
        let fileName = generateExportFileName(
            dictionaryFileName: dictionaryFileName,
            format: format,
            suffix: masteryNames
        )
        
        return ExportResult(
            fileName: fileName,
            data: exportData,
            wordCount: allTestedWords.count,
            format: format
        )
    }
    
    // MARK: - Private Helper Methods
    
    /// 获取词典现有单词列表
    private func getExistingWordsForDictionary(_ dictionaryFileName: String) async throws -> Set<String> {
        let testedWords = try await fetchTestedWords(for: dictionaryFileName)
        return Set(testedWords.map { $0.word.lowercased() })
    }
    
    /// 直接从数据库获取指定词典的已测试单词
    private func fetchTestedWords(for dictionaryFileName: String) async throws -> [TestedWord] {
        let descriptor = FetchDescriptor<TestedWord>(
            predicate: #Predicate<TestedWord> { testedWord in
                testedWord.dictionaryFileName == dictionaryFileName
            }
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// 创建单词测试记录
    private func createWordTestRecord(word: String, dictionaryFileName: String) async throws {
        // 创建一个基础的测试记录，标记为未测试状态
        let testedWord = TestedWord(
            word: word,
            dictionaryName: dictionaryFileName,
            dictionaryFileName: dictionaryFileName,
            masteryLevel: MasteryLevel.unfamiliar,
            testSessionId: nil,
            difficulty: "unknown",
            responseTime: 0.0
        )
        
        modelContext.insert(testedWord)
        try modelContext.save()
    }
    
    /// 删除现有单词记录
    private func removeExistingWordRecord(_ word: String, dictionaryFileName: String) async throws {
        let descriptor = FetchDescriptor<TestedWord>(
            predicate: #Predicate<TestedWord> { testedWord in
                testedWord.word == word &&
                testedWord.dictionaryFileName == dictionaryFileName
            }
        )
        
        let existingRecords = try modelContext.fetch(descriptor)
        for record in existingRecords {
            modelContext.delete(record)
        }
        try modelContext.save()
    }
    
    /// 从文件解析单词列表
    private func parseWordsFromFile(_ fileURL: URL) async throws -> [String] {
        guard fileURL.startAccessingSecurityScopedResource() else {
            throw ImportExportError.fileAccessDenied
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }
        
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        
        // 根据文件扩展名选择解析方式
        let fileExtension = fileURL.pathExtension.lowercased()
        
        switch fileExtension {
        case "txt":
            return parseTextFile(content)
        case "csv":
            return parseCSVFile(content)
        case "json":
            return try parseJSONFile(content)
        default:
            // 默认按文本文件处理
            return parseTextFile(content)
        }
    }
    
    /// 解析文本文件
    private func parseTextFile(_ content: String) -> [String] {
        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    /// 解析CSV文件
    private func parseCSVFile(_ content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var words: [String] = []
        
        for line in lines {
            let columns = line.components(separatedBy: ",")
            if let firstColumn = columns.first {
                let word = firstColumn.trimmingCharacters(in: .whitespacesAndNewlines)
                if !word.isEmpty {
                    words.append(word)
                }
            }
        }
        
        return words
    }
    
    /// 解析JSON文件
    private func parseJSONFile(_ content: String) throws -> [String] {
        guard let data = content.data(using: .utf8) else {
            throw ImportExportError.invalidFileFormat
        }
        
        // 尝试解析为字符串数组
        if let words = try? JSONDecoder().decode([String].self, from: data) {
            return words
        }
        
        // 尝试解析为包含单词字段的对象数组
        struct WordObject: Codable {
            let word: String?
            let text: String?
        }
        
        if let wordObjects = try? JSONDecoder().decode([WordObject].self, from: data) {
            return wordObjects.compactMap { obj in
                obj.word ?? obj.text
            }
        }
        
        throw ImportExportError.invalidFileFormat
    }
    
    /// 获取词典专属测试记录
    private func getDictionarySpecificTestedWords(_ dictionaryFileName: String) async throws -> [TestedWord] {
        return try await fetchTestedWords(for: dictionaryFileName)
    }
    
    /// 根据掌握程度获取单词
    private func getWordsByMastery(
        dictionaryFileName: String,
        masteryLevel: MasteryLevel
    ) async throws -> [TestedWord] {
        let allWords = try await getDictionarySpecificTestedWords(dictionaryFileName)
        return allWords.filter { $0.masteryLevel == masteryLevel.rawValue }
    }
    
    /// 生成导出数据
    private func generateExportData(
        testedWords: [TestedWord],
        dictionaryFileName: String,
        format: ExportFormat,
        includeTestResults: Bool
    ) async throws -> Data {
        switch format {
        case .text:
            return try generateTextExport(testedWords: testedWords, includeTestResults: includeTestResults)
        case .csv:
            return try generateCSVExport(testedWords: testedWords, includeTestResults: includeTestResults)
        case .json:
            return try generateJSONExport(testedWords: testedWords, includeTestResults: includeTestResults)
        case .markdown:
            return try await generateMarkdownExport(
                testedWords: testedWords,
                dictionaryFileName: dictionaryFileName,
                includeTestResults: includeTestResults
            )
        case .pdf:
            return try await generatePDFExport(
                testedWords: testedWords,
                dictionaryFileName: dictionaryFileName,
                includeTestResults: includeTestResults
            )
        }
    }
    
    /// 生成文本格式导出
    private func generateTextExport(testedWords: [TestedWord], includeTestResults: Bool) throws -> Data {
        var content = ""
        
        if includeTestResults {
            content += "# 词汇测试记录\n\n"
            content += "单词\t掌握程度\t正确次数\t错误次数\t最后测试时间\n"
            content += "---\n"
            
            for word in testedWords.sorted(by: { $0.word < $1.word }) {
                let masteryLevel = MasteryLevel(rawValue: word.masteryLevel) ?? .unfamiliar
                let lastTested = word.lastTestedDate.map { DateFormatter.shortDate.string(from: $0) } ?? "未测试"
                content += "\(word.word)\t\(masteryLevel.displayName)\t\(word.correctCount)\t\(word.testCount)\t\(lastTested)\n"
            }
        } else {
            content = testedWords.map { $0.word }.sorted().joined(separator: "\n")
        }
        
        guard let data = content.data(using: .utf8) else {
            throw ImportExportError.exportFailed
        }
        return data
    }
    
    /// 生成CSV格式导出
    private func generateCSVExport(testedWords: [TestedWord], includeTestResults: Bool) throws -> Data {
        var csvContent = ""
        
        if includeTestResults {
            csvContent += "单词,掌握程度,正确次数,测试次数,平均响应时间,最后测试时间\n"
            
            for word in testedWords.sorted(by: { $0.word < $1.word }) {
                let masteryLevel = MasteryLevel(rawValue: word.masteryLevel) ?? .unfamiliar
                let lastTested = word.lastTestedDate.map { DateFormatter.iso8601.string(from: $0) } ?? "未测试"
                csvContent += "\"\(word.word)\",\"\(masteryLevel.displayName)\",\(word.correctCount),\(word.testCount),\(word.responseTime),\"\(lastTested)\"\n"
            }
        } else {
            csvContent += "单词\n"
            for word in testedWords.sorted(by: { $0.word < $1.word }) {
                csvContent += "\"\(word.word)\"\n"
            }
        }
        
        guard let data = csvContent.data(using: .utf8) else {
            throw ImportExportError.exportFailed
        }
        return data
    }
    
    /// 生成JSON格式导出
    private func generateJSONExport(testedWords: [TestedWord], includeTestResults: Bool) throws -> Data {
        if includeTestResults {
            let exportData = testedWords.map { word in
                ExportableTestedWord(
                    word: word.word,
                    dictionaryFileName: word.dictionaryFileName,
                    masteryLevel: word.masteryLevel,
                    correctCount: word.correctCount,
                    testCount: word.testCount,
                    responseTime: word.responseTime,
                    testedAt: word.testedAt,
                    lastTestedDate: word.lastTestedDate
                )
            }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(exportData)
        } else {
            let words = testedWords.map { $0.word }.sorted()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(words)
        }
    }
    
    /// 生成Markdown格式导出
    private func generateMarkdownExport(
        testedWords: [TestedWord],
        dictionaryFileName: String,
        includeTestResults: Bool
    ) async throws -> Data {
        var content = "# \(dictionaryFileName) 词汇记录\n\n"
        content += "导出时间: \(DateFormatter.readable.string(from: Date()))\n"
        content += "总单词数: \(testedWords.count)\n\n"
        
        if includeTestResults {
            // 按掌握程度分组
            let groupedWords = Dictionary(grouping: testedWords) { word in
                MasteryLevel(rawValue: word.masteryLevel) ?? .unfamiliar
            }
            
            for masteryLevel in MasteryLevel.allCases {
                if let words = groupedWords[masteryLevel], !words.isEmpty {
                    content += "## \(masteryLevel.displayName) (\(words.count)个)\n\n"
                    
                    for word in words.sorted(by: { $0.word < $1.word }) {
                        content += "- **\(word.word)** "
                        let incorrectCount = word.testCount - word.correctCount
                        let lastTested = word.lastTestedDate.map { DateFormatter.shortDate.string(from: $0) } ?? "未测试"
                        content += "(正确: \(word.correctCount), 错误: \(incorrectCount), "
                        content += "最后测试: \(lastTested))\n"
                    }
                    content += "\n"
                }
            }
        } else {
            content += "## 单词列表\n\n"
            for word in testedWords.sorted(by: { $0.word < $1.word }) {
                content += "- \(word.word)\n"
            }
        }
        
        guard let data = content.data(using: .utf8) else {
            throw ImportExportError.exportFailed
        }
        return data
    }
    
    /// 生成PDF格式导出
    private func generatePDFExport(
        testedWords: [TestedWord],
        dictionaryFileName: String,
        includeTestResults: Bool
    ) async throws -> Data {
        print("📄 开始生成PDF文档")
        print("   - 词典: \(dictionaryFileName)")
        print("   - 单词数量: \(testedWords.count)")
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // A4 size
        let pdfData = NSMutableData()
        
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        
        guard UIGraphicsGetCurrentContext() != nil else {
            print("❌ 无法创建PDF上下文")
            throw ImportExportError.exportFailed
        }
        
        UIGraphicsBeginPDFPage()
        var currentY: CGFloat = 50
        
        // 绘制标题
        let title = "词典单词列表 - \(dictionaryFileName.replacingOccurrences(of: ".json", with: ""))"
        currentY = drawPDFTitle(title, at: currentY, pageRect: pageRect)
        currentY += 20
        
        // 绘制统计信息
        let statsText = "导出时间: \(DateFormatter.readable.string(from: Date()))\n单词总数: \(testedWords.count) 个"
        currentY = drawPDFText(statsText, at: currentY, pageRect: pageRect)
        currentY += 30
        
        // 绘制单词列表
        if includeTestResults {
            // 按掌握程度分组
            let masteredWords = testedWords.filter { MasteryLevel(rawValue: $0.masteryLevel) == .mastered }
            let familiarWords = testedWords.filter { MasteryLevel(rawValue: $0.masteryLevel) == .familiar }
            let unfamiliarWords = testedWords.filter { MasteryLevel(rawValue: $0.masteryLevel) == .unfamiliar }
            
            if !masteredWords.isEmpty {
                currentY = drawPDFSectionTitle("已掌握单词 (\(masteredWords.count))", at: currentY, pageRect: pageRect)
                currentY += 10
                for word in masteredWords.sorted(by: { $0.word < $1.word }) {
                    if currentY > pageRect.height - 100 {
                        UIGraphicsBeginPDFPage()
                        currentY = 50
                    }
                    currentY = drawPDFWordWithDetails(word, at: currentY, pageRect: pageRect)
                }
                currentY += 20
            }
            
            if !familiarWords.isEmpty {
                if currentY > pageRect.height - 150 {
                    UIGraphicsBeginPDFPage()
                    currentY = 50
                }
                currentY = drawPDFSectionTitle("熟悉单词 (\(familiarWords.count))", at: currentY, pageRect: pageRect)
                currentY += 10
                for word in familiarWords.sorted(by: { $0.word < $1.word }) {
                    if currentY > pageRect.height - 100 {
                        UIGraphicsBeginPDFPage()
                        currentY = 50
                    }
                    currentY = drawPDFWordWithDetails(word, at: currentY, pageRect: pageRect)
                }
                currentY += 20
            }
            
            if !unfamiliarWords.isEmpty {
                if currentY > pageRect.height - 150 {
                    UIGraphicsBeginPDFPage()
                    currentY = 50
                }
                currentY = drawPDFSectionTitle("不熟悉单词 (\(unfamiliarWords.count))", at: currentY, pageRect: pageRect)
                currentY += 10
                for word in unfamiliarWords.sorted(by: { $0.word < $1.word }) {
                    if currentY > pageRect.height - 100 {
                        UIGraphicsBeginPDFPage()
                        currentY = 50
                    }
                    currentY = drawPDFWordWithDetails(word, at: currentY, pageRect: pageRect)
                }
            }
        } else {
            // 简单单词列表
            currentY = drawPDFSectionTitle("单词列表", at: currentY, pageRect: pageRect)
            currentY += 10
            
            for word in testedWords.sorted(by: { $0.word < $1.word }) {
                if currentY > pageRect.height - 100 {
                    UIGraphicsBeginPDFPage()
                    currentY = 50
                }
                currentY = drawPDFSimpleWord(word.word, at: currentY, pageRect: pageRect)
            }
        }
        
        UIGraphicsEndPDFContext()
        
        print("✅ PDF生成完成，大小: \(pdfData.length) bytes")
        return pdfData as Data
    }
    
    // MARK: - PDF绘制辅助方法
    
    private func drawPDFTitle(_ title: String, at y: CGFloat, pageRect: CGRect) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: 18)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        let textRect = CGRect(x: 50, y: y, width: pageRect.width - 100, height: 30)
        title.draw(in: textRect, withAttributes: attributes)
        
        return y + 30
    }
    
    private func drawPDFSectionTitle(_ title: String, at y: CGFloat, pageRect: CGRect) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.darkGray
        ]
        
        let textRect = CGRect(x: 50, y: y, width: pageRect.width - 100, height: 20)
        title.draw(in: textRect, withAttributes: attributes)
        
        return y + 25
    }
    
    private func drawPDFText(_ text: String, at y: CGFloat, pageRect: CGRect) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        let textRect = CGRect(x: 50, y: y, width: pageRect.width - 100, height: 60)
        text.draw(in: textRect, withAttributes: attributes)
        
        return y + 60
    }
    
    private func drawPDFWordWithDetails(_ word: TestedWord, at y: CGFloat, pageRect: CGRect) -> CGFloat {
        let masteryLevel = MasteryLevel(rawValue: word.masteryLevel) ?? .unfamiliar
        let lastTested = word.lastTestedDate.map { DateFormatter.shortDate.string(from: $0) } ?? "未测试"
        
        let wordText = "\(word.word) - \(masteryLevel.displayName) (正确:\(word.correctCount)/\(word.testCount), 最后测试:\(lastTested))"
        
        let font = UIFont.systemFont(ofSize: 10)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        let textRect = CGRect(x: 70, y: y, width: pageRect.width - 120, height: 15)
        wordText.draw(in: textRect, withAttributes: attributes)
        
        return y + 18
    }
    
    private func drawPDFSimpleWord(_ word: String, at y: CGFloat, pageRect: CGRect) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        let textRect = CGRect(x: 70, y: y, width: pageRect.width - 120, height: 15)
        word.draw(in: textRect, withAttributes: attributes)
        
        return y + 18
    }
    
    /// 生成导出文件名
    private func generateExportFileName(
        dictionaryFileName: String,
        format: ExportFormat,
        suffix: String? = nil
    ) -> String {
        let baseName = dictionaryFileName.replacingOccurrences(of: ".json", with: "")
        let timestamp = DateFormatter.fileTimestamp.string(from: Date())
        let suffixPart = suffix != nil ? "_\(suffix!)" : ""
        return "\(baseName)_words\(suffixPart)_\(timestamp).\(format.fileExtension)"
    }
}

// MARK: - Supporting Types

/// 导入模式
enum ImportMode {
    case merge      // 合并（跳过重复）
    case overwrite  // 覆盖重复
    case skip       // 跳过重复
}

/// 导入结果
struct ImportResult {
    let totalWords: Int
    let successCount: Int
    let duplicateCount: Int
    let failedCount: Int
    let duplicateWords: [String]
    let failedWords: [String]
    
    var successRate: Double {
        return totalWords > 0 ? Double(successCount) / Double(totalWords) : 0.0
    }
}

/// 导出结果
struct ExportResult {
    let fileName: String
    let data: Data
    let wordCount: Int
    let format: ExportFormat
    
    // 为了兼容性添加的属性
    var exportedCount: Int {
        return wordCount
    }
    
    var fileURL: URL? {
        // 返回文档目录中的文件URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent(fileName)
    }
}

/// 可导出的测试单词数据结构
struct ExportableTestedWord: Codable {
    let word: String
    let dictionaryFileName: String
    let masteryLevel: String
    let correctCount: Int
    let testCount: Int
    let responseTime: TimeInterval
    let testedAt: Date
    let lastTestedDate: Date?
}

/// 导入导出错误
enum ImportExportError: Error, LocalizedError {
    case fileAccessDenied
    case invalidFileFormat
    case exportFailed
    case importFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileAccessDenied:
            return "无法访问文件"
        case .invalidFileFormat:
            return "文件格式不正确"
        case .exportFailed:
            return "导出失败"
        case .importFailed(let reason):
            return "导入失败: \(reason)"
        }
    }
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let readable: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}