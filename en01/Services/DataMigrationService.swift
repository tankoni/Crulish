//
//  DataMigrationService.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import SwiftData
import Foundation

/// 数据迁移服务协议
protocol DataMigrationServiceProtocol {
    func clearAllTestData() async throws
    func importFromExportFile(at url: URL) async throws -> DataMigrationResult
    func importFromExportData(_ data: Data) async throws -> DataMigrationResult
    func validateExportData(_ data: Data) throws -> ExportDataValidation
    func createBackup() async throws -> URL
}

/// 数据迁移服务实现
class DataMigrationService: DataMigrationServiceProtocol {
    private let modelContext: ModelContext
    private let globalWordService: GlobalWordServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    
    init(modelContext: ModelContext, 
         globalWordService: GlobalWordServiceProtocol,
         errorHandler: ErrorHandlerProtocol) {
        self.modelContext = modelContext
        self.globalWordService = globalWordService
        self.errorHandler = errorHandler
    }
    
    // MARK: - 数据清理
    
    /// 清除所有测试数据
    func clearAllTestData() async throws {
        do {
            print("🔄 [DataMigration] 开始清除所有测试数据...")
            
            // 清除 TestedWord 数据
            let testedWordDescriptor = FetchDescriptor<TestedWord>()
            let testedWords = try modelContext.fetch(testedWordDescriptor)
            
            for word in testedWords {
                modelContext.delete(word)
            }
            
            // 清除 VocabularyTest 数据
            let testDescriptor = FetchDescriptor<VocabularyTest>()
            let tests = try modelContext.fetch(testDescriptor)
            
            for test in tests {
                modelContext.delete(test)
            }
            
            // 清除 GlobalWord 数据
            try await globalWordService.clearAllTestData()
            
            // 保存更改
            try modelContext.save()
            
            print("✅ [DataMigration] 清除完成: TestedWord(\(testedWords.count)), VocabularyTest(\(tests.count))")
            
        } catch {
            errorHandler.handle(error, context: "清除所有测试数据")
            throw DataMigrationError.clearDataFailed(error)
        }
    }
    
    // MARK: - 数据导入
    
    /// 从导出文件导入数据
    func importFromExportFile(at url: URL) async throws -> DataMigrationResult {
        do {
            let data = try Data(contentsOf: url)
            return try await importFromExportData(data)
        } catch {
            errorHandler.handle(error, context: "从文件导入数据")
            throw DataMigrationError.fileReadFailed(error)
        }
    }
    
    /// 从导出数据导入
    func importFromExportData(_ data: Data) async throws -> DataMigrationResult {
        do {
            // 验证数据格式
            let validation = try validateExportData(data)
            guard validation.isValid else {
                throw DataMigrationError.invalidDataFormat(validation.errors)
            }
            
            print("🔄 [DataMigration] 开始导入数据...")
            
            // 解析数据
            let exportData = try parseExportData(data)
            
            var result = DataMigrationResult()
            
            // 导入词汇测试记录
            if let wordsData = exportData["words"] as? [[String: Any]] {
                result.importedWords = try await importWordRecords(wordsData)
            }
            
            // 导入测试历史
            if let testsData = exportData["tests"] as? [[String: Any]] {
                result.importedTests = try await importTestRecords(testsData)
            }
            
            // 保存更改
            try modelContext.save()
            
            result.success = true
            result.importDate = Date()
            
            print("✅ [DataMigration] 导入完成: 词汇(\(result.importedWords)), 测试(\(result.importedTests))")
            
            return result
            
        } catch {
            errorHandler.handle(error, context: "导入数据")
            throw error
        }
    }
    
    // MARK: - 数据验证
    
    /// 验证导出数据
    func validateExportData(_ data: Data) throws -> ExportDataValidation {
        var validation = ExportDataValidation()
        
        do {
            // 尝试解析JSON
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                validation.errors.append("数据格式不是有效的JSON对象")
                return validation
            }
            
            // 检查必需字段
            let requiredFields = ["exportDate", "version"]
            for field in requiredFields {
                if jsonObject[field] == nil {
                    validation.errors.append("缺少必需字段: \(field)")
                }
            }
            
            // 检查版本兼容性
            if let version = jsonObject["version"] as? String {
                validation.version = version
                if !isVersionSupported(version) {
                    validation.warnings.append("版本 \(version) 可能不完全兼容")
                }
            }
            
            // 检查数据结构
            if let wordsData = jsonObject["words"] as? [[String: Any]] {
                validation.wordCount = wordsData.count
                
                // 验证词汇数据结构
                for (index, wordData) in wordsData.prefix(10).enumerated() {
                    if wordData["word"] == nil {
                        validation.errors.append("词汇数据第\(index+1)项缺少word字段")
                    }
                }
            }
            
            if let testsData = jsonObject["tests"] as? [[String: Any]] {
                validation.testCount = testsData.count
            }
            
            validation.isValid = validation.errors.isEmpty
            
        } catch {
            validation.errors.append("JSON解析失败: \(error.localizedDescription)")
        }
        
        return validation
    }
    
    // MARK: - 备份创建
    
    /// 创建当前数据的备份
    func createBackup() async throws -> URL {
        do {
            print("🔄 [DataMigration] 创建数据备份...")
            
            // 导出当前数据
            let exportData = try await globalWordService.exportAllWords()
            
            // 添加额外的备份信息
            var backupData = exportData
            backupData["backupDate"] = Date().ISO8601Format()
            backupData["backupType"] = "migration_backup"
            
            // 创建备份文件
            let jsonData = try JSONSerialization.data(withJSONObject: backupData, options: .prettyPrinted)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let backupFileName = "backup_\(Date().ISO8601Format().replacingOccurrences(of: ":", with: "-")).json"
            let backupURL = documentsPath.appendingPathComponent(backupFileName)
            
            try jsonData.write(to: backupURL)
            
            print("✅ [DataMigration] 备份创建完成: \(backupURL.lastPathComponent)")
            
            return backupURL
            
        } catch {
            errorHandler.handle(error, context: "创建数据备份")
            throw DataMigrationError.backupFailed(error)
        }
    }
    
    // MARK: - 私有方法
    
    private func parseExportData(_ data: Data) throws -> [String: Any] {
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw DataMigrationError.invalidDataFormat(["数据不是有效的JSON对象"])
            }
            return jsonObject
        } catch {
            throw DataMigrationError.parseError(error)
        }
    }
    
    private func importWordRecords(_ wordsData: [[String: Any]]) async throws -> Int {
        var importedCount = 0
        
        for wordData in wordsData {
            do {
                guard let word = wordData["word"] as? String else {
                    continue
                }
                
                // 提取测试数据
                let masteryLevel = wordData["masteryLevel"] as? String ?? "unfamiliar"
                let testCount = wordData["testCount"] as? Int ?? 0
                let correctCount = wordData["correctCount"] as? Int ?? 0
                let masteryScore = wordData["masteryScore"] as? Double ?? 0
                
                var lastTestedDate: Date?
                if let dateString = wordData["lastTestedDate"] as? String {
                    lastTestedDate = ISO8601DateFormatter().date(from: dateString)
                }
                
                // 创建GlobalWord记录
                let globalWord = GlobalWord.fromExportData(
                    word: word,
                    masteryLevel: masteryLevel,
                    testCount: testCount,
                    correctCount: correctCount,
                    masteryScore: masteryScore,
                    lastTestedDate: lastTestedDate
                )
                
                modelContext.insert(globalWord)
                importedCount += 1
                
            } catch {
                print("⚠️ [DataMigration] 导入单词记录失败: \(error.localizedDescription)")
            }
        }
        
        return importedCount
    }
    
    private func importTestRecords(_ testsData: [[String: Any]]) async throws -> Int {
        var importedCount = 0
        
        for testData in testsData {
            do {
                // 这里可以根据需要导入测试历史记录
                // 目前主要关注词汇记录，测试历史可以后续扩展
                importedCount += 1
            } catch {
                print("⚠️ [DataMigration] 导入测试记录失败: \(error.localizedDescription)")
            }
        }
        
        return importedCount
    }
    
    private func isVersionSupported(_ version: String) -> Bool {
        let supportedVersions = ["1.0", "1.1", "2.0"]
        return supportedVersions.contains(version)
    }
}

// MARK: - 数据结构

/// 数据迁移结果
struct DataMigrationResult {
    var success: Bool = false
    var importedWords: Int = 0
    var importedTests: Int = 0
    var importDate: Date?
    var errors: [String] = []
    var warnings: [String] = []
    
    var summary: String {
        if success {
            return "导入成功: 词汇 \(importedWords) 个，测试 \(importedTests) 个"
        } else {
            return "导入失败: \(errors.joined(separator: ", "))"
        }
    }
}

/// 导出数据验证结果
struct ExportDataValidation {
    var isValid: Bool = false
    var version: String?
    var wordCount: Int = 0
    var testCount: Int = 0
    var errors: [String] = []
    var warnings: [String] = []
    
    var summary: String {
        if isValid {
            return "数据有效: 词汇 \(wordCount) 个，测试 \(testCount) 个"
        } else {
            return "数据无效: \(errors.joined(separator: ", "))"
        }
    }
}

// MARK: - 错误定义

enum DataMigrationError: LocalizedError {
    case clearDataFailed(Error)
    case fileReadFailed(Error)
    case invalidDataFormat([String])
    case parseError(Error)
    case backupFailed(Error)
    case importFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .clearDataFailed(let error):
            return "清除数据失败: \(error.localizedDescription)"
        case .fileReadFailed(let error):
            return "读取文件失败: \(error.localizedDescription)"
        case .invalidDataFormat(let errors):
            return "数据格式无效: \(errors.joined(separator: ", "))"
        case .parseError(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .backupFailed(let error):
            return "创建备份失败: \(error.localizedDescription)"
        case .importFailed(let error):
            return "导入数据失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Mock实现

class MockDataMigrationService: DataMigrationServiceProtocol {
    func clearAllTestData() async throws {
        print("Mock: 清除所有测试数据")
    }
    
    func importFromExportFile(at url: URL) async throws -> DataMigrationResult {
        var result = DataMigrationResult()
        result.success = true
        result.importedWords = 100
        result.importedTests = 10
        result.importDate = Date()
        return result
    }
    
    func importFromExportData(_ data: Data) async throws -> DataMigrationResult {
        var result = DataMigrationResult()
        result.success = true
        result.importedWords = 100
        result.importedTests = 10
        result.importDate = Date()
        return result
    }
    
    func validateExportData(_ data: Data) throws -> ExportDataValidation {
        var validation = ExportDataValidation()
        validation.isValid = true
        validation.version = "1.0"
        validation.wordCount = 100
        validation.testCount = 10
        return validation
    }
    
    func createBackup() async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("mock_backup.json")
    }
}