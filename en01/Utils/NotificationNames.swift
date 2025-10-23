//
//  NotificationNames.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation

// MARK: - 通知名称扩展
extension Notification.Name {
    // 学习进度相关通知
    static let learningProgressUpdated = Notification.Name("learningProgressUpdated")
    static let wordLearningProgressUpdated = Notification.Name("WordLearningProgressUpdated")
    
    // 统计数据相关通知
    static let statisticsDataUpdated = Notification.Name("StatisticsDataUpdated")
    
    // 测试相关通知
    static let selectProgressTab = Notification.Name("SelectProgressTab")
    static let startVocabularyTest = Notification.Name("StartVocabularyTest")
}