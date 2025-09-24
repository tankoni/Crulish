//
//  ArticleRanking.swift
//  en01
//
//  Created by SOLO Coding on 2025/1/18.
//

import Foundation
import SwiftData
import SwiftUI

// 文章智能排序模型
@Model
final class ArticleRanking: @unchecked Sendable {
    var id: UUID
    var userId: String // 用户ID（用于多用户支持）
    var articleID: String // 文章ID
    var articleTitle: String // 文章标题
    var rankingScore: Double // 综合排序分数（0-100）
    var vocabularyMatchScore: Double // 词汇匹配分数（0-100）
    var difficultyScore: Double // 难度适配分数（0-100）
    var priorityScore: Double // 优先级分数（0-100）
    var lastUpdated: Date // 最后更新时间
    var isRecommended: Bool // 是否推荐
    
    // 词汇分析结果
    var totalWords: Int // 文章总词数
    var unknownWords: Int // 未知单词数
    var familiarWords: Int // 熟悉单词数
    var masteredWords: Int // 已掌握单词数
    var newWords: Int // 新单词数（用户从未见过的）
    
    // 难度评估
    var estimatedDifficulty: ArticleDifficulty // 估算难度
    var readingTime: TimeInterval // 预估阅读时间（分钟）
    var vocabularyLevel: VocabularyLevel // 词汇水平要求
    
    // 学习价值评估
    var learningValue: Double // 学习价值（0-100）
    var vocabularyGrowth: Double // 词汇增长潜力（0-100）
    var reviewValue: Double // 复习价值（0-100）
    
    // 排序权重配置
    var vocabularyWeight: Double // 词汇匹配权重
    var difficultyWeight: Double // 难度权重
    var priorityWeight: Double // 优先级权重
    
    // 用户偏好匹配
    var topicMatch: Double // 主题匹配度（0-100）
    var yearPreference: Double // 年份偏好匹配度（0-100）
    var lengthPreference: Double // 长度偏好匹配度（0-100）
    
    init(userId: String, articleID: String, articleTitle: String) {
        self.id = UUID()
        self.userId = userId
        self.articleID = articleID
        self.articleTitle = articleTitle
        self.rankingScore = 0.0
        self.vocabularyMatchScore = 0.0
        self.difficultyScore = 0.0
        self.priorityScore = 0.0
        self.lastUpdated = Date()
        self.isRecommended = false
        
        // 初始化词汇分析结果
        self.totalWords = 0
        self.unknownWords = 0
        self.familiarWords = 0
        self.masteredWords = 0
        self.newWords = 0
        
        // 初始化难度评估
        self.estimatedDifficulty = .medium
        self.readingTime = 0
        self.vocabularyLevel = .intermediate
        
        // 初始化学习价值评估
        self.learningValue = 0.0
        self.vocabularyGrowth = 0.0
        self.reviewValue = 0.0
        
        // 初始化排序权重配置
        self.vocabularyWeight = 0.4
        self.difficultyWeight = 0.3
        self.priorityWeight = 0.3
        
        // 初始化用户偏好匹配
        self.topicMatch = 0.0
        self.yearPreference = 0.0
        self.lengthPreference = 0.0
    }
}

// 词汇水平枚举
enum VocabularyLevel: String, CaseIterable, Codable {
    case beginner = "初级"
    case intermediate = "中级"
    case advanced = "高级"
    case expert = "专家"
    
    var level: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .expert: return 4
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .red
        }
    }
    
    var requiredVocabulary: Int {
        switch self {
        case .beginner: return 2000
        case .intermediate: return 4000
        case .advanced: return 6000
        case .expert: return 8000
        }
    }
}

// 排序策略枚举
enum RankingStrategy: String, CaseIterable {
    case vocabulary = "词汇优先"
    case difficulty = "难度优先"
    case balanced = "平衡排序"
    case learning = "学习优先"
    case review = "复习优先"
    
    var displayName: String {
        return self.rawValue
    }
    
    var weights: (vocabulary: Double, difficulty: Double, priority: Double) {
        switch self {
        case .vocabulary: return (0.6, 0.2, 0.2)
        case .difficulty: return (0.2, 0.6, 0.2)
        case .balanced: return (0.33, 0.33, 0.34)
        case .learning: return (0.5, 0.3, 0.2)
        case .review: return (0.3, 0.2, 0.5)
        }
    }
}

extension ArticleRanking {
    // 计算综合排序分数
    func calculateRankingScore(strategy: RankingStrategy = .balanced) {
        let weights = strategy.weights
        
        self.vocabularyWeight = weights.vocabulary
        self.difficultyWeight = weights.difficulty
        self.priorityWeight = weights.priority
        
        self.rankingScore = (vocabularyMatchScore * vocabularyWeight +
                           difficultyScore * difficultyWeight +
                           priorityScore * priorityWeight)
        
        self.lastUpdated = Date()
    }
    
    // 计算词汇匹配分数
    func calculateVocabularyMatchScore() {
        guard totalWords > 0 else {
            self.vocabularyMatchScore = 0
            return
        }
        
        let unknownRatio = Double(unknownWords) / Double(totalWords)
        let familiarRatio = Double(familiarWords) / Double(totalWords)
        let newWordRatio = Double(newWords) / Double(totalWords)
        
        // 理想的未知单词比例是10-20%
        let idealUnknownRatio = 0.15
        let unknownScore = max(0, 100 - abs(unknownRatio - idealUnknownRatio) * 500)
        
        // 熟悉单词比例越高越好（但不要太高）
        let familiarScore = min(100, familiarRatio * 120)
        
        // 新单词比例适中最好（5-15%）
        let idealNewWordRatio = 0.10
        let newWordScore = max(0, 100 - abs(newWordRatio - idealNewWordRatio) * 1000)
        
        self.vocabularyMatchScore = (unknownScore * 0.4 + familiarScore * 0.4 + newWordScore * 0.2)
    }
    
    // 计算难度适配分数
    func calculateDifficultyScore(userLevel: VocabularyLevel) {
        // 将ArticleDifficulty转换为数值进行比较
        let difficultyValue: Double
        switch estimatedDifficulty {
        case .easy: difficultyValue = 1.0
        case .medium: difficultyValue = 2.0
        case .hard: difficultyValue = 3.0
        }
        
        let levelDifference = abs(difficultyValue - Double(userLevel.level))
        
        // 难度差距越小，分数越高
        switch levelDifference {
        case 0:
            self.difficultyScore = 100 // 完全匹配
        case 1:
            self.difficultyScore = 80  // 稍有差距
        case 2:
            self.difficultyScore = 50  // 中等差距
        default:
            self.difficultyScore = 20  // 差距较大
        }
        
        // 考虑阅读时间因素
        let timeScore = calculateTimeScore()
        self.difficultyScore = (difficultyScore * 0.7 + timeScore * 0.3)
    }
    
    // 计算时间适配分数
    private func calculateTimeScore() -> Double {
        let minutes = readingTime / 60
        
        // 理想阅读时间是10-30分钟
        if minutes >= 10 && minutes <= 30 {
            return 100
        } else if minutes >= 5 && minutes <= 45 {
            return 80
        } else if minutes >= 2 && minutes <= 60 {
            return 60
        } else {
            return 30
        }
    }
    
    // 计算优先级分数
    func calculatePriorityScore() {
        // 基于学习价值、词汇增长和复习价值计算
        self.priorityScore = (learningValue * 0.4 + vocabularyGrowth * 0.4 + reviewValue * 0.2)
    }
    
    // 计算学习价值
    func calculateLearningValue() {
        guard totalWords > 0 else {
            self.learningValue = 0
            return
        }
        
        let unknownRatio = Double(unknownWords) / Double(totalWords)
        let newWordRatio = Double(newWords) / Double(totalWords)
        
        // 未知单词和新单词比例适中时学习价值最高
        let unknownValue = min(100, unknownRatio * 500) // 最多20%未知单词
        let newWordValue = min(100, newWordRatio * 1000) // 最多10%新单词
        
        self.learningValue = (unknownValue + newWordValue) / 2
    }
    
    // 计算词汇增长潜力
    func calculateVocabularyGrowth() {
        guard totalWords > 0 else {
            self.vocabularyGrowth = 0
            return
        }
        
        // 新单词数量和质量决定增长潜力
        let newWordRatio = Double(newWords) / Double(totalWords)
        let growthPotential = min(100, newWordRatio * 800) // 最多12.5%新单词获得满分
        
        self.vocabularyGrowth = growthPotential
    }
    
    // 计算复习价值
    func calculateReviewValue() {
        guard totalWords > 0 else {
            self.reviewValue = 0
            return
        }
        
        let familiarRatio = Double(familiarWords) / Double(totalWords)
        
        // 熟悉单词比例高时复习价值高
        self.reviewValue = min(100, familiarRatio * 120)
    }
    
    // 更新推荐状态
    func updateRecommendationStatus(threshold: Double = 70.0) {
        self.isRecommended = rankingScore >= threshold
    }
    
    // 获取未知单词比例
    var unknownWordsPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(unknownWords) / Double(totalWords) * 100
    }
    
    // 获取新单词比例
    var newWordsPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(newWords) / Double(totalWords) * 100
    }
    
    // 获取掌握单词比例
    var masteredWordsPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWords) * 100
    }
    
    // 格式化排序分数
    var formattedRankingScore: String {
        return String(format: "%.1f", rankingScore)
    }
    
    // 格式化阅读时间
    var formattedReadingTime: String {
        let minutes = Int(readingTime / 60)
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)小时\(remainingMinutes)分钟"
        }
    }
    
    // 获取推荐理由
    var recommendationReason: String {
        var reasons: [String] = []
        
        if vocabularyMatchScore >= 80 {
            reasons.append("词汇匹配度高")
        }
        
        if difficultyScore >= 80 {
            reasons.append("难度适中")
        }
        
        if learningValue >= 70 {
            reasons.append("学习价值高")
        }
        
        if vocabularyGrowth >= 70 {
            reasons.append("词汇增长潜力大")
        }
        
        if reviewValue >= 70 {
            reasons.append("复习价值高")
        }
        
        return reasons.isEmpty ? "综合评分较高" : reasons.joined(separator: "、")
    }
    
    // 获取排序等级
    var rankingGrade: String {
        switch rankingScore {
        case 90...100: return "S"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        default: return "D"
        }
    }
    
    // 获取排序等级颜色
    var rankingGradeColor: Color {
        switch rankingGrade {
        case "S": return .purple
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        default: return .red
        }
    }
}