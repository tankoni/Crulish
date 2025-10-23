//
//  ReaderBottomToolbar.swift
//  en01
//
//  Created by AI Assistant on 2025/01/18.
//

import SwiftUI

// MARK: - 阅读器底部工具栏
struct ReaderBottomToolbar: View {
    let onWordLookup: () -> Void
    let onSentenceTranslation: () -> Void
    let onParagraphTranslation: () -> Void
    let onSettings: () -> Void
    let onBookmark: () -> Void
    let onShare: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 主工具栏
            HStack(spacing: 0) {
                // 单词查询
                ToolbarButton(
                    icon: "textformat.abc",
                    title: "单词",
                    color: .blue,
                    action: onWordLookup
                )
                
                Divider()
                    .frame(height: 30)
                
                // 句子翻译
                ToolbarButton(
                    icon: "text.bubble",
                    title: "句子",
                    color: .green,
                    action: onSentenceTranslation
                )
                
                Divider()
                    .frame(height: 30)
                
                // 段落翻译
                ToolbarButton(
                    icon: "text.alignleft",
                    title: "段落",
                    color: .orange,
                    action: onParagraphTranslation
                )
                
                Divider()
                    .frame(height: 30)
                
                // 设置
                ToolbarButton(
                    icon: "textformat.size",
                    title: "设置",
                    color: .purple,
                    action: onSettings
                )
                
                Divider()
                    .frame(height: 30)
                
                // 更多选项
                ToolbarButton(
                    icon: "ellipsis",
                    title: "更多",
                    color: .gray,
                    action: { isExpanded.toggle() }
                )
            }
            .frame(height: 60)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .top
            )
            
            // 扩展工具栏
            if isExpanded {
                HStack(spacing: 0) {
                    // 书签
                    ToolbarButton(
                        icon: "bookmark",
                        title: "书签",
                        color: .yellow,
                        action: {
                            onBookmark()
                            isExpanded = false
                        }
                    )
                    
                    Divider()
                        .frame(height: 30)
                    
                    // 分享
                    ToolbarButton(
                        icon: "square.and.arrow.up",
                        title: "分享",
                        color: .blue,
                        action: {
                            onShare()
                            isExpanded = false
                        }
                    )
                    
                    Spacer()
                }
                .frame(height: 60)
                .background(.ultraThinMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
}

// MARK: - 工具栏按钮组件
struct ToolbarButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.gray.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - 预览
#Preview {
    VStack {
        Spacer()
        
        ReaderBottomToolbar(
            onWordLookup: { print("单词查询") },
            onSentenceTranslation: { print("句子翻译") },
            onParagraphTranslation: { print("段落翻译") },
            onSettings: { print("设置") },
            onBookmark: { print("书签") },
            onShare: { print("分享") }
        )
    }
    .background(Color(.systemBackground))
}