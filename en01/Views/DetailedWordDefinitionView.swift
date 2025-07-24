//
//  DetailedWordDefinitionView.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import SwiftUI
import Foundation



/// 详细单词定义视图，显示丰富的考研词典信息
struct DetailedWordDefinitionView: View {
    let word: String
    let onDismiss: () -> Void
    
    @EnvironmentObject private var dictionaryService: DictionaryService
    @EnvironmentObject private var wordInteractionCoordinator: WordInteractionCoordinator
    @State private var masteryLevel: Int = 2 // 0: 未掌握, 1: 认识, 2: 熟悉, 3: 掌握
    @State private var isFavorited: Bool = false
    @State private var selectedMeaningIndex: Int = 0
    
    private var viewModel: WordDefinitionViewModel {
        wordInteractionCoordinator.wordDefinitionViewModel
    }
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // 弹窗内容
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    LoadingView()
                } else if let definition = viewModel.detailedDefinition {
                    ModernWordPopupView(
                        definition: definition,
                        masteryLevel: $masteryLevel,
                        isFavorited: $isFavorited,
                        selectedMeaningIndex: $selectedMeaningIndex,
                        onDismiss: onDismiss
                    )
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorPopupView(message: errorMessage, onDismiss: onDismiss)
                }
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width - 40, 600), maxHeight: UIScreen.main.bounds.height * 0.85)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 20)
        }
        .onAppear {
            if viewModel.detailedDefinition?.word != word {
                Task {
                    await viewModel.loadDetailedDefinition(for: word)
                }
            }
        }
    }
}

// MARK: - 现代化单词弹窗视图 - 按照原型图样式
struct ModernWordPopupView: View {
    let definition: DetailedWordDefinition
    @Binding var masteryLevel: Int
    @Binding var isFavorited: Bool
    @Binding var selectedMeaningIndex: Int
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部关闭按钮
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // 可滚动内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 单词标题区域
                    WordHeaderSection(
                        definition: definition,
                        masteryLevel: $masteryLevel,
                        isFavorited: $isFavorited,
                        onDismiss: onDismiss
                    )
                    
                    // 本文中的含义
                    if !definition.translations.isEmpty {
                        CurrentMeaningSection(
                            translations: definition.translations,
                            selectedIndex: $selectedMeaningIndex
                        )
                    }
                    
                    // 例句区域
                    ExampleSection()
                    
                    // 相关词汇
                    if !definition.relatedWords.isEmpty {
                        RelatedWordsSection(relatedWords: definition.relatedWords)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // 底部操作按钮
            BottomActionButtons(
                masteryLevel: $masteryLevel,
                isFavorited: $isFavorited,
                onDismiss: onDismiss
            )
        }
        .background(Color.white)
    }
}
// MARK: - 单词标题区域 - 按照原型图样式
struct WordHeaderSection: View {
    let definition: DetailedWordDefinition
    @Binding var masteryLevel: Int
    @Binding var isFavorited: Bool
    let onDismiss: () -> Void
    
    private var masteryText: String {
        switch masteryLevel {
        case 0: return "未掌握"
        case 1: return "认识"
        case 2: return "熟悉"
        case 3: return "掌握"
        default: return "未知"
        }
    }
    
    private var masteryColor: Color {
        switch masteryLevel {
        case 0: return .red
        case 1: return .orange
        case 2: return .blue
        case 3: return .green
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 单词和发音
            HStack(alignment: .center, spacing: 12) {
                // 单词
                Text(definition.displayTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)
                
                // 发音按钮
                Button(action: {}) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                
                Spacer()
            }
            
            // 发音标注
            if let usPhonetic = definition.usPhonetic {
                Text("/\(usPhonetic)/")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.1))
                    )
            }
            
            // 掌握程度和查询次数
            HStack(spacing: 16) {
                // 掌握程度
                HStack(spacing: 8) {
                    Circle()
                        .fill(masteryColor)
                        .frame(width: 12, height: 12)
                    Text(masteryText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(masteryColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(masteryColor.opacity(0.1))
                )
                
                // 查询次数
                Text("查询次数：\(definition.queryCount ?? 0)")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
    }
}
// MARK: - 本文中的含义区域 - 按照原型图样式
struct CurrentMeaningSection: View {
    let translations: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text("本文中的含义")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            // 当前含义卡片
            if selectedIndex < translations.count {
                VStack(alignment: .leading, spacing: 8) {
                    Text(translations[selectedIndex])
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                        .lineLimit(nil)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - 例句区域 - 按照原型图样式
struct ExampleSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text("例句")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            // 例句卡片
            VStack(alignment: .leading, spacing: 12) {
                // 英文例句
                Text("The company is transforming its business model to adapt to the digital age.")
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .lineLimit(nil)
                
                // 中文翻译
                Text("该公司正在转变其商业模式以适应数字时代。")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(nil)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - 其他含义区域
struct OtherMeaningsSection: View {
    let translations: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                Text("其他含义")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // 其他含义列表
            VStack(spacing: 12) {
                ForEach(Array(translations.enumerated()), id: \.offset) { index, translation in
                    if index != selectedIndex {
                        Button {
                            selectedIndex = index
                        } label: {
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(translation)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
}

// MARK: - 含义卡片
struct MeaningCard: View {
    let meaning: String
    let isSelected: Bool
    let example: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meaning)
                .font(.body)
                .foregroundColor(.primary)
            
            if let example = example {
                Text(example)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
        )
    }
}



// MARK: - 掌握程度指示器
struct MasteryIndicator: View {
    let level: Int
    
    private let levels = ["未掌握", "认识", "熟悉", "掌握"]
    private let colors: [Color] = [.red, .orange, .blue, .green]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index <= level ? colors[index] : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            
            Text(level < levels.count ? levels[level] : "未知")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 例句区域
struct ExampleSentenceSection: View {
    let sentences: [KaoyanWordSentence]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("例句")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(Array(sentences.prefix(2).enumerated()), id: \.0) { index, sentence in
                VStack(alignment: .leading, spacing: 6) {
                    Text(sentence.sContent)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(sentence.sCn)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.05))
                )
            }
        }
    }
}

// MARK: - 相关词汇区域
struct RelatedWordsSection: View {
    let relatedWords: [KaoyanWordRelated]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.blue)
                Text("相关词汇")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // 相关词汇网格
            Group {
                if !relatedWords.isEmpty {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Array(relatedWords.prefix(6).enumerated()), id: \.0) { index, relatedWord in
                            RelatedWordCard(
                                word: relatedWord.hwd,
                                partOfSpeech: "\(relatedWord.pos). \(relatedWord.tran)"
                            )
                        }
                    }
                } else {
                    Text("暂无相关词汇")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - 相关词汇卡片
struct RelatedWordCard: View {
    let word: String
    let partOfSpeech: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(word)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            
            Text(partOfSpeech)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        )
    }
}

// MARK: - 底部操作按钮 - 按照原型图样式
struct BottomActionButtons: View {
    @Binding var masteryLevel: Int
    @Binding var isFavorited: Bool
    let onDismiss: () -> Void
    
    // 掌握程度选项
    private let masteryLevels = [
        (text: "不认识", value: 0, color: Color.red),
        (text: "有印象", value: 1, color: Color.orange),
        (text: "认识", value: 2, color: Color.blue),
        (text: "熟悉", value: 3, color: Color.green)
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // 掌握程度按钮
            HStack(spacing: 12) {
                ForEach(masteryLevels, id: \.text) { level in
                    Button(action: {
                        masteryLevel = level.value
                    }) {
                        Text(level.text)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(masteryLevel == level.value ? .white : level.color)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(masteryLevel == level.value ? level.color : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(level.color, lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            
            // 操作按钮行
            HStack(spacing: 20) {
                // 收藏按钮
                Button(action: {
                    isFavorited.toggle()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .foregroundColor(isFavorited ? .red : .gray)
                        Text("收藏")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // 添加到词汇本按钮
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "book")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                        Text("词汇本")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // 分享按钮
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                        Text("分享")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.white)
    }
    
}

// MARK: - 加载视图
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 错误弹窗视图
struct ErrorPopupView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // 关闭按钮
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 错误内容
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                
                Text("加载失败")
                    .font(.headline)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 200)
        }
        .padding(20)
    }
}

#Preview {
    DetailedWordDefinitionView(word: "example") {
        // Preview dismiss action
    }
    // Preview without DictionaryService for now
}