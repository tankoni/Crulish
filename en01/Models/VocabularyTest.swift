//
//  VocabularyTest.swift
//  en01
//
//  Created by SOLO Coding on 2025/1/18.
//

import Foundation
import SwiftData
import SwiftUI

// 词汇量测试记录模型
@Model
final class VocabularyTest: @unchecked Sendable {
    var id: UUID
    var dictionaryId: UUID? // 词典ID，与DictionaryInfo.id关联（可选以支持旧数据迁移）
    var dictionaryName: String // 使用的词典名称
    var dictionaryFileName: String // 词典文件名
    var testDate: Date // 测试日期
    var createdAt: Date // 创建时间
    var completedAt: Date? // 完成时间
    var totalWords: Int // 测试总单词数
    var knownWords: Int // 认识的单词数
    var unknownWords: Int // 不认识的单词数
    var masteredCount: Int // 掌握的单词数
    var familiarCount: Int // 眼熟的单词数
    var unfamiliarCount: Int // 陌生的单词数
    var currentWordIndex: Int // 当前单词索引
    var estimatedVocabulary: Int // 估算词汇量
    var estimatedVocabularySize: Int // 估算词汇量大小
    var accuracyPercentage: Double // 准确率百分比
    var testDuration: TimeInterval // 测试用时（秒）
    var accuracy: Double // 测试准确度（0-1）
    var isCompleted: Bool // 是否完成测试
    var isPaused: Bool // 是否暂停测试
    
    // 测试会话状态 - 用于继续测试时的状态恢复
    var sessionMasteredCount: Int // 当前会话掌握的单词数
    var sessionFamiliarCount: Int // 当前会话眼熟的单词数
    var sessionUnfamiliarCount: Int // 当前会话陌生的单词数
    var isNewSession: Bool // 是否为新测试会话（区分新测试和继续测试）
    
    // 测试配置
    var sampleSize: Int // 抽样单词数量
    var difficultyRange: String // 难度范围，如"1-3"表示基础到高级
    
    // 测试结果详情
    private var testResultsData: Data? // 存储序列化的测试结果详情
    
    // 简化构造函数
    init(dictionaryName: String, sampleSize: Int = 100, difficultyRange: String = "1-4") {
        self.id = UUID()
        self.dictionaryId = nil // 默认为 nil，实际使用时应设置正确的词典ID
        self.dictionaryName = dictionaryName
        self.dictionaryFileName = ""
        self.testDate = Date()
        self.createdAt = Date()
        self.completedAt = nil
        self.totalWords = 0
        self.knownWords = 0
        self.unknownWords = 0
        self.masteredCount = 0
        self.familiarCount = 0
        self.unfamiliarCount = 0
        self.currentWordIndex = 0
        self.estimatedVocabulary = 0
        self.estimatedVocabularySize = 0
        self.accuracyPercentage = 0.0
        self.testDuration = 0
        self.accuracy = 0.0
        self.isCompleted = false
        self.isPaused = false
        
        // 初始化测试会话状态
        self.sessionMasteredCount = 0
        self.sessionFamiliarCount = 0
        self.sessionUnfamiliarCount = 0
        self.isNewSession = true
        
        self.sampleSize = sampleSize
        self.difficultyRange = difficultyRange
        self.testResultsData = nil
    }
    
    // 完整参数构造函数
    init(
        id: UUID,
        dictionaryId: UUID?,
        dictionaryName: String,
        dictionaryFileName: String,
        totalWords: Int,
        masteredCount: Int,
        familiarCount: Int,
        unfamiliarCount: Int,
        currentWordIndex: Int,
        isCompleted: Bool,
        isPaused: Bool,
        createdAt: Date,
        completedAt: Date?,
        estimatedVocabularySize: Int,
        accuracyPercentage: Double
    ) {
        self.id = id
        self.dictionaryId = dictionaryId
        self.dictionaryName = dictionaryName
        self.dictionaryFileName = dictionaryFileName
        self.testDate = createdAt
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.totalWords = totalWords
        self.knownWords = masteredCount + familiarCount
        self.unknownWords = unfamiliarCount
        self.masteredCount = masteredCount
        self.familiarCount = familiarCount
        self.unfamiliarCount = unfamiliarCount
        self.currentWordIndex = currentWordIndex
        self.estimatedVocabulary = estimatedVocabularySize
        self.estimatedVocabularySize = estimatedVocabularySize
        self.accuracyPercentage = accuracyPercentage
        self.testDuration = 0
        self.accuracy = accuracyPercentage / 100.0
        self.isCompleted = isCompleted
        self.isPaused = isPaused
        
        // 初始化测试会话状态 - 继续测试时保持原有状态
        self.sessionMasteredCount = masteredCount
        self.sessionFamiliarCount = familiarCount
        self.sessionUnfamiliarCount = unfamiliarCount
        self.isNewSession = false // 通过完整构造函数创建的通常是继续测试
        
        self.sampleSize = totalWords
        self.difficultyRange = "1-4"
        self.testResultsData = nil
    }
    

}

// 测试结果详情
struct VocabularyTestResult: Codable {
    let word: String
    let isKnown: Bool
    let responseTime: TimeInterval
    let difficulty: WordDifficulty
    let frequency: Int
}

// 词汇量测试状态
enum VocabularyTestStatus: String, CaseIterable {
    case notStarted = "未开始"
    case inProgress = "进行中"
    case completed = "已完成"
    case paused = "已暂停"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        case .paused: return .orange
        }
    }
}

extension VocabularyTest {
    // 计算词汇量估算
    func calculateEstimatedVocabulary(totalDictionaryWords: Int) {
        guard totalWords > 0 else { 
            self.estimatedVocabulary = 0
            return 
        }
        
        let knownRatio = Double(knownWords) / Double(totalWords)
        self.estimatedVocabulary = Int(knownRatio * Double(totalDictionaryWords))
        
        // 同时更新统计数据以确保一致性
        updateStatistics()
    }
    
    // 计算准确度（基于响应时间和一致性）
    func calculateAccuracy() {
        guard let resultsData = testResultsData,
              let results = try? JSONDecoder().decode([VocabularyTestResult].self, from: resultsData) else {
            self.accuracy = 0.0
            return
        }
        
        // 基于响应时间的一致性计算准确度
        let avgResponseTime = results.map { $0.responseTime }.reduce(0, +) / Double(results.count)
        let responseTimeVariance = results.map { pow($0.responseTime - avgResponseTime, 2) }.reduce(0, +) / Double(results.count)
        
        // 响应时间越一致，准确度越高
        let consistencyScore = max(0, 1 - (responseTimeVariance / (avgResponseTime * avgResponseTime)))
        self.accuracy = min(1.0, consistencyScore)
    }
    
    // 保存测试结果详情
    func saveTestResults(_ results: [VocabularyTestResult]) {
        do {
            self.testResultsData = try JSONEncoder().encode(results)
        } catch {
            print("Failed to encode test results: \(error)")
        }
    }
    
    // 获取测试结果详情
    func getTestResults() -> [VocabularyTestResult] {
        guard let data = testResultsData else { return [] }
        
        do {
            return try JSONDecoder().decode([VocabularyTestResult].self, from: data)
        } catch {
            print("Failed to decode test results: \(error)")
            return []
        }
    }
    
    // 完成测试
    func completeTest() {
        self.isCompleted = true
        self.unknownWords = totalWords - knownWords
        self.completedAt = Date()
        
        // 更新统计数据
        updateStatistics()
    }
    
    // 更新统计数据
    func updateStatistics() {
        let results = getTestResults()
        
        // 重置统计计数
        var masteredCount = 0
        var familiarCount = 0
        var unfamiliarCount = 0
        
        // 根据测试结果计算统计数据
        for result in results {
            if result.isKnown {
                // 根据响应时间判断是掌握还是熟悉
                if result.responseTime < 2.0 {
                    masteredCount += 1
                } else {
                    familiarCount += 1
                }
            } else {
                unfamiliarCount += 1
            }
        }
        
        // 更新统计字段
        self.masteredCount = masteredCount
        self.familiarCount = familiarCount
        self.unfamiliarCount = unfamiliarCount
        
        print("📊 [VocabularyTest] 统计数据已更新: 掌握(\(masteredCount)) 熟悉(\(familiarCount)) 陌生(\(unfamiliarCount))")
    }
    
    // 获取测试状态
    var status: VocabularyTestStatus {
        if !isCompleted && totalWords == 0 {
            return .notStarted
        } else if !isCompleted && totalWords > 0 {
            return .inProgress
        } else {
            return .completed
        }
    }
    
    // 获取完成百分比
    var completionPercentage: Double {
        guard sampleSize > 0 else { return 0 }
        return Double(totalWords) / Double(sampleSize) * 100
    }
    
    // 获取知晓率
    var knownRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(knownWords) / Double(totalWords) * 100
    }
    
    // 格式化测试用时
    var formattedDuration: String {
        let minutes = Int(testDuration) / 60
        let seconds = Int(testDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 格式化词汇量
    var formattedVocabulary: String {
        if estimatedVocabulary >= 1000 {
            return String(format: "%.1fK", Double(estimatedVocabulary) / 1000.0)
        } else {
            return "\(estimatedVocabulary)"
        }
    }
}