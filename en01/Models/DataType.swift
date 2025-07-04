//
//  DataType.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation

// MARK: - Data Type Enum

enum DataType: String, CaseIterable {
    case vocabulary = "vocabulary"
    case progress = "progress"
    case articles = "articles"
    case settings = "settings"
    
    var displayName: String {
        switch self {
        case .vocabulary:
            return "词汇数据"
        case .progress:
            return "学习进度"
        case .articles:
            return "文章数据"
        case .settings:
            return "设置数据"
        }
    }
    
    var description: String {
        switch self {
        case .vocabulary:
            return "已学习的单词和释义"
        case .progress:
            return "阅读进度和统计信息"
        case .articles:
            return "收藏的文章和笔记"
        case .settings:
            return "应用设置和偏好"
        }
    }
}