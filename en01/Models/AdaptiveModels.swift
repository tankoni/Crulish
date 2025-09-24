//
//  AdaptiveModels.swift
//  en01
//
//  Created by AI Assistant on 2024/12/30.
//

import Foundation

/// 自适应权重配置
struct AdaptiveWeights: Codable, Equatable {
    var vocabularyMatch: Double
    var difficultyAdaptation: Double
    var learningHistory: Double
    var progressOptimization: Double
    
    init(
        vocabularyMatch: Double = 0.7,
        difficultyAdaptation: Double = 0.8,
        learningHistory: Double = 0.6,
        progressOptimization: Double = 0.9
    ) {
        self.vocabularyMatch = vocabularyMatch
        self.difficultyAdaptation = difficultyAdaptation
        self.learningHistory = learningHistory
        self.progressOptimization = progressOptimization
    }
    
    /// 默认权重配置
    static let `default` = AdaptiveWeights()
}

/// 自适应推荐模式
enum AdaptiveMode: String, CaseIterable, Codable {
    case balanced = "balanced"
    case vocabularyFocused = "vocabulary_focused"
    case difficultyProgressive = "difficulty_progressive"
    case interestBased = "interest_based"
    
    var localizedName: String {
        switch self {
        case .balanced:
            return "平衡模式"
        case .vocabularyFocused:
            return "词汇导向"
        case .difficultyProgressive:
            return "难度递进"
        case .interestBased:
            return "兴趣导向"
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .balanced:
            return "综合考虑词汇、难度、兴趣等因素，提供均衡的推荐"
        case .vocabularyFocused:
            return "重点关注词汇学习效果，推荐生词数量适中的文章"
        case .difficultyProgressive:
            return "根据学习进度逐步提升难度，确保循序渐进"
        case .interestBased:
            return "基于阅读历史和偏好，推荐您感兴趣的主题内容"
        }
    }
}