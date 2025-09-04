//
//  VocabularyTestService.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import Foundation
import Combine
import CoreData

// MARK: - Protocol

protocol VocabularyTestServiceProtocol {
    /// 获取可用词典列表
    func getAvailableDictionaries() -> AnyPublisher<[DictionaryInfo], Error>
    
    /// 加载词典单词
    func loadDictionaryWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error>
    
    /// 开始词汇量测试
    func startVocabularyTest(dictionary: DictionaryInfo, sampleSize: Int) -> AnyPublisher<VocabularyTest, Error>
    
    /// 记录单词掌握程度
    func recordWordMastery(testId: UUID, word: DictionaryWord, mastery: MasteryLevel) -> AnyPublisher<Void, Error>
    
    /// 记录单词点击
    func recordWordClick(word: String, testId: UUID) -> AnyPublisher<Void, Error>
    
    /// 完成测试并计算词汇量
    func completeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error>
    
    /// 保存测试结果
    func saveTestResult(_ test: VocabularyTest) -> AnyPublisher<Void, Error>
    
    /// 获取测试历史
    func getTestHistory(limit: Int) -> AnyPublisher<[VocabularyTest], Error>
    
    /// 删除测试记录
    func deleteTestRecord(_ test: VocabularyTest) -> AnyPublisher<Void, Error>
    
    /// 删除测试
    func deleteTest(testId: UUID) -> AnyPublisher<Void, Error>
    
    /// 暂停测试
    func pauseTest(testId: UUID) -> AnyPublisher<Void, Error>
    
    /// 恢复测试
    func resumeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error>
    
    // MARK: - 阶段性保存功能
    
    /// 保存已测试单词
    func saveTestedWord(_ word: DictionaryWord, mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String, testSessionId: UUID?) -> AnyPublisher<Void, Error>
    
    /// 获取已测试单词列表
    func getTestedWords(for dictionaryFileName: String) -> AnyPublisher<[TestedWord], Error>
    
    /// 获取未测试单词列表
    func getUntestedWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error>
    
    /// 清除词典的所有测试记录
    func clearTestedWords(for dictionaryFileName: String) -> AnyPublisher<Void, Error>
    
    /// 获取词典测试进度
    func getTestProgress(for dictionaryFileName: String) -> AnyPublisher<TestProgress, Error>
    
    /// 获取最新测试
    func getLatestTest() -> AnyPublisher<VocabularyTest?, Error>
    
    /// 获取测试统计信息
    func getTestStatistics() -> AnyPublisher<TestStatistics, Error>
    
    /// 计算改进率
    func calculateImprovementRate() -> AnyPublisher<Double, Error>
    
    /// 获取当前单词
    func getCurrentWord() -> AnyPublisher<DictionaryWord?, Error>
    
    /// 获取剩余时间
    func getRemainingTime() -> AnyPublisher<TimeInterval, Error>
    
    /// 检查测试是否超时
    func isTestTimedOut() -> AnyPublisher<Bool, Error>
}

// MARK: - Implementation

class VocabularyTestService: VocabularyTestServiceProtocol {
    private let dictionaryService: DictionaryServiceProtocol
    private let coreDataStack: CoreDataStack
    private var activeTests: [UUID: VocabularyTest] = [:]
    private var testWords: [UUID: [DictionaryWord]] = [:]
    private var testResponses: [UUID: [WordTestResponse]] = [:]
    
    init(dictionaryService: DictionaryServiceProtocol, coreDataStack: CoreDataStack) {
        self.dictionaryService = dictionaryService
        self.coreDataStack = coreDataStack
    }
    
    func getAvailableDictionaries() -> AnyPublisher<[DictionaryInfo], Error> {
        return dictionaryService.getAvailableDictionaries()
            .map { dictionaries in
                dictionaries.map { dict in
                    DictionaryInfo(
                        name: dict.name,
                        displayName: dict.displayName,
                        fileName: dict.fileName,
                        filePath: dict.filePath,
                        version: dict.version,
                        description: dict.description,
                        language: dict.language,
                        totalWords: dict.totalWords,
                        difficultyLevels: dict.difficultyLevels,
                        categories: dict.categories,
                        fileSize: dict.fileSize,
                        checksum: dict.checksum,
                        isEnabled: dict.isEnabled,
                        priority: dict.priority,
                        statistics: dict.statistics,
                        configuration: dict.configuration
                    )
                }
            }
            .eraseToAnyPublisher()
    }
    
    func loadDictionaryWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        return dictionaryService.loadDictionary(fileName: dictionary.fileName)
            .map { words in
                words.map { word in
                    DictionaryWord(
                        word: word.word,
                        phonetic: word.phonetic,
                        definitions: word.definitions,
                        frequency: word.frequency,
                        difficulty: word.difficulty,
                        tags: word.tags,
                        categories: word.categories
                    )
                }
            }
            .eraseToAnyPublisher()
    }
    
    func startVocabularyTest(dictionary: DictionaryInfo, sampleSize: Int = 100) -> AnyPublisher<VocabularyTest, Error> {
        return loadDictionaryWords(from: dictionary)
            .tryMap { [weak self] words in
                guard let self = self else { throw VocabularyTestError.serviceUnavailable }
                
                // 随机选择测试单词
                let selectedWords = self.selectTestWords(from: words, count: sampleSize)
                
                // 创建测试实例
                let test = VocabularyTest(
                    id: UUID(),
                    dictionaryName: dictionary.name,
                    dictionaryFileName: dictionary.fileName,
                    totalWords: selectedWords.count,
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
                
                // 保存测试状态
                self.activeTests[test.id] = test
                self.testWords[test.id] = selectedWords
                self.testResponses[test.id] = []
                
                return test
            }
            .eraseToAnyPublisher()
    }
    
    func recordWordMastery(testId: UUID, word: DictionaryWord, mastery: MasteryLevel) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self,
                  let test = self.activeTests[testId] else {
                promise(.failure(VocabularyTestError.testNotFound))
                return
            }
            
            // 记录回答
            let response = WordTestResponse(
                word: word,
                mastery: mastery,
                timestamp: Date()
            )
            
            self.testResponses[testId, default: []].append(response)
            
            // 更新测试统计
            switch mastery {
            case .mastered:
                test.masteredCount += 1
            case .familiar:
                test.familiarCount += 1
            case .unfamiliar:
                test.unfamiliarCount += 1
            }
            
            test.currentWordIndex += 1
            self.activeTests[testId] = test
            
            // 阶段性保存已测试单词
            let _ = self.saveTestedWord(
                word,
                mastery: mastery,
                dictionaryName: test.dictionaryName,
                dictionaryFileName: test.dictionaryFileName,
                testSessionId: test.id
            ).sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("⚠️ 阶段性保存失败: \(error.localizedDescription)")
                    }
                },
                receiveValue: { _ in }
            )
            
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
    
    func completeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        return Future { [weak self] promise in
            guard let self = self,
                  let test = self.activeTests[testId],
                  let responses = self.testResponses[testId],
                  let words = self.testWords[testId] else {
                promise(.failure(VocabularyTestError.testNotFound))
                return
            }
            
            // 计算词汇量估算
            let estimatedSize = self.calculateVocabularySize(
                responses: responses,
                totalDictionaryWords: words.count
            )
            
            // 计算准确率（基于掌握和眼熟的比例）
            let knownWords = test.masteredCount + test.familiarCount
            let accuracy = test.totalWords > 0 ? Double(knownWords) / Double(test.totalWords) * 100 : 0
            
            // 更新测试结果
            test.isCompleted = true
            test.completedAt = Date()
            test.estimatedVocabularySize = estimatedSize
            test.accuracyPercentage = accuracy
            
            self.activeTests[testId] = test
            
            promise(.success(test))
        }
        .eraseToAnyPublisher()
    }
    
    func saveTestResult(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            let context = self.coreDataStack.context
            
            // 创建Core Data实体
            let testEntity = VocabularyTestEntity(context: context)
            testEntity.id = test.id
            testEntity.dictionaryName = test.dictionaryName
            testEntity.dictionaryFileName = test.dictionaryFileName
            testEntity.totalWords = Int32(test.totalWords)
            testEntity.masteredCount = Int32(test.masteredCount)
            testEntity.familiarCount = Int32(test.familiarCount)
            testEntity.unfamiliarCount = Int32(test.unfamiliarCount)
            testEntity.estimatedVocabularySize = Int32(test.estimatedVocabularySize)
            testEntity.accuracyPercentage = test.accuracyPercentage
            testEntity.createdAt = test.createdAt
            testEntity.completedAt = test.completedAt
            testEntity.isCompleted = test.isCompleted
            
            do {
                try context.save()
                
                // 清理活跃测试数据
                self.activeTests.removeValue(forKey: test.id)
                self.testWords.removeValue(forKey: test.id)
                self.testResponses.removeValue(forKey: test.id)
                
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func recordWordClick(word: String, testId: UUID) -> AnyPublisher<Void, Error> {
        return Future { promise in
            // 简单记录单词点击，可以用于统计分析
            print("Word clicked: \(word) in test: \(testId)")
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
    
    func getTestHistory(limit: Int = 20) -> AnyPublisher<[VocabularyTest], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            let context = self.coreDataStack.context
            let request: NSFetchRequest<VocabularyTestEntity> = VocabularyTestEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \VocabularyTestEntity.createdAt, ascending: false)]
            request.fetchLimit = limit
            
            do {
                let entities = try context.fetch(request)
                let tests = entities.compactMap { entity -> VocabularyTest? in
                    guard let id = entity.id,
                          let dictionaryName = entity.dictionaryName,
                          let dictionaryFileName = entity.dictionaryFileName,
                          let createdAt = entity.createdAt else {
                        return nil
                    }
                    
                    return VocabularyTest(
                        id: id,
                        dictionaryName: dictionaryName,
                        dictionaryFileName: dictionaryFileName,
                        totalWords: Int(entity.totalWords),
                        masteredCount: Int(entity.masteredCount),
                        familiarCount: Int(entity.familiarCount),
                        unfamiliarCount: Int(entity.unfamiliarCount),
                        currentWordIndex: Int(entity.totalWords), // 已完成
                        isCompleted: entity.isCompleted,
                        isPaused: false,
                        createdAt: createdAt,
                        completedAt: entity.completedAt,
                        estimatedVocabularySize: Int(entity.estimatedVocabularySize),
                        accuracyPercentage: entity.accuracyPercentage
                    )
                }
                
                promise(.success(tests))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func deleteTest(testId: UUID) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            let context = self.coreDataStack.context
            let request: NSFetchRequest<VocabularyTestEntity> = VocabularyTestEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", testId as CVarArg)
            
            do {
                let entities = try context.fetch(request)
                for entity in entities {
                    context.delete(entity)
                }
                try context.save()
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func deleteTestRecord(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            let context = self.coreDataStack.context
            let request: NSFetchRequest<VocabularyTestEntity> = VocabularyTestEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", test.id as CVarArg)
            
            do {
                let entities = try context.fetch(request)
                for entity in entities {
                    context.delete(entity)
                }
                try context.save()
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func pauseTest(testId: UUID) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self,
                  let test = self.activeTests[testId] else {
                promise(.failure(VocabularyTestError.testNotFound))
                return
            }
            
            let updatedTest = test
            updatedTest.isPaused = true
            // Removed redundant assignment
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
    
    func resumeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        return Future { [weak self] promise in
            guard let self = self,
                  let test = self.activeTests[testId] else {
                promise(.failure(VocabularyTestError.testNotFound))
                return
            }
            
            let updatedTest = test
            updatedTest.isPaused = false
            // Removed redundant assignment
            promise(.success(updatedTest))
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - 阶段性保存功能实现

extension VocabularyTestService {
    func saveTestedWord(_ word: DictionaryWord, mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String, testSessionId: UUID?) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            let context = self.coreDataStack.context
            
            do {
                // 检查是否已存在该单词的测试记录
                let request: NSFetchRequest<TestedWordEntity> = TestedWordEntity.fetchRequest()
                request.predicate = NSPredicate(format: "word == %@ AND dictionaryFileName == %@", word.word, dictionaryFileName)
                
                let existingWords = try context.fetch(request)
                
                if let existingWord = existingWords.first {
                    // 更新现有记录
                    existingWord.masteryLevel = mastery.rawValue
                    existingWord.testedAt = Date()
                } else {
                    // 创建新的测试记录
                    let testedWord = TestedWordEntity(context: context)
                    testedWord.id = UUID()
                    testedWord.word = word.word
                    testedWord.dictionaryName = dictionaryName
                    testedWord.dictionaryFileName = dictionaryFileName
                    testedWord.masteryLevel = mastery.rawValue
                    testedWord.testSessionId = testSessionId
                    testedWord.testedAt = Date()
                    testedWord.difficulty = self.calculateWordDifficulty(word).rawValue
                    testedWord.responseTime = 0.0
                }
                
                try context.save()
                print("✅ 已保存测试单词: \(word.word) - \(mastery)")
                promise(.success(()))
            } catch {
                print("❌ 保存测试单词失败: \(error.localizedDescription)")
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getTestedWords(for dictionaryFileName: String) -> AnyPublisher<[TestedWord], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            let context = self.coreDataStack.context
            
            do {
                let request: NSFetchRequest<TestedWordEntity> = TestedWordEntity.fetchRequest()
                request.predicate = NSPredicate(format: "dictionaryFileName == %@", dictionaryFileName)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \TestedWordEntity.testedAt, ascending: false)]
                
                let entities = try context.fetch(request)
                let testedWords = entities.compactMap { entity -> TestedWord? in
                    guard let word = entity.word,
                          let dictionaryName = entity.dictionaryName,
                          let dictionaryFileName = entity.dictionaryFileName,
                          let masteryLevelRaw = entity.masteryLevel,
                          let masteryLevel = MasteryLevel(rawValue: masteryLevelRaw),
                          let testedAt = entity.testedAt else {
                        return nil
                    }
                    
                    let difficultyLevel: DifficultyLevel
                    if let difficultyRaw = entity.difficulty {
                        difficultyLevel = DifficultyLevel(rawValue: difficultyRaw) ?? .intermediate
                    } else {
                        difficultyLevel = .intermediate
                    }
                    
                    let testedWord = TestedWord(
                        word: word,
                        dictionaryName: dictionaryName,
                        dictionaryFileName: dictionaryFileName,
                        masteryLevel: masteryLevel,
                        testSessionId: entity.testSessionId,
                        difficulty: difficultyLevel.rawValue
                    )
                    testedWord.testedAt = testedAt
                    return testedWord
                }
                
                print("✅ 获取已测试单词: \(testedWords.count) 个")
                promise(.success(testedWords))
            } catch {
                print("❌ 获取已测试单词失败: \(error.localizedDescription)")
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getUntestedWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        return Publishers.CombineLatest(
            loadDictionaryWords(from: dictionary),
            getTestedWords(for: dictionary.fileName)
        )
        .map { allWords, testedWords in
            let testedWordSet = Set(testedWords.map { $0.word })
            return allWords.filter { !testedWordSet.contains($0.word) }
        }
        .eraseToAnyPublisher()
    }
    
    func clearTestedWords(for dictionaryFileName: String) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            let context = self.coreDataStack.context
            
            do {
                let request: NSFetchRequest<TestedWordEntity> = TestedWordEntity.fetchRequest()
                request.predicate = NSPredicate(format: "dictionaryFileName == %@", dictionaryFileName)
                
                let entities = try context.fetch(request)
                for entity in entities {
                    context.delete(entity)
                }
                
                try context.save()
                print("✅ 已清除词典 \(dictionaryFileName) 的所有测试记录")
                promise(.success(()))
            } catch {
                print("❌ 清除测试记录失败: \(error.localizedDescription)")
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getTestProgress(for dictionaryFileName: String) -> AnyPublisher<TestProgress, Error> {
        return getAvailableDictionaries()
            .tryMap { dictionaries in
                guard let dictionary = dictionaries.first(where: { $0.fileName == dictionaryFileName }) else {
                    throw VocabularyTestError.invalidTestData
                }
                return dictionary
            }
            .flatMap { dictionary in
                Publishers.CombineLatest(
                    self.loadDictionaryWords(from: dictionary),
                    self.getTestedWords(for: dictionaryFileName)
                )
                .map { allWords, testedWords in
                    let totalWords = allWords.count
                    let testedCount = testedWords.count
                    let untestedCount = max(0, totalWords - testedCount)
                    let masteredCount = testedWords.filter { $0.masteryLevel == "掌握" }.count
                    let familiarCount = testedWords.filter { $0.masteryLevel == "熟悉" }.count
                    let unfamiliarCount = testedWords.filter { $0.masteryLevel == "生疏" }.count
                    
                    return TestProgress(
                        dictionaryFileName: dictionaryFileName,
                        dictionaryName: dictionary.name,
                        totalWords: totalWords,
                        testedWords: testedCount,
                        untestedWords: untestedCount,
                        masteredWords: masteredCount,
                        familiarWords: familiarCount,
                        unfamiliarWords: unfamiliarCount,
                        currentIndex: testedCount
                    )
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Additional Methods
    
    func getLatestTest() -> AnyPublisher<VocabularyTest?, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            let context = self.coreDataStack.context
            let request: NSFetchRequest<VocabularyTestEntity> = VocabularyTestEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            request.fetchLimit = 1
            
            do {
                let entities = try context.fetch(request)
                guard let entity = entities.first,
                      let id = entity.id,
                      let dictionaryName = entity.dictionaryName,
                      let dictionaryFileName = entity.dictionaryFileName,
                      let createdAt = entity.createdAt else {
                    promise(.success(nil))
                    return
                }
                
                let test = VocabularyTest(
                    id: id,
                    dictionaryName: dictionaryName,
                    dictionaryFileName: dictionaryFileName,
                    totalWords: Int(entity.totalWords),
                    masteredCount: Int(entity.masteredCount),
                    familiarCount: Int(entity.familiarCount),
                    unfamiliarCount: Int(entity.unfamiliarCount),
                    currentWordIndex: Int(entity.totalWords),
                    isCompleted: entity.isCompleted,
                    isPaused: false,
                    createdAt: createdAt,
                    completedAt: entity.completedAt,
                    estimatedVocabularySize: Int(entity.estimatedVocabularySize),
                    accuracyPercentage: entity.accuracyPercentage
                )
                promise(.success(test))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getTestStatistics() -> AnyPublisher<TestStatistics, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            let context = self.coreDataStack.context
            let request: NSFetchRequest<VocabularyTestEntity> = VocabularyTestEntity.fetchRequest()
            
            do {
                let entities = try context.fetch(request)
                let completedTests = entities.filter { $0.isCompleted }
                let totalTests = completedTests.count
                let averageScore = completedTests.isEmpty ? 0.0 : 
                    completedTests.map { Double($0.estimatedVocabularySize) }.reduce(0, +) / Double(totalTests)
                
                let statistics = TestStatistics(
                    totalTests: totalTests,
                    averageScore: averageScore,
                    bestScore: completedTests.map { Int($0.estimatedVocabularySize) }.max() ?? 0,
                    improvementRate: 0.0
                )
                promise(.success(statistics))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func calculateImprovementRate() -> AnyPublisher<Double, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(VocabularyTestError.serviceUnavailable))
                return
            }
            
            let context = self.coreDataStack.context
            let request: NSFetchRequest<VocabularyTestEntity> = VocabularyTestEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            
            do {
                let entities = try context.fetch(request)
                let completedTests = entities.filter { $0.isCompleted }
                
                guard completedTests.count >= 2 else {
                    promise(.success(0.0))
                    return
                }
                
                let firstScore = Double(completedTests.first?.estimatedVocabularySize ?? 0)
                let lastScore = Double(completedTests.last?.estimatedVocabularySize ?? 0)
                
                let improvementRate = firstScore > 0 ? ((lastScore - firstScore) / firstScore) * 100 : 0.0
                promise(.success(improvementRate))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getCurrentWord() -> AnyPublisher<DictionaryWord?, Error> {
        // 这个方法需要根据当前测试状态返回当前单词
        // 由于没有当前测试状态管理，返回nil
        return Just(nil)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getRemainingTime() -> AnyPublisher<TimeInterval, Error> {
        // 返回剩余时间，这里返回0表示没有时间限制或测试已结束
        return Just(0)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func isTestTimedOut() -> AnyPublisher<Bool, Error> {
        // 检查测试是否超时，这里返回false
        return Just(false)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - Private Methods

private extension VocabularyTestService {
    func mapDifficultyLevel(_ level: String) -> DifficultyLevel {
        switch level.lowercased() {
        case "beginner", "初级":
            return .beginner
        case "intermediate", "中级":
            return .intermediate
        case "advanced", "高级":
            return .advanced
        default:
            return .intermediate
        }
    }
    
    func calculateWordDifficulty(_ word: DictionaryWord) -> DifficultyLevel {
        // 基于单词长度和定义数量简单估算难度
        let wordLength = word.word.count
        let definitionCount = word.definitions.count
        
        if wordLength <= 4 && definitionCount <= 2 {
            return .beginner
        } else if wordLength <= 8 && definitionCount <= 4 {
            return .intermediate
        } else {
            return .advanced
        }
    }
    
    func selectTestWords(from words: [DictionaryWord], count: Int) -> [DictionaryWord] {
        guard words.count > count else { return words }
        
        // 分层抽样：确保各难度级别的单词都有代表
        let beginnerWords = words.filter { $0.difficulty == .basic }
        let intermediateWords = words.filter { $0.difficulty == .medium }
        let advancedWords = words.filter { $0.difficulty == .advanced }
        
        let beginnerCount = min(count / 3, beginnerWords.count)
        let intermediateCount = min(count / 3, intermediateWords.count)
        let advancedCount = min(count - beginnerCount - intermediateCount, advancedWords.count)
        
        var selectedWords: [DictionaryWord] = []
        selectedWords.append(contentsOf: Array(beginnerWords.shuffled().prefix(beginnerCount)))
        selectedWords.append(contentsOf: Array(intermediateWords.shuffled().prefix(intermediateCount)))
        selectedWords.append(contentsOf: Array(advancedWords.shuffled().prefix(advancedCount)))
        
        // 如果还需要更多单词，从剩余单词中随机选择
        if selectedWords.count < count {
            let remaining = words.filter { !selectedWords.contains($0) }
            let additionalCount = count - selectedWords.count
            selectedWords.append(contentsOf: Array(remaining.shuffled().prefix(additionalCount)))
        }
        
        return selectedWords.shuffled()
    }
    
    func calculateVocabularySize(responses: [WordTestResponse], totalDictionaryWords: Int) -> Int {
        guard !responses.isEmpty else { return 0 }
        
        // 使用简化的词汇量估算公式
        let masteredCount = responses.filter { $0.mastery == .mastered }.count
        let familiarCount = responses.filter { $0.mastery == .familiar }.count
        
        // 权重：掌握=1.0，眼熟=0.7，陌生=0.0
        let weightedKnownWords = Double(masteredCount) * 1.0 + Double(familiarCount) * 0.7
        let knowledgeRatio = weightedKnownWords / Double(responses.count)
        
        // 估算总词汇量
        let estimatedSize = Int(knowledgeRatio * Double(totalDictionaryWords))
        
        return max(estimatedSize, 0)
    }
}

// MARK: - Supporting Types

struct WordTestResponse {
    let word: DictionaryWord
    let mastery: MasteryLevel
    let timestamp: Date
}

struct TestStatistics {
    let totalTests: Int
    let averageScore: Double
    let bestScore: Int
    let improvementRate: Double
}

enum VocabularyTestError: LocalizedError {
    case testNotFound
    case serviceUnavailable
    case invalidTestData
    
    var errorDescription: String? {
        switch self {
        case .testNotFound:
            return "测试未找到"
        case .serviceUnavailable:
            return "服务不可用"
        case .invalidTestData:
            return "测试数据无效"
        }
    }
}

// MARK: - Mock Implementation

class MockVocabularyTestService: VocabularyTestServiceProtocol {
    private var mockTests: [VocabularyTest] = []
    
    func getAvailableDictionaries() -> AnyPublisher<[DictionaryInfo], Error> {
        let dictionaries = [
            DictionaryInfo(
                name: "考研词汇",
                displayName: "考研词汇",
                fileName: "KaoYan_1.json",
                filePath: "KaoYan_1.json",
                version: "1.0",
                description: "考研必备词汇，涵盖历年真题高频词汇",
                language: "en",
                totalWords: 5500,
                difficultyLevels: [1, 2, 3, 4],
                categories: ["考研"],
                fileSize: 2048000,
                checksum: "mock_checksum",
                isEnabled: true,
                priority: 1
            ),
            DictionaryInfo(
                name: "四级词汇",
                displayName: "四级词汇",
                fileName: "CET4.json",
                filePath: "CET4.json",
                version: "1.0",
                description: "大学英语四级考试词汇",
                language: "en",
                totalWords: 4000,
                difficultyLevels: [1, 2],
                categories: ["CET4"],
                fileSize: 1024000,
                checksum: "mock_checksum",
                isEnabled: true,
                priority: 2
            )
        ]
        
        return Just(dictionaries)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func loadDictionaryWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        let words = [
            DictionaryWord(
                word: "abandon",
                phonetic: "/əˈbændən/",
                definitions: [WordDefinition(partOfSpeech: .verb, meaning: "放弃，抛弃", examples: ["He abandoned his car in the snow."])],
                difficulty: .basic,
                categories: ["基础词汇"]
            ),
            DictionaryWord(
                word: "sophisticated",
                phonetic: "/səˈfɪstɪkeɪtɪd/",
                definitions: [
                    WordDefinition(partOfSpeech: .adjective, meaning: "复杂的，精密的"),
                    WordDefinition(partOfSpeech: .adjective, meaning: "老练的，世故的", examples: ["This is a sophisticated piece of equipment."])
                ],
                difficulty: .advanced,
                categories: ["高级词汇"]
            )
        ]
        
        return Just(words)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func startVocabularyTest(dictionary: DictionaryInfo, sampleSize: Int) -> AnyPublisher<VocabularyTest, Error> {
        let test = VocabularyTest(
            dictionaryName: dictionary.name,
            sampleSize: sampleSize,
            difficultyRange: "1-4"
        )
        test.totalWords = sampleSize
        
        return Just(test)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func recordWordMastery(testId: UUID, word: DictionaryWord, mastery: MasteryLevel) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func completeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        let test = VocabularyTest(
            dictionaryName: "考研词汇",
            sampleSize: 100,
            difficultyRange: "1-4"
        )
        test.id = testId
        test.totalWords = 100
        test.knownWords = 85
        test.unknownWords = 15
        test.estimatedVocabulary = 4200
        test.accuracy = 0.85
        test.isCompleted = true
        test.testDate = Date().addingTimeInterval(-3600)
        test.testDuration = 3600
        
        return Just(test)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func saveTestResult(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        mockTests.append(test)
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func recordWordClick(word: String, testId: UUID) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestHistory(limit: Int = 20) -> AnyPublisher<[VocabularyTest], Error> {
        let limitedTests = Array(mockTests.prefix(limit))
        return Just(limitedTests)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func deleteTest(testId: UUID) -> AnyPublisher<Void, Error> {
        mockTests.removeAll { $0.id == testId }
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func deleteTestRecord(_ test: VocabularyTest) -> AnyPublisher<Void, Error> {
        mockTests.removeAll { $0.id == test.id }
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func pauseTest(testId: UUID) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func resumeTest(testId: UUID) -> AnyPublisher<VocabularyTest, Error> {
        let test = VocabularyTest(
            dictionaryName: "考研词汇",
            sampleSize: 100,
            difficultyRange: "1-4"
        )
        test.id = testId
        test.totalWords = 55
        test.knownWords = 45
        test.unknownWords = 10
        test.isCompleted = false
        test.testDate = Date().addingTimeInterval(-1800)
        
        return Just(test)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - 阶段性保存功能
    
    func saveTestedWord(_ word: DictionaryWord, mastery: MasteryLevel, dictionaryName: String, dictionaryFileName: String, testSessionId: UUID?) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestedWords(for dictionaryFileName: String) -> AnyPublisher<[TestedWord], Error> {
        let testedWords = [
            TestedWord(
                word: "abandon",
                dictionaryName: "考研词汇",
                dictionaryFileName: dictionaryFileName,
                masteryLevel: .mastered,
                difficulty: "basic"
            ),
            TestedWord(
                word: "sophisticated",
                dictionaryName: "考研词汇",
                dictionaryFileName: dictionaryFileName,
                masteryLevel: .familiar,
                difficulty: "advanced"
            )
        ]
        
        return Just(testedWords)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getUntestedWords(from dictionary: DictionaryInfo) -> AnyPublisher<[DictionaryWord], Error> {
        let words = [
            DictionaryWord(
                word: "example",
                phonetic: "/ɪɡˈzæmpl/",
                definitions: [WordDefinition(partOfSpeech: .noun, meaning: "例子，实例")],
                difficulty: .medium,
                categories: ["常用词汇"]
            ),
            DictionaryWord(
                word: "challenge",
                phonetic: "/ˈtʃælɪndʒ/",
                definitions: [WordDefinition(partOfSpeech: .noun, meaning: "挑战，难题")],
                difficulty: .medium,
                categories: ["常用词汇"]
            )
        ]
        
        return Just(words)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func clearTestedWords(for dictionaryFileName: String) -> AnyPublisher<Void, Error> {
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestProgress(for dictionaryFileName: String) -> AnyPublisher<TestProgress, Error> {
        let progress = TestProgress(
            dictionaryFileName: dictionaryFileName,
            dictionaryName: "考研词汇",
            totalWords: 5500,
            testedWords: 150,
            untestedWords: 5350,
            masteredWords: 80,
            familiarWords: 45,
            unfamiliarWords: 25,
            currentIndex: 150
        )
        
        return Just(progress)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - 新增协议方法实现
    
    func getLatestTest() -> AnyPublisher<VocabularyTest?, Error> {
        let latestTest = mockTests.last
        return Just(latestTest)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getTestStatistics() -> AnyPublisher<TestStatistics, Error> {
        let stats = TestStatistics(
            totalTests: mockTests.count,
            averageScore: 0.85,
            bestScore: 95,
            improvementRate: 0.15
        )
        return Just(stats)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func calculateImprovementRate() -> AnyPublisher<Double, Error> {
        return Just(0.15)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getCurrentWord() -> AnyPublisher<DictionaryWord?, Error> {
        let word = DictionaryWord(
            word: "current",
            phonetic: "/ˈkɜːrənt/",
            definitions: [WordDefinition(partOfSpeech: .adjective, meaning: "当前的，现在的")],
            difficulty: .medium,
            categories: ["常用词汇"]
        )
        return Just(word)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func getRemainingTime() -> AnyPublisher<TimeInterval, Error> {
        return Just(1800.0) // 30分钟
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func isTestTimedOut() -> AnyPublisher<Bool, Error> {
        return Just(false)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}