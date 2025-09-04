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

    
    var body: some View {
        VStack {
            if let appViewModel = appViewModel {
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
                .environmentObject(appViewModel.coordinator.wordInteractionCoordinator!)
            } else {
                VStack {
                    SwiftUI.ProgressView()
                    Text("初始化中...")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
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
        .alert("错误", isPresented: .constant(appViewModel?.hasError ?? false)) {
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
                IntelligentRankingView(viewModel: intelligentRankingViewModel)
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
        if appViewModel == nil {
            let newAppViewModel = AppViewModel()
            let appSettings = AppSettings()
            newAppViewModel.setModelContext(modelContext, appSettings: appSettings)
            appViewModel = newAppViewModel
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Article.self, DictionaryWord.self, UserWord.self, UserProgress.self, DailyStudyRecord.self], inMemory: true)
}
