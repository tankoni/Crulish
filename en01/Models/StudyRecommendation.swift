//
//  StudyRecommendation.swift
//  en01
//
//  Created by SOLO Coding on 2025/01/18.
//

import Foundation

/// 学习建议模型
struct StudyRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let priority: Priority
    let action: (() -> Void)?
    
    enum Priority {
        case high
        case medium
        case low
    }
    
    init(title: String, description: String, priority: Priority = .medium, action: (() -> Void)? = nil) {
        self.title = title
        self.description = description
        self.priority = priority
        self.action = action
    }
}