import Foundation
import SwiftData

// MARK: - 设置数据模型

/// 用户设置数据
@Model
class UserSettings {
    var id: UUID
    var userId: String
    var studyReminders: StudyReminders
    var displayPreferences: DisplayPreferences
    var learningPreferences: LearningPreferences
    var privacySettings: PrivacySettings
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String) {
        self.id = UUID()
        self.userId = userId
        self.studyReminders = StudyReminders()
        self.displayPreferences = DisplayPreferences()
        self.learningPreferences = LearningPreferences()
        self.privacySettings = PrivacySettings()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// 学习提醒设置
struct StudyReminders: Codable {
    var isEnabled: Bool
    var dailyReminderTime: Date
    var weeklyGoalReminder: Bool
    var achievementNotifications: Bool
    var customReminders: [CustomReminder]
    
    init(isEnabled: Bool = true, dailyReminderTime: Date = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date(), weeklyGoalReminder: Bool = true, achievementNotifications: Bool = true, customReminders: [CustomReminder] = []) {
        self.isEnabled = isEnabled
        self.dailyReminderTime = dailyReminderTime
        self.weeklyGoalReminder = weeklyGoalReminder
        self.achievementNotifications = achievementNotifications
        self.customReminders = customReminders
    }
}

/// 自定义提醒
struct CustomReminder: Codable, Identifiable {
    let id: UUID
    var title: String
    var time: Date
    var isEnabled: Bool
    var repeatDays: [WeekDay]
    
    init(title: String, time: Date, isEnabled: Bool = true, repeatDays: [WeekDay] = []) {
        self.id = UUID()
        self.title = title
        self.time = time
        self.isEnabled = isEnabled
        self.repeatDays = repeatDays
    }
}

/// 星期枚举
enum WeekDay: String, Codable, CaseIterable {
    case monday = "monday"
    case tuesday = "tuesday"
    case wednesday = "wednesday"
    case thursday = "thursday"
    case friday = "friday"
    case saturday = "saturday"
    case sunday = "sunday"
    
    var displayName: String {
        switch self {
        case .monday: return "周一"
        case .tuesday: return "周二"
        case .wednesday: return "周三"
        case .thursday: return "周四"
        case .friday: return "周五"
        case .saturday: return "周六"
        case .sunday: return "周日"
        }
    }
}

/// 显示偏好设置
struct DisplayPreferences: Codable {
    var theme: AppTheme
    var fontSize: FontSize
    var lineSpacing: LineSpacing
    var colorScheme: ColorScheme
    var animationsEnabled: Bool
    var hapticFeedback: Bool
    
    init(theme: AppTheme = .system, fontSize: FontSize = .medium, lineSpacing: LineSpacing = .normal, colorScheme: ColorScheme = .system, animationsEnabled: Bool = true, hapticFeedback: Bool = true) {
        self.theme = theme
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.colorScheme = colorScheme
        self.animationsEnabled = animationsEnabled
        self.hapticFeedback = hapticFeedback
    }
}

/// 应用主题
enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "跟随系统"
        }
    }
}

/// 字体大小
enum FontSize: String, Codable, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extra_large"
    
    var displayName: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        case .extraLarge: return "特大"
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        }
    }
}

/// 行间距
enum LineSpacing: String, Codable, CaseIterable {
    case compact = "compact"
    case normal = "normal"
    case relaxed = "relaxed"
    
    var displayName: String {
        switch self {
        case .compact: return "紧凑"
        case .normal: return "正常"
        case .relaxed: return "宽松"
        }
    }
    
    var value: CGFloat {
        switch self {
        case .compact: return 2
        case .normal: return 4
        case .relaxed: return 6
        }
    }
}

/// 颜色方案
enum ColorScheme: String, Codable, CaseIterable {
    case system = "system"
    case blue = "blue"
    case green = "green"
    case purple = "purple"
    case orange = "orange"
    
    var displayName: String {
        switch self {
        case .system: return "系统默认"
        case .blue: return "蓝色"
        case .green: return "绿色"
        case .purple: return "紫色"
        case .orange: return "橙色"
        }
    }
}

/// 学习偏好设置
struct LearningPreferences: Codable {
    var difficultyLevel: DifficultyLevel
    var autoPlayAudio: Bool
    var showTranslations: Bool
    var highlightNewWords: Bool
    var adaptiveLearning: Bool
    var studyMode: StudyMode
    var reviewInterval: ReviewInterval
    
    init(difficultyLevel: DifficultyLevel = .intermediate, autoPlayAudio: Bool = false, showTranslations: Bool = true, highlightNewWords: Bool = true, adaptiveLearning: Bool = true, studyMode: StudyMode = .balanced, reviewInterval: ReviewInterval = .smart) {
        self.difficultyLevel = difficultyLevel
        self.autoPlayAudio = autoPlayAudio
        self.showTranslations = showTranslations
        self.highlightNewWords = highlightNewWords
        self.adaptiveLearning = adaptiveLearning
        self.studyMode = studyMode
        self.reviewInterval = reviewInterval
    }
}

// DifficultyLevel 已在 CommonTypes.swift 中定义

/// 学习模式
enum StudyMode: String, Codable, CaseIterable {
    case reading = "reading"
    case vocabulary = "vocabulary"
    case balanced = "balanced"
    case intensive = "intensive"
    
    var displayName: String {
        switch self {
        case .reading: return "阅读优先"
        case .vocabulary: return "词汇优先"
        case .balanced: return "平衡模式"
        case .intensive: return "强化模式"
        }
    }
}

/// 复习间隔
enum ReviewInterval: String, Codable, CaseIterable {
    case daily = "daily"
    case smart = "smart"
    case weekly = "weekly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .daily: return "每日复习"
        case .smart: return "智能间隔"
        case .weekly: return "每周复习"
        case .custom: return "自定义"
        }
    }
}

/// 隐私设置
struct PrivacySettings: Codable {
    var dataCollection: Bool
    var analyticsEnabled: Bool
    var crashReporting: Bool
    var personalizedAds: Bool
    var shareUsageData: Bool
    
    init(dataCollection: Bool = true, analyticsEnabled: Bool = true, crashReporting: Bool = true, personalizedAds: Bool = false, shareUsageData: Bool = false) {
        self.dataCollection = dataCollection
        self.analyticsEnabled = analyticsEnabled
        self.crashReporting = crashReporting
        self.personalizedAds = personalizedAds
        self.shareUsageData = shareUsageData
    }
}

/// 通知设置
@Model
class NotificationSettings {
    var id: UUID
    var userId: String
    var pushNotifications: Bool
    var emailNotifications: Bool
    var studyReminders: Bool
    var achievementAlerts: Bool
    var weeklyReports: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String, pushNotifications: Bool = true, emailNotifications: Bool = false, studyReminders: Bool = true, achievementAlerts: Bool = true, weeklyReports: Bool = true) {
        self.id = UUID()
        self.userId = userId
        self.pushNotifications = pushNotifications
        self.emailNotifications = emailNotifications
        self.studyReminders = studyReminders
        self.achievementAlerts = achievementAlerts
        self.weeklyReports = weeklyReports
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}