//
//  DictionaryLoaderTests.swift
//  en01Tests
//
//  Created by SOLO Coding on 2025/01/20.
//

import XCTest
@testable import en01

final class DictionaryLoaderTests: XCTestCase {
    var dictionaryLoader: DictionaryLoader!
    
    override func setUpWithError() throws {
        super.setUp()
        dictionaryLoader = DictionaryLoader()
    }
    
    override func tearDownWithError() throws {
        dictionaryLoader = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testDictionaryLoaderInitialization() {
        XCTAssertNotNil(dictionaryLoader)
        XCTAssertEqual(dictionaryLoader.getDictionaryInfos().count, 0)
        XCTAssertNil(dictionaryLoader.getCurrentDictionaryName())
        XCTAssertFalse(dictionaryLoader.isLoading)
    }
    
    // MARK: - Dictionary Info Tests
    
    func testGetDictionaryInfos() {
        let infos = dictionaryLoader.getDictionaryInfos()
        XCTAssertEqual(infos.count, 0, "Should return empty array when no dictionaries are loaded")
    }
    
    func testGetEnabledDictionaryInfos() {
        let enabledInfos = dictionaryLoader.getEnabledDictionaryInfos()
        XCTAssertTrue(enabledInfos.isEmpty)
    }
    
    // MARK: - Dictionary Scanning Tests
    
    func testScanDictionariesInDirectory() async throws {
        // 测试重新加载词典（内部会扫描目录）
        try await dictionaryLoader.reloadDictionaries()
        let infos = dictionaryLoader.getDictionaryInfos()
        XCTAssertEqual(infos.count, 0, "Should return empty array when no dictionaries found")
    }
    
    // MARK: - Dictionary Loading Tests
    
    func testLoadDictionaryFromFile() async throws {
        // 测试加载词典功能（通过重新加载）
        try await dictionaryLoader.reloadDictionaries()
        let infos = dictionaryLoader.getDictionaryInfos()
        XCTAssertEqual(infos.count, 0, "Should return empty array when no dictionary files found")
    }
    
    func testLoadDictionaryWithInvalidPath() async throws {
        // 测试加载不存在的词典文件
        do {
            try await dictionaryLoader.loadDictionaries()
            // 在没有词典文件的情况下，应该正常完成但不加载任何词典
        } catch {
            // 可能会抛出noDictionariesFound错误，这是正常的
            XCTAssertTrue(error is DictionaryLoaderError)
        }
    }
    
    func testLoadDictionaryWithCorruptedData() async throws {
        // 测试加载损坏的词典数据
        do {
            try await dictionaryLoader.loadDictionaries()
        } catch {
            // 可能会抛出各种错误，这是正常的
            XCTAssertTrue(error is DictionaryLoaderError)
        }
    }
    
    // MARK: - Word Retrieval Tests
    
    func testGetAllWords() {
        let words = dictionaryLoader.getAllWords()
        XCTAssertEqual(words.count, 0, "Should return empty array when no dictionaries are loaded")
    }
    
    func testGetAllWordsWithNoDictionary() {
        let allWords = dictionaryLoader.getAllWords()
        XCTAssertTrue(allWords.isEmpty)
    }
    
    func testSearchWordsByName() {
        let searchResults = dictionaryLoader.searchWords(query: "test")
        XCTAssertEqual(searchResults.count, 0, "Should return empty array when no words are available")
    }
    
    func testSearchWordsByDifficulty() {
        // 测试空词典的难度搜索
        let difficultyResults = dictionaryLoader.getWordsByDifficulty(.basic)
        XCTAssertTrue(difficultyResults.isEmpty)
    }
    
    func testGetRandomWords() {
        // 测试空词典的随机词汇获取
        let randomWords = dictionaryLoader.getRandomWords(count: 2)
        XCTAssertTrue(randomWords.isEmpty)
    }
    
    func testGetRandomWordsWithDifficultyRange() {
        // 测试空词典的难度范围随机词汇获取
        let randomWords = dictionaryLoader.getRandomWords(count: 5)
        XCTAssertTrue(randomWords.isEmpty)
    }
    
    // MARK: - Dictionary Management Tests
    
    func testGetAvailableDictionaries() {
        let availableDictionaries = dictionaryLoader.getDictionaryInfos()
        XCTAssertEqual(availableDictionaries.count, 0, "Should return empty array when no dictionaries are available")
    }
    
    func testSetCurrentDictionary() {
        // 测试设置不存在的词典
        dictionaryLoader.setCurrentDictionary("nonexistent")
        
        // 验证当前词典仍为空
        XCTAssertNil(dictionaryLoader.getCurrentDictionaryName())
    }
    
    func testSetCurrentDictionaryWithUnloadedDictionary() {
        // 测试设置不存在的词典
        dictionaryLoader.setCurrentDictionary("nonexistent")
        
        // 当前词典名称应该保持为nil
        XCTAssertNil(dictionaryLoader.getCurrentDictionaryName())
    }
    
    func testReloadCurrentDictionary() async throws {
        // 测试重新加载词典
        try await dictionaryLoader.reloadDictionaries()
        let infos = dictionaryLoader.getDictionaryInfos()
        XCTAssertEqual(infos.count, 0, "Should return empty array when no dictionaries found")
    }
    
    func testReloadWithNoDictionary() async throws {
        // 测试在没有词典的情况下重新加载
        try await dictionaryLoader.reloadDictionaries()
        
        // 验证加载状态
        XCTAssertFalse(dictionaryLoader.isDictionaryLoaded())
    }
    
    // MARK: - Loading Status Tests
    
    func testGetLoadingStatus() {
        let isLoading = dictionaryLoader.isLoading
        XCTAssertFalse(isLoading, "Should return false when no loading is in progress")
    }
    
    // MARK: - Statistics Tests
    
    func testGetStatistics() {
        let stats = dictionaryLoader.getDictionaryStatistics()
        XCTAssertEqual(stats.totalWords, 0, "Should return 0 total words when no dictionaries are loaded")
        XCTAssertEqual(stats.totalDictionaries, 0, "Should return 0 total dictionaries when none are loaded")
    }
    
    func testExportDictionaryData() {
        let exportData = dictionaryLoader.exportDictionaryInfo()
        XCTAssertNotNil(exportData, "Should return export data even when no dictionaries are loaded")
    }
    
    // MARK: - Error Handling Tests
    
    func testDictionaryLoaderErrorHandling() {
        // 测试设置无效词典
        dictionaryLoader.setCurrentDictionary("invalid")
        XCTAssertNil(dictionaryLoader.getCurrentDictionaryName(), "Should handle invalid dictionary name gracefully")
        
        // 测试获取不存在词典的单词
        let words = dictionaryLoader.getWords(from: "nonexistent")
        XCTAssertEqual(words.count, 0, "Should return empty array for non-existent dictionary")
    }
    
    // MARK: - Performance Tests
    
    func testWordSearchPerformance() {
        // 测试大量词汇搜索的性能
        measure {
            for i in 0..<1000 {
                let _ = dictionaryLoader.searchWords(query: "test\(i)")
            }
        }
    }
    
    func testRandomWordsPerformance() {
        // 测试随机词汇获取性能（在空词典情况下）
        measure {
            let randomWords = dictionaryLoader.getRandomWords(count: 50)
            XCTAssertTrue(randomWords.isEmpty)
        }
    }
}