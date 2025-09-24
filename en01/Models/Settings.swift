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
    
    // AI翻译设置
    @Published var selectedAIModel: AIModel = .gemini25flash // 优先使用Gemini
    @Published var enableAITranslation: Bool = true
    @Published var translationMode: TranslationMode = .word
    
    // Gemini API密钥（当前可用）
    @Published var geminiAPIKey: String = "AIzaSyCuGzUTUY_s_lB4NmKULmDqD2Z_gWsSN8w"
    @Published var geminiBackupAPIKey: String = "AIzaSyDPnQ0nL6aqJ6mVHTa-BZGbPy2Gd_JqHo0"
    
    // OpenAI API密钥（待用户配置）
    @Published var openaiAPIKey: String = ""
    
    // Claude API密钥（待用户配置）
    @Published var claudeAPIKey: String = ""
    
    // DeepSeek API密钥（待用户配置）
    @Published var deepseekAPIKey: String = ""
    
    // Qwen API密钥（待用户配置）
    @Published var qwenAPIKey: String = ""
    
    // 豆包 API密钥（待用户配置）
    @Published var doubaoAPIKey: String = ""
    
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
        
        // 保存AI翻译设置
        userDefaults.set(selectedAIModel.rawValue, forKey: "selectedAIModel")
        userDefaults.set(enableAITranslation, forKey: "enableAITranslation")
        userDefaults.set(translationMode.rawValue, forKey: "translationMode")
        
        // 保存所有AI服务商API密钥
        userDefaults.set(geminiAPIKey, forKey: "geminiAPIKey")
        userDefaults.set(geminiBackupAPIKey, forKey: "geminiBackupAPIKey")
        userDefaults.set(openaiAPIKey, forKey: "openaiAPIKey")
        userDefaults.set(claudeAPIKey, forKey: "claudeAPIKey")
        userDefaults.set(deepseekAPIKey, forKey: "deepseekAPIKey")
        userDefaults.set(qwenAPIKey, forKey: "qwenAPIKey")
        userDefaults.set(doubaoAPIKey, forKey: "doubaoAPIKey")
        
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
        
        // 加载AI翻译设置
        selectedAIModel = AIModel(rawValue: userDefaults.string(forKey: "selectedAIModel") ?? "") ?? .gemini25flash
        enableAITranslation = userDefaults.object(forKey: "enableAITranslation") as? Bool ?? true
        translationMode = TranslationMode(rawValue: userDefaults.string(forKey: "translationMode") ?? "") ?? .word
        
        // 加载所有AI服务商API密钥
        // 对于Gemini API密钥，如果UserDefaults中没有值或为空，则保持使用默认值
        if let savedGeminiKey = userDefaults.string(forKey: "geminiAPIKey"), !savedGeminiKey.isEmpty {
            geminiAPIKey = savedGeminiKey
        }
        if let savedGeminiBackupKey = userDefaults.string(forKey: "geminiBackupAPIKey"), !savedGeminiBackupKey.isEmpty {
            geminiBackupAPIKey = savedGeminiBackupKey
        }
        
        // 其他API密钥保持原有逻辑（默认为空，等待用户配置）
        openaiAPIKey = userDefaults.string(forKey: "openaiAPIKey") ?? ""
        claudeAPIKey = userDefaults.string(forKey: "claudeAPIKey") ?? ""
        deepseekAPIKey = userDefaults.string(forKey: "deepseekAPIKey") ?? ""
        qwenAPIKey = userDefaults.string(forKey: "qwenAPIKey") ?? ""
        doubaoAPIKey = userDefaults.string(forKey: "doubaoAPIKey") ?? ""
        
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
        
        // 重置AI翻译设置
        selectedAIModel = .gpt35turbo
        enableAITranslation = true
        translationMode = .word
        
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

// TextAlignment 转换扩展
extension TextAlignment {
    /// 转换为 SwiftUI HorizontalAlignment
    var alignment: HorizontalAlignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        case .justified:
            return .leading // justified 在 SwiftUI 中使用 leading
        }
    }
    
    /// 转换为 SwiftUI TextAlignment
    var textAlignment: SwiftUI.TextAlignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        case .justified:
            return .leading // justified 在 SwiftUI 中使用 leading
        }
    }
    
    /// 获取对应的 SF Symbols 图标名称
    public var iconName: String {
        switch self {
        case .leading:
            return "text.alignleft"
        case .center:
            return "text.aligncenter"
        case .trailing:
            return "text.alignright"
        case .justified:
            return "text.justify"
        }
    }
    
    /// 获取适用于设置界面的选项（排除 justified）
    static var settingsOptions: [TextAlignment] {
        return [.leading, .center, .trailing]
    }
}

// 应用配色方案
enum AppColorScheme: String, CaseIterable {
    case light = "浅色模式"
    case dark = "深色模式"
    case auto = "跟随系统"
    
    var colorScheme: SwiftUI.ColorScheme? {
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

// AI模型选择
public enum AIModel: String, CaseIterable {
    case gpt35turbo = "GPT-3.5 Turbo"
    case gpt4 = "GPT-4"
    case gpt4turbo = "GPT-4 Turbo"
    case gpt4o = "GPT-4o"
    case gpt4omini = "GPT-4o Mini"
    case claude3haiku = "Claude 3 Haiku"
    case claude3sonnet = "Claude 3 Sonnet"
    case claude3opus = "Claude 3 Opus"
    case claude35sonnet = "Claude 3.5 Sonnet"
    // Gemini 2.5 系列（最新）
    case gemini25pro = "Gemini 2.5 Pro"
    case gemini25flash = "Gemini 2.5 Flash"
    // Gemini 2.0 系列
    case gemini20flash = "Gemini 2.0 Flash"
    case gemini20flashSpark = "Gemini 2.0 Flash Spark"
    // Gemini 1.5 系列（稳定版）
    case gemini15pro = "Gemini 1.5 Pro"
    case gemini15flash = "Gemini 1.5 Flash"
    case deepseekV3 = "DeepSeek V3"
    case qwenMax = "Qwen Max"
    case doubaoLite = "豆包 Lite"
    case doubaoPro = "豆包 Pro"
    
    public var displayName: String {
        return rawValue
    }
    
    public var description: String {
        switch self {
        case .gpt35turbo:
            return "快速响应，适合日常翻译"
        case .gpt4:
            return "高质量翻译，理解能力强"
        case .gpt4turbo:
            return "最新模型，速度与质量兼备"
        case .gpt4o:
            return "多模态模型，支持图文理解"
        case .gpt4omini:
            return "轻量版GPT-4o，快速高效"
        case .claude3haiku:
            return "轻量快速，适合简单翻译"
        case .claude3sonnet:
            return "平衡性能，适合大多数场景"
        case .claude3opus:
            return "最高质量，适合复杂文本"
        case .claude35sonnet:
            return "最新Claude模型，性能卓越"
        case .gemini25pro:
            return "最新Gemini 2.5 Pro，性能卓越"
        case .gemini25flash:
            return "最新Gemini 2.5 Flash，快速高效"
        case .gemini20flash:
            return "Gemini 2.0 Flash，平衡性能"
        case .gemini20flashSpark:
            return "Gemini 2.0 Flash Spark，轻量快速"
        case .gemini15pro:
            return "Gemini 1.5 Pro，长文本处理"
        case .gemini15flash:
            return "Gemini 1.5 Flash，成本效益高"
        case .deepseekV3:
            return "国产开源模型，性价比高"
        case .qwenMax:
            return "阿里通义千问，中文优化"
        case .doubaoLite:
            return "字节豆包轻量版，快速翻译"
        case .doubaoPro:
            return "字节豆包专业版，高质量翻译"
        }
    }
    
    var iconName: String {
        switch self {
        case .gpt35turbo, .gpt4, .gpt4turbo, .gpt4o, .gpt4omini:
            return "brain.head.profile"
        case .claude3haiku, .claude3sonnet, .claude3opus, .claude35sonnet:
            return "sparkles"
        case .gemini25pro, .gemini25flash, .gemini20flash, .gemini20flashSpark, .gemini15pro, .gemini15flash:
            return "star.circle"
        case .deepseekV3:
            return "cpu"
        case .qwenMax:
            return "globe.asia.australia"
        case .doubaoLite, .doubaoPro:
            return "wand.and.rays"
        }
    }
    
    public var provider: TranslationProvider {
        switch self {
        case .gpt35turbo:
            return .gpt35turbo
        case .gpt4:
            return .gpt4
        case .gpt4turbo:
            return .gpt4turbo
        case .gpt4o:
            return .gpt4o
        case .gpt4omini:
            return .gpt4omini
        case .claude3haiku:
            return .claude3haiku
        case .claude3sonnet:
            return .claude3sonnet
        case .claude3opus:
            return .claude3opus
        case .claude35sonnet:
            return .claude35sonnet
        case .gemini25pro:
            return .gemini25pro
        case .gemini25flash:
            return .gemini25flash
        case .gemini20flash:
            return .gemini20flash
        case .gemini20flashSpark:
            return .gemini20flashSpark
        case .gemini15pro:
            return .gemini15pro
        case .gemini15flash:
            return .gemini15flash
        case .deepseekV3:
            return .deepseekV3
        case .qwenMax:
            return .qwenMax
        case .doubaoLite:
            return .doubaoLite
        case .doubaoPro:
            return .doubaoPro
        }
    }
    
    public var modelIdentifier: String {
        switch self {
        case .gpt35turbo:
            return "gpt-3.5-turbo"
        case .gpt4:
            return "gpt-4"
        case .gpt4turbo:
            return "gpt-4-turbo"
        case .gpt4o:
            return "gpt-4o"
        case .gpt4omini:
            return "gpt-4o-mini"
        case .claude3haiku:
            return "claude-3-haiku-20240307"
        case .claude3sonnet:
            return "claude-3-sonnet-20240229"
        case .claude3opus:
            return "claude-3-opus-20240229"
        case .claude35sonnet:
            return "claude-3-5-sonnet-20241022"
        case .gemini25pro:
            return "gemini-2.5-pro-001"
        case .gemini25flash:
            return "gemini-2.5-flash-001"
        case .gemini20flash:
            return "gemini-2.0-flash-001"
        case .gemini20flashSpark:
            return "gemini-2.0-flash-spark-001"
        case .gemini15pro:
            return "gemini-1.5-pro-001"
        case .gemini15flash:
            return "gemini-1.5-flash-001"
        case .deepseekV3:
            return "deepseek-chat"
        case .qwenMax:
            return "qwen-max"
        case .doubaoLite:
            return "doubao-lite-4k"
        case .doubaoPro:
            return "doubao-pro-4k"
        }
    }
}

// 翻译模式
enum TranslationMode: String, CaseIterable {
    case word = "word"
    case sentence = "sentence"
    
    var displayName: String {
        switch self {
        case .word:
            return "词"
        case .sentence:
            return "句"
        }
    }
    
    var iconName: String {
        switch self {
        case .word:
            return "textformat"
        case .sentence:
            return "text.alignleft"
        }
    }
    
    var description: String {
        switch self {
        case .word:
            return "翻译选中的单词"
        case .sentence:
            return "翻译选中的句段，包含上下文分析"
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