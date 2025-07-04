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
    @State private var appViewModel = AppViewModel()
    
    var body: some View {
        TabView(selection: $appViewModel.selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: TabSelection.home.iconName)
                    Text(TabSelection.home.title)
                }
                .tag(TabSelection.home)
            
            ReadingView()
                .tabItem {
                    Image(systemName: TabSelection.reading.iconName)
                    Text(TabSelection.reading.title)
                }
                .tag(TabSelection.reading)
            
            VocabularyView()
                .tabItem {
                    Image(systemName: TabSelection.vocabulary.iconName)
                    Text(TabSelection.vocabulary.title)
                }
                .tag(TabSelection.vocabulary)
            
            ProgressView()
                .tabItem {
                    Image(systemName: TabSelection.progress.iconName)
                    Text(TabSelection.progress.title)
                }
                .tag(TabSelection.progress)
            
            SettingsView()
                .tabItem {
                    Image(systemName: TabSelection.settings.iconName)
                    Text(TabSelection.settings.title)
                }
                .tag(TabSelection.settings)
        }
        .environment(appViewModel)
        .onAppear {
            appViewModel.setModelContext(modelContext)
        }
        .alert("错误", isPresented: $appViewModel.isShowingError) {
            Button("确定") {
                appViewModel.dismissError()
            }
        } message: {
            if let errorMessage = appViewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Article.self, DictionaryWord.self, UserWord.self, UserWordRecord.self, UserProgress.self, DailyStudyRecord.self], inMemory: true)
}
