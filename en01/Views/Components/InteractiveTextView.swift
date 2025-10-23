//
//  InteractiveTextView.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import SwiftUI
import SwiftData

/// 可交互的文本视图 - 支持单词点击，使用统一的WordInteractionCoordinator
struct InteractiveTextView: View {
    
    // MARK: - Properties
    
    let text: String
    let articleId: UUID
    let onWordClick: (String, String, Int) -> Void
    
    @EnvironmentObject private var wordInteractionCoordinator: WordInteractionCoordinator
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(textParagraphs.enumerated()), id: \.offset) { index, paragraph in
                    InteractiveParagraphView(
                        text: paragraph,
                        paragraphIndex: index,
                        onWordTap: handleWordTap
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $wordInteractionCoordinator.showDetailedSheet) {
            DetailedWordDefinitionView(
                word: wordInteractionCoordinator.selectedWord,
                onDismiss: {
                    wordInteractionCoordinator.hideDetailedSheet()
                }
            )
        }
        .overlay(
            // 统一的单词提示tooltip
            ZStack {
                if wordInteractionCoordinator.showTooltip {
                    WordTooltipView(
                        word: wordInteractionCoordinator.selectedWord,
                        isLoading: wordInteractionCoordinator.isLoading,
                        phonetic: wordInteractionCoordinator.simplePhonetic,
                        definition: wordInteractionCoordinator.simpleDefinition,
                        wordPosition: wordInteractionCoordinator.selectedWordPosition,
                        onViewMore: {
                            wordInteractionCoordinator.showDetailedDefinition()
                        },
                        onDismiss: {
                            wordInteractionCoordinator.hideTooltip()
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.2), value: wordInteractionCoordinator.showTooltip)
                }
            }
        )
    }
    
    // MARK: - Computed Properties
    
    private var textParagraphs: [String] {
        return text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    // MARK: - Methods
    
    private func handleWordTap(word: String, context: String, position: Int) {
        // 调用原有的回调（用于兼容性）
        onWordClick(word, context, position)
        
        // 使用统一的协调器处理单词交互
        wordInteractionCoordinator.handleWordTap(word, at: CGPoint.zero)
    }
}

// MARK: - Interactive Paragraph View

struct InteractiveParagraphView: View {
    let text: String
    let paragraphIndex: Int
    let onWordTap: (String, String, Int) -> Void
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(Array(sentences.enumerated()), id: \.offset) { sentenceIndex, sentence in
                InteractiveSentenceView(
                    sentence: sentence,
                    sentenceIndex: sentenceIndex,
                    paragraphIndex: paragraphIndex,
                    onWordTap: onWordTap
                )
            }
        }
    }
    
    private var sentences: [String] {
        return text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Interactive Sentence View

struct InteractiveSentenceView: View {
    let sentence: String
    let sentenceIndex: Int
    let paragraphIndex: Int
    let onWordTap: (String, String, Int) -> Void
    
    var body: some View {
        LazyHStack(alignment: .top, spacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { wordIndex, word in
                InteractiveWordView(
                    word: word,
                    context: sentence,
                    position: calculateWordPosition(wordIndex),
                    onTap: onWordTap
                )
            }
        }
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private var words: [String] {
        return sentence.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
    }
    
    private func calculateWordPosition(_ wordIndex: Int) -> Int {
        return paragraphIndex * 1000 + sentenceIndex * 100 + wordIndex
    }
}

// MARK: - Interactive Word View

struct InteractiveWordView: View {
    let word: String
    let context: String
    let position: Int
    let onTap: (String, String, Int) -> Void
    
    @State private var isHighlighted = false
    @State private var isUnknownWord = false
    @EnvironmentObject private var wordInteractionCoordinator: WordInteractionCoordinator
    
    var body: some View {
        Button(action: {
            handleWordTap()
        }) {
            Text(cleanWord)
                .font(.body)
                .foregroundColor(wordColor)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(wordBackgroundColor)
                        .padding(.horizontal, -2)
                        .padding(.vertical, -1)
                )
                .scaleEffect(isHighlighted ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isHighlighted)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.1) {
            // 长按效果
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHighlighted = pressing
            }
        }
        .onAppear {
            checkIfUnknownWord()
        }
    }
    
    private var cleanWord: String {
        return word.trimmingCharacters(in: CharacterSet.punctuationCharacters)
    }
    
    private var wordColor: Color {
        if isHighlighted {
            return .blue
        } else if isUnknownWord {
            return .red
        } else {
            return .primary
        }
    }
    
    private var wordBackgroundColor: Color {
        if isHighlighted {
            return Color.blue.opacity(0.1)
        } else if isUnknownWord {
            return Color.red.opacity(0.15)
        } else {
            return Color.clear
        }
    }
    
    private func checkIfUnknownWord() {
        // 检查单词是否为生词
        let cleaned = cleanWord.lowercased()
        guard cleaned.count > 1,
              cleaned.rangeOfCharacter(from: .letters) != nil,
              !isStopWord(cleaned) else {
            return
        }
        
        // 这里可以通过词汇服务检查单词是否为生词
        // 暂时使用简单的逻辑：长度大于6的单词标记为生词
        isUnknownWord = cleaned.count > 6
    }
    
    private func handleWordTap() {
        // 只处理有意义的单词（长度大于1，包含字母）
        let cleaned = cleanWord.lowercased()
        guard cleaned.count > 1,
              cleaned.rangeOfCharacter(from: .letters) != nil,
              !isStopWord(cleaned) else {
            return
        }
        
        // 触发点击回调
        onTap(cleaned, context, position)
        
        // 添加触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = Set([
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "is", "are", "was", "were", "be", "been", "have",
            "has", "had", "do", "does", "did", "will", "would", "could", "should",
            "may", "might", "can", "must", "shall", "this", "that", "these", "those",
            "i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them"
        ])
        return stopWords.contains(word)
    }
}

// MARK: - Preview

struct InteractiveTextView_Previews: PreviewProvider {
    static var previews: some View {
        InteractiveTextView(
            text: "This is a sample text for testing the interactive text view. You can tap on any word to see its definition.",
            articleId: UUID(),
            onWordClick: { word, context, position in
                print("Word clicked: \(word)")
            }
        )
        .environmentObject(WordInteractionCoordinator(
            dictionaryService: DictionaryService(
                modelContext: try! ModelContainer(for: UserWord.self).mainContext,
                cacheManager: CacheManager(),
                errorHandler: ErrorHandler()
            ),
            translationService: TranslationServiceImpl(),
            learningTrackingService: LearningTrackingService(
                modelContext: try! ModelContainer(for: LearningRecord.self).mainContext,
                cacheManager: CacheManager(),
                errorHandler: ErrorHandler()
            )
        ))
    }
}