//
//  ServiceContainer.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftData

/// 服务容器 - 管理所有服务的生命周期和依赖注入
class ServiceContainer {
    static let shared = ServiceContainer()
    
    // 核心服务
    private let cacheManager: CacheManagerProtocol
    private let errorHandler: ErrorHandlerProtocol
    private let unifiedErrorHandler: UnifiedErrorHandler
    private let memoryManager: MemoryManager
    private let performanceConfig: PerformanceConfig
    
    // 业务服务
    private var articleService: ArticleServiceProtocol?
    private var dictionaryService: DictionaryServiceProtocol?
    private var userProgressService: UserProgressServiceProtocol?
    private var pdfService: PDFServiceProtocol?
    private var textProcessor: TextProcessorProtocol?
    
    // MARK: - 模型上下文
    private var modelContext: ModelContext?
    
    private init() {
        // 初始化核心服务
        self.cacheManager = CacheManager()
        self.errorHandler = ErrorHandler()
        self.unifiedErrorHandler = UnifiedErrorHandler()
        self.memoryManager = MemoryManager.shared
        self.performanceConfig = PerformanceConfig.shared
    }
    
    // MARK: - 服务配置
    
    /// 配置所有服务
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // 首先初始化基础服务
        self.textProcessor = TextProcessor()
        
        self.pdfService = PDFService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: unifiedErrorHandler
        )
        
        // 然后初始化依赖其他服务的业务服务
        self.articleService = ArticleService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: unifiedErrorHandler,
            pdfService: pdfService!
        )
        
        self.dictionaryService = DictionaryService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: unifiedErrorHandler
        )
        
        self.userProgressService = UserProgressService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: unifiedErrorHandler
        )
        
        // 设置服务间依赖关系
        setupServiceDependencies()
    }
    
    /// 设置服务间的依赖关系
    private func setupServiceDependencies() {
        // 服务间依赖关系已通过构造函数注入完成
        // 所有服务都共享相同的 ModelContext、CacheManager 和 ErrorHandler
        // 这确保了数据一致性和统一的错误处理
    }
    
    // MARK: - 服务获取方法
    
    /// 获取文章服务
    func getArticleService() -> ArticleServiceProtocol {
        guard let service = articleService else {
            fatalError("ArticleService not initialized. Call configure(with:) first.")
        }
        return service
    }
    
    /// 获取词典服务
    func getDictionaryService() -> DictionaryServiceProtocol {
        guard let service = dictionaryService else {
            fatalError("DictionaryService not initialized. Call configure(with:) first.")
        }
        return service
    }
    
    /// 获取用户进度服务
    func getUserProgressService() -> UserProgressServiceProtocol {
        guard let service = userProgressService else {
            fatalError("UserProgressService not initialized. Call configure(with:) first.")
        }
        return service
    }
    
    /// 获取PDF服务
    func getPDFService() -> PDFServiceProtocol {
        guard let service = pdfService else {
            fatalError("PDFService not initialized. Call configure(with:) first.")
        }
        return service
    }
    
    /// 获取文本处理器
    func getTextProcessor() -> TextProcessorProtocol {
        guard let processor = textProcessor else {
            fatalError("TextProcessor not initialized. Call configure(with:) first.")
        }
        return processor
    }
    
    /// 获取缓存管理器
    func getCacheManager() -> CacheManagerProtocol {
        return cacheManager
    }
    
    /// 获取错误处理器
    func getErrorHandler() -> ErrorHandlerProtocol {
        return errorHandler
    }
    
    /// 获取统一错误处理器
    func getUnifiedErrorHandler() -> UnifiedErrorHandler {
        return unifiedErrorHandler
    }
    
    /// 获取内存管理器
    func getMemoryManager() -> MemoryManager {
        return memoryManager
    }
    
    /// 获取性能配置
    func getPerformanceConfig() -> PerformanceConfig {
        return performanceConfig
    }
    
    // MARK: - 测试支持
    
    /// 为测试注入 Mock 服务
    /// - Parameters:
    ///   - articleService: Mock 文章服务
    ///   - dictionaryService: Mock 词典服务
    ///   - userProgressService: Mock 用户进度服务
    ///   - pdfService: Mock PDF服务
    ///   - textProcessor: Mock 文本处理器
    func injectMockServices(
        articleService: ArticleServiceProtocol? = nil,
        dictionaryService: DictionaryServiceProtocol? = nil,
        userProgressService: UserProgressServiceProtocol? = nil,
        pdfService: PDFServiceProtocol? = nil,
        textProcessor: TextProcessorProtocol? = nil,
        cacheManager: CacheManagerProtocol? = nil,
        errorHandler: ErrorHandlerProtocol? = nil
    ) {
        if let articleService = articleService {
            self.articleService = articleService
        }
        if let dictionaryService = dictionaryService {
            self.dictionaryService = dictionaryService
        }
        if let userProgressService = userProgressService {
            self.userProgressService = userProgressService
        }
        if let pdfService = pdfService {
            self.pdfService = pdfService
        }
        if let textProcessor = textProcessor {
            self.textProcessor = textProcessor
        }
        // 注意：cacheManager 和 errorHandler 是 let 常量，不能重新赋值
        // 如果需要在测试中替换它们，需要重新设计架构
    }
    
    /// 重置所有服务（主要用于测试）
    func reset() {
        articleService = nil
        dictionaryService = nil
        userProgressService = nil
        pdfService = nil
        textProcessor = nil
        modelContext = nil
        // 注意：cacheManager 和 errorHandler 是 let 常量，不会被重置
    }
}

// MARK: - 便利扩展

extension ServiceContainer {
    /// 创建完整配置的 AppCoordinator
    @MainActor
    func createAppCoordinator() -> AppCoordinator {
        return AppCoordinator(serviceContainer: self)
    }
}