//
//  ReviewStatItem.swift
//  en01
//
//  Created by AI Assistant on 2024/12/30.
//

import SwiftUI

/// 复习统计项组件
struct ReviewStatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ReviewStatItem(
        title: "今日复习",
        value: "12",
        color: .blue
    )
    .padding()
}