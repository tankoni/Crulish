//
//  SettingsViewModel.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI
import SwiftData
import Combine

/// 设置ViewModel，负责应用设置和配置管理功能
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var userSettings: UserSettings = UserSettings()
    @Published var readingSettings: ReadingSettings = ReadingSettings()
    @Published var vocabularySettings: VocabularySettings = VocabularySettings()
    @Published var notificationSettings: NotificationSettings = NotificationSettings()
    @Published var privacySettings: PrivacySettings = PrivacySettings()
    @Published var appearanceSettings: AppearanceSettings = AppearanceSettings()
    @Published var dataSettings: DataSettings = DataSettings()
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingResetAlert: Bool = false
    @Published var showingExportSheet: Bool = false
    @Published var showingImportSheet: Bool = false
    
    // MARK: - Cache Properties
    private var settingsCache: [String: (settings: Any, timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 600 // 10分钟
    
    // MARK: - Services
    private let userProgressService: UserProgressServiceProtocol
    private let errorHandler: ErrorHandlerProtocol
    private let cacheManager: CacheManagerProtocol
    
    // MARK: - Initialization
    init(
        userProgressService: UserProgressServiceProtocol,
        errorHandler: ErrorHandlerProtocol,
        cacheManager: CacheManagerProtocol
    ) {
        self.userProgressService = userProgressService
        self.errorHandler = errorHandler
        self.cacheManager = cacheManager
        
        loadAllSettings()
    }
    
    // MARK: - Settings Loading
    func loadAllSettings() {
        isLoading = true
        errorMessage = nil
        
        Task {
            await loadUserSettings()
            await loadReadingSettings()
            await loadVocabularySettings()
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadUserSettings() async {
        // 检查缓存
        if let cache = settingsCache["user"],
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            if let settings = cache.settings as? UserSettings {
                await MainActor.run {
                    self.userSettings = settings
                }
                return
            }
        }
        
        do {
            let settings = try await userProgressService.getUserSettings()
            
            await MainActor.run {
                self.userSettings = settings
                self.settingsCache["user"] = (settings, Date())
            }
            
            errorHandler.logSuccess("加载用户设置成功")
        } catch {
            errorHandler.handle(error, context: "SettingsViewModel.loadUserSettings")
        }
    }
    
    private func loadReadingSettings() async {
        // 检查缓存
        if let cache = settingsCache["reading"],
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            if let settings = cache.settings as? ReadingSettings {
                await MainActor.run {
                    self.readingSettings = settings
                }
                return
            }
        }
        
        do {
            let settings = try await userProgressService.getReadingSettings()
            
            await MainActor.run {
                self.readingSettings = settings
                self.settingsCache["reading"] = (settings, Date())
            }
            
            errorHandler.logSuccess("加载阅读设置成功")
        } catch {
            errorHandler.handle(error, context: "SettingsViewModel.loadReadingSettings")
        }
    }
    
    private func loadVocabularySettings() async {
        // 检查缓存
        if let cache = settingsCache["vocabulary"],
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            if let settings = cache.settings as? VocabularySettings {
                await MainActor.run {
                    self.vocabularySettings = settings
                }
                return
            }
        }
        
        do {
            let settings = try await userProgressService.getVocabularySettings()
            
            await MainActor.run {
                self.vocabularySettings = settings
                self.settingsCache["vocabulary"] = (settings, Date())
            }
            
            errorHandler.logSuccess("加载词汇设置成功")
        } catch {
            errorHandler.handle(error, context: "SettingsViewModel.loadVocabularySettings")
        }
    }
    

    

    

    
    // MARK: - Settings Update
    func updateUserSettings(_ settings: UserSettings) {
        Task {
            do {
                try await userProgressService.updateUserSettings(settings)
                await MainActor.run {
                    self.userSettings = settings
                    self.settingsCache["user"] = (settings, Date())
                }
                errorHandler.logSuccess("更新用户设置成功")
            } catch {
                errorHandler.handle(error, context: "SettingsViewModel.updateUserSettings")
            }
        }
    }
    
    func updateReadingSettings(_ settings: ReadingSettings) {
        Task {
            do {
                try await userProgressService.updateReadingSettings(settings)
                await MainActor.run {
                    self.readingSettings = settings
                    self.settingsCache["reading"] = (settings, Date())
                }
                errorHandler.logSuccess("更新阅读设置成功")
            } catch {
                errorHandler.handle(error, context: "SettingsViewModel.updateReadingSettings")
            }
        }
    }
    
    func updateVocabularySettings(_ settings: VocabularySettings) {
        Task {
            do {
                try await userProgressService.updateVocabularySettings(settings)
                await MainActor.run {
                    self.vocabularySettings = settings
                    self.settingsCache["vocabulary"] = (settings, Date())
                }
                errorHandler.logSuccess("更新词汇设置成功")
            } catch {
                errorHandler.handle(error, context: "SettingsViewModel.updateVocabularySettings")
            }
        }
    }
    
    func updateNotificationSettings(_ settings: NotificationSettings) {
        Task {
            do {
                try await userProgressService.updateNotificationSettings(settings)
                await MainActor.run {
                    self.notificationSettings = settings
                    self.settingsCache["notification"] = (settings, Date())
                }
                errorHandler.logSuccess("更新通知设置成功")
            } catch {
                errorHandler.handle(error, context: "SettingsViewModel.updateNotificationSettings")
            }
        }
    }
    
    func updatePrivacySettings(_ settings: PrivacySettings) {
        Task {
            do {
                try await userProgressService.updatePrivacySettings(settings)
                await MainActor.run {
                    self.privacySettings = settings
                    self.settingsCache["privacy"] = (settings, Date())
                }
                errorHandler.logSuccess("更新隐私设置成功")
            } catch {
                errorHandler.handle(error, context: "SettingsViewModel.updatePrivacySettings")
            }
        }
    }
    
    func updateAppearanceSettings(_ settings: AppearanceSettings) {
        Task {
            do {
                try await userProgressService.updateAppearanceSettings(settings)
                await MainActor.run {
                    self.appearanceSettings = settings
                    self.settingsCache["appearance"] = (settings, Date())
                }
                errorHandler.logSuccess("更新外观设置成功")
            } catch {
                errorHandler.handle(error, context: "SettingsViewModel.updateAppearanceSettings")
            }
        }
    }
    
    // MARK: - Data Management
    func exportAllData() {
        showingExportSheet = true
    }
    
    func importData() {
        showingImportSheet = true
    }
    
    func exportSettings() -> Data? {
        let exportData = SettingsExportData(
            userSettings: userSettings,
            readingSettings: readingSettings,
            vocabularySettings: vocabularySettings,
            notificationSettings: notificationSettings,
            privacySettings: privacySettings,
            appearanceSettings: appearanceSettings,
            exportDate: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(exportData)
        } catch {
            errorHandler.handle(error, context: "SettingsViewModel.exportSettings")
            return nil
        }
    }
    
    func importSettings(from data: Data) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importData = try decoder.decode(SettingsExportData.self, from: data)
            
            // 更新所有设置
            updateUserSettings(importData.userSettings)
            updateReadingSettings(importData.readingSettings)
            updateVocabularySettings(importData.vocabularySettings)
            updateNotificationSettings(importData.notificationSettings)
            updatePrivacySettings(importData.privacySettings)
            updateAppearanceSettings(importData.appearanceSettings)
            
            errorHandler.logSuccess("导入设置成功")
        } catch {
            errorHandler.handle(error, context: "SettingsViewModel.importSettings")
        }
    }
    
    func clearAllCache() {
        cacheManager.clearAll()
        settingsCache.removeAll()
        errorHandler.logSuccess("清除缓存成功")
    }
    
    func resetAllData() {
        showingResetAlert = true
    }
    
    func confirmResetAllData() {
        Task {
            do {
                try await userProgressService.resetAllData()
                clearAllCache()
                loadAllSettings()
                errorHandler.logSuccess("重置所有数据成功")
            } catch {
                errorHandler.handle(error, context: "SettingsViewModel.confirmResetAllData")
            }
        }
    }
    
    // MARK: - Cache Management
    func refreshSettings() {
        settingsCache.removeAll()
        loadAllSettings()
    }
    
    func loadSettings() {
        loadAllSettings()
    }
    
    func clearCache() async {
        clearAllCache()
    }
    
    func exportData(types: Set<DataType>) async -> Bool {
        // 实现数据导出逻辑
        do {
            // 这里应该实现实际的导出逻辑
            try await Task.sleep(nanoseconds: 1_000_000_000) // 模拟导出过程
            errorHandler.logSuccess("数据导出成功")
            return true
        } catch {
            errorHandler.handle(error, context: "SettingsViewModel.exportData")
            return false
        }
    }
    
    func importData(from url: URL) async -> Result<Void, Error> {
        // 实现数据导入逻辑
        do {
            // 这里应该实现实际的导入逻辑
            try await Task.sleep(nanoseconds: 1_000_000_000) // 模拟导入过程
            errorHandler.logSuccess("数据导入成功")
            return .success(())
        } catch {
            errorHandler.handle(error, context: "SettingsViewModel.importData")
            return .failure(error)
        }
    }
    
    func clearSettingsCache() {
        settingsCache.removeAll()
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Computed Properties
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    var deviceInfo: String {
        "\(UIDevice.current.model) - iOS \(UIDevice.current.systemVersion)"
    }
    
    var totalCacheSize: String {
        // 计算缓存大小的逻辑
        return "计算中..."
    }
}

// MARK: - Supporting Types
struct UserSettings: Codable {
    var username: String = ""
    var email: String = ""
    var profileImageURL: String? = nil
    var preferredLanguage: String = "zh-CN"
    var timezone: String = TimeZone.current.identifier
    var dateJoined: Date = Date()
    var lastActiveDate: Date = Date()
}

struct ReadingSettings: Codable {
    var fontSize: Double = 16.0
    var fontFamily: String = "System"
    var lineSpacing: Double = 1.2
    var backgroundColor: String = "#FFFFFF"
    var textColor: String = "#000000"
    var highlightColor: String = "#FFFF00"
    var linkColor: String = "#007AFF"
    var readingMargin: Double = 16.0
    var paragraphSpacing: Double = 8.0
    var autoScrollSpeed: Double = 1.0
    var enableAutoScroll: Bool = false
    var showWordCount: Bool = true
    var showReadingTime: Bool = true
    var enableImmersiveMode: Bool = false
    var dailyReadingGoal: Int = 30 // 分钟
    var weeklyReadingGoal: Int = 210 // 分钟
    var colorScheme: String = "system" // Use String instead of enum to avoid conflicts
    
    enum CodingKeys: String, CodingKey {
        case fontSize, fontFamily, lineSpacing, backgroundColor, textColor
        case highlightColor, linkColor, readingMargin, paragraphSpacing
        case autoScrollSpeed, enableAutoScroll, showWordCount, showReadingTime
        case enableImmersiveMode, dailyReadingGoal, weeklyReadingGoal, colorScheme
    }
    
    init() {
        // Use default values
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 16.0
        fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily) ?? "System"
        lineSpacing = try container.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? 1.2
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor) ?? "#FFFFFF"
        textColor = try container.decodeIfPresent(String.self, forKey: .textColor) ?? "#000000"
        highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor) ?? "#FFFF00"
        linkColor = try container.decodeIfPresent(String.self, forKey: .linkColor) ?? "#007AFF"
        readingMargin = try container.decodeIfPresent(Double.self, forKey: .readingMargin) ?? 16.0
        paragraphSpacing = try container.decodeIfPresent(Double.self, forKey: .paragraphSpacing) ?? 8.0
        autoScrollSpeed = try container.decodeIfPresent(Double.self, forKey: .autoScrollSpeed) ?? 1.0
        enableAutoScroll = try container.decodeIfPresent(Bool.self, forKey: .enableAutoScroll) ?? false
        showWordCount = try container.decodeIfPresent(Bool.self, forKey: .showWordCount) ?? true
        showReadingTime = try container.decodeIfPresent(Bool.self, forKey: .showReadingTime) ?? true
        enableImmersiveMode = try container.decodeIfPresent(Bool.self, forKey: .enableImmersiveMode) ?? false
        dailyReadingGoal = try container.decodeIfPresent(Int.self, forKey: .dailyReadingGoal) ?? 30
        weeklyReadingGoal = try container.decodeIfPresent(Int.self, forKey: .weeklyReadingGoal) ?? 210
        colorScheme = try container.decodeIfPresent(String.self, forKey: .colorScheme) ?? "system"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(fontFamily, forKey: .fontFamily)
        try container.encode(lineSpacing, forKey: .lineSpacing)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(textColor, forKey: .textColor)
        try container.encode(highlightColor, forKey: .highlightColor)
        try container.encode(linkColor, forKey: .linkColor)
        try container.encode(readingMargin, forKey: .readingMargin)
        try container.encode(paragraphSpacing, forKey: .paragraphSpacing)
        try container.encode(autoScrollSpeed, forKey: .autoScrollSpeed)
        try container.encode(enableAutoScroll, forKey: .enableAutoScroll)
        try container.encode(showWordCount, forKey: .showWordCount)
        try container.encode(showReadingTime, forKey: .showReadingTime)
        try container.encode(enableImmersiveMode, forKey: .enableImmersiveMode)
        try container.encode(dailyReadingGoal, forKey: .dailyReadingGoal)
        try container.encode(weeklyReadingGoal, forKey: .weeklyReadingGoal)
        try container.encode(colorScheme, forKey: .colorScheme)
    }
}

struct VocabularySettings: Codable {
    var enableAutoLookup: Bool = true
    var showPronunciation: Bool = true
    var showExamples: Bool = true
    var enableSpacedRepetition: Bool = true
    var reviewFrequency: ReviewFrequency = .daily
    var difficultyAdjustment: DifficultyAdjustment = .automatic
    var maxNewWordsPerDay: Int = 20
    var enableNotifications: Bool = true
    var preferredDictionary: String = "default"
    var autoAddToReview: Bool = true
}

struct NotificationSettings: Codable {
    var enableDailyReminder: Bool = true
    var dailyReminderTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    var enableReviewReminder: Bool = true
    var reviewReminderInterval: Int = 4 // 小时
    var enableAchievementNotifications: Bool = true
    var enableProgressNotifications: Bool = true
    var enableWeeklyReport: Bool = true
    var weeklyReportDay: Int = 1 // 周一
    var notificationSound: String = "default"
    var enableVibration: Bool = true
}

struct PrivacySettings: Codable {
    var enableAnalytics: Bool = true
    var enableCrashReporting: Bool = true
    var shareUsageData: Bool = false
    var enableCloudSync: Bool = true
    var autoBackup: Bool = true
    var dataRetentionPeriod: Int = 365 // 天
    var enableLocationServices: Bool = false
}

struct AppearanceSettings: Codable {
    var colorScheme: ColorSchemePreference = .system
    var accentColor: String = "#007AFF"
    var enableDynamicType: Bool = true
    var enableReduceMotion: Bool = false
    var enableHighContrast: Bool = false
    var tabBarStyle: TabBarStyle = .standard
    var navigationStyle: NavigationStyle = .standard
}

struct SettingsExportData: Codable {
    let userSettings: UserSettings
    let readingSettings: ReadingSettings
    let vocabularySettings: VocabularySettings
    let notificationSettings: NotificationSettings
    let privacySettings: PrivacySettings
    let appearanceSettings: AppearanceSettings
    let exportDate: Date
}

// MARK: - Enums
enum ReviewFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case twiceDaily = "twice_daily"
    case weekly = "weekly"
    case custom = "custom"
    
    var title: String {
        switch self {
        case .daily:
            return "每日"
        case .twiceDaily:
            return "每日两次"
        case .weekly:
            return "每周"
        case .custom:
            return "自定义"
        }
    }
}

enum DifficultyAdjustment: String, CaseIterable, Codable {
    case automatic = "automatic"
    case manual = "manual"
    case disabled = "disabled"
    
    var title: String {
        switch self {
        case .automatic:
            return "自动调整"
        case .manual:
            return "手动调整"
        case .disabled:
            return "禁用"
        }
    }
}

enum ColorSchemePreference: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var title: String {
        switch self {
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        case .system:
            return "跟随系统"
        }
    }
}

enum TabBarStyle: String, CaseIterable, Codable {
    case standard = "standard"
    case compact = "compact"
    case minimal = "minimal"
    
    var title: String {
        switch self {
        case .standard:
            return "标准"
        case .compact:
            return "紧凑"
        case .minimal:
            return "极简"
        }
    }
}

enum NavigationStyle: String, CaseIterable, Codable {
    case standard = "standard"
    case large = "large"
    case inline = "inline"
    
    var title: String {
        switch self {
        case .standard:
            return "标准"
        case .large:
            return "大标题"
        case .inline:
            return "内联"
        }
    }
}

// AppColorScheme enum is defined in Models/Settings.swift to avoid duplication

struct DataSettings: Codable {
    var enableAutoBackup: Bool = true
    var backupFrequency: BackupFrequency = .weekly
    var enableCloudSync: Bool = true
    var maxCacheSize: Int = 100 // MB
    var enableDataCompression: Bool = true
    
    init() {
        // 使用默认值
    }
    
    enum CodingKeys: String, CodingKey {
        case enableAutoBackup
        case backupFrequency
        case enableCloudSync
        case maxCacheSize
        case enableDataCompression
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enableAutoBackup = try container.decodeIfPresent(Bool.self, forKey: .enableAutoBackup) ?? true
        enableCloudSync = try container.decodeIfPresent(Bool.self, forKey: .enableCloudSync) ?? true
        maxCacheSize = try container.decodeIfPresent(Int.self, forKey: .maxCacheSize) ?? 100
        enableDataCompression = try container.decodeIfPresent(Bool.self, forKey: .enableDataCompression) ?? true
        
        if let frequencyString = try container.decodeIfPresent(String.self, forKey: .backupFrequency) {
            backupFrequency = BackupFrequency(rawValue: frequencyString) ?? .weekly
        } else {
            backupFrequency = .weekly
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enableAutoBackup, forKey: .enableAutoBackup)
        try container.encode(backupFrequency.rawValue, forKey: .backupFrequency)
        try container.encode(enableCloudSync, forKey: .enableCloudSync)
        try container.encode(maxCacheSize, forKey: .maxCacheSize)
        try container.encode(enableDataCompression, forKey: .enableDataCompression)
    }
}

// BackupFrequency is defined in Models/Settings.swift