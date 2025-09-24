//
//  AdaptiveSettingsSheet.swift
//  en01
//
//  Created by AI Assistant on 2024/12/30.
//

import SwiftUI

/// 自适应推荐设置面板
struct AdaptiveSettingsSheet: View {
    @Binding var isPresented: Bool
    @Binding var isAdaptiveEnabled: Bool
    @Binding var adaptiveWeights: AdaptiveWeights
    @Binding var adaptiveMode: AdaptiveMode
    
    @State private var tempWeights: AdaptiveWeights
    @State private var tempMode: AdaptiveMode
    @State private var tempEnabled: Bool
    
    init(
        isPresented: Binding<Bool>,
        isAdaptiveEnabled: Binding<Bool>,
        adaptiveWeights: Binding<AdaptiveWeights>,
        adaptiveMode: Binding<AdaptiveMode>
    ) {
        self._isPresented = isPresented
        self._isAdaptiveEnabled = isAdaptiveEnabled
        self._adaptiveWeights = adaptiveWeights
        self._adaptiveMode = adaptiveMode
        
        // 初始化临时状态
        self._tempWeights = State(initialValue: adaptiveWeights.wrappedValue)
        self._tempMode = State(initialValue: adaptiveMode.wrappedValue)
        self._tempEnabled = State(initialValue: isAdaptiveEnabled.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 自适应推荐开关
                    adaptiveToggleSection
                    
                    if tempEnabled {
                        // 推荐模式选择
                        adaptiveModeSection
                        
                        // 权重调整
                        weightsAdjustmentSection
                        
                        // 预览效果
                        previewSection
                    }
                }
                .padding()
            }
            .navigationTitle("自适应设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        resetToOriginal()
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - 自适应推荐开关
    private var adaptiveToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("智能推荐")
                .font(.headline)
                .fontWeight(.semibold)
            
            Toggle(isOn: $tempEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("启用自适应推荐")
                        .font(.subheadline)
                    
                    Text("基于您的学习行为和进度，智能推荐最适合的文章")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .purple))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 推荐模式选择
    private var adaptiveModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐模式")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(AdaptiveMode.allCases, id: \.self) { mode in
                    AdaptiveModeCard(
                        mode: mode,
                        isSelected: tempMode == mode,
                        onSelect: { tempMode = mode }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 权重调整
    private var weightsAdjustmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("推荐权重调整")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("调整不同因素在推荐算法中的重要性")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                WeightSlider(
                    title: "词汇匹配度",
                    description: "基于您已掌握的词汇推荐文章",
                    value: $tempWeights.vocabularyMatch,
                    icon: "textformat.abc",
                    color: .blue
                )
                
                WeightSlider(
                    title: "难度适应性",
                    description: "根据您的学习水平调整文章难度",
                    value: $tempWeights.difficultyAdaptation,
                    icon: "chart.bar.fill",
                    color: .green
                )
                
                WeightSlider(
                    title: "学习历史",
                    description: "考虑您的阅读偏好和学习轨迹",
                    value: $tempWeights.learningHistory,
                    icon: "clock.arrow.circlepath",
                    color: .orange
                )
                
                WeightSlider(
                    title: "进度优化",
                    description: "优化学习进度和效果",
                    value: $tempWeights.progressOptimization,
                    icon: "arrow.up.right",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 预览效果
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预览效果")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("当前设置下的推荐特点：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(getPreviewFeatures(), id: \.self) { feature in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                                .padding(.top, 2)
                            
                            Text(feature)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 辅助方法
    private func resetToOriginal() {
        tempWeights = adaptiveWeights
        tempMode = adaptiveMode
        tempEnabled = isAdaptiveEnabled
    }
    
    private func saveSettings() {
        isAdaptiveEnabled = tempEnabled
        adaptiveWeights = tempWeights
        adaptiveMode = tempMode
    }
    
    private func getPreviewFeatures() -> [String] {
        var features: [String] = []
        
        switch tempMode {
        case .balanced:
            features.append("平衡考虑各项因素，提供全面的推荐")
        case .vocabularyFocused:
            features.append("重点关注词汇学习，推荐生词适中的文章")
        case .difficultyProgressive:
            features.append("渐进式难度提升，循序渐进的学习路径")
        case .interestBased:
            features.append("基于阅读兴趣，推荐您喜欢的主题类型")
        }
        
        if tempWeights.vocabularyMatch > 0.7 {
            features.append("优先推荐词汇匹配度高的文章")
        }
        
        if tempWeights.difficultyAdaptation > 0.7 {
            features.append("智能调整文章难度，避免过难或过易")
        }
        
        if tempWeights.learningHistory > 0.7 {
            features.append("深度分析学习历史，个性化推荐")
        }
        
        return features
    }
}

// MARK: - 自适应模式卡片
struct AdaptiveModeCard: View {
    let mode: AdaptiveMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.purple.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 权重滑块
struct WeightSlider: View {
    let title: String
    let description: String
    @Binding var value: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .frame(width: 40, alignment: .trailing)
            }
            
            Slider(value: $value, in: 0...1, step: 0.1)
                .accentColor(color)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - 自适应模式扩展
extension AdaptiveMode {
    var displayName: String {
        switch self {
        case .balanced:
            return "平衡模式"
        case .vocabularyFocused:
            return "词汇导向"
        case .difficultyProgressive:
            return "难度递进"
        case .interestBased:
            return "兴趣导向"
        }
    }
    
    var description: String {
        switch self {
        case .balanced:
            return "综合考虑词汇、难度、兴趣等因素，提供均衡的推荐"
        case .vocabularyFocused:
            return "重点关注词汇学习效果，推荐生词数量适中的文章"
        case .difficultyProgressive:
            return "根据学习进度逐步提升难度，确保循序渐进"
        case .interestBased:
            return "基于阅读历史和偏好，推荐您感兴趣的主题内容"
        }
    }
}

#Preview {
    AdaptiveSettingsSheet(
        isPresented: .constant(true),
        isAdaptiveEnabled: .constant(true),
        adaptiveWeights: .constant(AdaptiveWeights(
            vocabularyMatch: 0.8,
            difficultyAdaptation: 0.7,
            learningHistory: 0.6,
            progressOptimization: 0.9
        )),
        adaptiveMode: .constant(.balanced)
    )
}