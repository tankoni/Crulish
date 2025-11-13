//
//  TestResultExportService.swift
//  en01
//
//  Created by AI Assistant on 2024/12/26.
//

import Foundation
import SwiftData
import UIKit
import PDFKit
import Combine

/// 测试结果导出服务协议
protocol TestResultExportServiceProtocol {
    func exportTestResults(for dictionaryName: String, format: ExportFormat) async throws -> URL
    func generateExportableData(for dictionaryName: String) async throws -> ExportableTestResult
}

/// 测试结果导出服务实现
@MainActor
class TestResultExportService: TestResultExportServiceProtocol {
    private let modelContext: ModelContext
    private let fileManager = FileManager.default
    private let dictionaryService: DictionaryService
    private var cancellables = Set<AnyCancellable>()
    
    init(modelContext: ModelContext, dictionaryService: DictionaryServiceProtocol) {
        self.modelContext = modelContext
        self.dictionaryService = dictionaryService as! DictionaryService
        print("🔧 TestResultExportService 初始化完成")
    }
    
    // MARK: - 额外的导出格式支持
    
    private func exportToText(_ data: ExportableTestResult) async throws -> URL {
        let content = generateTextContent(data)
        let fileName = generateFileName(for: data, format: .text)
        let url = try getDocumentsURL().appendingPathComponent(fileName)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    private func exportToCSV(_ data: ExportableTestResult) async throws -> URL {
        let content = generateCSVContent(data)
        let fileName = generateFileName(for: data, format: .csv)
        let url = try getDocumentsURL().appendingPathComponent(fileName)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    private func exportToJSON(_ data: ExportableTestResult) async throws -> URL {
        let content = generateJSONContent(data)
        let fileName = generateFileName(for: data, format: .json)
        let url = try getDocumentsURL().appendingPathComponent(fileName)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    private func exportVocabularyTestToText(_ data: VocabularyTestExportData) async throws -> URL {
        let content = generateVocabularyTestTextContent(data)
        let fileName = generateVocabularyTestFileName(for: data, format: .text)
        let url = try getDocumentsURL().appendingPathComponent(fileName)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    private func exportVocabularyTestToCSV(_ data: VocabularyTestExportData) async throws -> URL {
        let content = generateVocabularyTestCSVContent(data)
        let fileName = generateVocabularyTestFileName(for: data, format: .csv)
        let url = try getDocumentsURL().appendingPathComponent(fileName)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    private func exportVocabularyTestToJSON(_ data: VocabularyTestExportData) async throws -> URL {
        let content = generateVocabularyTestJSONContent(data)
        let fileName = generateVocabularyTestFileName(for: data, format: .json)
        let url = try getDocumentsURL().appendingPathComponent(fileName)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    // MARK: - 内容生成方法
    
    private func generateTextContent(_ data: ExportableTestResult) -> String {
        var content = "词汇量测试结果\n"
        content += "================\n\n"
        content += "词典: \(data.dictionaryName)\n"
        content += "测试时间: \(DateFormatter.localizedString(from: data.testDate, dateStyle: .medium, timeStyle: .short))\n"
        content += "总词汇量: \(data.totalWords)\n"
        content += "认识单词: \(data.knownWords.count)\n"
        content += "不认识单词: \(data.unknownWords.count)\n\n"
        
        if !data.knownWords.isEmpty {
            content += "认识的单词:\n"
            content += "----------\n"
            for word in data.knownWords {
                content += "• \(word.word)\n"
            }
            content += "\n"
        }
        
        if !data.unknownWords.isEmpty {
            content += "不认识的单词:\n"
            content += "------------\n"
            for word in data.unknownWords {
                content += "• \(word.word)\n"
            }
        }
        
        return content
    }
    
    private func generateCSVContent(_ data: ExportableTestResult) -> String {
        var content = "单词,状态,词性,释义\n"
        
        for word in data.knownWords {
            let meaning = word.meanings.first ?? ""
            let partOfSpeech = ""  // ExportableWord没有partOfSpeech属性，使用空字符串
            content += "\"\(word.word)\",\"认识\",\"\(partOfSpeech)\",\"\(meaning)\"\n"
        }
        
        for word in data.unknownWords {
            let meaning = word.meanings.first ?? ""
            let partOfSpeech = ""  // ExportableWord没有partOfSpeech属性，使用空字符串
            content += "\"\(word.word)\",\"不认识\",\"\(partOfSpeech)\",\"\(meaning)\"\n"
        }
        
        return content
    }
    
    private func generateJSONContent(_ data: ExportableTestResult) -> String {
        let jsonData: [String: Any] = [
            "dictionaryName": data.dictionaryName,
            "testDate": ISO8601DateFormatter().string(from: data.testDate),
            "totalWords": data.totalWords,
            "knownWordsCount": data.knownWords.count,
            "unknownWordsCount": data.unknownWords.count,
            "knownWords": data.knownWords.map { word in
                [
                    "word": word.word,
                    "meanings": word.meanings.map { ["meaning": $0] }  // meanings是String数组，不是对象数组
                ]
            },
            "unknownWords": data.unknownWords.map { word in
                [
                    "word": word.word,
                    "meanings": word.meanings.map { ["meaning": $0] }  // meanings是String数组，不是对象数组
                ]
            }
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"JSON序列化失败\"}"
        }
    }
    
    private func generateVocabularyTestTextContent(_ data: VocabularyTestExportData) -> String {
        var content = "词汇量测试单词详情\n"
        content += "==================\n\n"
        content += "词典: \(data.dictionaryName)\n"
        content += "测试时间: \(DateFormatter.localizedString(from: data.testDate, dateStyle: .medium, timeStyle: .short))\n"
        content += "总单词数: \(data.words.count)\n\n"
        
        for word in data.words {
            content += "单词: \(word.word)\n"
            content += "状态: \(word.masteryLevel)\n"  // 使用masteryLevel而不是isKnown
            content += "释义: \(word.definition)\n"    // 使用definition而不是meanings
            content += "\n"
        }
        
        return content
    }
    
    private func generateVocabularyTestCSVContent(_ data: VocabularyTestExportData) -> String {
        var content = "单词,状态,释义\n"
        
        for word in data.words {
            let definition = word.definition  // 使用definition而不是meanings
            content += "\"\(word.word)\",\"\(word.masteryLevel)\",\"\(definition)\"\n"  // 使用masteryLevel而不是isKnown
        }
        
        return content
    }
    
    private func generateVocabularyTestJSONContent(_ data: VocabularyTestExportData) -> String {
        let jsonData: [String: Any] = [
            "dictionaryName": data.dictionaryName,
            "testDate": ISO8601DateFormatter().string(from: data.testDate),
            "totalWords": data.words.count,
            "words": data.words.map { word in
                [
                    "word": word.word,
                    "masteryLevel": word.masteryLevel,
                    "definition": word.definition
                ]
            }
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"JSON序列化失败\"}"
        }
    }
    
    // MARK: - Public Methods
    
    /// 导出测试结果
    func exportTestResults(for dictionaryName: String, format: ExportFormat) async throws -> URL {
        print("🚀 开始导出测试结果")
        print("📋 参数信息:")
        print("   - 词典名称: \(dictionaryName)")
        print("   - 导出格式: \(format.displayName)")
        print("   - 当前时间: \(Date())")
        
        do {
            let exportData = try await self.generateExportableData(for: dictionaryName)
            print("✅ 数据生成成功，开始格式化导出")
            
            let resultURL: URL
            switch format {
            case .markdown:
                print("📝 开始Markdown格式导出")
                resultURL = try await exportToMarkdown(exportData)
            case .pdf:
                print("📄 开始PDF格式导出")
                resultURL = try await exportToPDF(exportData)
            case .text:
                print("📄 开始Text格式导出")
                resultURL = try await exportToText(exportData)
            case .csv:
                print("📊 开始CSV格式导出")
                resultURL = try await exportToCSV(exportData)
            case .json:
                print("📋 开始JSON格式导出")
                resultURL = try await exportToJSON(exportData)
            }
            
            print("🎉 导出完成！文件路径: \(resultURL.path)")
            print("📊 导出统计:")
            print("   - 认识单词: \(exportData.knownWords.count)")
            print("   - 不认识单词: \(exportData.unknownWords.count)")
            print("   - 总计: \(exportData.knownWords.count + exportData.unknownWords.count)")
            
            return resultURL
        } catch {
            print("❌ 导出失败: \(error.localizedDescription)")
            if let exportError = error as? ExportError {
                print("   - 错误类型: \(exportError)")
            }
            print("   - 错误详情: \(error)")
            throw error
        }
    }
    
    /// 生成词汇量测试的可导出数据
    func exportVocabularyTestWords(for dictionaryName: String, format: ExportFormat) async throws -> URL {
        print("🚀 开始导出词汇量测试单词数据")
        print("📋 参数信息:")
        print("   - 词典名称: \(dictionaryName)")
        print("   - 导出格式: \(format.displayName)")
        print("   - 当前时间: \(Date())")
        
        do {
            let exportData = try await generateVocabularyTestExportData(for: dictionaryName)
            print("✅ 词汇量测试数据生成成功，开始格式化导出")
            
            let resultURL: URL
            switch format {
            case .markdown:
                print("📝 开始Markdown格式导出")
                resultURL = try await exportVocabularyTestToMarkdown(exportData)
            case .pdf:
                print("📄 开始PDF格式导出")
                resultURL = try await exportVocabularyTestToPDF(exportData)
            case .text:
                print("📄 开始Text格式导出")
                resultURL = try await exportVocabularyTestToText(exportData)
            case .csv:
                print("📊 开始CSV格式导出")
                resultURL = try await exportVocabularyTestToCSV(exportData)
            case .json:
                print("📋 开始JSON格式导出")
                resultURL = try await exportVocabularyTestToJSON(exportData)
            }
            
            print("🎉 词汇量测试导出完成！文件路径: \(resultURL.path)")
            print("📊 导出统计:")
            print("   - 已掌握单词: \(exportData.masteredWords.count)")
            print("   - 熟悉单词: \(exportData.familiarWords.count)")
            print("   - 不熟悉单词: \(exportData.unfamiliarWords.count)")
            print("   - 总计: \(exportData.totalWords)")
            
            return resultURL
        } catch {
            print("❌ 词汇量测试导出失败: \(error.localizedDescription)")
            if let exportError = error as? ExportError {
                print("   - 错误类型: \(exportError)")
            }
            print("   - 错误详情: \(error)")
            throw error
        }
    }

    /// 生成词汇量测试的可导出数据
    func generateVocabularyTestExportData(for dictionaryName: String) async throws -> VocabularyTestExportData {
        print("📊 开始生成词汇量测试导出数据")
        print("   - 目标词典: \(dictionaryName)")
        
        guard !dictionaryName.isEmpty else {
            print("❌ 词典名称为空")
            throw ExportError.noDataFound
        }
        
        do {
            // 获取指定词典的所有测试记录
            print("🔍 查询词汇量测试记录...")
            
            // 首先尝试通过dictionaryName获取对应的dictionaryFileName
            let dictionaryFileName: String
            do {
                let dictionaries = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[DictionaryInfo], Error>) in
                    var cancellable: AnyCancellable?
                    var hasResumed = false
                    
                    // 设置30秒超时
                    let timeoutTask = Task {
                        try? await Task.sleep(nanoseconds: 30_000_000_000)
                        if !hasResumed {
                            hasResumed = true
                            cancellable?.cancel()
                            continuation.resume(throwing: VocabularyTestError.timeout)
                        }
                    }
                    
                    cancellable = dictionaryService.getAvailableDictionaries()
                        .sink(
                            receiveCompletion: { completion in
                                timeoutTask.cancel()
                                guard !hasResumed else { return }
                                hasResumed = true
                                
                                if case .failure(let error) = completion {
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            },
                            receiveValue: { dictionaries in
                                timeoutTask.cancel()
                                guard !hasResumed else { return }
                                hasResumed = true
                                
                                continuation.resume(returning: dictionaries)
                                cancellable?.cancel()
                            }
                        )
                }
                
                if let dictionary = dictionaries.first(where: { $0.name == dictionaryName }) {
                    dictionaryFileName = dictionary.fileName
                    print("   - 找到词典文件名: \(dictionaryFileName)")
                } else {
                    // 如果找不到对应的词典，直接使用dictionaryName作为fileName
                    dictionaryFileName = dictionaryName
                    print("   - 使用词典名称作为文件名: \(dictionaryFileName)")
                }
            } catch {
                // 如果获取词典列表失败，直接使用dictionaryName作为fileName
                dictionaryFileName = dictionaryName
                print("   - 获取词典列表失败，使用词典名称作为文件名: \(dictionaryFileName)")
            }
            
            let descriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.dictionaryFileName == dictionaryFileName
                },
                sortBy: [SortDescriptor(\.word)]
            )
            
            let testedWords = try modelContext.fetch(descriptor)
            print("✅ 查询完成，找到 \(testedWords.count) 个测试记录")
            
            // 添加详细的调试信息
            if testedWords.isEmpty {
                print("⚠️ 未找到任何测试记录，开始诊断...")
                print("🔍 查询条件: dictionaryFileName == '\(dictionaryFileName)'")
                
                // 查询所有TestedWord记录进行对比
                let allDescriptor = FetchDescriptor<TestedWord>(sortBy: [SortDescriptor(\.testedAt, order: .reverse)])
                let allTestedWords = try modelContext.fetch(allDescriptor)
                print("📊 数据库中总共有 \(allTestedWords.count) 个TestedWord记录")
                
                if !allTestedWords.isEmpty {
                    print("🔍 最近的5条记录:")
                    for (index, word) in allTestedWords.prefix(5).enumerated() {
                        print("   \(index + 1). 单词: '\(word.word)', dictionaryName: '\(word.dictionaryName)', dictionaryFileName: '\(word.dictionaryFileName)', 测试时间: \(word.testedAt)")
                    }
                    
                    // 检查是否有匹配dictionaryName的记录
                    let nameMatches = allTestedWords.filter { $0.dictionaryName == dictionaryName }
                    print("🔍 匹配dictionaryName '\(dictionaryName)' 的记录: \(nameMatches.count) 个")
                    
                    if !nameMatches.isEmpty {
                        let uniqueFileNames = Set(nameMatches.map { $0.dictionaryFileName })
                        print("🔍 这些记录的dictionaryFileName值: \(Array(uniqueFileNames))")
                    }
                }
                
                throw ExportError.noDataFound
            }
            
            // 按掌握程度分类，并去重处理
            print("🔄 开始按掌握程度分类单词...")
            var masteredWords: [VocabularyTestWord] = []
            var familiarWords: [VocabularyTestWord] = []
            var unfamiliarWords: [VocabularyTestWord] = []
            var processedWords: Set<String> = [] // 用于去重
            var processedCount = 0
            
            // 按测试时间倒序排序，确保使用最新的测试结果
            let sortedTestedWords = testedWords.sorted { $0.testedAt > $1.testedAt }
            
            for testedWord in sortedTestedWords {
                // 跳过已处理的单词，避免重复
                if processedWords.contains(testedWord.word) {
                    continue
                }
                processedWords.insert(testedWord.word)
                
                processedCount += 1
                if processedCount % 50 == 0 {
                    print("   - 已处理: \(processedCount)/\(testedWords.count)")
                }
                
                // 从词典服务获取单词详细信息
                var dictionaryWord = dictionaryService.lookupWord(testedWord.word, context: "")
                
                // 如果标准查找失败，尝试使用考研词典查找
                if dictionaryWord == nil {
                    if let kaoyanDetails = dictionaryService.getKaoyanWordDetails(testedWord.word) {
                        // 将考研词典数据转换为 DictionaryWord
                        let definitions = kaoyanDetails.translations.map { translation in
                            WordDefinition(
                                partOfSpeech: PartOfSpeech.fromString(translation.pos) ?? .noun,
                                meaning: translation.tranCn,
                                englishMeaning: translation.tranOther,
                                examples: kaoyanDetails.sentences.map { $0.sContent },
                                contextKeywords: []
                            )
                        }
                        
                        dictionaryWord = DictionaryWord(
                            word: kaoyanDetails.word,
                            phonetic: kaoyanDetails.usPhone,
                            definitions: definitions,
                            frequency: 1000,
                            difficulty: .medium,
                            tags: []
                        )
                        print("   ✅ 通过考研词典找到单词定义: \(testedWord.word)")
                    } else {
                        print("   ❌ 未找到单词定义: \(testedWord.word)")
                    }
                }
                
                let vocabularyTestWord = VocabularyTestWord(from: testedWord, dictionaryWord: dictionaryWord)
                
                // 根据掌握程度分类（统一使用枚举，避免字符串别名偏差）
                switch testedWord.masteryLevelEnum {
                case .mastered:
                    masteredWords.append(vocabularyTestWord)
                case .familiar:
                    familiarWords.append(vocabularyTestWord)
                case .unfamiliar:
                    unfamiliarWords.append(vocabularyTestWord)
                }
            }
            
            print("✅ 词汇量测试数据处理完成")
            print("📈 分类统计:")
            print("   - 已掌握单词: \(masteredWords.count)")
            print("   - 熟悉单词: \(familiarWords.count)")
            print("   - 不熟悉单词: \(unfamiliarWords.count)")
            print("   - 总计: \(masteredWords.count + familiarWords.count + unfamiliarWords.count)")
            
            let result = VocabularyTestExportData(
                dictionaryName: dictionaryName,
                testDate: Date(), // 使用当前时间作为测试时间
                exportDate: Date(),
                masteredWords: masteredWords,
                familiarWords: familiarWords,
                unfamiliarWords: unfamiliarWords
            )
            
            print("🎯 词汇量测试导出数据生成完成")
            return result
            
        } catch {
            print("❌ 生成词汇量测试导出数据失败: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   - 错误域: \(nsError.domain)")
                print("   - 错误代码: \(nsError.code)")
                print("   - 用户信息: \(nsError.userInfo)")
            }
            throw error
        }
    }

    // MARK: - Private Methods - Vocabulary Test Markdown Export
    
    private func exportVocabularyTestToMarkdown(_ data: VocabularyTestExportData) async throws -> URL {
        print("📝 开始生成词汇量测试Markdown文档")
        print("   - 词典: \(data.dictionaryName)")
        print("   - 已掌握单词数: \(data.masteredWords.count)")
        print("   - 熟悉单词数: \(data.familiarWords.count)")
        print("   - 不熟悉单词数: \(data.unfamiliarWords.count)")
        
        do {
            print("🔄 生成Markdown内容...")
            let content = generateVocabularyTestMarkdownContent(data)
            print("✅ Markdown内容生成完成，长度: \(content.count) 字符")
            
            let fileName = generateVocabularyTestFileName(for: data, format: .markdown)
            print("📁 文件名: \(fileName)")
            
            let documentsURL = try getDocumentsURL()
            let fileURL = documentsURL.appendingPathComponent(fileName)
            print("📍 文件路径: \(fileURL.path)")
            
            // 确保目录存在
            let directoryURL = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directoryURL.path) {
                print("📂 创建目录: \(directoryURL.path)")
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            
            print("💾 写入文件...")
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ 词汇量测试Markdown文件已保存: \(fileURL.path)")
            
            // 验证文件是否成功创建
            if fileManager.fileExists(atPath: fileURL.path) {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("📊 文件验证成功，大小: \(fileSize) 字节")
            } else {
                print("❌ 文件创建失败")
                throw ExportError.fileCreationFailed
            }
            
            return fileURL
        } catch {
            print("❌ 词汇量测试Markdown导出失败: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   - 错误域: \(nsError.domain)")
                print("   - 错误代码: \(nsError.code)")
            }
            throw error
        }
    }
    
    private func generateVocabularyTestMarkdownContent(_ data: VocabularyTestExportData) -> String {
        var content = ""
        
        // 标题
        content += "# \(data.dictionaryName) 词汇量测试单词分类\n\n"
        
        // 导出信息
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        content += "**导出时间**: \(formatter.string(from: data.exportDate))\n"
        content += "**总词数**: \(data.totalWords)\n\n"
        
        // 统计概览
        content += "## 📊 测试结果统计\n\n"
        content += "| 掌握程度 | 单词数量 | 占比 |\n"
        content += "|---------|---------|------|\n"
        let masteryRate = data.totalWords > 0 ? Double(data.masteredWords.count) / Double(data.totalWords) * 100 : 0
        let familiarRate = data.totalWords > 0 ? Double(data.familiarWords.count) / Double(data.totalWords) * 100 : 0
        let unfamiliarRate = data.totalWords > 0 ? Double(data.unfamiliarWords.count) / Double(data.totalWords) * 100 : 0
        
        content += "| 已掌握 | \(data.masteredWords.count) | \(String(format: "%.1f", masteryRate))% |\n"
        content += "| 熟悉 | \(data.familiarWords.count) | \(String(format: "%.1f", familiarRate))% |\n"
        content += "| 不熟悉 | \(data.unfamiliarWords.count) | \(String(format: "%.1f", unfamiliarRate))% |\n\n"
        
        // 已掌握的单词
        if !data.masteredWords.isEmpty {
            content += "## ✅ 已掌握的单词 (\(data.masteredWords.count)个)\n\n"
            for word in data.masteredWords {
                content += generateVocabularyTestWordEntry(word)
            }
            content += "\n"
        }
        
        // 熟悉的单词
        if !data.familiarWords.isEmpty {
            content += "## 🔄 熟悉的单词 (\(data.familiarWords.count)个)\n\n"
            for word in data.familiarWords {
                content += generateVocabularyTestWordEntry(word)
            }
            content += "\n"
        }
        
        // 不熟悉的单词
        if !data.unfamiliarWords.isEmpty {
            content += "## ❌ 不熟悉的单词 (\(data.unfamiliarWords.count)个)\n\n"
            for word in data.unfamiliarWords {
                content += generateVocabularyTestWordEntry(word)
            }
        }
        
        return content
    }
    
    private func generateVocabularyTestWordEntry(_ word: VocabularyTestWord) -> String {
        var entry = "### \(word.word)\n\n"
        entry += "**释义**: \(word.definition)\n\n"
        
        if let example = word.example, !example.isEmpty {
            entry += "**例句**: \(example)\n\n"
            
            // 尝试获取例句释义
            if let exampleTranslation = getExampleTranslation(example) {
                entry += "**例句释义**: \(exampleTranslation)\n\n"
            }
        }
        
        // 添加测试信息
        let testFormatter = DateFormatter()
        testFormatter.dateStyle = .short
        testFormatter.timeStyle = .short
        entry += "**掌握程度**: \(word.masteryLevel)\n"
        entry += "**测试时间**: \(testFormatter.string(from: word.testDate))\n"
        if word.responseTime > 0 {
            entry += "**反应时间**: \(String(format: "%.1f", word.responseTime))秒\n"
        }
        
        entry += "\n---\n\n"
        return entry
    }
    
    /// 获取例句的中文释义
    private func getExampleTranslation(_ example: String) -> String? {
        // 这里可以集成翻译服务来获取例句的中文释义
        // 目前先返回nil，表示暂时不提供例句释义功能
        // 未来可以通过调用翻译API或查询本地翻译数据库来实现
        return nil
    }

    // MARK: - Private Methods - Vocabulary Test PDF Export
    
    private func exportVocabularyTestToPDF(_ data: VocabularyTestExportData) async throws -> URL {
        print("📄 开始生成词汇量测试PDF文档")
        
        // 暂时使用Markdown格式导出为文本文件
        let content = generateVocabularyTestMarkdownContent(data)
        let fileName = generateVocabularyTestFileName(for: data, format: .pdf)
        
        let documentsURL = try getDocumentsURL()
        let fileURL = documentsURL.appendingPathComponent(fileName.replacingOccurrences(of: ".pdf", with: ".txt"))
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        print("✅ 词汇量测试文件已保存: \(fileURL.path)")
        
        return fileURL
    }
    
    private func generateVocabularyTestFileName(for data: VocabularyTestExportData, format: ExportFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let dateString = formatter.string(from: data.exportDate)
        
        return "\(data.dictionaryName)_词汇量测试单词分类_\(dateString).\(format.fileExtension)"
    }

    private func exportToMarkdown(_ data: ExportableTestResult) async throws -> URL {
        print("📝 开始生成Markdown文档")
        print("   - 词典: \(data.dictionaryName)")
        print("   - 认识单词数: \(data.knownWords.count)")
        print("   - 不认识单词数: \(data.unknownWords.count)")
        
        do {
            print("🔄 生成Markdown内容...")
            let content = generateMarkdownContent(data)
            print("✅ Markdown内容生成完成，长度: \(content.count) 字符")
            
            let fileName = generateFileName(for: data, format: .markdown)
            print("📁 文件名: \(fileName)")
            
            let documentsURL = try getDocumentsURL()
            let fileURL = documentsURL.appendingPathComponent(fileName)
            print("📍 文件路径: \(fileURL.path)")
            
            // 确保目录存在
            let directoryURL = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directoryURL.path) {
                print("📂 创建目录: \(directoryURL.path)")
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            
            print("💾 写入文件...")
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Markdown文件已保存: \(fileURL.path)")
            
            // 验证文件是否成功创建
            if fileManager.fileExists(atPath: fileURL.path) {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("📊 文件验证成功，大小: \(fileSize) 字节")
            } else {
                print("❌ 文件创建失败")
                throw ExportError.fileCreationFailed
            }
            
            return fileURL
        } catch {
            print("❌ Markdown导出失败: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   - 错误域: \(nsError.domain)")
                print("   - 错误代码: \(nsError.code)")
            }
            throw error
        }
    }
    
    private func generateMarkdownContent(_ data: ExportableTestResult) -> String {
        var content = ""
        
        // 标题
        content += "# \(data.dictionaryName) 测试单词本\n\n"
        
        // 导出信息
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        content += "**导出时间**: \(formatter.string(from: data.exportDate))\n"
        content += "**总词数**: \(data.totalWords)\n\n"
        
        // 认识的单词
        if !data.knownWords.isEmpty {
            content += "## 认识的单词 (\(data.knownWordsCount)个)\n\n"
            for word in data.knownWords {
                content += generateMarkdownWordEntry(word)
            }
            content += "\n"
        }
        
        // 不认识的单词
        if !data.unknownWords.isEmpty {
            content += "## 不认识的单词 (\(data.unknownWordsCount)个)\n\n"
            for word in data.unknownWords {
                content += generateMarkdownWordEntry(word)
            }
        }
        
        return content
    }
    
    private func generateMarkdownWordEntry(_ word: ExportableWord) -> String {
        var entry = "### \(word.word)\n\n"
        entry += "**释义**: \(word.definition)\n\n"
        
        if let example = word.example, !example.isEmpty {
            entry += "**例句**: \(example)\n\n"
        }
        
        entry += "---\n\n"
        return entry
    }
    
    // MARK: - Private Methods - PDF Export
    
    private func exportToPDF(_ data: ExportableTestResult) async throws -> URL {
        print("📄 开始生成PDF文档")
        print("   - 词典: \(data.dictionaryName)")
        print("   - 认识单词数: \(data.knownWords.count)")
        print("   - 不认识单词数: \(data.unknownWords.count)")
        
        do {
            let fileName = generateFileName(for: data, format: .pdf)
            print("📁 PDF文件名: \(fileName)")
            
            let documentsURL = try getDocumentsURL()
            let fileURL = documentsURL.appendingPathComponent(fileName)
            print("📍 PDF文件路径: \(fileURL.path)")
            
            // 确保目录存在
            let directoryURL = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directoryURL.path) {
                print("📂 创建PDF目录: \(directoryURL.path)")
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            
            print("🎨 开始PDF渲染...")
            let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // A4 size
            
            UIGraphicsBeginPDFContextToFile(fileURL.path, pageRect, nil)
            
            guard UIGraphicsGetCurrentContext() != nil else {
                print("❌ 无法创建PDF上下文")
                throw ExportError.fileCreationFailed
            }
            
            UIGraphicsBeginPDFPage()
            var currentY: CGFloat = 50
            
            // 绘制标题
            print("✏️ 绘制PDF标题...")
            currentY = drawPDFTitle("词汇测试结果 - \(data.dictionaryName)", at: currentY, pageRect: pageRect)
            currentY += 20
            
            // 绘制统计信息
            let statsText = "导出时间: \(DateFormatter.localizedString(from: data.exportDate, dateStyle: .medium, timeStyle: .short))\n认识单词: \(data.knownWords.count) 个\n不认识单词: \(data.unknownWords.count) 个"
            currentY = drawPDFText(statsText, at: currentY, pageRect: pageRect)
            currentY += 30
            
            // 绘制认识的单词
            if !data.knownWords.isEmpty {
                print("✏️ 绘制认识的单词 (\(data.knownWords.count) 个)...")
                currentY = drawPDFSectionTitle("认识的单词", at: currentY, pageRect: pageRect)
                currentY += 10
                
                for (index, word) in data.knownWords.enumerated() {
                    if currentY > pageRect.height - 100 {
                        UIGraphicsBeginPDFPage()
                        currentY = 50
                    }
                    currentY = drawPDFWordEntry(word, at: currentY, pageRect: pageRect)
                    
                    if (index + 1) % 20 == 0 {
                        print("   - 已绘制认识单词: \(index + 1)/\(data.knownWords.count)")
                    }
                }
            }
            
            // 绘制不认识的单词
            if !data.unknownWords.isEmpty {
                print("✏️ 绘制不认识的单词 (\(data.unknownWords.count) 个)...")
                if currentY > pageRect.height - 200 {
                    UIGraphicsBeginPDFPage()
                    currentY = 50
                }
                
                currentY = drawPDFSectionTitle("不认识的单词", at: currentY, pageRect: pageRect)
                currentY += 10
                
                for (index, word) in data.unknownWords.enumerated() {
                    if currentY > pageRect.height - 100 {
                        UIGraphicsBeginPDFPage()
                        currentY = 50
                    }
                    currentY = drawPDFWordEntry(word, at: currentY, pageRect: pageRect)
                    
                    if (index + 1) % 20 == 0 {
                        print("   - 已绘制不认识单词: \(index + 1)/\(data.unknownWords.count)")
                    }
                }
            }
            
            UIGraphicsEndPDFContext()
            print("✅ PDF渲染完成")
            
            // 验证PDF文件
            if fileManager.fileExists(atPath: fileURL.path) {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("📊 PDF文件验证成功，大小: \(fileSize) 字节")
                
                // 验证PDF是否可读
                if let pdfDocument = PDFDocument(url: fileURL) {
                    let pageCount = pdfDocument.pageCount
                    print("📄 PDF页数: \(pageCount)")
                } else {
                    print("⚠️ PDF文件可能损坏，但文件已创建")
                }
            } else {
                print("❌ PDF文件创建失败")
                throw ExportError.fileCreationFailed
            }
            
            return fileURL
        } catch {
            print("❌ PDF导出失败: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   - 错误域: \(nsError.domain)")
                print("   - 错误代码: \(nsError.code)")
            }
            throw error
        }
    }
    
    private func drawPDFTitle(_ title: String, at y: CGFloat, pageRect: CGRect) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: 24)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        let margin: CGFloat = 50
        let rect = CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 40)
        title.draw(in: rect, withAttributes: attributes)
        
        return y + 50
    }
    
    private func drawPDFSectionTitle(_ title: String, at y: CGFloat, pageRect: CGRect) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: 18)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        let margin: CGFloat = 50
        let rect = CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 30)
        title.draw(in: rect, withAttributes: attributes)
        
        return y + 40
    }
    
    private func drawPDFText(_ text: String, at y: CGFloat, pageRect: CGRect) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        let margin: CGFloat = 50
        let rect = CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 20)
        text.draw(in: rect, withAttributes: attributes)
        
        return y + 25
    }
    
    private func drawPDFWordEntry(_ word: ExportableWord, at y: CGFloat, pageRect: CGRect) -> CGFloat {
        var currentY = y
        let margin: CGFloat = 50
        let contentWidth = pageRect.width - 2 * margin
        
        // 单词标题
        let wordFont = UIFont.boldSystemFont(ofSize: 16)
        let wordAttributes: [NSAttributedString.Key: Any] = [
            .font: wordFont,
            .foregroundColor: UIColor.black
        ]
        
        let wordRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 25)
        word.word.draw(in: wordRect, withAttributes: wordAttributes)
        currentY += 30
        
        // 释义
        let definitionFont = UIFont.systemFont(ofSize: 14)
        let definitionAttributes: [NSAttributedString.Key: Any] = [
            .font: definitionFont,
            .foregroundColor: UIColor.black
        ]
        
        let definitionText = "释义: \(word.definition)"
        let definitionRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 20)
        definitionText.draw(in: definitionRect, withAttributes: definitionAttributes)
        currentY += 25
        
        // 例句
        if let example = word.example, !example.isEmpty {
            let exampleText = "例句: \(example)"
            let exampleRect = CGRect(x: margin + 20, y: currentY, width: contentWidth - 20, height: 40)
            exampleText.draw(in: exampleRect, withAttributes: definitionAttributes)
            currentY += 45
        }
        
        currentY += 10 // 间距
        return currentY
    }
    
    // MARK: - Helper Methods
    
    private func generateFileName(for data: ExportableTestResult, format: ExportFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let dateString = formatter.string(from: data.exportDate)
        
        return "\(data.dictionaryName)_测试单词本_\(dateString).\(format.fileExtension)"
    }
    
    private func getDocumentsURL() throws -> URL {
        // 优先尝试使用下载目录，这样文件会出现在"文件-下载"中
        if let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            return downloadsURL
        }
        
        // 如果下载目录不可用，回退到文档目录
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "TestResultExportService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法访问文档目录"])
        }
        return documentsURL
    }
    
    /// 生成可导出的测试结果数据
    public func generateExportableData(for dictionaryName: String) async throws -> ExportableTestResult {
        print("🔍 开始生成可导出数据")
        print("📋 词典名称: \(dictionaryName)")
        
        // 检查词典加载状态
        if dictionaryName.contains("考研") || dictionaryName.contains("kaoyan") || dictionaryName.contains("KaoYan") {
            print("📚 检查考研词典加载状态...")
            
            // 如果考研词典未加载完成，等待加载
            if !dictionaryService.isKaoyanDictionaryReady() {
                print("⏳ 考研词典正在加载中，等待完成...")
                do {
                    let success = try await dictionaryService.waitForKaoyanDictionary()
                    if success {
                        print("✅ 考研词典加载完成")
                    } else {
                        print("❌ 考研词典加载失败")
                        throw ExportError.dictionaryNotReady
                    }
                } catch {
                    print("❌ 考研词典加载失败: \(error.localizedDescription)")
                    throw ExportError.dictionaryNotReady
                }
            }
        }
        
        do {
            // 查询所有已测试的单词，不限制特定测试会话
            let testedWordsFetch = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.dictionaryFileName.contains(dictionaryName) || 
                    word.dictionaryName == dictionaryName
                },
                sortBy: [SortDescriptor(\.testedAt, order: .reverse)]
            )
            
            let testedWords = try modelContext.fetch(testedWordsFetch)
            print("✅ 获取已完成测试结果: \(testedWords.count) 个")
            
            guard !testedWords.isEmpty else {
                print("❌ 未找到测试数据")
                throw ExportError.noDataFound
            }
            
            var allTestedWords: [ExportableWord] = []
            var failedLookups: [String] = []
            var processedCount = 0
            
            print("🔄 开始处理 \(testedWords.count) 个测试记录...")
            
            for testedWord in testedWords {
                processedCount += 1
                
                // 每处理100个单词输出一次进度
                if processedCount % 100 == 0 {
                    print("   - 已处理: \(processedCount)/\(testedWords.count)")
                }
                
                // 根据词典类型选择合适的查找方法
                var dictionaryWord: DictionaryWord?
                
                if dictionaryName.contains("考研") || dictionaryName.contains("kaoyan") || dictionaryName.contains("KaoYan") {
                    // 使用考研词典查找
                    if let kaoyanDetails = dictionaryService.getKaoyanWordDetails(testedWord.word) {
                        let definitions = kaoyanDetails.translations.map { translation in
                            WordDefinition(
                                partOfSpeech: PartOfSpeech.fromString(translation.pos) ?? .noun,
                                meaning: translation.tranCn,
                                englishMeaning: translation.tranOther,
                                examples: kaoyanDetails.sentences.map { $0.sContent },
                                contextKeywords: []
                            )
                        }
                        
                        dictionaryWord = DictionaryWord(
                            word: kaoyanDetails.word,
                            phonetic: kaoyanDetails.usPhone,
                            definitions: definitions,
                            frequency: 1000,
                            difficulty: .medium,
                            tags: []
                        )
                    }
                } else {
                    // 使用基础词典查找
                    dictionaryWord = dictionaryService.lookupWord(testedWord.word, context: "")
                }
                
                if let dictionaryWord = dictionaryWord {
                    let exportableWord = ExportableWord(
                        from: testedWord,
                        dictionaryWord: dictionaryWord
                    )
                    allTestedWords.append(exportableWord)
                } else {
                    failedLookups.append(testedWord.word)
                }
            }
            
            print("✅ 单词处理完成")
            print("   - 成功处理: \(allTestedWords.count) 个")
            if !failedLookups.isEmpty {
                print("   - 查找失败: \(failedLookups.count) 个")
                if failedLookups.count <= 10 {
                    print("   - 失败单词: \(failedLookups.joined(separator: ", "))")
                } else {
                    print("   - 失败单词示例: \(failedLookups.prefix(10).joined(separator: ", "))...")
                }
            }

            // 分离已知和未知单词 - 使用正确的掌握度映射
            let knownWords = allTestedWords.filter { 
                $0.masteryLevel == MasteryLevel.mastered.rawValue || 
                $0.masteryLevel == MasteryLevel.familiar.rawValue 
            }
            let unknownWords = allTestedWords.filter { 
                $0.masteryLevel == MasteryLevel.unfamiliar.rawValue 
            }
            
            let result = ExportableTestResult(
                dictionaryName: dictionaryName,
                testDate: Date(), // 使用当前时间作为测试时间
                exportDate: Date(),
                knownWords: knownWords,
                unknownWords: unknownWords
            )
            
            print("✅ 可导出数据生成完成，包含 \(allTestedWords.count) 个单词")
            print("   - 已知单词: \(knownWords.count)")
            print("   - 未知单词: \(unknownWords.count)")
            if !failedLookups.isEmpty {
                print("   - 查找失败: \(failedLookups.count)")
            }
            return result
            
        } catch {
            print("❌ 生成可导出数据失败: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   - 错误域: \(nsError.domain)")
                print("   - 错误代码: \(nsError.code)")
                print("   - 用户信息: \(nsError.userInfo)")
            }
            throw error
        }
    }
}

/// 导出错误枚举
enum ExportError: LocalizedError {
    case noDataFound
    case fileCreationFailed
    case invalidFormat
    case dictionaryNotReady
    
    var errorDescription: String? {
        switch self {
        case .noDataFound:
            return "未找到测试数据"
        case .fileCreationFailed:
            return "文件创建失败"
        case .invalidFormat:
            return "不支持的导出格式"
        case .dictionaryNotReady:
            return "词典尚未加载完成，请稍后再试"
        }
    }
}
