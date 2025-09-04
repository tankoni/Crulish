//
//  QuestionTestCard.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import Foundation

/// 选择题形式的词汇测试卡片组件
struct QuestionTestCard: View {
    let question: TestQuestion
    let selectedAnswer: TestOption?
    let onAnswerSelected: (TestOption) -> Void
    let onSubmitAnswer: () -> Void
    let showResult: Bool
    
    @State private var isAnimating = false
    @State private var selectedOption: TestOption?
    
    var body: some View {
        VStack(spacing: 24) {
            // 题目区域
            questionSection
            
            // 选项区域
            optionsSection
            
            // 提交按钮
            if selectedAnswer != nil && !showResult {
                submitButton
            }
            
            // 结果显示
            if showResult {
                resultSection
            }
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
        }
        .onChange(of: question.id) {
            // 重置状态
            selectedOption = nil
            
            // 重新触发动画
            isAnimating = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isAnimating = true
            }
        }
    }
    
    private var questionSection: some View {
        VStack(spacing: 16) {
            // 题目类型标识
            HStack {
                Image(systemName: question.mode == .englishToChinese ? "abc" : "character.textbox")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(question.mode == .englishToChinese ? "英译中" : "中译英")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            )
            
            // 题目内容
            Text(question.question)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
    }
    
    private var optionsSection: some View {
        VStack(spacing: 12) {
            ForEach(question.options, id: \.id) { option in
                OptionButton(
                    option: option,
                    isSelected: selectedAnswer?.id == option.id,
                    showResult: showResult,
                    correctAnswerText: question.correctAnswer
                ) {
                    if !showResult {
                        onAnswerSelected(option)
                    }
                }
            }
        }
    }
    
    private var submitButton: some View {
        Button(action: onSubmitAnswer) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                
                Text("提交答案")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var resultSection: some View {
        VStack(spacing: 12) {
            // 结果图标和文字
            HStack {
                Image(systemName: selectedAnswer?.isCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(selectedAnswer?.isCorrect == true ? .green : .red)
                
                Text(selectedAnswer?.isCorrect == true ? "回答正确！" : "回答错误")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedAnswer?.isCorrect == true ? .green : .red)
            }
            
            // 正确答案提示
            if selectedAnswer?.isCorrect != true {
                Text("正确答案：\(question.correctAnswer)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((selectedAnswer?.isCorrect == true ? Color.green : Color.red).opacity(0.1))
        )
    }
}

// MARK: - Supporting Views

struct OptionButton: View {
    let option: TestOption
    let isSelected: Bool
    let showResult: Bool
    let correctAnswerText: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    private var buttonColor: Color {
        if showResult {
            if option.isCorrect {
                return .green
            } else if isSelected && !option.isCorrect {
                return .red
            } else {
                return .gray
            }
        } else if isSelected {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var backgroundColor: Color {
        if showResult {
            if option.isCorrect {
                return .green.opacity(0.1)
            } else if isSelected && !option.isCorrect {
                return .red.opacity(0.1)
            } else {
                return .gray.opacity(0.05)
            }
        } else if isSelected {
            return .blue
        } else {
            return .gray.opacity(0.05)
        }
    }
    
    private var textColor: Color {
        if showResult {
            if option.isCorrect {
                return .green
            } else if isSelected && !option.isCorrect {
                return .red
            } else {
                return .secondary
            }
        } else if isSelected {
            return .white
        } else {
            return .primary
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                // 选项标识
                Circle()
                    .fill(isSelected ? buttonColor : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(buttonColor, lineWidth: 2)
                    )
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: showResult && option.isCorrect ? "checkmark" : (showResult && isSelected && !option.isCorrect ? "xmark" : ""))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                // 选项文本
                Text(option.text)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(buttonColor, lineWidth: isSelected ? 0 : 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if !showResult {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    let testWord = TestWord(
        word: "vocabulary",
        pronunciation: "/vəˈkæbjʊləri/",
        definitions: ["词汇", "词汇量"],
        examples: ["Building vocabulary is important."],
        difficulty: .advanced,
        frequency: 85
    )
    
    QuestionTestCard(
        question: TestQuestion(
            word: testWord,
            mode: .englishToChinese
        ),
        selectedAnswer: nil,
        onAnswerSelected: { _ in },
        onSubmitAnswer: {},
        showResult: false
    )
    .padding()
}