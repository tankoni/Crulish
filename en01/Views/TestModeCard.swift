//
//  TestModeCard.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI

/// 测试模式选择卡片
struct TestModeCard: View {
    let mode: VocabularyTestMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 模式图标
                Image(systemName: mode.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : mode.themeColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 选择指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mode.themeColor : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? mode.themeColor : Color.gray.opacity(0.2),
                                lineWidth: isSelected ? 0 : 1
                            )
                    )
            )
            .shadow(
                color: isSelected ? mode.themeColor.opacity(0.3) : .black.opacity(0.05),
                radius: isSelected ? 8 : 2,
                x: 0,
                y: isSelected ? 4 : 1
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        TestModeCard(
            mode: .englishToChinese,
            isSelected: true,
            onSelect: {}
        )
        
        TestModeCard(
            mode: .chineseToEnglish,
            isSelected: false,
            onSelect: {}
        )
    }
    .padding()
}