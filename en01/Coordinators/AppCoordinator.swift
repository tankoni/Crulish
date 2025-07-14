//
//  AppCoordinator.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI
import SwiftData
import Combine

/// 应用协调器，负责管理全局导航和状态协调
@MainActor
class AppCoordinator: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTab: TabSelection = .home
    @Published var isLoading: Bool = false
    @Published var showingError: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Child ViewModels
    @Published var homeViewModel: HomeViewModel?
    @Published var readingViewModel: ReadingViewModel?
    @Published var vocabularyViewModel: VocabularyViewModel?
    @Published var progressViewModel: ProgressViewModel?
    @Published var settingsViewModel: SettingsViewModel?
    
    // MARK: - Services
    private let serviceContainer: ServiceContainer
    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false
    
    // MARK: - Initialization
    init(serviceContainer: ServiceContainer) {
        self.serviceContainer = serviceContainer
        // ViewModels will be initialized when setModelContext is called
    }
    
    private func initializeViewModels() {
        guard !isConfigured else { return }
        
        // 初始化子ViewModels
        self.homeViewModel = HomeViewModel(
            articleService: serviceContainer.getArticleService(),
            userProgressService: serviceContainer.getUserProgressService(),
            errorHandler: serviceContainer.getErrorHandler()
        )
        
        self.readingViewModel = ReadingViewModel(
            articleService: serviceContainer.getArticleService(),
            userProgressService: serviceContainer.getUserProgressService(),
            dictionaryService: serviceContainer.getDictionaryService(),
            textProcessor: serviceContainer.getTextProcessor() as! TextProcessor,
            errorHandler: serviceContainer.getErrorHandler()
        )
        
        self.vocabularyViewModel = VocabularyViewModel(
            dictionaryService: serviceContainer.getDictionaryService(),
            userProgressService: serviceContainer.getUserProgressService(),
            errorHandler: serviceContainer.getErrorHandler()
        )
        
        self.progressViewModel = ProgressViewModel(
            userProgressService: serviceContainer.getUserProgressService(),
            articleService: serviceContainer.getArticleService(),
            errorHandler: serviceContainer.getErrorHandler()
        )
        
        self.settingsViewModel = SettingsViewModel(
            userProgressService: serviceContainer.getUserProgressService(),
            errorHandler: serviceContainer.getErrorHandler(),
            cacheManager: serviceContainer.getCacheManager(),
            coordinator: self
        )
        
        isConfigured = true
        setupCoordination()
        
        // 检查并执行PDF导入
        checkAndImportPDFs()
    }
    
    // MARK: - Setup
    private func setupCoordination() {
        // 错误处理将通过各个ViewModel直接处理
        
        // 阅读和复习完成事件将通过直接调用方法处理
    }
    
    // MARK: - PDF Import
    
    /// 检查并导入PDF文件
    private func checkAndImportPDFs() {
        Task {
            do {
                // 检查是否已经导入过PDF
                let hasImported = UserDefaults.standard.bool(forKey: "hasImportedPDFs")
                
                if !hasImported {
                    await MainActor.run {
                        isLoading = true
                    }
                    
                    // 导入PDF文章
                    await serviceContainer.getArticleService().importArticlesFromPDFs()
                    
                    await MainActor.run {
                        // 标记已导入
                        UserDefaults.standard.set(true, forKey: "hasImportedPDFs")
                        // 更新导入时间戳
                        UserDefaults.standard.set(Date(), forKey: "lastPDFImportDate")
                        
                        isLoading = false
                        
                        // 刷新所有相关数据
                        refreshAllData()
                    }
                } else {
                    // 已经导入过，检查是否有文章数据
                    let articles = serviceContainer.getArticleService().getAllArticles()
                    if articles.isEmpty {
                        // 如果没有文章数据，重新导入
                        print("检测到没有文章数据，重新导入PDF...")
                        await MainActor.run {
                            isLoading = true
                        }
                        await serviceContainer.getArticleService().importArticlesFromPDFs()
                        await MainActor.run {
                            isLoading = false
                            refreshAllData()
                        }
                    } else {
                        // 直接刷新数据
                        await MainActor.run {
                            refreshAllData()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // 对于PDF导入错误，只记录日志，不显示错误弹窗
                    print("[INFO] PDF导入过程中遇到问题，将使用示例数据")
                    // 如果PDF导入失败，尝试初始化示例数据
                    serviceContainer.getArticleService().initializeSampleData()
                    refreshAllData()
                }
            }
        }
    }
    
    /// 异步导入PDF文件并显示进度
    private func importPDFsWithProgress() async {
        await MainActor.run {
            isLoading = true
        }
        
        // 在后台线程执行PDF导入
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            print("开始导入PDF文章...")
            
            // 执行PDF导入
            await self.serviceContainer.getArticleService().importArticlesFromPDFs()
            
            // 检查导入结果
            let articles = await self.serviceContainer.getArticleService().getAllArticles()
            print("PDF导入完成，共导入 \(articles.count) 篇文章")
            
            // 如果没有PDF文件或导入失败，则导入示例数据
            if articles.isEmpty {
                print("未找到PDF文章，导入示例数据...")
                await MainActor.run {
                    self.serviceContainer.getArticleService().initializeSampleData()
                    let sampleArticles = self.serviceContainer.getArticleService().getAllArticles()
                    print("示例数据导入完成，共 \(sampleArticles.count) 篇文章")
                }
            }
        }
    }
    
    /// 手动重新导入PDF文件（用于后续手动导入功能）
    func reimportPDFs() {
        isLoading = true
        
        // 重置PDF导入状态，强制重新导入
        UserDefaults.standard.set(false, forKey: "hasImportedPDFs")
        
        Task {
            // 先清除所有现有文章数据
            await MainActor.run {
                print("[INFO] 开始清除现有文章数据...")
                serviceContainer.getArticleService().clearAllArticles()
                print("[INFO] 现有文章数据清除完成")
            }
            
            await importPDFsWithProgress()
            
            await MainActor.run {
                // 标记已导入
                UserDefaults.standard.set(true, forKey: "hasImportedPDFs")
                // 更新导入时间戳
                UserDefaults.standard.set(Date(), forKey: "lastPDFImportDate")
                
                isLoading = false
                
                // 刷新所有相关数据
                refreshAllData()
            }
        }
    }
    
    // MARK: - Coordination Methods
    
    /// 开始阅读文章
    func startReading(_ article: Article) {
        readingViewModel?.startReading(article)
        selectedTab = .reading
    }
    
    /// 完成阅读
    func finishReading() {
        // 更新进度统计
        progressViewModel?.refreshReadingStats()
        
        // 更新首页推荐
        homeViewModel?.refreshData()
        
        selectedTab = .home
    }
    
    /// 添加单词到词汇表
    func addWordToVocabulary(word: String, context: String) {
        vocabularyViewModel?.addWord(word: word, context: context)
        
        // 更新词汇统计
        progressViewModel?.refreshVocabularyStats()
    }
    
    /// 更新用户进度
    func updateProgress() {
        progressViewModel?.refreshData()
        homeViewModel?.refreshData()
    }
    
    /// 开始词汇复习
    func startVocabularyReview() {
        vocabularyViewModel?.startReview()
        selectedTab = .vocabulary
    }
    
    /// 完成词汇复习
    func finishVocabularyReview() {
        // 更新进度统计
        progressViewModel?.refreshVocabularyStats()
        
        // 更新首页数据
        homeViewModel?.refreshData()
    }
    
    /// 更新设置
    func updateSettings() {
        // 刷新所有相关的ViewModel
        homeViewModel?.refreshData()
        readingViewModel?.refreshSettings()
        vocabularyViewModel?.refreshSettings()
        progressViewModel?.refreshData()
    }
    
    /// 添加单词（简化版本）
    func addWord(_ word: String, context: String) {
        addWordToVocabulary(word: word, context: context)
    }
    
    /// 清除缓存（异步版本）
    func clearCache() async {
        clearAllCaches()
    }
    
    /// 刷新数据（异步版本）
    func refreshData() async {
        refreshAllData()
    }
    
    /// 清除所有缓存
    func clearAllCaches() {
        homeViewModel?.clearCache()
        readingViewModel?.clearCache()
        vocabularyViewModel?.clearCache()
        progressViewModel?.clearCache()
        settingsViewModel?.clearAllCache()
    }
    
    /// 刷新所有数据
    func refreshAllData() {
        homeViewModel?.refreshData()
        vocabularyViewModel?.refreshData()
        progressViewModel?.refreshData()
        settingsViewModel?.refreshSettings()
    }
    
    /// 处理深度链接
    func handleDeepLink(_ url: URL) {
        // 解析URL并导航到相应的页面
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        guard let host = components?.host else { return }
        
        switch host {
        case "article":
            if let articleId = components?.queryItems?.first(where: { $0.name == "id" })?.value {
                homeViewModel?.selectArticle(by: articleId)
                selectedTab = .reading
            }
        case "vocabulary":
            selectedTab = .vocabulary
        case "progress":
            selectedTab = .progress
        case "settings":
            selectedTab = .settings
        default:
            selectedTab = .home
        }
    }
    
    // MARK: - Error Handling
    var hasError: Bool {
        return showingError
    }
    
    var currentErrorMessage: String? {
        return showingError ? errorMessage : nil
    }
    
    private func handleGlobalError(_ error: AppError) {
        errorMessage = error.localizedDescription
        showingError = true
    }
    
    func clearError() {
        showingError = false
        errorMessage = ""
    }
    
    // MARK: - Navigation Helpers
    func navigateToHome() {
        selectedTab = .home
    }
    
    func navigateToReading() {
        selectedTab = .reading
    }
    
    func navigateToVocabulary() {
        selectedTab = .vocabulary
    }
    
    func navigateToProgress() {
        selectedTab = .progress
    }
    
    func navigateToSettings() {
        selectedTab = .settings
    }
    
    // MARK: - State Management
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    func setModelContext(_ context: ModelContext) {
        serviceContainer.configure(with: context)
        initializeViewModels()
    }
    
    // MARK: - Lifecycle
    func onAppear() {
        // 应用启动时的初始化逻辑
        refreshAllData()
    }
    
    func onDisappear() {
        // 应用退出时的清理逻辑
        cancellables.removeAll()
    }
    
    func onBackground() {
        // 应用进入后台时的处理
        // 可以在这里保存状态或暂停某些操作
    }
    
    func onForeground() {
        // 应用回到前台时的处理
        refreshAllData()
    }
}

// MARK: - TabSelection