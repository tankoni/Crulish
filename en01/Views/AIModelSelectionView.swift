//
//  AIModelSelectionView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI

struct AIModelSelectionView: View {
    @Binding var selectedModel: AIModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    // 添加AppSettings以检查API密钥可用性
    @EnvironmentObject var appSettings: AppSettings
    
    // 检查模型是否可用（有对应的API密钥）
    private func isModelAvailable(_ model: AIModel) -> Bool {
        switch model.provider {
        case .openai:
            return !appSettings.openaiAPIKey.isEmpty
        case .gemini:
            // Gemini有默认API密钥，检查是否有有效的密钥（不为空）
            // 默认密钥AIzaSyCuGzUTUY_s_lB4NmKULmDqD2Z_gWsSN8w被认为是有效的
            return !appSettings.geminiAPIKey.isEmpty
        case .deepseek:
            return !appSettings.deepseekAPIKey.isEmpty
        case .doubao:
            return !appSettings.doubaoAPIKey.isEmpty
        default:
            // 对于其他提供者，检查相应的API密钥
            if model.displayName.contains("Claude") {
                return !appSettings.claudeAPIKey.isEmpty
            } else if model.displayName.contains("Qwen") {
                return !appSettings.qwenAPIKey.isEmpty
            }
            return false
        }
    }
    
    private var filteredModels: [AIModel] {
        if searchText.isEmpty {
            return AIModel.allCases
        } else {
            return AIModel.allCases.filter { model in
                model.displayName.localizedCaseInsensitiveContains(searchText) ||
                model.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var groupedModels: [(String, [AIModel])] {
        let groups = Dictionary(grouping: filteredModels) { model in
            switch model.provider {
            case .openai:
                if model.displayName.contains("GPT") {
                    return "OpenAI GPT 系列"
                } else if model.displayName.contains("Claude") {
                    return "Anthropic Claude 系列"
                } else {
                    return "其他 OpenAI 兼容模型"
                }
            case .gemini:
                return "Google Gemini 系列"
            case .deepseek:
                return "DeepSeek 系列"
            case .doubao:
                return "字节豆包系列"
            default:
                return "其他模型"
            }
        }
        return groups.sorted { $0.key < $1.key }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groupedModels, id: \.0) { groupName, models in
                    Section {
                        ForEach(models, id: \.self) { model in
                            ModelRow(
                                model: model,
                                isSelected: selectedModel == model,
                                isAvailable: isModelAvailable(model)
                            ) {
                                selectedModel = model
                            }
                        }
                    } header: {
                        Text(groupName)
                    }
                }
                
                if filteredModels.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("未找到匹配的模型")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("请尝试其他搜索关键词")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索AI模型")
            .navigationTitle("AI模型选择")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ModelRow: View {
    let model: AIModel
    let isSelected: Bool
    let isAvailable: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            if isAvailable {
                onTap()
            }
        }) {
            HStack(spacing: 12) {
                // 模型图标
                Image(systemName: model.iconName)
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(iconColor.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    // 模型名称
                    Text(model.displayName)
                        .font(.headline)
                        .foregroundColor(isAvailable ? .primary : .secondary)
                    
                    // 模型描述
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(isAvailable ? .secondary : Color.secondary.opacity(0.6))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // 不可用状态标签
                    if !isAvailable {
                        Text("需要配置API密钥")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                    }
                    
                    // 提供商标签
                    HStack(spacing: 4) {
                        Text(providerDisplayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill((isAvailable ? providerColor : Color.gray).opacity(0.2))
                            )
                            .foregroundColor(isAvailable ? providerColor : Color.gray)
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // 选中状态
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isAvailable ? 1.0 : 0.6)
    }
    
    private var iconColor: Color {
        switch model.provider {
        case .openai:
            return .green
        case .gemini:
            return .blue
        case .deepseek:
            return .purple
        case .doubao:
            return .orange
        default:
            return .gray
        }
    }
    
    private var providerColor: Color {
        iconColor
    }
    
    private var providerDisplayName: String {
        switch model.provider {
        case .openai:
            if model.displayName.contains("GPT") {
                return "OpenAI"
            } else if model.displayName.contains("Claude") {
                return "Anthropic"
            } else {
                return "OpenAI兼容"
            }
        case .gemini:
            return "Google"
        case .deepseek:
            return "DeepSeek"
        case .doubao:
            return "字节跳动"
        default:
            return "其他"
        }
    }
}

#Preview {
    AIModelSelectionView(selectedModel: .constant(.gpt35turbo))
}