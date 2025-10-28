//
//  WordMasterySelector.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import SwiftUI

/// 单词掌握程度选择器组件
struct WordMasterySelector: View {
    
    // MARK: - Properties
    
    let word: String
    let currentMastery: MasteryLevel?
    let onMasterySelected: (MasteryLevel) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedMastery: MasteryLevel?
    @State private var showConfirmation = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            headerView
            
            // 单词显示
            wordDisplayView
            
            // 掌握程度选项
            masteryOptionsView
            
            // 操作按钮
            actionButtonsView
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onAppear {
            selectedMastery = currentMastery
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            Text("设置掌握程度")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var wordDisplayView: some View {
        VStack(spacing: 8) {
            Text(word)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let current = currentMastery {
                Text("当前: \(current.masteryDisplayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(current.masteryColor.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var masteryOptionsView: some View {
        VStack(spacing: 12) {
            ForEach(MasteryLevel.allCases, id: \.self) { level in
                MasteryOptionCard(
                    level: level,
                    isSelected: selectedMastery == level,
                    onTap: {
                        selectedMastery = level
                        showConfirmation = true
                    }
                )
            }
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            Button("取消") {
                onDismiss()
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            
            Button("确认") {
                if let mastery = selectedMastery {
                    onMasterySelected(mastery)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(selectedMastery != nil ? Color.blue : Color.gray)
            .cornerRadius(8)
            .disabled(selectedMastery == nil)
        }
        .alert("确认更改", isPresented: $showConfirmation) {
            Button("取消", role: .cancel) {
                showConfirmation = false
            }
            Button("确认") {
                if let mastery = selectedMastery {
                    onMasterySelected(mastery)
                }
            }
        } message: {
            if let mastery = selectedMastery {
                Text("将单词 \"\(word)\" 的掌握程度设置为 \"\(mastery.masteryDisplayName)\"？")
            }
        }
    }
}

// MARK: - Mastery Option Card

struct MasteryOptionCard: View {
    let level: MasteryLevel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: level.masteryIconName)
                    .font(.title2)
                    .foregroundColor(level.masteryColor)
                    .frame(width: 30)
                
                // 文本信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.masteryDisplayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(level.masteryDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // 选择指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? level.masteryColor.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? level.masteryColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - MasteryLevel Extensions

extension MasteryLevel {
    var masteryDisplayName: String {
        switch self {
        case .unfamiliar:
            return "陌生"
        case .familiar:
            return "眼熟"
        case .mastered:
            return "掌握"
        }
    }
    
    var masteryDescription: String {
        switch self {
        case .unfamiliar:
            return "完全不认识这个单词"
        case .familiar:
            return "见过但不确定意思"
        case .mastered:
            return "完全掌握这个单词"
        }
    }
    
    var masteryIconName: String {
        switch self {
        case .unfamiliar:
            return "questionmark.circle"
        case .familiar:
            return "eye"
        case .mastered:
            return "checkmark.circle"
        }
    }
    
    var masteryColor: Color {
        switch self {
        case .unfamiliar:
            return .red
        case .familiar:
            return .orange
        case .mastered:
            return .green
        }
    }
}

// MARK: - Preview

struct WordMasterySelector_Previews: PreviewProvider {
    static var previews: some View {
        WordMasterySelector(
            word: "example",
            currentMastery: .familiar,
            onMasterySelected: { _ in },
            onDismiss: { }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}