//
//  WordInteractionProtocol.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation
import SwiftUI

// MARK: - 单词交互协议

/// 定义单词交互的标准接口
protocol WordInteractionProtocol {
    /// 处理单词点击事件
    /// - Parameters:
    ///   - word: 被点击的单词
    ///   - position: 点击位置
    ///   - context: 单词所在的上下文
    ///   - articleId: 文章ID（可选）
    func handleWordTap(_ word: String, at position: CGPoint, context: String?, articleId: UUID?)
    
    /// 处理单词长按事件
    /// - Parameters:
    ///   - word: 被长按的单词
    ///   - position: 长按位置
    ///   - context: 单词所在的上下文
    ///   - articleId: 文章ID（可选）
    func handleWordLongPress(_ word: String, at position: CGPoint, context: String?, articleId: UUID?)
    
    /// 设置单词掌握程度
    /// - Parameters:
    ///   - word: 单词
    ///   - mastery: 掌握程度
    ///   - context: 上下文
    ///   - articleId: 文章ID（可选）
    func setWordMastery(_ word: String, mastery: MasteryLevel, context: String?, articleId: UUID?)
    
    /// 显示单词详细定义
    /// - Parameter word: 要显示定义的单词
    func showDetailedDefinition(for word: String)
    
    /// 隐藏当前显示的提示
    func hideTooltip()
}

// MARK: - 学习行为跟踪协议

/// 定义学习行为跟踪的标准接口
protocol LearningTrackingProtocol {
    /// 记录单词点击行为
    /// - Parameters:
    ///   - word: 被点击的单词
    ///   - context: 上下文
    ///   - articleId: 文章ID
    ///   - position: 点击位置
    func trackWordClick(_ word: String, context: String, articleId: UUID, position: Int) async
    
    /// 记录单词查看行为
    /// - Parameters:
    ///   - word: 被查看的单词
    ///   - viewDuration: 查看时长
    ///   - articleId: 文章ID
    func trackWordView(_ word: String, viewDuration: TimeInterval, articleId: UUID) async
    
    /// 记录掌握程度设置
    /// - Parameters:
    ///   - word: 单词
    ///   - mastery: 掌握程度
    ///   - previousMastery: 之前的掌握程度
    ///   - articleId: 文章ID
    func trackMasteryChange(_ word: String, mastery: MasteryLevel, previousMastery: MasteryLevel?, articleId: UUID) async
    
    /// 记录阅读行为
    /// - Parameters:
    ///   - articleId: 文章ID
    ///   - readingTime: 阅读时间
    ///   - wordsEncountered: 遇到的单词数
    func trackReadingSession(articleId: UUID, readingTime: TimeInterval, wordsEncountered: Int) async
}

// MARK: - 单词交互状态

/// 单词交互状态
struct WordInteractionState {
    let selectedWord: String
    let selectedWordPosition: CGPoint
    let showTooltip: Bool
    let isLoading: Bool
    let simplePhonetic: String?
    let simpleDefinition: String
    let currentTranslationMode: TranslationMode
}

// MARK: - 交互模式枚举

/// 交互模式
enum InteractionMode {
    case text    // 文本模式
    case pdf     // PDF模式
    case hybrid  // 混合模式
}

// MARK: - 翻译模式枚举

/// 翻译模式
/// 注释：此枚举已在Settings.swift中定义，此处删除重复定义

/// 掌握程度
/// 注释：此枚举已在Word.swift中定义，此处删除重复定义

// MARK: - 单词交互事件

/// 单词交互事件类型
enum WordInteractionEvent {
    case tap(word: String, position: CGPoint, context: String?)
    case longPress(word: String, position: CGPoint, context: String?)
    case masterySet(word: String, mastery: MasteryLevel, context: String?)
    case definitionViewed(word: String, duration: TimeInterval)
    case tooltipDismissed(word: String, viewDuration: TimeInterval)
}

// MARK: - 单词交互配置

/// 单词交互配置
struct WordInteractionConfig {
    let enableTooltip: Bool
    let tooltipDelay: TimeInterval
    let autoHideTooltip: Bool
    let autoHideDelay: TimeInterval
    let enableHapticFeedback: Bool
    let trackingEnabled: Bool
    
    static let `default` = WordInteractionConfig(
        enableTooltip: true,
        tooltipDelay: 0.1,
        autoHideTooltip: true,
        autoHideDelay: 3.0,
        enableHapticFeedback: true,
        trackingEnabled: true
    )
}