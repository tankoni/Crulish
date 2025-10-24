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
    
    // MARK: - 核心服务（单例）
    private var cacheManager: CacheManagerProtocol
    private var errorHandler: ErrorHandlerProtocol
    private let unifiedErrorHandler: UnifiedErrorHandler
    private let memoryManager: MemoryManager
    private let performanceConfig: PerformanceConfig
    
    // 启动进度管理器
    @MainActor lazy var startupProgressManager = StartupProgressManager()
    
    // 业务服务
    private var articleService: ArticleServiceProtocol?
    private var dictionaryService: DictionaryServiceProtocol?
    private var userProgressService: UserProgressServiceProtocol?
    private var pdfService: PDFServiceProtocol?
    private var textProcessor: TextProcessorProtocol?
    private var translationService: TranslationServiceProtocol?
    private var vocabularyTestService: VocabularyTestServiceProtocol?
    private var learningTrackingService: LearningTrackingService?
    private var testResultExportService: TestResultExportService?
    private var statisticsExportService: StatisticsExportService?
    
    // 自适应学习相关服务
    private var adaptiveLearningService: AdaptiveLearningService?
    private var adaptiveRecommendationEngine: AdaptiveRecommendationEngine?
    
    // 组合排序服务
    private var compositeRankingService: CompositeRankingService?
    private var intelligentRankingService: IntelligentRankingService?
    
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
    
    /// 配置所有服务 - 分阶段初始化以优化启动性能
    @MainActor func configure(with modelContext: ModelContext, appSettings: AppSettings) {
        // 防止重复配置
        if self.modelContext != nil {
            print("[ServiceContainer] 服务已配置，跳过重复初始化")
            return
        }
        
        self.modelContext = modelContext
        
        // 开始启动进度跟踪
        startupProgressManager.updateStage(.initializing, message: "正在初始化应用...", detail: "准备核心组件")
        
        // 阶段一：初始化核心基础服务（立即需要的）
        startupProgressManager.updateStage(.loadingCoreServices, message: "正在加载核心服务...", detail: "初始化文本处理器和PDF服务")
        
        self.textProcessor = TextProcessor()
        startupProgressManager.updateStageProgress(.loadingCoreServices, progress: 0.3)
        
        self.pdfService = PDFService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: unifiedErrorHandler
        )
        startupProgressManager.updateStageProgress(.loadingCoreServices, progress: 0.6)
        
        // 阶段二：初始化业务服务（UI需要的）
        startupProgressManager.completeStage(.loadingCoreServices)
        startupProgressManager.updateStage(.loadingBusinessServices, message: "正在加载业务服务...", detail: "初始化文章和词典服务")
        
        self.articleService = ArticleService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: unifiedErrorHandler,
            pdfService: pdfService!
        )
        startupProgressManager.updateStageProgress(.loadingBusinessServices, progress: 0.4)
        
        self.dictionaryService = DictionaryService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: unifiedErrorHandler
        )
        startupProgressManager.updateStageProgress(.loadingBusinessServices, progress: 0.7)
        
        self.userProgressService = UserProgressService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: unifiedErrorHandler
        )
        
        // 初始化翻译服务（UI必需，同步初始化）
        let translationConfig = createTranslationConfig(from: appSettings)
        self.translationService = TranslationServiceImpl(
            modelContext: modelContext,
            config: translationConfig
        )
        
        // 初始化学习跟踪服务（UI必需，同步初始化）
        self.learningTrackingService = LearningTrackingService(
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: unifiedErrorHandler
        )

        // 初始化词汇测试服务（UI需要，同步初始化）
        self.vocabularyTestService = VocabularyTestService(
            dictionaryService: dictionaryService!,
            modelContext: modelContext,
            cacheManager: cacheManager,
            errorHandler: unifiedErrorHandler
        )

        // 初始化测试结果导出服务（UI需要，同步初始化）
        self.testResultExportService = TestResultExportService(
            modelContext: modelContext,
            dictionaryService: dictionaryService! as! DictionaryService
        )

        // 初始化统计数据导出服务（UI需要，同步初始化）
        self.statisticsExportService = StatisticsExportService(
            modelContext: modelContext,
            vocabularyTestService: vocabularyTestService!,
            errorHandler: unifiedErrorHandler,
            dictionaryService: dictionaryService! as! DictionaryService
        )
        
        startupProgressManager.completeStage(.loadingBusinessServices)
        
        // 阶段三：延迟初始化重量级数据（后台加载）
        Task { @MainActor in
            // 优先初始化基础词典（轻量级）
            startupProgressManager.updateStage(.loadingDictionary, message: "正在加载基础词典...", detail: "加载常用词汇数据")
            try? await dictionaryService?.initializeDictionary()
            startupProgressManager.completeStage(.loadingDictionary)
            
            // 延迟初始化考研词典（重量级，在启动完成后进行）
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 延迟2秒，让应用先完成启动
            startupProgressManager.updateStage(.loadingKaoyanDict, message: "正在加载考研词典...", detail: "加载10940个考研词汇")
            await dictionaryService?.initializeKaoyanDictionary()
            startupProgressManager.completeStage(.loadingKaoyanDict)
        }
        
        // 阶段四：初始化非核心服务（同步执行，确保ViewModel获取时已就绪）
        startupProgressManager.updateStage(.loadingOptionalServices, message: "正在加载扩展服务...", detail: "初始化自适应学习服务")

        // 初始化智能排序服务（同步）
        self.intelligentRankingService = IntelligentRankingService(
            dictionaryService: dictionaryService!,
            vocabularyTestService: vocabularyTestService
        )

        // 初始化自适应学习服务（同步）
        self.adaptiveLearningService = AdaptiveLearningService(
            modelContext: modelContext,
            learningTrackingService: learningTrackingService!,
            userProgressService: userProgressService! as! UserProgressService,
            intelligentRankingService: intelligentRankingService!
        )

        // 初始化自适应推荐引擎（同步）
        if let adaptiveService = self.adaptiveLearningService {
            let learningBehaviorAnalyzer = LearningBehaviorAnalyzer(modelContext: modelContext)

            self.adaptiveRecommendationEngine = AdaptiveRecommendationEngine(
                modelContext: modelContext,
                adaptiveLearningService: adaptiveService,
                intelligentRankingService: intelligentRankingService!,
                learningBehaviorAnalyzer: learningBehaviorAnalyzer
            )
        }

        // 初始化组合排序服务（同步）
        self.compositeRankingService = CompositeRankingService(
            intelligentRankingService: intelligentRankingService!,
            dictionaryService: dictionaryService!,
            vocabularyTestService: vocabularyTestService,
            errorHandler: unifiedErrorHandler
        )

        startupProgressManager.completeStage(.loadingOptionalServices)
        
        // 设置服务间依赖关系
        setupServiceDependencies()
        
        // 只有在所有核心服务都初始化完成后才标记启动完成
        // 注意：考研词典的加载是异步的，不影响核心功能，所以不阻塞启动完成
        startupProgressManager.updateStage(.completed, message: "启动完成", detail: "核心服务已就绪")
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
    
    /// 获取学习跟踪服务
    func getLearningTrackingService() -> LearningTrackingService {
        guard let service = learningTrackingService else {
            fatalError("LearningTrackingService not initialized. Call configure(with:) first.")
        }
        return service
    }
    
    /// 获取缓存管理器
    func getCacheManager() -> CacheManagerProtocol {
        return cacheManager
    }
    
    /// 获取模型上下文
    func getModelContext() -> ModelContext? {
        return modelContext
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
    
    /// 获取自适应学习服务
    func getAdaptiveLearningService() -> AdaptiveLearningService {
        guard let service = adaptiveLearningService else {
            fatalError("AdaptiveLearningService not initialized. Call configure(with:) first.")
        }
        return service
    }
    
    /// 获取自适应推荐引擎
    func getAdaptiveRecommendationEngine() -> AdaptiveRecommendationEngine {
        guard let engine = adaptiveRecommendationEngine else {
            fatalError("AdaptiveRecommendationEngine not initialized. Call configure(with:) first.")
        }
        return engine
    }
    
    /// 获取组合排序服务
    func getCompositeRankingService() -> CompositeRankingService {
        guard let service = compositeRankingService else {
            fatalError("CompositeRankingService not initialized. Call configure(with:) first.")
        }
        return service
    }
    
    /// 获取智能排序服务
    func getIntelligentRankingService() -> IntelligentRankingService {
        guard let service = intelligentRankingService else {
            fatalError("IntelligentRankingService not initialized. Call configure(with:) first.")
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
        if let cacheManager = cacheManager {
            self.cacheManager = cacheManager
        }
        if let errorHandler = errorHandler {
            self.errorHandler = errorHandler
        }
        if let learningTrackingService = learningTrackingService {
            self.learningTrackingService = learningTrackingService
        }
    }
    
    /// 获取测试结果导出服务
    func getTestResultExportService() -> TestResultExportService {
        guard let service = testResultExportService else {
            fatalError("TestResultExportService not initialized. Call configure(with:) first.")
        }
        return service
    }
    
    /// 获取统计数据导出服务
    func getStatisticsExportService() -> StatisticsExportServiceProtocol {
        guard let service = statisticsExportService else {
            fatalError("StatisticsExportService not initialized. Call configure(with:) first.")
        }
        return service
    }
    
    /// 重置所有服务（主要用于测试）
    @MainActor
    func reset() {
        print("[ServiceContainer] 开始重置服务容器")
        
        // 清理服务实例
        vocabularyTestService?.clearCache()
        vocabularyTestService = nil
        
        // 清理缓存
        cacheManager.clearAll()
        
        // 重置启动进度管理器
        startupProgressManager.reset()
        
        // 重置配置状态
        modelContext = nil
        
        print("[ServiceContainer] 服务容器重置完成")
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
