//
//  Settings.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftUI

// 应用设置模型
class AppSettings: ObservableObject {
    // 阅读设置
    @Published var fontSize: Double = 16.0
    @Published var lineSpacing: Double = 1.2
    @Published var fontFamily: FontFamily = .system
    @Published var textAlignment: TextAlignment = .leading
    @Published var paragraphSpacing: Double = 8.0
    @Published var readingMargin: Double = 16.0
    
    // 主题设置
    @Published var colorScheme: AppColorScheme = .auto
    @Published var accentColor: AccentColor = .blue
    @Published var useSystemColors: Bool = true
    @Published var eyeCareMode: Bool = false
    @Published var autoNightMode: Bool = false
    @Published var backgroundColor: Color = .white
    @Published var textColor: Color = .black
    @Published var linkColor: Color = .blue
    
    // 交互设置
    @Published var tapToShowDefinition: Bool = true
    @Published var longPressForTranslation: Bool = true
    @Published var autoHideDefinition: Bool = true
    @Published var definitionHideDelay: Double = 3.0
    @Published var hapticFeedback: Bool = true
    @Published var soundEffects: Bool = false
    
    // 学习设置
    @Published var autoAddToVocabulary: Bool = true
    @Published var showPhonetics: Bool = true
    @Published var showPartOfSpeech: Bool = true
    @Published var preferredDefinitionLanguage: DefinitionLanguage = .chinese
    @Published var definitionLanguage: DefinitionLanguage = .chinese
    @Published var showContextInDefinition: Bool = true
    @Published var enableSmartReview: Bool = true
    @Published var dailyReviewGoal: Int = 20
    @Published var autoSaveWords: Bool = true
    @Published var smartReviewReminder: Bool = true
    @Published var showExamples: Bool = true
    @Published var dailyGoalMinutes: Int = 30
    
    // 通知设置
    @Published var enableNotifications: Bool = false
    @Published var dailyReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    @Published var reviewReminders: Bool = false
    @Published var achievementNotifications: Bool = true
    @Published var studyReminder: Bool = false
    @Published var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    @Published var reviewReminder: Bool = false
    @Published var achievementNotification: Bool = true
    
    // 数据设置
    @Published var autoBackup: Bool = true
    @Published var backupFrequency: BackupFrequency = .weekly
    @Published var syncWithiCloud: Bool = false
    @Published var dataRetentionDays: Int = 365
    
    // 高级设置
    @Published var enableAnalytics: Bool = false
    @Published var debugMode: Bool = false
    @Published var experimentalFeatures: Bool = false
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    // 保存设置到UserDefaults
    func saveSettings() {
        userDefaults.set(fontSize, forKey: "fontSize")
        userDefaults.set(lineSpacing, forKey: "lineSpacing")
        userDefaults.set(fontFamily.rawValue, forKey: "fontFamily")
        userDefaults.set(textAlignment.rawValue, forKey: "textAlignment")
        userDefaults.set(paragraphSpacing, forKey: "paragraphSpacing")
        userDefaults.set(readingMargin, forKey: "readingMargin")
        
        userDefaults.set(colorScheme.rawValue, forKey: "colorScheme")
        userDefaults.set(accentColor.rawValue, forKey: "accentColor")
        userDefaults.set(useSystemColors, forKey: "useSystemColors")
        userDefaults.set(eyeCareMode, forKey: "eyeCareMode")
        userDefaults.set(autoNightMode, forKey: "autoNightMode")
        
        // 保存颜色设置
        if let backgroundColorData = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(backgroundColor), requiringSecureCoding: false) {
            userDefaults.set(backgroundColorData, forKey: "backgroundColor")
        }
        if let textColorData = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(textColor), requiringSecureCoding: false) {
            userDefaults.set(textColorData, forKey: "textColor")
        }
        if let linkColorData = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(linkColor), requiringSecureCoding: false) {
            userDefaults.set(linkColorData, forKey: "linkColor")
        }
        
        userDefaults.set(tapToShowDefinition, forKey: "tapToShowDefinition")
        userDefaults.set(longPressForTranslation, forKey: "longPressForTranslation")
        userDefaults.set(autoHideDefinition, forKey: "autoHideDefinition")
        userDefaults.set(definitionHideDelay, forKey: "definitionHideDelay")
        userDefaults.set(hapticFeedback, forKey: "hapticFeedback")
        userDefaults.set(soundEffects, forKey: "soundEffects")
        
        userDefaults.set(autoAddToVocabulary, forKey: "autoAddToVocabulary")
        userDefaults.set(showPhonetics, forKey: "showPhonetics")
        userDefaults.set(showPartOfSpeech, forKey: "showPartOfSpeech")
        userDefaults.set(preferredDefinitionLanguage.rawValue, forKey: "preferredDefinitionLanguage")
        userDefaults.set(definitionLanguage.rawValue, forKey: "definitionLanguage")
        userDefaults.set(showContextInDefinition, forKey: "showContextInDefinition")
        userDefaults.set(enableSmartReview, forKey: "enableSmartReview")
        userDefaults.set(dailyReviewGoal, forKey: "dailyReviewGoal")
        userDefaults.set(autoSaveWords, forKey: "autoSaveWords")
        userDefaults.set(smartReviewReminder, forKey: "smartReviewReminder")
        userDefaults.set(showExamples, forKey: "showExamples")
        userDefaults.set(dailyGoalMinutes, forKey: "dailyGoalMinutes")
        
        userDefaults.set(enableNotifications, forKey: "enableNotifications")
        userDefaults.set(dailyReminderTime, forKey: "dailyReminderTime")
        userDefaults.set(reviewReminders, forKey: "reviewReminders")
        userDefaults.set(achievementNotifications, forKey: "achievementNotifications")
        userDefaults.set(studyReminder, forKey: "studyReminder")
        userDefaults.set(reminderTime, forKey: "reminderTime")
        userDefaults.set(reviewReminder, forKey: "reviewReminder")
        userDefaults.set(achievementNotification, forKey: "achievementNotification")
        
        userDefaults.set(autoBackup, forKey: "autoBackup")
        userDefaults.set(backupFrequency.rawValue, forKey: "backupFrequency")
        userDefaults.set(syncWithiCloud, forKey: "syncWithiCloud")
        userDefaults.set(dataRetentionDays, forKey: "dataRetentionDays")
        
        userDefaults.set(enableAnalytics, forKey: "enableAnalytics")
        userDefaults.set(debugMode, forKey: "debugMode")
        userDefaults.set(experimentalFeatures, forKey: "experimentalFeatures")
    }
    
    // 从UserDefaults加载设置
    private func loadSettings() {
        fontSize = userDefaults.object(forKey: "fontSize") as? Double ?? 16.0
        lineSpacing = userDefaults.object(forKey: "lineSpacing") as? Double ?? 1.2
        fontFamily = FontFamily(rawValue: userDefaults.string(forKey: "fontFamily") ?? "") ?? .system
        textAlignment = TextAlignment(rawValue: userDefaults.string(forKey: "textAlignment") ?? "") ?? .leading
        paragraphSpacing = userDefaults.object(forKey: "paragraphSpacing") as? Double ?? 8.0
        readingMargin = userDefaults.object(forKey: "readingMargin") as? Double ?? 16.0
        
        colorScheme = AppColorScheme(rawValue: userDefaults.string(forKey: "colorScheme") ?? "") ?? .auto
        accentColor = AccentColor(rawValue: userDefaults.string(forKey: "accentColor") ?? "") ?? .blue
        useSystemColors = userDefaults.object(forKey: "useSystemColors") as? Bool ?? true
        eyeCareMode = userDefaults.object(forKey: "eyeCareMode") as? Bool ?? false
        autoNightMode = userDefaults.object(forKey: "autoNightMode") as? Bool ?? false
        
        // 加载颜色设置
        if let backgroundColorData = userDefaults.data(forKey: "backgroundColor"),
           let uiBackgroundColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: backgroundColorData) {
            backgroundColor = Color(uiBackgroundColor)
        } else {
            backgroundColor = .white
        }
        
        if let textColorData = userDefaults.data(forKey: "textColor"),
           let uiTextColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: textColorData) {
            textColor = Color(uiTextColor)
        } else {
            textColor = .black
        }
        
        if let linkColorData = userDefaults.data(forKey: "linkColor"),
           let uiLinkColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: linkColorData) {
            linkColor = Color(uiLinkColor)
        } else {
            linkColor = .blue
        }
        
        tapToShowDefinition = userDefaults.object(forKey: "tapToShowDefinition") as? Bool ?? true
        longPressForTranslation = userDefaults.object(forKey: "longPressForTranslation") as? Bool ?? true
        autoHideDefinition = userDefaults.object(forKey: "autoHideDefinition") as? Bool ?? true
        definitionHideDelay = userDefaults.object(forKey: "definitionHideDelay") as? Double ?? 3.0
        hapticFeedback = userDefaults.object(forKey: "hapticFeedback") as? Bool ?? true
        soundEffects = userDefaults.object(forKey: "soundEffects") as? Bool ?? false
        
        autoAddToVocabulary = userDefaults.object(forKey: "autoAddToVocabulary") as? Bool ?? true
        showPhonetics = userDefaults.object(forKey: "showPhonetics") as? Bool ?? true
        showPartOfSpeech = userDefaults.object(forKey: "showPartOfSpeech") as? Bool ?? true
        preferredDefinitionLanguage = DefinitionLanguage(rawValue: userDefaults.string(forKey: "preferredDefinitionLanguage") ?? "") ?? .chinese
        definitionLanguage = DefinitionLanguage(rawValue: userDefaults.string(forKey: "definitionLanguage") ?? "") ?? .chinese
        showContextInDefinition = userDefaults.object(forKey: "showContextInDefinition") as? Bool ?? true
        enableSmartReview = userDefaults.object(forKey: "enableSmartReview") as? Bool ?? true
        dailyReviewGoal = userDefaults.object(forKey: "dailyReviewGoal") as? Int ?? 20
        autoSaveWords = userDefaults.object(forKey: "autoSaveWords") as? Bool ?? true
        smartReviewReminder = userDefaults.object(forKey: "smartReviewReminder") as? Bool ?? true
        showExamples = userDefaults.object(forKey: "showExamples") as? Bool ?? true
        dailyGoalMinutes = userDefaults.object(forKey: "dailyGoalMinutes") as? Int ?? 30
        
        enableNotifications = userDefaults.object(forKey: "enableNotifications") as? Bool ?? false
        dailyReminderTime = userDefaults.object(forKey: "dailyReminderTime") as? Date ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
        reviewReminders = userDefaults.object(forKey: "reviewReminders") as? Bool ?? false
        achievementNotifications = userDefaults.object(forKey: "achievementNotifications") as? Bool ?? true
        studyReminder = userDefaults.object(forKey: "studyReminder") as? Bool ?? false
        reminderTime = userDefaults.object(forKey: "reminderTime") as? Date ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
        reviewReminder = userDefaults.object(forKey: "reviewReminder") as? Bool ?? false
        achievementNotification = userDefaults.object(forKey: "achievementNotification") as? Bool ?? true
        
        autoBackup = userDefaults.object(forKey: "autoBackup") as? Bool ?? true
        backupFrequency = BackupFrequency(rawValue: userDefaults.string(forKey: "backupFrequency") ?? "") ?? .weekly
        syncWithiCloud = userDefaults.object(forKey: "syncWithiCloud") as? Bool ?? false
        dataRetentionDays = userDefaults.object(forKey: "dataRetentionDays") as? Int ?? 365
        
        enableAnalytics = userDefaults.object(forKey: "enableAnalytics") as? Bool ?? false
        debugMode = userDefaults.object(forKey: "debugMode") as? Bool ?? false
        experimentalFeatures = userDefaults.object(forKey: "experimentalFeatures") as? Bool ?? false
    }
    
    // 重置为默认设置
    func resetToDefaults() {
        fontSize = 16.0
        lineSpacing = 1.2
        fontFamily = .system
        textAlignment = .leading
        paragraphSpacing = 8.0
        readingMargin = 16.0
        
        colorScheme = .auto
        accentColor = .blue
        useSystemColors = true
        eyeCareMode = false
        autoNightMode = false
        backgroundColor = .white
        textColor = .black
        linkColor = .blue
        
        tapToShowDefinition = true
        longPressForTranslation = true
        autoHideDefinition = true
        definitionHideDelay = 3.0
        hapticFeedback = true
        soundEffects = false
        
        autoAddToVocabulary = true
        showPhonetics = true
        showPartOfSpeech = true
        preferredDefinitionLanguage = .chinese
        definitionLanguage = .chinese
        showContextInDefinition = true
        enableSmartReview = true
        dailyReviewGoal = 20
        autoSaveWords = true
        smartReviewReminder = true
        showExamples = true
        dailyGoalMinutes = 30
        
        enableNotifications = false
        dailyReminderTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
        reviewReminders = false
        achievementNotifications = true
        studyReminder = false
        reminderTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
        reviewReminder = false
        achievementNotification = true
        
        autoBackup = true
        backupFrequency = .weekly
        syncWithiCloud = false
        dataRetentionDays = 365
        
        enableAnalytics = false
        debugMode = false
        experimentalFeatures = false
        
        saveSettings()
    }
}

// 字体家族
enum FontFamily: String, CaseIterable {
    case system = "系统字体"
    case serif = "衬线字体"
    case monospace = "等宽字体"
    case rounded = "圆体字体"
    
    var font: Font {
        switch self {
        case .system:
            return .system(size: 16)
        case .serif:
            return .system(size: 16, design: .serif)
        case .monospace:
            return .system(size: 16, design: .monospaced)
        case .rounded:
            return .system(size: 16, design: .rounded)
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

// 文本对齐
enum TextAlignment: String, CaseIterable {
    case leading = "左对齐"
    case center = "居中"
    case trailing = "右对齐"
    
    var alignment: HorizontalAlignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
    
    var textAlignment: SwiftUI.TextAlignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
    
    var displayName: String {
        return rawValue
    }
    
    var iconName: String {
        switch self {
        case .leading:
            return "text.alignleft"
        case .center:
            return "text.aligncenter"
        case .trailing:
            return "text.alignright"
        }
    }
}

// 应用配色方案
enum AppColorScheme: String, CaseIterable {
    case light = "浅色模式"
    case dark = "深色模式"
    case auto = "跟随系统"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .auto:
            return nil
        }
    }
    
    var displayName: String {
        return rawValue
    }
    
    var iconName: String {
        switch self {
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        case .auto:
            return "circle.lefthalf.filled"
        }
    }
}

// 主题色
enum AccentColor: String, CaseIterable {
    case blue = "蓝色"
    case green = "绿色"
    case orange = "橙色"
    case red = "红色"
    case purple = "紫色"
    case pink = "粉色"
    case teal = "青色"
    case indigo = "靛蓝"
    
    var color: Color {
        switch self {
        case .blue:
            return .blue
        case .green:
            return .green
        case .orange:
            return .orange
        case .red:
            return .red
        case .purple:
            return .purple
        case .pink:
            return .pink
        case .teal:
            return .teal
        case .indigo:
            return .indigo
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

// 释义语言偏好
enum DefinitionLanguage: String, CaseIterable {
    case chinese = "中文"
    case english = "英文"
    case both = "中英文"
    
    var displayName: String {
        return rawValue
    }
}

// 备份频率
enum BackupFrequency: String, CaseIterable {
    case daily = "每日"
    case weekly = "每周"
    case monthly = "每月"
    case manual = "手动"
    
    var displayName: String {
        return rawValue
    }
    
    var interval: TimeInterval? {
        switch self {
        case .daily:
            return 24 * 60 * 60
        case .weekly:
            return 7 * 24 * 60 * 60
        case .monthly:
            return 30 * 24 * 60 * 60
        case .manual:
            return nil
        }
    }
}

// 设置分组
enum SettingsSection: String, CaseIterable {
    case reading = "阅读设置"
    case appearance = "外观设置"
    case interaction = "交互设置"
    case learning = "学习设置"
    case notifications = "通知设置"
    case data = "数据设置"
    case advanced = "高级设置"
    case about = "关于应用"
    
    var icon: String {
        switch self {
        case .reading:
            return "book"
        case .appearance:
            return "paintbrush"
        case .interaction:
            return "hand.tap"
        case .learning:
            return "brain.head.profile"
        case .notifications:
            return "bell"
        case .data:
            return "externaldrive"
        case .advanced:
            return "gearshape.2"
        case .about:
            return "info.circle"
        }
    }
}

extension AppSettings {
    // 获取当前字体
    func getCurrentFont(size: CGFloat? = nil) -> Font {
        let fontSize = size ?? CGFloat(self.fontSize)
        
        switch fontFamily {
        case .system:
            return .system(size: fontSize)
        case .serif:
            return .system(size: fontSize, design: .serif)
        case .monospace:
            return .system(size: fontSize, design: .monospaced)
        case .rounded:
            return .system(size: fontSize, design: .rounded)
        }
    }
    
    // 获取行间距
    func getLineSpacing() -> CGFloat {
        return CGFloat(lineSpacing * fontSize)
    }
    
    // 获取段落间距
    func getParagraphSpacing() -> CGFloat {
        return CGFloat(paragraphSpacing)
    }
    
    // 检查是否启用触觉反馈
    func shouldProvideHapticFeedback() -> Bool {
        return hapticFeedback
    }
    
    // 检查是否启用音效
    func shouldPlaySoundEffects() -> Bool {
        return soundEffects
    }
    
    // 获取定义隐藏延迟
    func getDefinitionHideDelay() -> TimeInterval {
        return autoHideDefinition ? definitionHideDelay : 0
    }
}