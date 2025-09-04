//
//  VocabularyTestMode.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import Foundation
import SwiftUI

/// 词汇测试模式
enum VocabularyTestMode: String, CaseIterable, Codable {
    case englishToChinese = "english_to_chinese"  // 英译中：给英文测释义
    case chineseToEnglish = "chinese_to_english"  // 中译英：给释义测英文
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .englishToChinese:
            return "英译中"
        case .chineseToEnglish:
            return "中译英"
        }
    }
    
    /// 详细描述
    var description: String {
        switch self {
        case .englishToChinese:
            return "给英文单词，选择正确的中文释义"
        case .chineseToEnglish:
            return "给中文释义，选择正确的英文单词"
        }
    }
    
    /// 图标名称
    var iconName: String {
        switch self {
        case .englishToChinese:
            return "a.circle.fill"
        case .chineseToEnglish:
            return "textformat.abc"
        }
    }
    
    /// 主题色
    var color: String {
        switch self {
        case .englishToChinese:
            return "blue"
        case .chineseToEnglish:
            return "purple"
        }
    }
    
    /// 主题颜色（SwiftUI Color类型）
    var themeColor: Color {
        switch self {
        case .englishToChinese:
            return .blue
        case .chineseToEnglish:
            return .purple
        }
    }
}

/// 测试选项数据结构
struct TestOption: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isCorrect: Bool
    
    init(text: String, isCorrect: Bool = false) {
        self.text = text
        self.isCorrect = isCorrect
    }
}

/// 测试题目数据结构
struct TestQuestion: Identifiable {
    let id = UUID()
    let word: TestWord
    let mode: VocabularyTestMode
    let question: String  // 题目文本
    let options: [TestOption]  // 选项列表
    let correctAnswer: String  // 正确答案
    
    init(word: TestWord, mode: VocabularyTestMode, distractors: [String] = []) {
        self.word = word
        self.mode = mode
        
        switch mode {
        case .englishToChinese:
            self.question = word.word
            // 正确答案是第一个释义
            self.correctAnswer = word.definitions.first ?? ""
            
            // 生成选项（包含正确答案和干扰项）
            var allOptions: [TestOption] = [TestOption(text: self.correctAnswer, isCorrect: true)]
            
            // 添加干扰项
            let distractorOptions = distractors.prefix(3).map { TestOption(text: $0, isCorrect: false) }
            allOptions.append(contentsOf: distractorOptions)
            
            // 如果干扰项不足，添加默认干扰项
            if allOptions.count < 4 {
                let defaultDistractors = ["其他释义1", "其他释义2", "其他释义3"]
                for i in allOptions.count..<4 {
                    if i-1 < defaultDistractors.count {
                        allOptions.append(TestOption(text: defaultDistractors[i-1], isCorrect: false))
                    }
                }
            }
            
            // 随机打乱选项顺序
            self.options = allOptions.shuffled()
            
        case .chineseToEnglish:
            self.question = word.definitions.first ?? ""
            self.correctAnswer = word.word
            
            // 生成选项（包含正确答案和干扰项）
            var allOptions: [TestOption] = [TestOption(text: self.correctAnswer, isCorrect: true)]
            
            // 添加干扰项
            let distractorOptions = distractors.prefix(3).map { TestOption(text: $0, isCorrect: false) }
            allOptions.append(contentsOf: distractorOptions)
            
            // 如果干扰项不足，添加默认干扰项
            if allOptions.count < 4 {
                let defaultDistractors = ["option1", "option2", "option3"]
                for i in allOptions.count..<4 {
                    if i-1 < defaultDistractors.count {
                        allOptions.append(TestOption(text: defaultDistractors[i-1], isCorrect: false))
                    }
                }
            }
            
            // 随机打乱选项顺序
            self.options = allOptions.shuffled()
        }
    }
}