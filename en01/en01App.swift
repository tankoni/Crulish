//
//  en01App.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI
import SwiftData

@main
struct en01App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Article.self,
            DictionaryWord.self,
            WordDefinition.self,
            UserWord.self,
            UserProgress.self,
            DailyStudyRecord.self,
            // 考研词典模型
            KaoyanWord.self,
            KaoyanTranslation.self,
            KaoyanSentence.self,
            KaoyanSynonym.self,
            KaoyanPhrase.self,
            KaoyanRelatedWord.self,
            KaoyanExam.self,
            KaoyanChoice.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
