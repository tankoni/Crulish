//
//  TestProgress.swift
//  en01
//
//  Created by Crulish on 2024/12/24.
//

import Foundation

/// 测试进度信息
struct TestProgress {
    /// 词典文件名
    let dictionaryFileName: String
    
    /// 词典显示名称
    let dictionaryName: String
    
    /// 总单词数
    let totalWords: Int
    
    /// 已测试单词数
    let testedWords: Int
    
    /// 未测试单词数
    let untestedWords: Int
    
    /// 掌握的单词数
    let masteredWords: Int
    
    /// 熟悉的单词数
    let familiarWords: Int
    
    /// 不熟悉的单词数
    let unfamiliarWords: Int
    
    /// 当前单词索引
    let currentIndex: Int
    
    /// 测试进度百分比 (0.0 - 1.0)
    var progressPercentage: Double {
        guard totalWords > 0 else { return 0.0 }
        return Double(testedWords) / Double(totalWords)
    }
    
    /// 掌握率百分比 (0.0 - 1.0)
    var masteryPercentage: Double {
        guard testedWords > 0 else { return 0.0 }
        return Double(masteredWords) / Double(testedWords)
    }
    
    /// 是否已完成测试
    var isCompleted: Bool {
        return untestedWords == 0
    }
    
    /// 格式化的进度文本
    var progressText: String {
        return "\(testedWords)/\(totalWords) (\(Int(progressPercentage * 100))%)"
    }
    
    /// 格式化的掌握率文本
    var masteryText: String {
        return "\(masteredWords)/\(testedWords) (\(Int(masteryPercentage * 100))%)"
    }
}

// MARK: - 扩展方法

extension TestProgress {
    /// 创建空的测试进度
    static func empty(for dictionaryFileName: String, dictionaryName: String) -> TestProgress {
        return TestProgress(
            dictionaryFileName: dictionaryFileName,
            dictionaryName: dictionaryName,
            totalWords: 0,
            testedWords: 0,
            untestedWords: 0,
            masteredWords: 0,
            familiarWords: 0,
            unfamiliarWords: 0,
            currentIndex: 0
        )
    }
    
    /// 从已测试单词列表创建进度信息
    static func from(testedWords: [TestedWord], totalWords: Int, dictionaryFileName: String, dictionaryName: String, currentIndex: Int = 0) -> TestProgress {
        let masteredCount = testedWords.filter { $0.masteryLevel == "mastered" }.count
        let familiarCount = testedWords.filter { $0.masteryLevel == "familiar" }.count
        let unfamiliarCount = testedWords.filter { $0.masteryLevel == "unfamiliar" }.count
        
        return TestProgress(
            dictionaryFileName: dictionaryFileName,
            dictionaryName: dictionaryName,
            totalWords: totalWords,
            testedWords: testedWords.count,
            untestedWords: max(0, totalWords - testedWords.count),
            masteredWords: masteredCount,
            familiarWords: familiarCount,
            unfamiliarWords: unfamiliarCount,
            currentIndex: currentIndex
        )
    }
}