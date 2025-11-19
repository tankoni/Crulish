//
//  WordTestCard.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import Foundation

/// 词汇测试单词卡片组件
struct WordTestCard: View {
    let word: TestWord
    let testMode: VocabularyTestMode
    let onMasterySelected: (MasteryLevel) -> Void
    
    @State private var showDefinition = false
    @State private var showExample = false
    @State private var selectedMastery: MasteryLevel?
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // 单词主体区域
            wordMainSection
            
            // 详细信息区域
            wordDetailsSection
            
            // 掌握程度选择按钮
            masterySelectionButtons
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
        )
        .scaleEffect(isAnimating ? 1.0 : 0.95)
        .opacity(isAnimating ? 1.0 : 0.8)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
            if testMode == VocabularyTestMode.chineseToEnglish {
                showDefinition = true
            }
        }
        .onChange(of: word.word) { _, _ in
            // 重置状态
            showDefinition = false
            showExample = false
            selectedMastery = nil
            
            // 重新触发动画
            isAnimating = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isAnimating = true
            }
            if testMode == VocabularyTestMode.chineseToEnglish {
                showDefinition = true
            }
        }
    }
    
    private var wordMainSection: some View {
        VStack(spacing: 16) {
            // 单词
            Text(word.word)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            
            // 音标
            if let pronunciation = word.pronunciation, !pronunciation.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(pronunciation)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
                .onTapGesture {
                    // TODO: 播放发音
                    playPronunciation()
                }
            }
        }
    }
    
    private var wordDetailsSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showDefinition.toggle()
                    }
                }) {
                    HStack {
                        Text("释义")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Image(systemName: showDefinition ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .foregroundColor(.primary)
                
                if showDefinition {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array((word.definitions.isEmpty ? ["暂无释义"] : word.definitions).enumerated()), id: \.offset) { _, definition in
                                Text(definition)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(4)
                                    .minimumScaleFactor(0.9)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
            
            // 例句区域
            if let examples = word.examples, !examples.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showExample.toggle()
                        }
                    }) {
                        HStack {
                            Text("例句")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Image(systemName: showExample ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    if showExample {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(examples.enumerated()), id: \.offset) { _, example in
                                Text(example)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                    .italic()
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var masterySelectionButtons: some View {
        VStack(spacing: 16) {
            Text("你对这个单词的掌握程度？")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                MasteryButton(
                    title: "掌握",
                    subtitle: "完全认识",
                    color: .green,
                    icon: "checkmark.circle.fill",
                    isSelected: selectedMastery == .mastered
                ) {
                    selectMastery(.mastered)
                }
                
                // 只在中译英模式下显示眼熟选项
                if testMode == VocabularyTestMode.chineseToEnglish {
                    MasteryButton(
                        title: "眼熟",
                        subtitle: "有印象",
                        color: .orange,
                        icon: "eye.fill",
                        isSelected: selectedMastery == .familiar
                    ) {
                        selectMastery(.familiar)
                    }
                }
                
                MasteryButton(
                    title: "陌生",
                    subtitle: "不认识",
                    color: .red,
                    icon: "questionmark.circle.fill",
                    isSelected: selectedMastery == .unfamiliar
                ) {
                    selectMastery(.unfamiliar)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func selectMastery(_ level: MasteryLevel) {
        // 防止重复选择
        guard selectedMastery == nil else { return }
        
        selectedMastery = level
        
        // 立即执行回调
        onMasterySelected(level)
        
        // 添加动画效果
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimating = true
        }
        
        // 延迟重置状态
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒延迟
            withAnimation {
                selectedMastery = nil
                isAnimating = false
            }
        }
    }
    
    private func playPronunciation() {
        // TODO: 实现发音功能
        print("播放单词发音: \(word.word)")
    }
}

// MARK: - Supporting Views

struct MasteryButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : color.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color, lineWidth: isSelected ? 0 : 2)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Supporting Types

// MasteryLevel 已在 Word.swift 中定义

#Preview {
    ScrollView {
        WordTestCard(
            word: TestWord(
                word: "vocabulary",
                pronunciation: "/vəˈkæbjʊləri/",
                definitions: ["n. 词汇，词汇量；词表"],
                examples: ["Reading helps expand your vocabulary."],
                difficulty: .medium,
                frequency: 3
            ),
            testMode: VocabularyTestMode.chineseToEnglish
        ) { mastery in
            print("Selected mastery: \(mastery)")
        }
        .padding()
    }
    .background(.background)
}
