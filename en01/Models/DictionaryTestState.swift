//
//  DictionaryTestState.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation

// MARK: - 词典测试状态枚举
enum DictionaryTestStatus {
    case notTested          // 未测试
    case tested             // 已测试（单次）
    case multipleTests      // 多次测试
    
    var displayText: String {
        switch self {
        case .notTested:
            return "未测试"
        case .tested:
            return "已测试"
        case .multipleTests:
            return "多个记录"
        }
    }
    
    var color: String {
        switch self {
        case .notTested:
            return "gray"
        case .tested:
            return "green"
        case .multipleTests:
            return "blue"
        }
    }
}

// MARK: - 词典测试状态数据结构
struct DictionaryTestState {
    let dictionaryId: UUID
    let dictionaryName: String
    let dictionary: DictionaryInfo  // 完整的词典信息
    let status: DictionaryTestStatus
    let latestTest: VocabularyTest?
    let testHistory: [VocabularyTest]
    let selectedTest: VocabularyTest?  // 用户选择的测试记录
    
    // 计算属性
    var hasMultipleTests: Bool {
        return testHistory.count > 1
    }
    
    var latestTestDate: Date? {
        return latestTest?.completedAt ?? latestTest?.testDate
    }
    
    var estimatedVocabularySize: Int {
        return selectedTest?.estimatedVocabularySize ?? latestTest?.estimatedVocabularySize ?? 0
    }
    
    var accuracyPercentage: Double {
        return selectedTest?.accuracyPercentage ?? latestTest?.accuracyPercentage ?? 0.0
    }
    
    // 获取用于排序的测试数据
    var testForRanking: VocabularyTest? {
        return selectedTest ?? latestTest
    }
    
    // 获取已测试词数（从TestDataService获取正确数据）
    func getTestedWordsCount(using testDataService: TestDataService) async -> Int {
        do {
            let results = try await testDataService.getDictionaryTestResults(for: dictionary.fileName)
                .values.first(where: { _ in true })
            return results?.totalTestedWords ?? 0
        } catch {
            print("❌ 获取已测试词数失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    init(dictionaryId: UUID, dictionaryName: String, dictionary: DictionaryInfo, testHistory: [VocabularyTest] = [], selectedTest: VocabularyTest? = nil) {
        self.dictionaryId = dictionaryId
        self.dictionaryName = dictionaryName
        self.dictionary = dictionary
        self.testHistory = testHistory.sorted { $0.completedAt ?? $0.testDate > $1.completedAt ?? $1.testDate }
        self.latestTest = self.testHistory.first
        self.selectedTest = selectedTest
        
        // 确定状态
        if testHistory.isEmpty {
            self.status = .notTested
        } else if testHistory.count == 1 {
            self.status = .tested
        } else {
            self.status = .multipleTests
        }
    }
    
    // 更新选择的测试记录
    func withSelectedTest(_ test: VocabularyTest?) -> DictionaryTestState {
        return DictionaryTestState(
            dictionaryId: dictionaryId,
            dictionaryName: dictionaryName,
            dictionary: dictionary,
            testHistory: testHistory,
            selectedTest: test
        )
    }
}

// MARK: - 词典重合度数据结构
struct DictionaryOverlapInfo {
    let dictionaryId: UUID
    let article: Article                  // 关联的文章
    let totalWords: Int                   // 词典总词数
    let overlapWords: Int                 // 重合词数
    let overlapPercentage: Double         // 重合度百分比
    let overlapWordsList: [String]        // 重合词列表
    let userMasteryInfo: UserMasteryInfo? // 用户掌握情况
    
    init(dictionaryId: UUID, article: Article, totalWords: Int, overlapWords: Int, overlapWordsList: [String] = [], userMasteryInfo: UserMasteryInfo? = nil) {
        self.dictionaryId = dictionaryId
        self.article = article
        self.totalWords = totalWords
        self.overlapWords = overlapWords
        self.overlapPercentage = totalWords > 0 ? Double(overlapWords) / Double(totalWords) * 100 : 0
        self.overlapWordsList = overlapWordsList
        self.userMasteryInfo = userMasteryInfo
    }
}

// MARK: - 用户掌握情况数据结构
struct UserMasteryInfo {
    let article: Article              // 关联的文章
    let masteredCount: Int            // 已掌握词数
    let familiarCount: Int            // 熟悉词数
    let unfamiliarCount: Int          // 陌生词数
    let totalCount: Int               // 总词数
    let masteredWords: [String]       // 已掌握词列表
    let unfamiliarWords: [String]     // 陌生词列表
    
    // 计算属性
    var masteredPercentage: Double {
        return totalCount > 0 ? Double(masteredCount) / Double(totalCount) * 100 : 0
    }
    
    var unfamiliarPercentage: Double {
        return totalCount > 0 ? Double(unfamiliarCount) / Double(totalCount) * 100 : 0
    }
    
    // 用于排序的分数（陌生词越多分数越高，优先推荐）
    var rankingScore: Double {
        return unfamiliarPercentage
    }
    
    init(article: Article, masteredCount: Int, familiarCount: Int, unfamiliarCount: Int, masteredWords: [String] = [], unfamiliarWords: [String] = []) {
        self.article = article
        self.masteredCount = masteredCount
        self.familiarCount = familiarCount
        self.unfamiliarCount = unfamiliarCount
        self.totalCount = masteredCount + familiarCount + unfamiliarCount
        self.masteredWords = masteredWords
        self.unfamiliarWords = unfamiliarWords
    }
}

// MARK: - 分阶段排序结果
struct StagedRankingResult {
    let stage1Results: [DictionaryOverlapInfo]  // 第一阶段：词典重合度排序结果
    let stage2Results: [UserMasteryInfo]        // 第二阶段：用户掌握度排序结果
    let testRecord: VocabularyTest              // 测试记录
    let dictionary: DictionaryInfo              // 词典信息
    
    // 便于访问的计算属性
    var articles: [Article] {
        // 从stage1Results中提取文章列表
        return stage1Results.map { $0.article }
    }
    
    init(stage1Results: [DictionaryOverlapInfo], stage2Results: [UserMasteryInfo], testRecord: VocabularyTest, dictionary: DictionaryInfo) {
        self.stage1Results = stage1Results
        self.stage2Results = stage2Results
        self.testRecord = testRecord
        self.dictionary = dictionary
    }
}

// MARK: - 单个文章的排序结果（用于详细展示）
struct ArticleRankingResult {
    let article: Article
    let overlapInfo: DictionaryOverlapInfo?
    let masteryInfo: UserMasteryInfo?
    let stage: RankingStage
    let stageScore: Double      // 阶段内排序分数
    let originalMatchResult: ArticleMatchResult
    
    enum RankingStage: Int, CaseIterable {
        case highOverlap = 1    // 高重合度
        case mediumOverlap = 2  // 中重合度
        case lowOverlap = 3     // 低重合度
        case noOverlap = 4      // 无重合度
        
        var displayName: String {
            switch self {
            case .highOverlap:
                return "高重合度"
            case .mediumOverlap:
                return "中重合度"
            case .lowOverlap:
                return "低重合度"
            case .noOverlap:
                return "无重合度"
            }
        }
        
        // 根据重合度百分比确定阶段
        static func stage(for overlapPercentage: Double) -> RankingStage {
            if overlapPercentage >= 70 {
                return .highOverlap
            } else if overlapPercentage >= 40 {
                return .mediumOverlap
            } else if overlapPercentage >= 10 {
                return .lowOverlap
            } else {
                return .noOverlap
            }
        }
    }
}