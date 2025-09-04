//
//  MasteryProgressBar.swift
//  en01
//
//  Created by AI Assistant on 2024/12/30.
//

import SwiftUI

/// 掌握程度进度条组件
struct MasteryProgressBar: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        // 进度
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(
                                width: geometry.size.width * percentage,
                                height: 8
                            )
                            .animation(.easeInOut(duration: 0.8), value: percentage)
                    }
                }
                .frame(height: 8)
                
                // 百分比
                Text("\(Int(percentage * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        MasteryProgressBar(
            title: "已掌握",
            count: 150,
            total: 500,
            color: .green
        )
        
        MasteryProgressBar(
            title: "学习中",
            count: 200,
            total: 500,
            color: .orange
        )
        
        MasteryProgressBar(
            title: "未学习",
            count: 150,
            total: 500,
            color: .gray
        )
    }
    .padding()
}