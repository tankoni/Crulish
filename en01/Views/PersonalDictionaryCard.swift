//
//  PersonalDictionaryCard.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import SwiftUI

struct PersonalDictionaryCard: View {
    let dictionary: PersonalDictionary
    let onDelete: () -> Void
    
    @State private var isShowingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 词典标题和操作按钮
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dictionary.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if !dictionary.description.isEmpty {
                        Text(dictionary.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(role: .destructive) {
                        isShowingDeleteAlert = true
                    } label: {
                        Label("删除词典", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            
            // 词典统计信息
            HStack(spacing: 16) {
                DictionaryStatItem(
                    icon: "book.closed",
                    title: "单词数量",
                    value: "\(dictionary.wordCount)",
                    color: .blue
                )
                
                DictionaryStatItem(
                    icon: "calendar",
                    title: "导入时间",
                    value: formatDate(dictionary.importDate),
                    color: .green
                )
                
                if dictionary.sourceType == .kaoyan {
                    DictionaryStatItem(
                        icon: "graduationcap",
                        title: "类型",
                        value: "考研词汇",
                        color: .orange
                    )
                } else {
                    DictionaryStatItem(
                        icon: "person",
                        title: "类型",
                        value: "自定义",
                        color: .purple
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .alert("删除词典", isPresented: $isShowingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("确定要删除词典\"\(dictionary.name)\"吗？此操作无法撤销。")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct DictionaryStatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PersonalDictionaryCard(
        dictionary: PersonalDictionary(
            id: "test",
            name: "考研核心词汇",
            description: "包含考研英语核心词汇，适合备考使用",
            wordCount: 1500,
            importDate: Date(),
            sourceType: .kaoyan
        ),
        onDelete: {}
    )
    .padding()
}