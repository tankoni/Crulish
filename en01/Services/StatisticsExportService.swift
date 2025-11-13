//
//  StatisticsExportService.swift
//  en01
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import SwiftData
import Combine

// MARK: - Protocol

protocol StatisticsExportServiceProtocol {
    /// 获取已完成的词汇测试结果
    func getCompletedTestResults() async throws -> [VocabularyTest]
    
    /// 获取指定测试的详细单词分类结果
    func getTestWordDetails(for test: VocabularyTest) async throws -> [TestedWord]
    
    /// 生成Markdown格式的导出内容
    func generateMarkdownContent(for tests: [VocabularyTest]) async throws -> String
    
    /// 生成单个测试的详细报告
    func generateTestDetailReport(for test: VocabularyTest) async throws -> String
}

// MARK: - Implementation

class StatisticsExportService: StatisticsExportServiceProtocol {
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private let vocabularyTestService: VocabularyTestServiceProtocol
    private let errorHandler: UnifiedErrorHandler
    private let dictionaryService: DictionaryServiceProtocol
    
    // MARK: - Cache
    
    private var testResultsCache: (data: [VocabularyTest], timestamp: Date)?
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        vocabularyTestService: VocabularyTestServiceProtocol,
        errorHandler: UnifiedErrorHandler,
        dictionaryService: DictionaryServiceProtocol
    ) {
        self.modelContext = modelContext
        self.vocabularyTestService = vocabularyTestService
        self.errorHandler = errorHandler
        self.dictionaryService = dictionaryService
    }
    
    // MARK: - Public Methods
    
    func getCompletedTestResults() async throws -> [VocabularyTest] {
        // 检查缓存
        if let cache = testResultsCache,
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            print("✅ 使用缓存的测试结果: \(cache.data.count) 个")
            return cache.data
        }
        
        do {
            let descriptor = FetchDescriptor<VocabularyTest>(
                predicate: #Predicate<VocabularyTest> { test in
                    test.isCompleted == true
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            let tests = try modelContext.fetch(descriptor)
            
            // 更新缓存
            testResultsCache = (tests, Date())
            
            print("✅ 获取已完成测试结果: \(tests.count) 个")
            return tests
        } catch {
            print("❌ 获取测试结果失败: \(error.localizedDescription)")
            errorHandler.handle(error, context: "获取已完成测试结果")
            throw error
        }
    }
    
    func getTestWordDetails(for test: VocabularyTest) async throws -> [TestedWord] {
        do {
            // 首先尝试使用测试ID关联查询
            let testId = test.id
            var descriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.testSessionId == testId
                },
                sortBy: [SortDescriptor(\.testedAt, order: .reverse)]
            )
            
            var testedWords = try modelContext.fetch(descriptor)
            
            // 如果通过测试ID没有找到数据，尝试使用词典名称和测试时间范围查询
        if testedWords.isEmpty {
            let testDate = test.testDate
            let startDate = Calendar.current.date(byAdding: .minute, value: -30, to: testDate) ?? testDate
            let endDate = Calendar.current.date(byAdding: .minute, value: 30, to: testDate) ?? testDate
            let dictionaryName = test.dictionaryName
            
            descriptor = FetchDescriptor<TestedWord>(
                predicate: #Predicate<TestedWord> { word in
                    word.dictionaryName == dictionaryName &&
                    word.testedAt >= startDate &&
                    word.testedAt <= endDate
                },
                sortBy: [SortDescriptor(\.testedAt, order: .reverse)]
            )
            
            testedWords = try modelContext.fetch(descriptor)
            print("⚠️ 通过测试ID未找到数据，使用词典名称和时间范围查询到: \(testedWords.count) 个单词")
        } else {
            print("✅ 通过测试ID获取测试单词详情: \(testedWords.count) 个")
        }
            
            return testedWords
        } catch {
            print("❌ 获取测试单词详情失败: \(error.localizedDescription)")
            errorHandler.handle(error, context: "获取测试单词详情")
            throw error
        }
    }
    
    func generateMarkdownContent(for tests: [VocabularyTest]) async throws -> String {
        var content = """
        # 词汇测试统计报告
        
        生成时间：\(DateFormatter.displayFormatter.string(from: Date()))
        
        ## 测试概览
        
        """
        
        if tests.isEmpty {
            content += "暂无已完成的测试记录。\n"
            return content
        }
        
        // 总体统计
        let totalTests = tests.count
        let totalWords = tests.reduce(0) { $0 + $1.totalWords }
        let totalKnown = tests.reduce(0) { $0 + $1.knownWords }
        let totalUnknown = tests.reduce(0) { $0 + $1.unknownWords }
        let averageVocabulary = tests.reduce(0) { $0 + $1.estimatedVocabulary } / totalTests
        
        content += """
        - **测试总数**: \(totalTests) 次
        - **测试单词总数**: \(totalWords) 个
        - **已掌握单词**: \(totalKnown) 个
        - **未掌握单词**: \(totalUnknown) 个
        - **平均词汇量**: \(averageVocabulary) 个
        - **总体掌握率**: \(String(format: "%.1f", Double(totalKnown) / Double(totalWords) * 100))%
        
        ## 详细测试记录
        
        """
        
        // 为每个测试生成详细报告
        for (index, test) in tests.enumerated() {
            content += "### \(index + 1). \(test.dictionaryName)\n\n"
            
            let testDetail = try await generateTestDetailReport(for: test)
            content += testDetail + "\n\n"
        }
        
        // 成就统计
        content += generateAchievementStatistics(for: tests)
        
        return content
    }
    
    func generateTestDetailReport(for test: VocabularyTest) async throws -> String {
        var report = """
        **测试信息**:
        - 词典: \(test.dictionaryName)
        - 测试时间: \(DateFormatter.displayFormatter.string(from: test.createdAt))
        - 测试用时: \(test.formattedDuration)
        - 估算词汇量: \(test.estimatedVocabulary) 个
        
        **测试结果**:
        - 总测试单词: \(test.totalWords) 个
        - 已掌握: \(test.knownWords) 个 (\(String(format: "%.1f", test.knownRate))%)
        - 未掌握: \(test.unknownWords) 个 (\(String(format: "%.1f", Double(test.unknownWords) / Double(test.totalWords) * 100))%)
        
        """
        
        // 获取详细的单词分类结果
        do {
            let testedWords = try await getTestWordDetails(for: test)
            if !testedWords.isEmpty {
                report += try await generateWordCategoryDetails(testedWords: testedWords)
            }
        } catch {
            report += "⚠️ 无法获取详细单词分类信息: \(error.localizedDescription)\n"
        }
        
        return report
    }
    
    // MARK: - Private Methods
    
    private func generateWordCategoryDetails(testedWords: [TestedWord]) async throws -> String {
        let unique = uniqueByWord(testedWords)
        let masteredWords = unique.filter { $0.masteryLevel == MasteryLevel.mastered.rawValue }
        let familiarWords = unique.filter { $0.masteryLevel == MasteryLevel.familiar.rawValue }
        let unfamiliarWords = unique.filter { $0.masteryLevel == MasteryLevel.unfamiliar.rawValue }
        
        var details = """
        
        **单词分类详情**:
        
        #### 已掌握单词 (\(masteredWords.count) 个)
        """
        
        if masteredWords.isEmpty {
            details += "\n无\n"
        } else {
            details += "\n"
                for word in masteredWords {
                    let clean = normalizeWordString(word.word)
                    let wordDetails = await getWordDetailsForExport(clean)
                    details += "- **\(clean)** \(wordDetails)\n"
                }
        }
        
        details += """
        
        #### 眼熟单词 (\(familiarWords.count) 个)
        """
        
        if familiarWords.isEmpty {
            details += "\n无\n"
        } else {
            details += "\n"
                for word in familiarWords {
                    let clean = normalizeWordString(word.word)
                    let wordDetails = await getWordDetailsForExport(clean)
                    details += "- **\(clean)** \(wordDetails)\n"
                }
        }
        
        details += """
        
        #### 陌生单词 (\(unfamiliarWords.count) 个)
        """
        
        if unfamiliarWords.isEmpty {
            details += "\n无\n"
        } else {
            details += "\n"
                for word in unfamiliarWords {
                    let clean = normalizeWordString(word.word)
                    let wordDetails = await getWordDetailsForExport(clean)
                    details += "- **\(clean)** \(wordDetails)\n"
                }
        }
        
        // 统计分析
        let totalWords = testedWords.count
        if totalWords > 0 {
            let masteryRate = Double(masteredWords.count) / Double(totalWords) * 100
            let familiarRate = Double(familiarWords.count) / Double(totalWords) * 100
            let unfamiliarRate = Double(unfamiliarWords.count) / Double(totalWords) * 100
            
            details += """
            
            **统计分析**:
            - 掌握率: \(String(format: "%.1f", masteryRate))%
            - 眼熟率: \(String(format: "%.1f", familiarRate))%
            - 陌生率: \(String(format: "%.1f", unfamiliarRate))%
            """
        }
        
        return details
    }

    private func normalizeWordString(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix("- ") { s = String(s.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines) }
        while s.hasPrefix("* ") { s = String(s.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines) }
        while s.hasPrefix("• ") { s = String(s.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines) }
        var idx = s.startIndex
        var digitsCount = 0
        while idx < s.endIndex, s[idx].isNumber { digitsCount += 1; idx = s.index(after: idx) }
        if digitsCount > 0, idx < s.endIndex, s[idx] == "." {
            let nextIdx = s.index(after: idx)
            if nextIdx < s.endIndex, s[nextIdx] == " " {
                s = String(s[nextIdx...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if let start = s.range(of: "**"), let end = s.range(of: "**", range: start.upperBound..<s.endIndex) {
            s = String(s[start.upperBound..<end.lowerBound])
        }
        return s
    }

    private func uniqueByWord(_ words: [TestedWord]) -> [TestedWord] {
        var map: [String: TestedWord] = [:]
        for w in words {
            let key = normalizeWordString(w.word).lowercased()
            if let existing = map[key] {
                let a = masteryRank(existing)
                let b = masteryRank(w)
                if b > a {
                    map[key] = w
                } else if b == a {
                    let t1 = existing.lastTestedDate ?? existing.testedAt
                    let t2 = w.lastTestedDate ?? w.testedAt
                    if t2 > t1 { map[key] = w }
                }
            } else {
                map[key] = w
            }
        }
        return Array(map.values)
    }

    private func masteryRank(_ w: TestedWord) -> Int {
        let level = MasteryLevel(rawValue: w.masteryLevel) ?? .unfamiliar
        switch level {
        case .mastered: return 2
        case .familiar: return 1
        case .unfamiliar: return 0
        }
    }
    
    /// 获取单词的详细信息用于导出
    private func getWordDetailsForExport(_ word: String) async -> String {
        // 首先尝试从考研词典获取详细信息
        if let kaoyanDetails = await getKaoyanWordDetails(word) {
            var details = ""
            
            // 添加音标
            if let usPhone = kaoyanDetails.usPhone, !usPhone.isEmpty {
                details += "/\(usPhone)/ "
            }
            
            // 添加释义
            let meanings = kaoyanDetails.translations.prefix(3).map { translation in
                let pos = translation.pos.isEmpty ? "" : "[\(translation.pos)] "
                return "\(pos)\(translation.tranCn)"
            }.joined(separator: "; ")
            
            if !meanings.isEmpty {
                details += "- \(meanings)"
            }
            
            // 添加例句
            if let firstSentence = kaoyanDetails.sentences.first {
                details += " | 例句: \(firstSentence.sContent)"
            }
            
            return details
        }
        
        // 如果考研词典中没有，尝试基础词典
        if let dictionaryWord = getDictionaryWord(for: word) {
            var details = ""
            
            // 添加音标
            if let phonetic = dictionaryWord.phonetic, !phonetic.isEmpty {
                details += "/\(phonetic)/ "
            }
            
            // 添加释义
            if let firstDefinition = dictionaryWord.definitions.first {
                details += "- [\(firstDefinition.partOfSpeech.displayName)] \(firstDefinition.meaning)"
                
                // 添加例句
                if let firstExample = firstDefinition.examples.first {
                    details += " | 例句: \(firstExample)"
                }
            }
            
            return details
        }
        
        return "- 暂无释义信息"
    }
    
    /// 从考研词典获取单词详情
    private func getKaoyanWordDetails(_ word: String) async -> KaoyanWordDetails? {
        // getKaoyanWordDetails 是同步方法，不需要 await
        return dictionaryService.getKaoyanWordDetails(word)
    }
    
    /// 从基础词典获取单词详情
    private func getDictionaryWord(for word: String) -> DictionaryWord? {
        // 使用同步方法查找单词
        return dictionaryService.lookupWord(word, context: "")
    }
    
    private func generateAchievementStatistics(for tests: [VocabularyTest]) -> String {
        guard !tests.isEmpty else { return "" }
        
        let bestTest = tests.max { $0.estimatedVocabulary < $1.estimatedVocabulary }
        let recentTest = tests.first // 已按时间降序排列
        
        var achievements = """
        ## 成就统计
        
        """
        
        if let best = bestTest {
            achievements += "🏆 **最佳成绩**: \(best.dictionaryName) - \(best.estimatedVocabulary) 个单词\n"
        }
        
        if let recent = recentTest {
            achievements += "📅 **最近测试**: \(recent.dictionaryName) - \(DateFormatter.displayFormatter.string(from: recent.createdAt))\n"
        }
        
        // 进步趋势分析
        if tests.count >= 2 {
            let firstTest = tests.last!
            let latestTest = tests.first!
            let improvement = latestTest.estimatedVocabulary - firstTest.estimatedVocabulary
            
            if improvement > 0 {
                achievements += "📈 **进步情况**: 相比首次测试提升了 \(improvement) 个单词\n"
            } else if improvement < 0 {
                achievements += "📉 **变化情况**: 相比首次测试减少了 \(abs(improvement)) 个单词\n"
            } else {
                achievements += "➡️ **稳定表现**: 词汇量保持稳定\n"
            }
        }
        
        return achievements
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        testResultsCache = nil
        print("✅ 清除导出服务缓存")
    }
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    static let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
}
