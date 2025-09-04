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
    private var translationService: TranslationServiceProtocol?
    private var vocabularyTestService: VocabularyTestServiceProtocol?
    
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
    func configure(with modelContext: ModelContext, appSettings: AppSettings) {
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
        
        // 初始化词典数据
        Task {
            try? await dictionaryService?.initializeDictionary()
            // 初始化考研词典数据
            await dictionaryService?.initializeKaoyanDictionary()
        }
        
        self.userProgressService = UserProgressService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: unifiedErrorHandler
        )
        
        // 初始化词汇测试服务
        self.vocabularyTestService = VocabularyTestService(
            dictionaryService: dictionaryService!,
            coreDataStack: CoreDataStack.shared
        )
        
        // 初始化翻译服务
        let translationConfig = createTranslationConfig(from: appSettings)
        self.translationService = TranslationServiceImpl(
            modelContext: modelContext,
            config: translationConfig
        )
        
        // 设置服务间依赖关系
        setupServiceDependencies()
    }
    
    /// 根据AppSettings创建TranslationConfig
    private func createTranslationConfig(from appSettings: AppSettings) -> TranslationConfig {
        let selectedModel = appSettings.selectedAIModel
        let primaryProvider = selectedModel.provider
        
        // 设置备用提供者列表
        var fallbackProviders: [TranslationProvider] = []
        
        // 根据主提供者设置合理的备用提供者
        switch primaryProvider {
        // GPT系列模型的备用提供者
        case .gpt35turbo, .gpt4, .gpt4turbo, .gpt4o, .gpt4omini:
            fallbackProviders = [.gemini25flash, .gemini20flash, .local]
        
        // Claude系列模型的备用提供者
        case .claude3haiku, .claude3sonnet, .claude3opus, .claude35sonnet:
            fallbackProviders = [.gpt4o, .gemini25flash, .local]
        
        // Gemini系列模型的备用提供者
        case .gemini25pro, .gemini25flash, .gemini20flash, .gemini20flashSpark, .gemini15pro, .gemini15flash:
            fallbackProviders = [.gpt4o, .claude35sonnet, .local]
        
        // DeepSeek系列模型的备用提供者
        case .deepseekV3:
            fallbackProviders = [.gpt4o, .gemini25flash, .local]
        
        // Qwen系列模型的备用提供者
        case .qwenMax:
            fallbackProviders = [.gpt4o, .gemini25flash, .local]
        
        // 豆包系列模型的备用提供者
        case .doubaoLite, .doubaoPro:
            fallbackProviders = [.gpt4o, .gemini25flash, .local]
        
        // 传统翻译服务的备用提供者
        case .google, .baidu, .tencent:
            fallbackProviders = [.gpt4o, .gemini25flash, .local]
        
        // 兼容性提供者的备用提供者
        case .gemini:
            fallbackProviders = [.geminiDirect, .local, .openai]
        case .openai:
            fallbackProviders = [.gemini, .local]
        case .deepseek:
            fallbackProviders = [.openai, .gemini, .local]
        case .doubao:
            fallbackProviders = [.openai, .gemini, .local]
        
        // 本地模型
        case .local:
            fallbackProviders = [.gpt4o, .gemini25flash]
        
        default:
            fallbackProviders = [.gpt4o, .gemini25flash, .local]
        }
        
        // 构建API密钥字典
        var apiKeys: [TranslationProvider: String] = [:]
        
        // 添加Gemini API密钥（所有Gemini系列模型共享）
        if !appSettings.geminiAPIKey.isEmpty {
            // 为所有Gemini系列模型设置API密钥
            apiKeys[.gemini25pro] = appSettings.geminiAPIKey
            apiKeys[.gemini25flash] = appSettings.geminiAPIKey
            apiKeys[.gemini20flash] = appSettings.geminiAPIKey
            apiKeys[.gemini20flashSpark] = appSettings.geminiAPIKey
            apiKeys[.gemini15pro] = appSettings.geminiAPIKey
            apiKeys[.gemini15flash] = appSettings.geminiAPIKey
            // 兼容性提供者
            apiKeys[.gemini] = appSettings.geminiAPIKey
        }
        if !appSettings.geminiBackupAPIKey.isEmpty {
            apiKeys[.geminiDirect] = appSettings.geminiBackupAPIKey
        }
        
        // 添加OpenAI API密钥（GPT系列模型）
        if !appSettings.openaiAPIKey.isEmpty {
            apiKeys[.gpt35turbo] = appSettings.openaiAPIKey
            apiKeys[.gpt4] = appSettings.openaiAPIKey
            apiKeys[.gpt4turbo] = appSettings.openaiAPIKey
            apiKeys[.gpt4o] = appSettings.openaiAPIKey
            apiKeys[.gpt4omini] = appSettings.openaiAPIKey
            // 兼容性提供者
            apiKeys[.openai] = appSettings.openaiAPIKey
        }
        
        // 添加Claude API密钥（Claude系列模型）
        if !appSettings.claudeAPIKey.isEmpty {
            apiKeys[.claude3haiku] = appSettings.claudeAPIKey
            apiKeys[.claude3sonnet] = appSettings.claudeAPIKey
            apiKeys[.claude3opus] = appSettings.claudeAPIKey
            apiKeys[.claude35sonnet] = appSettings.claudeAPIKey
        }
        
        // 添加DeepSeek API密钥
        if !appSettings.deepseekAPIKey.isEmpty {
            apiKeys[.deepseekV3] = appSettings.deepseekAPIKey
            // 兼容性提供者
            apiKeys[.deepseek] = appSettings.deepseekAPIKey
        }
        
        // 添加Qwen API密钥
        if !appSettings.qwenAPIKey.isEmpty {
            apiKeys[.qwenMax] = appSettings.qwenAPIKey
        }
        
        // 添加豆包API密钥
        if !appSettings.doubaoAPIKey.isEmpty {
            apiKeys[.doubaoLite] = appSettings.doubaoAPIKey
            apiKeys[.doubaoPro] = appSettings.doubaoAPIKey
            // 兼容性提供者
            apiKeys[.doubao] = appSettings.doubaoAPIKey
        }
        
        return TranslationConfig(
            primaryProvider: primaryProvider,
            fallbackProviders: fallbackProviders,
            enableCache: true,
            cacheExpiration: 3600, // 1小时
            maxCacheSize: 1000,
            enableLocalModel: true,
            apiKeys: apiKeys
        )
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
    
    /// 获取词汇测试服务
    func getVocabularyTestService() -> VocabularyTestServiceProtocol {
        guard let service = vocabularyTestService else {
            fatalError("VocabularyTestService not initialized. Call configure(with:) first.")
        }
        return service
    }
    
    /// 获取词汇服务（别名方法，指向词汇测试服务）
    func getVocabularyService() -> VocabularyTestServiceProtocol {
        return getVocabularyTestService()
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
    
    /// 获取翻译服务
    func getTranslationService() -> TranslationServiceProtocol {
        guard let service = translationService else {
            fatalError("TranslationService not initialized. Call configure(with:) first.")
        }
        return service
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
        translationService = nil
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