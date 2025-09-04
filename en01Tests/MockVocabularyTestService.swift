//
//  MockVocabularyTestService.swift
//  en01Tests
//
//  Created by AI Assistant on 2024/12/24.
//

import Foundation
import Combine
@testable import en01

// MARK: - Mock Core Data Stack

class MockCoreDataStack {
    // Mock implementation without inheriting from CoreDataStack
    init() {
        // Mock initialization
    }
}

// MockDictionaryService is imported from MockServices.swift

// MARK: - Mock Vocabulary Test Service

class MockVocabularyTestService: VocabularyTestServiceProtocol {
    private let dictionaryService: MockDictionaryService
    private let coreDataStack: MockCoreDataStack
    
    // 默认配置
    let defaultSampleSize: Int = 100
    let defaultDifficultyRange: ClosedRange<Int> = 1...4
    
    // Test state
    var currentTest: VocabularyTest?
    private var currentWords: [DictionaryWord] = []
    private var currentWordIndex: Int = 0
    private var testStartTime: Date?
    private var testResponses: [WordTestResponse] = []
    private var testHistory: [VocabularyTest] = []
    
    // Test configuration
    var timeLimit: TimeInterval = 1800 // 30 minutes default
    
    var isTestInProgress: Bool {
        return currentTest != nil
    }
    
    init(dictionaryService: MockDictionaryService, coreDataStack: MockCoreDataStack) {
        self.dictionaryService = dictionaryService
        self.coreDataStack = coreDataStack
    }
    
    // MARK: - VocabularyTestServiceProtocol Implementation
    

    
    // MARK: - Helper Methods for Testing
    
    private func parseDifficultyRange(_ range: String) -> ClosedRange<Int> {
        let components = range.split(separator: "-")
        guard components.count == 2,
              let start = Int(components[0]),
              let end = Int(components[1]) else {
            return 1...4 // Default range
        }
        return start...end
    }
    
    // MARK: - VocabularyTestServiceProtocol Implementation
    
    func getAvailableDictionaries() -> AnyPublisher<[DictionaryInfo], Error> {
        return dictionaryService.getAvailableDictionaries()
    }
    
    func loadDictionaryWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        return dictionaryService.loadDictionary(fileName: dictionary.fileName)
    }
    
    func startVocabularyTest(dictionary: DictionaryInfo, sampleSize: Int) -> AnyPublisher<VocabularyTest, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            let words = self.dictionaryService.getRandomWords(count: sampleSize)
            let test = VocabularyTest(
                id: UUID(),
                dictionaryName: dictionary.name,
                dictionaryFileName: dictionary.fileName,
                totalWords: words.count,
                masteredCount: 0,
                familiarCount: 0,
                unfamiliarCount: 0,
                currentWordIndex: 0,
                isCompleted: false,
                isPaused: false,
                createdAt: Date(),
                completedAt: nil,
                estimatedVocabularySize: 0,
                accuracyPercentage: 0.0
            )
            
            self.currentTest = test
            self.currentWords = words
            self.currentWordIndex = 0
            
            promise(.success(test))
        }
        .eraseToAnyPublisher()
    }
    
    func recordWordMastery(testId: UUID, word: DictionaryWord, mastery: MasteryLevel) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self,
                  let test = self.currentTest,
                  test.id == testId else {
                promise(.failure(VocabularyTestError.testNotFound))
                return
            }
            
            // Update test statistics
            switch mastery {
            case .mastered:
                test.masteredCount += 1
            case .familiar:
                test.familiarCount += 1
            case .unfamiliar:
                test.unfamiliarCount += 1
            }
            
            test.currentWordIndex += 1
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
    
    func recordWordClick(word: String, testId: UUID) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func completeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        return Future { [weak self] promise in
            guard let self = self,
                  let test = self.currentTest,
                  test.id == testId else {
                promise(.failure(VocabularyTestError.testNotFound))
                return
            }
            
            test.isCompleted = true
            test.completedAt = Date()
            
            // Calculate estimated vocabulary size
            let totalAnswered = test.masteredCount + test.familiarCount + test.unfamiliarCount
            if totalAnswered > 0 {
                let accuracy = Double(test.masteredCount + test.familiarCount) / Double(totalAnswered)
                test.accuracyPercentage = accuracy * 100
                test.estimatedVocabularySize = Int(accuracy * Double(self.dictionaryService.getAllWords().count))
            }
            
            self.testHistory.append(test)
            self.currentTest = nil
            self.currentWords = []
            self.currentWordIndex = 0
            
            promise(.success(test))
        }
        .eraseToAnyPublisher()
    }
    
    func saveTestResult(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestHistory(limit: Int) -> AnyPublisher<[VocabularyTest], Error> {
        let test1 = VocabularyTest(
            id: UUID(),
            dictionaryName: "Test Dictionary 1",
            dictionaryFileName: "test1.json",
            totalWords: 100,
            masteredCount: 60,
            familiarCount: 20,
            unfamiliarCount: 20,
            currentWordIndex: 100,
            isCompleted: true,
            isPaused: false,
            createdAt: Date().addingTimeInterval(-86400),
            completedAt: Date().addingTimeInterval(-86000),
            estimatedVocabularySize: 6000,
            accuracyPercentage: 80.0
        )
        
        let test2 = VocabularyTest(
            id: UUID(),
            dictionaryName: "Test Dictionary 2",
            dictionaryFileName: "test2.json",
            totalWords: 50,
            masteredCount: 30,
            familiarCount: 10,
            unfamiliarCount: 10,
            currentWordIndex: 50,
            isCompleted: true,
            isPaused: false,
            createdAt: Date().addingTimeInterval(-172800),
            completedAt: Date().addingTimeInterval(-172400),
            estimatedVocabularySize: 3000,
            accuracyPercentage: 75.0
        )
        
        let limitedTests = Array([test1, test2].prefix(limit))
        return Just(limitedTests)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func deleteTestRecord(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        testHistory.removeAll { $0.id == test.id }
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func deleteTest(testId: UUID) -> AnyPublisher<Void, Error> {
        testHistory.removeAll { $0.id == testId }
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func pauseTest(testId: UUID) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self,
                  let test = self.currentTest,
                  test.id == testId else {
                promise(.failure(VocabularyTestError.testNotFound))
                return
            }
            
            test.isPaused = true
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
    
    func resumeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        return Future { [weak self] promise in
            guard let self = self,
                  let test = self.currentTest,
                  test.id == testId else {
                promise(.failure(VocabularyTestError.testNotFound))
                return
            }
            
            test.isPaused = false
            promise(.success(test))
        }
        .eraseToAnyPublisher()
    }
    
    func saveTestedWord(_ word: DictionaryWord, mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String, testSessionId: UUID?) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestedWords(for dictionaryFileName: String) -> AnyPublisher<[TestedWord], Error> {
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getUntestedWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        return loadDictionaryWords(from: dictionary)
    }
    
    func clearTestedWords(for dictionaryFileName: String) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestProgress(for dictionaryFileName: String) -> AnyPublisher<TestProgress, Error> {
        let totalWords = currentTest?.totalWords ?? 10
        let currentIndex = currentWordIndex
        
        let progress = TestProgress(
            dictionaryFileName: dictionaryFileName,
            dictionaryName: "Test Dictionary",
            totalWords: totalWords,
            testedWords: currentIndex,
            untestedWords: totalWords - currentIndex,
            masteredWords: 0,
            familiarWords: 0,
            unfamiliarWords: 0,
            currentIndex: currentIndex
        )
        return Just(progress)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Protocol Required Methods
    
    func getLatestTest() -> AnyPublisher<VocabularyTest?, Error> {
        return Just(testHistory.first)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestStatistics() -> AnyPublisher<TestStatistics, Error> {
        let totalTests = testHistory.count
        let totalAccuracy = testHistory.reduce(0.0) { $0 + $1.accuracyPercentage }
        let averageAccuracy = totalTests > 0 ? totalAccuracy / Double(totalTests) : 0.0
        
        let totalVocabularySize = testHistory.reduce(0) { $0 + $1.estimatedVocabularySize }
        let averageVocabularySize = totalTests > 0 ? totalVocabularySize / totalTests : 0
        
        let totalTestTime: TimeInterval = testHistory.reduce(0) { result, test in
            if let completedAt = test.completedAt {
                return result + completedAt.timeIntervalSince(test.createdAt)
            }
            return result
        }
        let averageTestTime = totalTests > 0 ? totalTestTime / Double(totalTests) : 0.0
        
        let stats = TestStatistics(
             totalTests: totalTests,
             averageScore: averageAccuracy,
             bestScore: Int((testHistory.map { $0.accuracyPercentage }.max() ?? 0.0) * 100),
             improvementRate: calculateImprovementRateSync()
         )
        
        return Just(stats)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func calculateImprovementRate() -> AnyPublisher<Double, Error> {
        let rate = calculateImprovementRateSync()
        return Just(rate)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getCurrentWord() -> AnyPublisher<DictionaryWord?, Error> {
        let word = currentWordIndex < currentWords.count ? currentWords[currentWordIndex] : nil
        return Just(word)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getRemainingTime() -> AnyPublisher<TimeInterval, Error> {
        guard let startTime = testStartTime else {
            return Just(timeLimit)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = max(0, timeLimit - elapsed)
        return Just(remaining)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func isTestTimedOut() -> AnyPublisher<Bool, Error> {
        return getRemainingTime()
            .map { $0 <= 0 }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Additional Methods for Testing
    
    private var currentTestId: UUID?
    private var testWords: [DictionaryWord] = []
    
    func cancelTest() throws {
        guard currentTest != nil else {
            throw VocabularyTestError.testNotFound
        }
        
        currentTest = nil
        testWords = []
        currentWordIndex = 0
        testStartTime = nil
    }
    
    private func calculateImprovementRateSync() -> Double {
        guard testHistory.count >= 2 else {
            return 0.0
        }
        
        let latest = testHistory[0]
        let previous = testHistory[1]
        
        let improvement = latest.accuracyPercentage - previous.accuracyPercentage
        return improvement
    }
    
    func answerCurrentWord(isKnown: Bool) throws {
        guard currentTestId != nil else {
            throw VocabularyTestError.testNotFound
        }
        currentWordIndex += 1
    }
    
    func skipCurrentWord() throws {
        guard currentTestId != nil else {
            throw VocabularyTestError.testNotFound
        }
        currentWordIndex += 1
    }
    

    

}

// MARK: - Supporting Types

// TestStatistics 和 VocabularyTestError 已在主项目的 VocabularyTestService.swift 中定义，此处不需要重复定义
// UserWord 已在主项目的 Models/Word.swift 中定义，此处不需要重复定义

struct WordTestResult {
    let word: String
    let isKnown: Bool
    let timestamp: Date
}