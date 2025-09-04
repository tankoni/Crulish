//
//  DetailedStatCard.swift
//  en01
//
//  Created by AI Assistant on 2024/12/30.
//

import SwiftUI

/// 详细统计卡片组件
struct DetailedStatCard: View {
    let title: String
    let stats: [(String, String)] // (标题, 值)
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            
            VStack(spacing: 8) {
                ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                    HStack {
                        Text(stat.0)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(stat.1)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    if index < stats.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    DetailedStatCard(
        title: "本周统计",
        stats: [
            ("阅读时长", "5h 30m"),
            ("文章数量", "12"),
            ("新词学习", "45"),
            ("复习次数", "23")
        ],
        color: .blue
    )
    .padding()
}