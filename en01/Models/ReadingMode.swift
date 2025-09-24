//
//  ReadingMode.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import Foundation

/// 阅读模式枚举
enum ReadingMode: String, CaseIterable, Identifiable {
    case yearlyExams = "yearly_exams"
    case soloArticles = "solo_articles"
    
    var id: String { rawValue }
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .yearlyExams:
            return "年份试卷"
        case .soloArticles:
            return "单篇文章"
        }
    }
    
    /// 图标名称
    var iconName: String {
        switch self {
        case .yearlyExams:
            return "calendar"
        case .soloArticles:
            return "doc.text"
        }
    }
    
    /// 描述文本
    var description: String {
        switch self {
        case .yearlyExams:
            return "按年份组织的考研真题"
        case .soloArticles:
            return "独立的单篇文章练习"
        }
    }
}