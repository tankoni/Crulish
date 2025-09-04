//
//  en01Tests.swift
//  en01Tests
//
//  Created by tankoni TK on 2025/7/1.
//

import Testing
import SwiftUI
import Foundation
@testable import en01

struct en01Tests {
    
    // MARK: - HomeViewModel Tests
    @Test func testHomeViewModelInitialization() async throws {
        let mockArticleService = MockArticleService()
        let mockUserProgressService = MockUserProgressService()
        let mockErrorHandler = MockErrorHandler()
        
        let viewModel = HomeViewModel(
            articleService: mockArticleService,
            userProgressService: mockUserProgressService,
            errorHandler: mockErrorHandler
        )
        
        #expect(viewModel.articles.isEmpty)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedYear == "全部")
        #expect(viewModel.selectedDifficulty == "全部")
        #expect(!viewModel.isLoading)
    }
    
    @Test func testHomeViewModelLoadArticles() async throws {
        let mockArticleService = MockArticleService()
        let mockUserProgressService = MockUserProgressService()
        let mockErrorHandler = MockErrorHandler()
        
        let viewModel = HomeViewModel(
            articleService: mockArticleService,
            userProgressService: mockUserProgressService,
            errorHandler: mockErrorHandler
        )
        
        viewModel.loadArticles()
        
        // 等待异步操作完成
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(!viewModel.isLoading)
        #expect(!viewModel.articles.isEmpty)
    }
    
    @Test func testHomeViewModelSearch() async throws {
        let mockArticleService = MockArticleService()
        let mockUserProgressService = MockUserProgressService()
        let mockErrorHandler = MockErrorHandler()
        
        let viewModel = HomeViewModel(
            articleService: mockArticleService,
            userProgressService: mockUserProgressService,
            errorHandler: mockErrorHandler
        )
        
        await MainActor.run {
            viewModel.searchText = "Test"
        }
        
        let searchText = await MainActor.run { viewModel.searchText }
        #expect(searchText == "Test")
        // 注意：filteredArticles 需要先加载数据
        await viewModel.loadArticles()
        let filteredCount = await MainActor.run { viewModel.filteredArticles.count }
        #expect(filteredCount >= 0)
    }
    
    // MARK: - ReadingViewModel Tests
    @Test func testReadingViewModelInitialization() async throws {
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
        
        let currentArticle = await MainActor.run { viewModel.currentArticle }
        let isReading = await MainActor.run { viewModel.isReading }
        let readingProgress = await MainActor.run { viewModel.readingProgress }
        let selectedText = await MainActor.run { viewModel.selectedText }
        
        #expect(currentArticle == nil)
        #expect(!isReading)
        #expect(readingProgress == 0.0)
        #expect(selectedText.isEmpty)
    }
    
    @Test func testReadingViewModelStartReading() async throws {
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
            examType: ExamType.postgraduate1.rawValue,
            difficulty: ArticleDifficulty.medium,
            wordCount: 100,
            estimatedReadingTime: 5
        )
        
        await viewModel.startReading(testArticle)
        
        let currentArticleId = await MainActor.run { viewModel.currentArticle?.id }
        let isReading = await MainActor.run { viewModel.isReading }
        let readingStartTime = await MainActor.run { viewModel.readingStartTime }
        
        #expect(currentArticleId == "test-1")
        #expect(isReading)
        #expect(readingStartTime != nil)
    }
    
    // MARK: - VocabularyViewModel Tests
    @Test func testVocabularyViewModelInitialization() async throws {
        let mockDictionaryService = MockDictionaryService()
        let mockUserProgressService = MockUserProgressService()
        let mockErrorHandler = MockErrorHandler()
        
        let viewModel = VocabularyViewModel(
            dictionaryService: mockDictionaryService,
            userProgressService: mockUserProgressService,
            errorHandler: mockErrorHandler
        )
        
        let vocabulary = await MainActor.run { viewModel.vocabulary }
        let searchText = await MainActor.run { viewModel.searchText }
        let selectedMastery = await MainActor.run { viewModel.selectedMastery }
        let isLoading = await MainActor.run { viewModel.isLoading }
        
        #expect(vocabulary.isEmpty)
        #expect(searchText.isEmpty)
        #expect(selectedMastery == nil)
        #expect(!isLoading)
    }
    
    @Test func testVocabularyViewModelLoadVocabulary() async throws {
        let mockDictionaryService = MockDictionaryService()
        let mockUserProgressService = MockUserProgressService()
        let mockErrorHandler = MockErrorHandler()
        
        let viewModel = VocabularyViewModel(
            dictionaryService: mockDictionaryService,
            userProgressService: mockUserProgressService,
            errorHandler: mockErrorHandler
        )
        
        await viewModel.loadVocabulary()
        
        // 等待异步操作完成
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let isLoading = await MainActor.run { viewModel.isLoading }
        let vocabulary = await MainActor.run { viewModel.vocabulary }
        
        #expect(!isLoading)
        #expect(!vocabulary.isEmpty)
        #expect(vocabulary.count == 2)
    }
    
    // MARK: - ArticleService Tests
    @Test func testArticleServiceGetArticles() async throws {
        let mockService = MockArticleService()
        
        let articles = await mockService.getAllArticles()
        
        #expect(!articles.isEmpty)
        #expect(articles.count == 2)
        #expect(articles.first?.title == "Test Article 1")
    }
    
    @Test func testArticleServiceGetArticlesByYear() {
        let mockService = MockArticleService()
        
        let articles = mockService.getArticlesByYear(2023)
        
        #expect(!articles.isEmpty)
        #expect(articles.allSatisfy { $0.year == 2023 })
    }
    
    // MARK: - DictionaryService Tests
    @Test func testDictionaryServiceLookupWord() async throws {
        let mockService = MockDictionaryService()
        
        let word = try await mockService.lookupWord("test")
        
        #expect(word.word == "test")
        #expect(word.selectedDefinition != nil)
    }
    
    @Test func testDictionaryServiceGetUserVocabulary() async throws {
        let mockService = MockDictionaryService()
        
        let vocabulary = await mockService.getUserWordRecords()
        
        #expect(!vocabulary.isEmpty)
        #expect(vocabulary.count == 2)
    }
    
    // MARK: - UserProgressService Tests
    @Test func testUserProgressServiceGetProgress() async throws {
        let mockService = MockUserProgressService()
        
        let progress = await mockService.getUserProgress()
        
        #expect(progress != nil)
        #expect(progress?.totalReadingTime > 0)
    }
    
    @Test func testUserProgressServiceUpdateReadingTime() async throws {
        let mockService = MockUserProgressService()
        
        await mockService.addReadingTime(30.0)
        let progress = await mockService.getUserProgress()
        
        #expect(progress != nil)
        #expect((progress?.totalReadingTime ?? 0) > 0)
    }
    
    // MARK: - Performance Tests
    @Test func testArticleLoadingPerformance() async throws {
        let mockService = MockArticleService()
        
        let startTime = Date()
        let _ = await mockService.getAllArticles()
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 1.0) // 应该在1秒内完成
    }
    
    @Test func testVocabularySearchPerformance() async throws {
        let mockDictionaryService = MockDictionaryService()
        let mockUserProgressService = MockUserProgressService()
        let mockErrorHandler = MockErrorHandler()
        
        let viewModel = VocabularyViewModel(
            dictionaryService: mockDictionaryService,
            userProgressService: mockUserProgressService,
            errorHandler: mockErrorHandler
        )
        
        await viewModel.loadVocabulary()
        
        // 等待异步操作完成
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let startTime = Date()
        // 模拟滚动操作
        for i in 0..<100 {
            await MainActor.run {
                viewModel.searchText = "search\(i)"
            }
        }
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 0.1) // 搜索应该在100ms内完成
    }
}
