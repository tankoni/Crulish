//
//  en01Tests.swift
//  en01Tests
//
//  Created by tankoni TK on 2025/7/1.
//

import Testing
import SwiftData
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
        
        await viewModel.loadArticles()
        
        #expect(!viewModel.articles.isEmpty)
        #expect(viewModel.articles.count == 2)
    }
    
    @Test func testHomeViewModelSearchFunctionality() async throws {
        let mockArticleService = MockArticleService()
        let mockUserProgressService = MockUserProgressService()
        let mockErrorHandler = MockErrorHandler()
        
        let viewModel = HomeViewModel(
            articleService: mockArticleService,
            userProgressService: mockUserProgressService,
            errorHandler: mockErrorHandler
        )
        
        await viewModel.loadArticles()
        viewModel.searchText = "Test"
        
        #expect(viewModel.filteredArticles.count == 1)
        #expect(viewModel.filteredArticles.first?.title.contains("Test") == true)
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
        
        #expect(viewModel.currentArticle == nil)
        #expect(!viewModel.isReading)
        #expect(viewModel.readingProgress == 0.0)
        #expect(viewModel.selectedText.isEmpty)
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
            examType: .english1,
            difficulty: .medium,
            wordCount: 100,
            estimatedReadingTime: 5
        )
        
        viewModel.startReading(article: testArticle)
        
        #expect(viewModel.currentArticle?.id == "test-1")
        #expect(viewModel.isReading)
        #expect(viewModel.readingStartTime != nil)
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
        
        #expect(viewModel.vocabulary.isEmpty)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedMastery == nil)
        #expect(!viewModel.isLoading)
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
        
        #expect(!viewModel.vocabulary.isEmpty)
        #expect(viewModel.vocabulary.count == 2)
    }
    
    // MARK: - ArticleService Tests
    @Test func testArticleServiceGetArticles() async throws {
        let mockService = MockArticleService()
        
        let articles = try await mockService.getArticles()
        
        #expect(!articles.isEmpty)
        #expect(articles.count == 2)
        #expect(articles.first?.title == "Test Article 1")
    }
    
    @Test func testArticleServiceGetArticlesByYear() async throws {
        let mockService = MockArticleService()
        
        let articles = try await mockService.getArticles(year: 2023)
        
        #expect(!articles.isEmpty)
        #expect(articles.allSatisfy { $0.year == 2023 })
    }
    
    // MARK: - DictionaryService Tests
    @Test func testDictionaryServiceLookupWord() async throws {
        let mockService = MockDictionaryService()
        
        let word = try await mockService.lookupWord("test")
        
        #expect(word != nil)
        #expect(word?.word == "test")
        #expect(!word?.definitions.isEmpty == true)
    }
    
    @Test func testDictionaryServiceGetUserVocabulary() async throws {
        let mockService = MockDictionaryService()
        
        let vocabulary = try await mockService.getUserVocabulary()
        
        #expect(!vocabulary.isEmpty)
        #expect(vocabulary.count == 2)
    }
    
    // MARK: - UserProgressService Tests
    @Test func testUserProgressServiceGetProgress() async throws {
        let mockService = MockUserProgressService()
        
        let progress = try await mockService.getUserProgress()
        
        #expect(progress != nil)
        #expect(progress?.totalReadingTime > 0)
    }
    
    @Test func testUserProgressServiceUpdateReadingTime() async throws {
        let mockService = MockUserProgressService()
        
        try await mockService.updateReadingTime(duration: 300)
        let progress = try await mockService.getUserProgress()
        
        #expect(progress?.totalReadingTime == 300)
    }
    
    // MARK: - Performance Tests
    @Test func testArticleLoadingPerformance() async throws {
        let mockService = MockArticleService()
        
        let startTime = Date()
        let _ = try await mockService.getArticles()
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
        
        let startTime = Date()
        viewModel.searchText = "test"
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 0.1) // 搜索应该在100ms内完成
    }
}
