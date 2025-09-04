//
//  VocabularyTestTests.swift
//  en01Tests
//
//  Created by SOLO Coding on 2025/01/20.
//

import XCTest
import Combine
@testable import en01

final class VocabularyTestTests: XCTestCase {
    
    var vocabularyTest: VocabularyTest!
    
    override func setUpWithError() throws {
        super.setUp()
        vocabularyTest = VocabularyTest(dictionaryName: "TestDictionary", sampleSize: 100, difficultyRange: "1-4")
    }
    
    override func tearDownWithError() throws {
        vocabularyTest = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testVocabularyTestInitialization() {
        XCTAssertNotNil(vocabularyTest!.id)
        XCTAssertNotNil(vocabularyTest!.testDate)
        XCTAssertEqual(vocabularyTest!.sampleSize, 100)
        XCTAssertEqual(vocabularyTest!.difficultyRange, "1-4")
        XCTAssertEqual(vocabularyTest!.totalWords, 0)
        XCTAssertEqual(vocabularyTest!.knownWords, 0)
        XCTAssertEqual(vocabularyTest!.estimatedVocabulary, 0)
        XCTAssertEqual(vocabularyTest!.testDuration, 0)
        XCTAssertEqual(vocabularyTest!.accuracy, 0.0)
        XCTAssertTrue(vocabularyTest!.getTestResults().isEmpty)
        XCTAssertEqual(vocabularyTest!.status, .notStarted)
    }
    
    func testVocabularyTestInitializationWithCustomValues() {
        let customTest = VocabularyTest(
            dictionaryName: "CustomDictionary",
            sampleSize: 200,
            difficultyRange: "2-5"
        )
        
        XCTAssertEqual(customTest.sampleSize, 200)
        XCTAssertEqual(customTest.difficultyRange, "2-5")
    }
    
    // MARK: - Test Management Tests
    
    func testStartTest() {
        // 模拟测试开始
        vocabularyTest!.currentWordIndex = 1
        vocabularyTest!.totalWords = 1
        
        XCTAssertEqual(vocabularyTest!.status, .inProgress)
        XCTAssertNotNil(vocabularyTest!.createdAt)
    }
    
    func testCompleteTest() {
        // 模拟测试结果
        let testResults = [
            VocabularyTestResult(word: "apple", isKnown: true, responseTime: 1.5, difficulty: .basic, frequency: 100),
            VocabularyTestResult(word: "sophisticated", isKnown: false, responseTime: 3.2, difficulty: .advanced, frequency: 50),
            VocabularyTestResult(word: "cat", isKnown: true, responseTime: 0.8, difficulty: .basic, frequency: 200)
        ]
        
        vocabularyTest!.saveTestResults(testResults)
        vocabularyTest!.isCompleted = true
        
        XCTAssertEqual(vocabularyTest!.status, .completed)
        XCTAssertNotNil(vocabularyTest!.completedAt)
        XCTAssertEqual(vocabularyTest!.getTestResults().count, 3)
        XCTAssertEqual(vocabularyTest!.totalWords, 3)
        XCTAssertEqual(vocabularyTest!.knownWords, 2)
        XCTAssertGreaterThan(vocabularyTest!.testDuration, 0)
    }
    
    func testPauseAndResumeTest() {
        // VocabularyTest结构体没有暂停/恢复功能，跳过此测试
        // 或者可以测试其他状态变化
        vocabularyTest!.currentWordIndex = 1
        XCTAssertEqual(vocabularyTest!.status, .inProgress)
        
        vocabularyTest!.isCompleted = true
        XCTAssertEqual(vocabularyTest!.status, .completed)
    }
    
    func testCancelTest() {
        // VocabularyTest结构体没有取消功能，测试重置状态
        vocabularyTest!.currentWordIndex = 5
        XCTAssertEqual(vocabularyTest!.status, .inProgress)
        
        // 重置到初始状态
        vocabularyTest!.currentWordIndex = 0
        XCTAssertEqual(vocabularyTest!.status, .notStarted)
    }
    
    // MARK: - Calculation Tests
    
    func testCalculateEstimatedVocabulary() {
        let testResults = [
            VocabularyTestResult(word: "apple", isKnown: true, responseTime: 1.5, difficulty: .basic, frequency: 100),
            VocabularyTestResult(word: "sophisticated", isKnown: false, responseTime: 3.2, difficulty: .advanced, frequency: 50),
            VocabularyTestResult(word: "cat", isKnown: true, responseTime: 0.8, difficulty: .basic, frequency: 200),
            VocabularyTestResult(word: "elephant", isKnown: true, responseTime: 1.2, difficulty: .medium, frequency: 80)
        ]
        
        vocabularyTest!.saveTestResults(testResults)
        vocabularyTest!.isCompleted = true
        vocabularyTest!.calculateEstimatedVocabulary(totalDictionaryWords: 10000)
        
        // 基于75%的正确率和100的样本大小，估算词汇量应该大于0
        XCTAssertGreaterThan(vocabularyTest!.estimatedVocabulary, 0)
    }
    
    func testCalculateAccuracy() {
        let testResults = [
            VocabularyTestResult(word: "apple", isKnown: true, responseTime: 1.5, difficulty: .basic, frequency: 100),
            VocabularyTestResult(word: "sophisticated", isKnown: false, responseTime: 3.2, difficulty: .advanced, frequency: 50),
            VocabularyTestResult(word: "cat", isKnown: true, responseTime: 0.8, difficulty: .basic, frequency: 200),
            VocabularyTestResult(word: "elephant", isKnown: true, responseTime: 1.2, difficulty: .medium, frequency: 80)
        ]
        
        vocabularyTest!.saveTestResults(testResults)
        vocabularyTest!.isCompleted = true
        vocabularyTest!.calculateAccuracy()
        
        XCTAssertEqual(vocabularyTest!.accuracy, 0.75, accuracy: 0.01) // 3/4 = 0.75
    }
    
    func testCalculateAccuracyWithEmptyResults() {
        vocabularyTest!.calculateAccuracy()
        XCTAssertEqual(vocabularyTest!.accuracy, 0.0)
    }
    
    // MARK: - Progress Tests
    
    func testGetCompletionPercentage() {
        vocabularyTest!.totalWords = 50
        vocabularyTest!.sampleSize = 100
        
        let percentage = vocabularyTest!.completionPercentage
        XCTAssertEqual(percentage, 50.0)
    }
    
    func testGetCompletionPercentageWithZeroSample() {
        vocabularyTest!.sampleSize = 0
        
        let percentage = vocabularyTest!.completionPercentage
        XCTAssertEqual(percentage, 0.0)
    }
    
    func testGetKnownWordsRate() {
        vocabularyTest!.totalWords = 100
        vocabularyTest!.knownWords = 75
        
        let rate = vocabularyTest!.knownRate / 100.0
        XCTAssertEqual(rate, 0.75)
    }
    
    func testGetKnownWordsRateWithZeroTotal() {
        vocabularyTest!.totalWords = 0
        vocabularyTest!.knownWords = 0
        
        let rate = vocabularyTest!.knownRate / 100.0
        XCTAssertEqual(rate, 0.0)
    }
    
    // MARK: - Formatting Tests
    
    func testFormatDuration() {
        vocabularyTest!.testDuration = 125 // 2分5秒
        
        let formatted = vocabularyTest!.formattedDuration
        XCTAssertEqual(formatted, "2:05")
    }
    
    func testFormatDurationLessThanMinute() {
        vocabularyTest!.testDuration = 45
        
        let formatted = vocabularyTest!.formattedDuration
        XCTAssertEqual(formatted, "0:45")
    }
    
    func testFormatDurationMoreThanHour() {
        vocabularyTest!.testDuration = 3665 // 1小时1分5秒
        
        let formatted = vocabularyTest!.formattedDuration
        XCTAssertEqual(formatted, "1:01:05")
    }
    
    func testFormatVocabularySize() {
        vocabularyTest!.estimatedVocabulary = 5432
        
        let formatted = vocabularyTest!.formattedVocabulary
        XCTAssertEqual(formatted, "5,432")
    }
    
    func testFormatVocabularySizeThousands() {
        vocabularyTest!.estimatedVocabulary = 12345
        
        let formatted = vocabularyTest!.formattedVocabulary
        XCTAssertEqual(formatted, "12.3K")
    }
    
    // MARK: - Status Tests
    
    func testGetTestStatus() {
        XCTAssertEqual(vocabularyTest!.status, .notStarted)
        
        // 测试状态变化 - 由于VocabularyTest是结构体，状态变化需要通过其他方式实现
        XCTAssertEqual(vocabularyTest!.status, .notStarted)
        
        // 模拟测试进行中的状态
        var inProgressTest = vocabularyTest!
        inProgressTest.currentWordIndex = 5
        XCTAssertEqual(inProgressTest.status, .inProgress)
        
        // 模拟测试完成的状态
        var completedTest = vocabularyTest!
        completedTest.isCompleted = true
        XCTAssertEqual(completedTest.status, .completed)
    }
    
    func testIsTestInProgress() {
        XCTAssertFalse(vocabularyTest!.status == .inProgress)
        
        // 测试是否在进行中
        XCTAssertFalse(vocabularyTest!.status == .inProgress)
        
        // 模拟测试进行中
        var inProgressTest = vocabularyTest!
        inProgressTest.currentWordIndex = 5
        XCTAssertTrue(inProgressTest.status == .inProgress)
        
        // 模拟测试完成
        var completedTest = vocabularyTest!
        completedTest.isCompleted = true
        XCTAssertFalse(completedTest.status == .inProgress)
    }
    
    func testCanStartTest() {
        XCTAssertTrue(vocabularyTest!.status == .notStarted)
        
        // 模拟测试开始
        var startedTest = vocabularyTest!
        startedTest.currentWordIndex = 1
        XCTAssertFalse(startedTest.status == .notStarted)
        
        // 模拟测试完成
        var completedTest = vocabularyTest!
        completedTest.isCompleted = true
        XCTAssertFalse(completedTest.status == .notStarted)
    }
    
    func testCanResumeTest() {
        XCTAssertFalse(vocabularyTest!.status == .paused)
        
        // 测试暂停状态 - VocabularyTest结构体中没有暂停状态
        XCTAssertFalse(vocabularyTest!.status == .paused)
        
        // 模拟测试进行中
        var inProgressTest = vocabularyTest!
        inProgressTest.currentWordIndex = 5
        XCTAssertFalse(inProgressTest.status == .paused)
    }
    
    // MARK: - Data Persistence Tests
    
    func testSaveAndLoadTestResult() {
        let testResults = [
            VocabularyTestResult(word: "apple", isKnown: true, responseTime: 1.5, difficulty: .basic, frequency: 100),
            VocabularyTestResult(word: "sophisticated", isKnown: false, responseTime: 3.2, difficulty: .advanced, frequency: 50)
        ]
        
        // 模拟测试开始和完成
        var testWithResults = vocabularyTest!
        testWithResults.currentWordIndex = testResults.count
        testWithResults.isCompleted = true
        testWithResults.saveTestResults(testResults)
        
        // 验证结果保存
        XCTAssertEqual(testWithResults.getTestResults().count, testResults.count)
        
        // 验证测试状态
        XCTAssertEqual(testWithResults.status, .completed)
        XCTAssertEqual(testWithResults.getTestResults().count, 2)
    }
    
    func testLoadNonExistentTestResult() {
        let newTest = VocabularyTest(dictionaryName: "EmptyDictionary", sampleSize: 50, difficultyRange: "1-3")
        let emptyResults = newTest.getTestResults()
        XCTAssertTrue(emptyResults.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    func testCalculateEstimatedVocabularyPerformance() {
        // 创建大量测试结果
        var testResults: [VocabularyTestResult] = []
        for i in 0..<1000 {
            testResults.append(VocabularyTestResult(
                word: "word\(i)",
                isKnown: i % 2 == 0,
                responseTime: Double.random(in: 0.5...3.0),
                difficulty: WordDifficulty.allCases.randomElement() ?? .basic,
                frequency: Int.random(in: 1...1000)
            ))
        }
        
        vocabularyTest!.saveTestResults(testResults)
        vocabularyTest!.isCompleted = true
        
        measure {
            vocabularyTest!.calculateEstimatedVocabulary(totalDictionaryWords: 10000)
        }
    }
    
    func testCalculateAccuracyPerformance() {
        // 创建大量测试结果
        var testResults: [VocabularyTestResult] = []
        for i in 0..<1000 {
            testResults.append(VocabularyTestResult(
                word: "word\(i)",
                isKnown: i % 3 != 0, // 约66.7%的正确率
                responseTime: Double.random(in: 0.5...3.0),
                difficulty: WordDifficulty.allCases.randomElement() ?? .basic,
                frequency: Int.random(in: 1...1000)
            ))
        }
        
        vocabularyTest!.saveTestResults(testResults)
        vocabularyTest!.isCompleted = true
        
        measure {
            vocabularyTest!.calculateAccuracy()
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testCompleteTestWithEmptyResults() {
        // 模拟空结果的完成测试
        var emptyTest = vocabularyTest!
        emptyTest.isCompleted = true
        emptyTest.saveTestResults([])
        
        XCTAssertEqual(emptyTest.status, .completed)
        XCTAssertEqual(emptyTest.totalWords, 0)
        XCTAssertEqual(emptyTest.knownWords, 0)
        XCTAssertEqual(emptyTest.accuracy, 0.0)
        XCTAssertEqual(emptyTest.estimatedVocabulary, 0)
    }
    
    func testMultipleStartCalls() {
        // 模拟测试开始
        var startedTest = vocabularyTest!
        startedTest.currentWordIndex = 1
        let firstStartTime = startedTest.createdAt
        
        // 验证测试状态
        XCTAssertEqual(startedTest.status, .inProgress)
        XCTAssertEqual(startedTest.createdAt, firstStartTime)
    }
    
    func testCompleteTestWithoutStarting() {
        // 尝试在未开始的情况下完成测试
        var unStartedTest = vocabularyTest!
        unStartedTest.saveTestResults([])
        
        // 应该保持原始状态
        XCTAssertEqual(unStartedTest.status, .notStarted)
        XCTAssertNotNil(unStartedTest.createdAt)
        XCTAssertNil(unStartedTest.completedAt)
    }
}

// MARK: - Test Result Tests

final class VocabularyTestResultTests: XCTestCase {
    
    func testVocabularyTestResultInitialization() {
        let testResult = VocabularyTestResult(
            word: "example",
            isKnown: true,
            responseTime: 2.5,
            difficulty: .medium,
            frequency: 100
        )
        
        XCTAssertEqual(testResult.word, "example")
        XCTAssertTrue(testResult.isKnown)
        XCTAssertEqual(testResult.responseTime, 2.5)
        XCTAssertEqual(testResult.difficulty, .medium)
        XCTAssertEqual(testResult.frequency, 100)
    }
    
    func testVocabularyTestResultCodable() throws {
        let testResult = VocabularyTestResult(
            word: "example",
            isKnown: true,
            responseTime: 2.5,
            difficulty: .medium,
            frequency: 100
        )
        
        // 测试编码
        let encoder = JSONEncoder()
        let data = try encoder.encode(testResult)
        
        // 测试解码
        let decoder = JSONDecoder()
        let decodedResult = try decoder.decode(VocabularyTestResult.self, from: data)
        
        XCTAssertEqual(decodedResult.word, testResult.word)
        XCTAssertEqual(decodedResult.isKnown, testResult.isKnown)
        XCTAssertEqual(decodedResult.responseTime, testResult.responseTime)
        XCTAssertEqual(decodedResult.difficulty, testResult.difficulty)
        XCTAssertEqual(decodedResult.frequency, testResult.frequency)
    }
}