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
                    if let homeViewModel = appViewModel.homeViewModel {
                HomeView(viewModel: homeViewModel)
                    .tabItem {
                        Image(systemName: TabSelection.home.iconName)
                        Text(TabSelection.home.title)
                    }
                    .tag(TabSelection.home)
                    } else {
                        Text("加载中...")
                            .tabItem {
                                Image(systemName: TabSelection.home.iconName)
                                Text(TabSelection.home.title)
                            }
                            .tag(TabSelection.home)
                    }
            
                    if let readingViewModel = appViewModel.readingViewModel {
                ReadingView(viewModel: readingViewModel)
                    .tabItem {
                        Image(systemName: TabSelection.reading.iconName)
                        Text(TabSelection.reading.title)
                    }
                    .tag(TabSelection.reading)
                    } else {
                        Text("加载中...")
                            .tabItem {
                                Image(systemName: TabSelection.reading.iconName)
                                Text(TabSelection.reading.title)
                            }
                            .tag(TabSelection.reading)
                    }
            
                    if let vocabularyViewModel = appViewModel.vocabularyViewModel {
                VocabularyView(viewModel: vocabularyViewModel)
                    .tabItem {
                        Image(systemName: TabSelection.vocabulary.iconName)
                        Text(TabSelection.vocabulary.title)
                    }
                    .tag(TabSelection.vocabulary)
                    } else {
                        Text("加载中...")
                            .tabItem {
                                Image(systemName: TabSelection.vocabulary.iconName)
                                Text(TabSelection.vocabulary.title)
                            }
                            .tag(TabSelection.vocabulary)
                    }
            
                    if let progressViewModel = appViewModel.progressViewModel {
                ProgressView(viewModel: progressViewModel)
                    .tabItem {
                        Image(systemName: TabSelection.progress.iconName)
                        Text(TabSelection.progress.title)
                    }
                    .tag(TabSelection.progress)
                    } else {
                        Text("加载中...")
                            .tabItem {
                                Image(systemName: TabSelection.progress.iconName)
                                Text(TabSelection.progress.title)
                            }
                            .tag(TabSelection.progress)
                    }
            
                    if let settingsViewModel = appViewModel.settingsViewModel {
                SettingsView(viewModel: settingsViewModel)
                    .tabItem {
                        Image(systemName: TabSelection.settings.iconName)
                        Text(TabSelection.settings.title)
                    }
                    .tag(TabSelection.settings)
                    } else {
                        Text("加载中...")
                            .tabItem {
                                Image(systemName: TabSelection.settings.iconName)
                                Text(TabSelection.settings.title)
                            }
                            .tag(TabSelection.settings)
                    }
                }
                .environment(appViewModel)
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
