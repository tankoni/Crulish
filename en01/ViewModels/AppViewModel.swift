//
//  AppViewModel.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
class AppViewModel {
    // MARK: - Dependencies
    let coordinator: AppCoordinator
    
    // MARK: - State
    var selectedTab: TabSelection = .home
    
    // MARK: - Error Handling
    var errorMessage: String?
    var isShowingError = false
    
    init(serviceContainer: ServiceContainer = ServiceContainer.shared) {
        self.coordinator = AppCoordinator(serviceContainer: serviceContainer)
    }
    
    // MARK: - Initialization
    
    func setModelContext(_ context: ModelContext, appSettings: AppSettings) {
        coordinator.setModelContext(context, appSettings: appSettings)
    }
    
    // MARK: - Tab Navigation
    
    func selectTab(_ tab: TabSelection) {
        selectedTab = tab
    }
    
    // MARK: - Coordinator Access
    
    var readingViewModel: ReadingViewModel? {
        return coordinator.readingViewModel
    }
    
    var vocabularyViewModel: VocabularyViewModel? {
        return coordinator.vocabularyViewModel
    }
    
    var intelligentRankingViewModel: IntelligentRankingViewModel? {
        return coordinator.intelligentRankingViewModel
    }
    
    var progressViewModel: ProgressViewModel? {
        return coordinator.progressViewModel
    }
    
    var settingsViewModel: SettingsViewModel? {
        return coordinator.settingsViewModel
    }
    
    var homeViewModel: HomeViewModel? {
        return coordinator.homeViewModel
    }
    
    // MARK: - Error Handling
    
    var hasError: Bool {
        return coordinator.hasError
    }
    
    var currentErrorMessage: String? {
        return coordinator.currentErrorMessage
    }
    

    

    

    

    

    

    

    

    

    

    
    // MARK: - Error Handling
    
    // MARK: - Coordinator Actions
    
    func startReading(_ article: Article) {
        coordinator.startReading(article)
        selectedTab = .reading
    }
    
    func finishReading() {
        coordinator.finishReading()
        selectedTab = .home
    }
    
    func addWord(_ word: String, context: String) {
        coordinator.addWord(word, context: context)
    }
    
    func updateProgress() {
        coordinator.updateProgress()
    }
    
    func startVocabularyReview() {
        coordinator.startVocabularyReview()
        selectedTab = .vocabulary
    }
    
    func startVocabularyTest() {
        coordinator.startVocabularyTest()
        selectedTab = .vocabulary
    }
    
    func finishVocabularyReview() {
        coordinator.finishVocabularyReview()
    }
    
    func updateSettings(_ settings: AppSettings) {
        coordinator.updateSettings()
    }
    
    func clearCache() async {
        await coordinator.clearCache()
    }
    
    func refreshData() async {
        await coordinator.refreshData()
    }
    
    func handleDeepLink(_ url: URL) {
        coordinator.handleDeepLink(url)
    }
}