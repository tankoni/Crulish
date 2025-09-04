//
//  GroupSelectionCard.swift
//  en01
//
//  Created by AI Assistant on 2024/12/30.
//

import SwiftUI

struct GroupSelectionCard: View {
    let groupName: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 16))
                
                Text(groupName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(UIColor.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 8) {
        GroupSelectionCard(
            groupName: "基础词汇",
            isSelected: true,
            onToggle: {}
        )
        
        GroupSelectionCard(
            groupName: "高级词汇",
            isSelected: false,
            onToggle: {}
        )
    }
    .padding()
}