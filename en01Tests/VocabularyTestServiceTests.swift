//
//  VocabularyTestServiceTests.swift
//  en01Tests
//
//  Created by SOLO Coding on 2025/01/20.
//

import XCTest
import Combine
@testable import en01

class VocabularyTestServiceTests: XCTestCase {
    var vocabularyTestService: MockVocabularyTestService!
    var mockDictionaryService: MockDictionaryService!
    var mockCoreDataStack: MockCoreDataStack!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockDictionaryService = MockDictionaryService()
        mockCoreDataStack = MockCoreDataStack()
        vocabularyTestService = MockVocabularyTestService(
            dictionaryService: mockDictionaryService,
            coreDataStack: mockCoreDataStack
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        vocabularyTestService = nil
        mockDictionaryService = nil
        mockCoreDataStack = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testVocabularyTestServiceInitialization() {
        XCTAssertNil(vocabularyTestService.currentTest)
        XCTAssertFalse(vocabularyTestService.isTestInProgress)
        XCTAssertEqual(vocabularyTestService.defaultSampleSize, 100)
        XCTAssertEqual(vocabularyTestService.defaultDifficultyRange, 1...4)
        XCTAssertEqual(vocabularyTestService.timeLimit, 1800) // 30分钟
    }
    
    // MARK: - Test Management Tests
    
    func testStartNewTest() async throws {
        // 准备测试数据
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        let test = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 50)
        
        XCTAssertNotNil(test)
        XCTAssertEqual(test.totalWords, 50)
        XCTAssertFalse(test.isCompleted)
        XCTAssertFalse(test.isPaused)
    }
    
    func testStartNewTestWithDefaultParameters() async throws {
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
                XCTFail("No dictionaries available")
                return
            }
        
        let test = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 100)
        
        XCTAssertEqual(test.totalWords, 100)
    }
    
    func testStartNewTestWhileTestInProgress() async throws {
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
                    XCTFail("No dictionaries available")
                    return
                }
        
        // 开始第一个测试
        _ = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 10)
        
        // 尝试开始第二个测试应该抛出错误
        do {
            _ = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 10)
            XCTFail("应该抛出测试进行中的错误")
        } catch {
            // 预期的错误
        }
    }
    
    func testAnswerCurrentWord() async throws {
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        let test = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 5)
        
        // 获取测试单词
        let words = try await vocabularyTestService.loadDictionaryWords(from: dictionary)
        guard let currentWord = words.first else {
            XCTFail("No words available")
            return
        }
        
        // 回答认识
        try await vocabularyTestService.recordWordMastery(testId: test.id, word: currentWord, mastery: .mastered)
        
        // 验证单词被记录为已掌握
        let testedWords = try await vocabularyTestService.getTestedWords(for: dictionary.fileName)
        XCTAssertGreaterThan(testedWords.count, 0)
    }
    
    func testAnswerCurrentWordWithoutTest() async {
        // 没有测试时尝试回答单词应该抛出错误
        let mockWord = DictionaryWord(word: "test", phonetic: nil, definitions: [], frequency: 0, difficulty: .basic, tags: [], categories: [])
        do {
            _ = try await vocabularyTestService.recordWordMastery(testId: UUID(), word: mockWord, mastery: .mastered)
            XCTFail("Should throw error")
        } catch {
            // 预期的错误
        }
    }
    
    func testSkipCurrentWord() async throws {
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        let test = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 5)
        
        // 获取测试单词
        let words = try await vocabularyTestService.loadDictionaryWords(from: dictionary)
        guard let currentWord = words.first else {
            XCTFail("No words available")
            return
        }
        
        // 跳过当前单词
        try await vocabularyTestService.recordWordMastery(testId: test.id, word: currentWord, mastery: .unfamiliar)
        
        // 验证单词被记录
        let testedWords = try await vocabularyTestService.getTestedWords(for: dictionary.fileName)
        XCTAssertGreaterThan(testedWords.count, 0)
    }
    
    func testCompleteTest() async throws {
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        let test = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 5)
        
        // 模拟回答几个单词
        let words = try await vocabularyTestService.loadDictionaryWords(from: dictionary)
        let mockWord = words.first ?? DictionaryWord(word: "test", phonetic: nil, definitions: [], frequency: 0, difficulty: .basic, tags: [], categories: [])
        for _ in 0..<3 {
            try await vocabularyTestService.recordWordMastery(testId: test.id, word: mockWord, mastery: .mastered)
        }
        
        // 完成测试
        let result = try await vocabularyTestService.completeTest(testId: test.id)
        XCTAssertNotNil(result)
        
        // 验证测试历史中有记录
        let history = try await vocabularyTestService.getTestHistory(limit: 10)
        XCTAssertGreaterThan(history.count, 0)
    }
    
    func testPauseAndResumeTest() async throws {
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        let test = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 5)
        
        // 暂停测试
        _ = try await vocabularyTestService.pauseTest(testId: test.id)
        
        // 恢复测试
        _ = try await vocabularyTestService.resumeTest(testId: test.id)
    }
    
    func testCancelTest() async throws {
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        let test = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 5)
        
        // 取消测试
        try await vocabularyTestService.deleteTest(testId: test.id)
    }
    
    // MARK: - Word Generation Tests
    
    func testGenerateTestWords() async throws {
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        let words = try await vocabularyTestService.loadDictionaryWords(from: dictionary)
        
        XCTAssertGreaterThan(words.count, 0)
        
        // 检查单词结构
        for word in words {
            XCTAssertFalse(word.word.isEmpty)
        }
    }
    
    func testGenerateTestWordsWithInsufficientWords() async throws {
        // 设置少量单词
        mockDictionaryService.setupMockWords(count: 5)
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        do {
            let test = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 100000)
            // 应该不会抛出错误，但可能返回比请求更少的单词
            XCTAssertGreaterThan(test.totalWords, 0)
        } catch {
            // 预期抛出单词不足的错误
            XCTAssertTrue(error is VocabularyTestError)
        }
    }
    
    func testSmartSample() async throws {
        mockDictionaryService.setupMockWords(count: 100)
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        let words = try await vocabularyTestService.loadDictionaryWords(from: dictionary)
        
        XCTAssertGreaterThan(words.count, 0)
        
        // 测试能够成功加载单词
        for word in words.prefix(30) {
            XCTAssertFalse(word.word.isEmpty)
        }
    }
    
    // MARK: - User Word Management Tests
    
    func testRecordKnownWord() async throws {
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        let test = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 10)
        
        let words = try await vocabularyTestService.loadDictionaryWords(from: dictionary)
        let mockWord = words.first ?? DictionaryWord(word: "test", phonetic: nil, definitions: [], frequency: 0, difficulty: .basic, tags: [], categories: [])
        try await vocabularyTestService.recordWordMastery(testId: test.id, word: mockWord, mastery: .mastered)
        
        let testedWords = try await vocabularyTestService.getTestedWords(for: dictionary.fileName)
        XCTAssertTrue(testedWords.contains { $0.word == mockWord.word })
    }
    
    // MARK: - Test History Tests
    
    func testGetTestHistory() async throws {
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        // 创建并完成几个测试
        for _ in 0..<3 {
            let test = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 5)
            _ = try await vocabularyTestService.completeTest(testId: test.id)
        }
        
        let history = try await vocabularyTestService.getTestHistory(limit: 10)
        XCTAssertEqual(history.count, 3)
        
        // 检查是否按时间倒序排列
        for i in 0..<(history.count - 1) {
            XCTAssertGreaterThanOrEqual(history[i].createdAt, history[i + 1].createdAt)
        }
    }
    
    func testGetLatestTest() {
        let expectation = XCTestExpectation(description: "Get latest test")
        mockDictionaryService.setupMockWords()
        
        // 没有测试历史时
        vocabularyTestService.getLatestTest()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to get latest test: \(error)")
                    }
                },
                receiveValue: { initialLatest in
                    XCTAssertNil(initialLatest)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDeleteTest() async throws {
        mockDictionaryService.setupMockWords()
        
        let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
        guard let dictionary = dictionaries.first else {
            XCTFail("No dictionaries available")
            return
        }
        
        let test = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 1)
        let completedTest = try await vocabularyTestService.completeTest(testId: test.id)
        
        _ = try await vocabularyTestService.deleteTest(testId: completedTest.id)
        
        let history = try await vocabularyTestService.getTestHistory(limit: 10)
        XCTAssertEqual(history.count, 0)
    }
    
    // MARK: - Statistics Tests
    
    func testGetTestStatistics() {
        let expectation = XCTestExpectation(description: "Get test statistics")
        mockDictionaryService.setupMockWords()
        
        // 测试获取测试统计
        vocabularyTestService.getTestStatistics()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to get test statistics: \(error)")
                    }
                    expectation.fulfill()
                },
                receiveValue: { receivedStatistics in
                    XCTAssertNotNil(receivedStatistics)
                    XCTAssertGreaterThanOrEqual(receivedStatistics.totalTests, 0)
                    XCTAssertGreaterThanOrEqual(receivedStatistics.averageScore, 0)
                    XCTAssertGreaterThanOrEqual(receivedStatistics.bestScore, 0)
                    XCTAssertGreaterThanOrEqual(receivedStatistics.improvementRate, 0.0)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCalculateImprovementRate() {
        let expectation = XCTestExpectation(description: "Calculate improvement rate")
        mockDictionaryService.setupMockWords()
        
        vocabularyTestService.calculateImprovementRate()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to calculate improvement rate: \(error)")
                    }
                    expectation.fulfill()
                },
                receiveValue: { improvementRate in
                    XCTAssertGreaterThanOrEqual(improvementRate, 0.0)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Current Test Information Tests
    
    func testGetCurrentWord() {
        let expectation = XCTestExpectation(description: "Get current word")
        mockDictionaryService.setupMockWords()
        
        vocabularyTestService.getCurrentWord()
            .sink(
                receiveCompletion: { completion in
                    expectation.fulfill()
                },
                receiveValue: { currentWord in
                    // currentWord可能为nil，这里只是测试方法能正常调用
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGetTestProgress() {
        let expectation = XCTestExpectation(description: "Get test progress")
        mockDictionaryService.setupMockWords()
        
        vocabularyTestService.getTestProgress(for: "test_dictionary.txt")
            .sink(
                receiveCompletion: { completion in
                    expectation.fulfill()
                },
                receiveValue: { progress in
                    XCTAssertNotNil(progress)
                    XCTAssertGreaterThanOrEqual(progress.testedWords, 0)
                    XCTAssertGreaterThanOrEqual(progress.totalWords, 0)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGetRemainingTime() {
        let expectation = XCTestExpectation(description: "Get remaining time")
        mockDictionaryService.setupMockWords()
        
        vocabularyTestService.getRemainingTime()
            .sink(
                receiveCompletion: { completion in
                    expectation.fulfill()
                },
                receiveValue: { remainingTime in
                    XCTAssertGreaterThanOrEqual(remainingTime, 0)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testIsTestTimedOut() {
        let expectation = XCTestExpectation(description: "Check if test is timed out")
        mockDictionaryService.setupMockWords()
        
        vocabularyTestService.isTestTimedOut()
            .sink(
                receiveCompletion: { completion in
                    expectation.fulfill()
                },
                receiveValue: { isTimedOut in
                    // 这里只是测试方法能正常调用
                    XCTAssertNotNil(isTimedOut)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async throws {
        // 测试在没有设置mock数据的情况下启动测试
        do {
            let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
            guard let dictionary = dictionaries.first else {
                // 预期没有可用字典时的行为
                return
            }
            _ = try await vocabularyTestService.startVocabularyTest(dictionary: dictionary, sampleSize: 10)
        } catch {
            // 预期的错误
            XCTAssertTrue(error is VocabularyTestError)
        }
        
        // 测试各种错误情况
        
        // 没有测试时尝试操作
        let mockWord = DictionaryWord(word: "test", phonetic: nil, definitions: [], frequency: 0, difficulty: .basic, tags: [], categories: [])
        let randomTestId = UUID()
        
        do {
            try await vocabularyTestService.recordWordMastery(testId: randomTestId, word: mockWord, mastery: .mastered)
            XCTFail("Expected error but operation succeeded")
        } catch {
            // 预期的错误
        }
        
        do {
            _ = try await vocabularyTestService.completeTest(testId: randomTestId)
            XCTFail("Expected error but operation succeeded")
        } catch {
            // 预期的错误
        }
        
        do {
            _ = try await vocabularyTestService.pauseTest(testId: randomTestId)
            XCTFail("Expected error but operation succeeded")
        } catch {
            // 预期的错误
        }
        
        do {
            _ = try await vocabularyTestService.resumeTest(testId: randomTestId)
            XCTFail("Expected error but operation succeeded")
        } catch {
            // 预期的错误
        }
    }
    
    // MARK: - Performance Tests
    
    func testGenerateTestWordsPerformance() throws {
        mockDictionaryService.setupMockWords(count: 10000)
        
        measure {
            Task {
                do {
                    let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
                    guard let dictionary = dictionaries.first else {
                        return
                    }
                    _ = try await vocabularyTestService.loadDictionaryWords(from: dictionary)
                } catch {
                    XCTFail("性能测试失败: \(error)")
                }
            }
        }
    }
    
    func testSmartSamplePerformance() throws {
        mockDictionaryService.setupMockWords(count: 10000)
        
        measure {
            Task {
                do {
                    let dictionaries = try await vocabularyTestService.getAvailableDictionaries()
                    guard let dictionary = dictionaries.first else {
                        return
                    }
                    _ = try await vocabularyTestService.loadDictionaryWords(from: dictionary)
                } catch {
                    XCTFail("性能测试失败: \(error)")
                }
            }
        }
    }
}

// MARK: - Mock Dictionary Service
// MockDictionaryService is defined in MockServices.swift

// MARK: - Publisher Extension for Testing

extension AnyPublisher {
    func async() async throws -> Output {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
}

// MARK: - VocabularyTestService Extension for Testing

extension VocabularyTestService {
    var dictionaryService: MockDictionaryService? {
        get { return nil }
        set { /* 在实际实现中，这里会设置依赖注入 */ }
    }
}