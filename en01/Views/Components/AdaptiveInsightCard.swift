//
//  AdaptiveInsightCard.swift
//  en01
//
//  Created by AI Assistant on 2024/12/30.
//

import SwiftUI

/// 自适应学习洞察卡片组件
struct AdaptiveInsightCard: View {
    let insights: LearningInsights
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                        .font(.title2)
                    
                    Text("学习洞察")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Button(action: onToggleExpansion) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            // 核心指标
            HStack(spacing: 12) {
                InsightMetric(
                    title: "学习模式",
                    value: insights.learningPattern.displayName,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
                
                InsightMetric(
                    title: "推荐置信度",
                    value: "\(Int(insights.recommendationConfidence * 100))%",
                    icon: "target",
                    color: .green
                )
                
                InsightMetric(
                    title: "适应性评分",
                    value: String(format: "%.1f", insights.adaptabilityScore),
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange
                )
            }
            
            if isExpanded {
                expandedContent
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 展开内容
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            
            // 学习趋势
            VStack(alignment: .leading, spacing: 8) {
                Text("学习趋势")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    TrendIndicator(
                        title: "词汇掌握",
                        trend: insights.vocabularyTrend,
                        value: "\(insights.vocabularyMasteryRate)%"
                    )
                    
                    TrendIndicator(
                        title: "阅读速度",
                        trend: insights.readingSpeedTrend,
                        value: "\(insights.averageReadingSpeed) wpm"
                    )
                    
                    TrendIndicator(
                        title: "理解准确率",
                        trend: insights.comprehensionTrend,
                        value: "\(insights.comprehensionAccuracy)%"
                    )
                }
            }
            
            // 推荐理由
            if !insights.recommendationReasons.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("推荐理由")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(insights.recommendationReasons.prefix(3), id: \.self) { reason in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 6)
                                
                                Text(reason)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            
            // 学习建议
            if !insights.learningRecommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("学习建议")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(insights.learningRecommendations.prefix(2), id: \.self) { recommendation in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                    .padding(.top, 2)
                                
                                Text(recommendation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 洞察指标组件
struct InsightMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 趋势指示器组件
struct TrendIndicator: View {
    let title: String
    let trend: LearningTrend
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: trend.iconName)
                    .foregroundColor(trend.color)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

// MARK: - 学习趋势扩展
extension LearningTrend {
    var iconName: String {
        switch self {
        case .improving:
            return "arrow.up.right"
        case .stable:
            return "arrow.right"
        case .declining:
            return "arrow.down.right"
        }
    }
    
    var color: Color {
        switch self {
        case .improving:
            return .green
        case .stable:
            return .blue
        case .declining:
            return .red
        }
    }
}

// MARK: - 学习模式扩展
extension LearningPattern {
    var displayName: String {
        switch self {
        case .intensive:
            return "集中型"
        case .gradual:
            return "渐进型"
        case .mixed:
            return "混合型"
        case .exploratory:
            return "探索型"
        
            case .balanced:
                return "均衡型"
}
    }
}

#Preview {
    AdaptiveInsightCard(
        insights: LearningInsights(
            learningPattern: LearningPattern.intensive,
            recommendationConfidence: 0.85,
            adaptabilityScore: 7.2,
            vocabularyTrend: LearningTrend.improving,
            readingSpeedTrend: LearningTrend.stable,
            comprehensionTrend: LearningTrend.improving,
            vocabularyMasteryRate: 78,
            averageReadingSpeed: 180,
            comprehensionAccuracy: 85,
            recommendationReasons: [
                "基于您的词汇掌握情况，推荐中等难度文章",
                "您在科技类文章上表现较好，建议继续此类阅读",
                "当前学习节奏适中，可适当增加挑战性"
            ],
            learningRecommendations: [
                "建议每天阅读2-3篇文章保持学习节奏",
                "可以尝试更多商务英语类文章拓展词汇"
            ]
        ),
        isExpanded: true,
        onToggleExpansion: {}
    )
    .padding()
}