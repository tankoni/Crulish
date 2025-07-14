//
//  PerformanceTests.swift
//  en01Tests
//
//  Created by Assistant on 2024-12-19.
//

import Testing
import Foundation
@testable import en01

struct PerformanceTests {
    
    // MARK: - Memory Performance Tests
    @Test func testMemoryUsageWithLargeArticleList() async throws {
        let mockService = MockArticleService()
        let mockUserProgressService = MockUserProgressService()
        let mockErrorHandler = MockErrorHandler()
        
        let viewModel = HomeViewModel(
            articleService: mockService,
            userProgressService: mockUserProgressService,
            errorHandler: mockErrorHandler
        )
        
        // 模拟加载大量文章
        let startMemory = getMemoryUsage()
        
        for _ in 0..<1000 {
            await viewModel.loadArticles()
        }
        
        let endMemory = getMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        
        // 内存增长应该控制在合理范围内（50MB）
        #expect(memoryIncrease < 50 * 1024 * 1024)
    }
    
    @Test func testVocabularyListScrollingPerformance() async throws {
        let mockDictionaryService = MockDictionaryService()
        let mockUserProgressService = MockUserProgressService()
        let mockErrorHandler = MockErrorHandler()
        
        let viewModel = VocabularyViewModel(
            dictionaryService: mockDictionaryService,
            userProgressService: mockUserProgressService,
            errorHandler: mockErrorHandler
        )
        
        await viewModel.loadVocabulary()
        
        // 测试搜索性能
        let startTime = Date()
        
        for i in 0..<100 {
            viewModel.searchText = "test\(i)"
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // 100次搜索应该在1秒内完成
        #expect(duration < 1.0)
    }
    
    // MARK: - Network Performance Tests
    @Test func testArticleLoadingConcurrency() async throws {
        let mockService = MockArticleService()
        
        let startTime = Date()
        
        // 并发加载多个文章
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        let _ = try await mockService.getArticles()
                    } catch {
                        // Handle error
                    }
                }
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // 并发加载应该比串行加载快
        #expect(duration < 2.0)
    }
    
    @Test func testDictionaryLookupPerformance() async throws {
        let mockService = MockDictionaryService()
        
        let words = ["test", "example", "performance", "optimization", "swift"]
        let startTime = Date()
        
        for word in words {
            let _ = try await mockService.lookupWord(word)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // 5个单词查询应该在0.5秒内完成
        #expect(duration < 0.5)
    }
    
    // MARK: - Cache Performance Tests
    @Test func testCacheEfficiency() async throws {
        let cacheManager = CacheManager()
        
        // 测试缓存写入性能
        let writeStartTime = Date()
        
        for i in 0..<1000 {
            let key = "test_key_\(i)"
            let value = "test_value_\(i)"
            cacheManager.set(key: key, value: value, expiration: .seconds(300))
        }
        
        let writeEndTime = Date()
        let writeDuration = writeEndTime.timeIntervalSince(writeStartTime)
        
        // 1000次写入应该在1秒内完成
        #expect(writeDuration < 1.0)
        
        // 测试缓存读取性能
        let readStartTime = Date()
        
        for i in 0..<1000 {
            let key = "test_key_\(i)"
            let _: String? = cacheManager.get(key: key)
        }
        
        let readEndTime = Date()
        let readDuration = readEndTime.timeIntervalSince(readStartTime)
        
        // 1000次读取应该在0.5秒内完成
        #expect(readDuration < 0.5)
    }
    
    @Test func testCacheMemoryManagement() async throws {
        let cacheManager = CacheManager()
        
        let startMemory = getMemoryUsage()
        
        // 添加大量缓存项
        for i in 0..<10000 {
            let key = "large_key_\(i)"
            let value = String(repeating: "x", count: 1000) // 1KB per item
            cacheManager.set(key: key, value: value, expiration: .seconds(300))
        }
        
        let midMemory = getMemoryUsage()
        
        // 清理缓存
        cacheManager.removeAll()
        
        // 等待内存回收
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let endMemory = getMemoryUsage()
        
        // 验证内存被正确释放
        let memoryIncrease = endMemory - startMemory
        #expect(memoryIncrease < 5 * 1024 * 1024) // 应该小于5MB
    }
    
    // MARK: - UI Performance Tests
    @Test func testViewModelUpdatePerformance() async throws {
        let mockArticleService = MockArticleService()
        let mockUserProgressService = MockUserProgressService()
        let mockErrorHandler = MockErrorHandler()
        
        let viewModel = HomeViewModel(
            articleService: mockArticleService,
            userProgressService: mockUserProgressService,
            errorHandler: mockErrorHandler
        )
        
        await viewModel.loadArticles()
        
        let startTime = Date()
        
        // 模拟快速的UI更新
        for i in 0..<100 {
            viewModel.searchText = "search\(i)"
            viewModel.selectedYear = i % 2 == 0 ? "2023" : "2024"
            viewModel.selectedDifficulty = i % 3 == 0 ? "简单" : "中等"
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // UI更新应该很快
        #expect(duration < 0.5)
    }
    
    @Test func testReadingProgressUpdatePerformance() async throws {
        let mockArticleService = MockArticleService()
        let mockUserProgressService = MockUserProgressService()
        let mockDictionaryService = MockDictionaryService()
        let mockTextProcessor = MockTextProcessor()
        let mockErrorHandler = MockErrorHandler()
        
        let viewModel = ReadingViewModel(
            articleService: mockArticleService,
            userProgressService: mockUserProgressService,
            dictionaryService: mockDictionaryService,
            textProcessor: mockTextProcessor,
            errorHandler: mockErrorHandler
        )
        
        let testArticle = Article(
            id: "test-1",
            title: "Test Article",
            content: "Test content",
            year: 2023,
            examType: .english1,
            difficulty: .medium,
            wordCount: 100,
            estimatedReadingTime: 5
        )
        
        viewModel.startReading(article: testArticle)
        
        let startTime = Date()
        
        // 模拟频繁的进度更新
        for i in 0..<100 {
            let progress = Double(i) / 100.0
            viewModel.updateReadingProgress(progress)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // 进度更新应该很快
        #expect(duration < 0.2)
    }
    
    // MARK: - Database Performance Tests
    @Test func testUserProgressSavePerformance() async throws {
        let mockService = MockUserProgressService()
        
        let startTime = Date()
        
        // 模拟频繁的进度保存
        for i in 0..<50 {
            try await mockService.updateReadingTime(duration: Double(i))
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // 50次保存应该在2秒内完成
        #expect(duration < 2.0)
    }
    
    @Test func testVocabularyBatchOperationPerformance() async throws {
        let mockService = MockDictionaryService()
        
        let startTime = Date()
        
        // 批量添加词汇
        for i in 0..<100 {
            let word = Word(
                word: "testword\(i)",
                definitions: ["Definition \(i)"],
                pronunciation: "/test\(i)/",
                partOfSpeech: "noun",
                examples: ["Example \(i)"],
                difficulty: .medium,
                frequency: 0.5,
                mastery: .unfamiliar,
                dateAdded: Date(),
                lastReviewed: nil,
                reviewCount: 0,
                correctCount: 0,
                tags: ["test"]
            )
            try await mockService.addWord(word)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // 100个词汇添加应该在3秒内完成
        #expect(duration < 3.0)
    }
    
    // MARK: - Helper Methods
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}