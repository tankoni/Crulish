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
                        ForEach(availableDictionaries.filter { !$0.isImported }, id: \.id) { dictionary in
                            DictionarySelectionCard(
                                dictionary: dictionary,
                                isSelected: selectedDictionaries.contains(dictionary.id),
                                onToggle: {
                                    if selectedDictionaries.contains(dictionary.id) {
                                        selectedDictionaries.remove(dictionary.id)
                                    } else {
                                        selectedDictionaries.insert(dictionary.id)
                                    }
                                }
                            )
                        }
                        
                        if availableDictionaries.filter({ !$0.isImported }).isEmpty {
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
                if !availableDictionaries.filter({ !$0.isImported }).isEmpty {
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
                    Text(dictionary.name)
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
                        Label("\(dictionary.wordCount) 个单词", systemImage: "book.closed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if dictionary.isImported {
                            Text("已导入")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
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
                id: "kaoyan_core",
                name: "考研核心词汇",
                fileName: "kaoyan_core.json",
                description: "包含考研英语核心词汇，适合备考使用",
                wordCount: 1500,
                isImported: false
            ),
            DictionaryInfo(
                id: "kaoyan_advanced",
                name: "考研高频词汇",
                fileName: "kaoyan_advanced.json",
                description: "考研英语高频出现的重点词汇",
                wordCount: 800,
                isImported: true
            )
        ],
        selectedDictionaries: .constant(["kaoyan_core"]),
        onImport: {},
        onCancel: {}
    )
}