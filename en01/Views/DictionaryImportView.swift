//
//  DictionaryImportView.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import SwiftUI

struct DictionaryImportView: View {
    let availableDictionaries: [DictionaryInfo]
    @Binding var selectedDictionaries: Set<String>
    let onImport: () -> Void
    let onCancel: () -> Void
    
    @State private var isImporting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标题和说明
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择要导入的词典")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("选择您想要导入的考研词典库，导入后将作为您的个人学习词典。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                
                // 词典列表
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(availableDictionaries.filter { $0.isEnabled }, id: \.id) { dictionary in
                            DictionarySelectionCard(
                                dictionary: dictionary,
                                isSelected: selectedDictionaries.contains(dictionary.name),
                                onToggle: {
                                    if selectedDictionaries.contains(dictionary.name) {
                                        selectedDictionaries.remove(dictionary.name)
                                    } else {
                                        selectedDictionaries.insert(dictionary.name)
                                    }
                                }
                            )
                        }
                        
                        if availableDictionaries.filter({ $0.isEnabled }).isEmpty {
                            // 无可导入词典的提示
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.green)
                                
                                Text("所有词典已导入")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("您已经导入了所有可用的考研词典库")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                // 底部操作按钮
                if !availableDictionaries.filter({ $0.isEnabled }).isEmpty {
                    VStack(spacing: 12) {
                        Divider()
                        
                        HStack {
                            Text("已选择 \(selectedDictionaries.count) 个词典")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("取消") {
                                onCancel()
                            }
                            .foregroundColor(.secondary)
                            
                            Button("导入") {
                                isImporting = true
                                onImport()
                            }
                            .disabled(selectedDictionaries.isEmpty || isImporting)
                            .foregroundColor(selectedDictionaries.isEmpty ? .secondary : .blue)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct DictionarySelectionCard: View {
    let dictionary: DictionaryInfo
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 选择指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                // 词典信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(dictionary.displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !dictionary.description.isEmpty {
                        Text(dictionary.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    HStack {
                        Label("\(dictionary.totalWords) 个单词", systemImage: "book.closed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if !dictionary.isEnabled {
                            Text("已禁用")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DictionaryImportView(
        availableDictionaries: [
            DictionaryInfo(
                name: "考研核心词汇",
                displayName: "考研核心词汇",
                fileName: "kaoyan_core.json",
                filePath: "/path/to/kaoyan_core.json",
                version: "1.0",
                description: "包含考研英语核心词汇，适合备考使用",
                language: "en",
                totalWords: 1500,
                difficultyLevels: [1, 2, 3],
                categories: ["考研", "核心词汇"],
                fileSize: 1024000,
                checksum: "abc123",
                isEnabled: true,
                priority: 1,
                statistics: DictionaryStatistics(),
                configuration: DictionaryConfiguration()
            ),
            DictionaryInfo(
                name: "考研高频词汇",
                displayName: "考研高频词汇",
                fileName: "kaoyan_advanced.json",
                filePath: "/path/to/kaoyan_advanced.json",
                version: "1.0",
                description: "考研英语高频出现的重点词汇",
                language: "en",
                totalWords: 800,
                difficultyLevels: [2, 3],
                categories: ["考研", "高频词汇"],
                fileSize: 512000,
                checksum: "def456",
                isEnabled: true,
                priority: 2,
                statistics: DictionaryStatistics(),
                configuration: DictionaryConfiguration()
            )
        ],
        selectedDictionaries: Binding.constant(["kaoyan_core"]),
        onImport: {},
        onCancel: {}
    )
}