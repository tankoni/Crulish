//
//  ContentView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appViewModel: AppViewModel?
    
    var body: some View {
        Group {
            if let appViewModel = appViewModel {
                TabView(selection: Binding(
                    get: { appViewModel.selectedTab },
                    set: { appViewModel.selectTab($0) }
                )) {
                    // Home Tab
                    Group {
                        if let homeViewModel = appViewModel.homeViewModel {
                            HomeView(viewModel: homeViewModel)
                        } else {
                            VStack {
                                ProgressView()
                                Text("加载中...")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tabItem {
                        Image(systemName: "house")
                        Text("首页")
                    }
                    .tag(TabSelection.home)
                    
                    // Reading Tab
                    Group {
                        if let readingViewModel = appViewModel.readingViewModel {
                            ReadingView(viewModel: readingViewModel)
                        } else {
                            VStack {
                                ProgressView()
                                Text("加载中...")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tabItem {
                        Image(systemName: "book")
                        Text("阅读")
                    }
                    .tag(TabSelection.reading)
                    
                    // Vocabulary Tab
                    Group {
                        if let vocabularyViewModel = appViewModel.vocabularyViewModel {
                            VocabularyView(viewModel: vocabularyViewModel)
                        } else {
                            VStack {
                                ProgressView()
                                Text("加载中...")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tabItem {
                        Image(systemName: "text.book.closed")
                        Text("词汇")
                    }
                    .tag(TabSelection.vocabulary)
                    
                    // Progress Tab
                    Group {
                        if let progressViewModel = appViewModel.progressViewModel {
                            ProgressDashboardView(viewModel: progressViewModel)
                        } else {
                            VStack {
                                ProgressView()
                                Text("加载中...")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("进度")
                    }
                    .tag(TabSelection.progress)
                    
                    // Settings Tab
                    Group {
                        if let settingsViewModel = appViewModel.settingsViewModel {
                            SettingsView(viewModel: settingsViewModel)
                        } else {
                            VStack {
                                ProgressView()
                                Text("加载中...")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tabItem {
                        Image(systemName: "gear")
                        Text("设置")
                    }
                    .tag(TabSelection.settings)
                }
                .environment(appViewModel)
                .environmentObject(appViewModel.coordinator)
                .environmentObject(appViewModel.coordinator.getDictionaryService() as! DictionaryService)
                .environmentObject(appViewModel.coordinator.getTextProcessor() as! TextProcessor)
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
            if appViewModel == nil {
                let newAppViewModel = AppViewModel()
                newAppViewModel.setModelContext(modelContext)
                appViewModel = newAppViewModel
            }
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
}

#Preview {
    ContentView()
        .modelContainer(for: [Article.self, DictionaryWord.self, UserWord.self, UserProgress.self, DailyStudyRecord.self], inMemory: true)
}
