//
//  ContentView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI
import SwiftData
import Combine
import Foundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appViewModel: AppViewModel?
    @State private var showStartupProgress = true
    @State private var isInitializing = false
    @State private var hasInitialized = false
    
    // 计算属性：简化TabView的selection绑定
    private var selectedTabBinding: Binding<TabSelection> {
        guard let viewModel = appViewModel else {
            return .constant(.home)
        }
        return Binding(
            get: { viewModel.selectedTab },
            set: { viewModel.selectTab($0) }
        )
    }
    
    // 错误弹窗绑定，避免使用常量绑定导致无法关闭
    private var showingErrorBinding: Binding<Bool> {
        guard let viewModel = appViewModel else {
            return .constant(false)
        }
        return Binding(
            get: { viewModel.coordinator.showingError },
            set: { viewModel.coordinator.showingError = $0 }
        )
    }

    
    var body: some View {
        VStack {
            if showStartupProgress {
                // 显示启动进度界面
                StartupProgressView(progressManager: ServiceContainer.shared.startupProgressManager)
                    .onReceive(ServiceContainer.shared.startupProgressManager.$isCompleted) { isCompleted in
                        print("[ContentView] 启动进度状态变化: isCompleted=\(isCompleted)")
                        if isCompleted {
                            // 启动完成后延迟一点时间再隐藏进度界面，让用户看到完成状态
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    print("[ContentView] 隐藏启动进度界面")
                                    showStartupProgress = false
                                }
                            }
                        }
                    }
            } else if let appViewModel = appViewModel {
                // 条件注入 wordInteractionCoordinator，避免强制解包导致崩溃
                let wordCoordinator = appViewModel.coordinator.wordInteractionCoordinator
                Group {
                    TabView(selection: selectedTabBinding) {
                        homeTab(appViewModel: appViewModel)
                        readingTab(appViewModel: appViewModel)
                        vocabularyTab(appViewModel: appViewModel)
                        intelligentRankingTab(appViewModel: appViewModel)
                        progressTab(appViewModel: appViewModel)
                        settingsTab(appViewModel: appViewModel)
                    }
                    .environment(appViewModel)
                    .environment(appViewModel.coordinator.getUnifiedErrorHandler())
                    .environmentObject(appViewModel.coordinator)
                    .environmentObject(appViewModel.coordinator.getDictionaryService())
                    .environmentObject(appViewModel.coordinator.getTextProcessor())
                    .environmentObject(appViewModel.coordinator.getTranslationService())
                    .transition(.opacity)
                    .modifier(ConditionalWordCoordinator(coordinator: wordCoordinator))
                }
                .onAppear {
                    print("[ContentView] 显示主界面，appViewModel已初始化")
                }
            } else {
                VStack {
                    SwiftUI.ProgressView()
                    Text("初始化中...")
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    print("[ContentView] 显示初始化界面，appViewModel为nil")
                }
            }
        }
        .onAppear {
            print("[ContentView] onAppear - 开始初始化")
            initializeAppViewModelIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartVocabularyTest"))) { _ in
            appViewModel?.startVocabularyTest()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectReadingTab"))) { _ in
            appViewModel?.selectTab(.reading)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectVocabularyTab"))) { _ in
            appViewModel?.selectTab(.vocabulary)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectProgressTab"))) { _ in
            appViewModel?.selectTab(.progress)
        }
        .alert("错误", isPresented: showingErrorBinding) {
            Button("确定") {
                // Error dismissal will be handled by coordinator
            }
        } message: {
            if let errorMessage = appViewModel?.currentErrorMessage {
                Text(errorMessage)
            }
        }
    }
    
    @ViewBuilder
    private func homeTab(appViewModel: AppViewModel) -> some View {
        Group {
            if let homeViewModel = appViewModel.homeViewModel {
                HomeView(viewModel: homeViewModel)
            } else {
                loadingView
            }
        }
        .tabItem {
            Image(systemName: "house")
            Text("首页")
        }
        .tag(TabSelection.home)
    }
    
    @ViewBuilder
    private func readingTab(appViewModel: AppViewModel) -> some View {
        Group {
            if let readingViewModel = appViewModel.readingViewModel {
                ReadingView(viewModel: readingViewModel)
            } else {
                loadingView
            }
        }
        .tabItem {
            Image(systemName: "book")
            Text("阅读")
        }
        .tag(TabSelection.reading)
    }
    
    @ViewBuilder
    private func vocabularyTab(appViewModel: AppViewModel) -> some View {
        Group {
            if let vocabularyViewModel = appViewModel.vocabularyViewModel {
                VocabularyView(viewModel: vocabularyViewModel)
            } else {
                loadingView
            }
        }
        .tabItem {
            Image(systemName: "text.book.closed")
            Text("词汇")
        }
        .tag(TabSelection.vocabulary)
    }
    
    @ViewBuilder
    private func intelligentRankingTab(appViewModel: AppViewModel) -> some View {
        Group {
            if let intelligentRankingViewModel = appViewModel.intelligentRankingViewModel {
                IntelligentRankingView()
                    .environmentObject(intelligentRankingViewModel)
            } else {
                loadingView
            }
        }
        .tabItem {
            Image(systemName: "brain.head.profile")
            Text("智能排序")
        }
        .tag(TabSelection.intelligentRanking)
    }
    
    @ViewBuilder
    private func progressTab(appViewModel: AppViewModel) -> some View {
        Group {
            if let progressViewModel = appViewModel.progressViewModel {
                StatisticsView(viewModel: progressViewModel)
            } else {
                loadingView
            }
        }
        .tabItem {
            Image(systemName: "chart.bar")
            Text("统计")
        }
        .tag(TabSelection.progress)
    }
    
    @ViewBuilder
    private func settingsTab(appViewModel: AppViewModel) -> some View {
        Group {
            if let settingsViewModel = appViewModel.settingsViewModel {
                SettingsView(viewModel: settingsViewModel)
            } else {
                loadingView
            }
        }
        .tabItem {
            Image(systemName: "gear")
            Text("设置")
        }
        .tag(TabSelection.settings)
    }
    
    // MARK: - 辅助视图
    @ViewBuilder
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("加载中...")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 初始化方法
    private func initializeAppViewModelIfNeeded() {
        // 防止重复初始化
        guard !isInitializing && !hasInitialized && appViewModel == nil else {
            print("[ContentView] appViewModel已存在或正在初始化，跳过初始化")
            return
        }
        
        print("[ContentView] 开始初始化appViewModel")
        isInitializing = true
        
        Task { @MainActor in
            // 确保服务容器已配置
            let appSettings = AppSettings()
            ServiceContainer.shared.configure(with: modelContext, appSettings: appSettings)
            
            print("[ContentView] 创建AppViewModel实例")
            let newAppViewModel = AppViewModel()
            newAppViewModel.setModelContext(modelContext, appSettings: appSettings)
            self.appViewModel = newAppViewModel
            self.isInitializing = false
            self.hasInitialized = true
            print("[ContentView] AppViewModel初始化完成")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Article.self, DictionaryWord.self, UserWord.self, UserProgress.self, DailyStudyRecord.self], inMemory: true)
}
