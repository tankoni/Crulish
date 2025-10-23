//
//  WordDefinitionViewModel.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation
import SwiftUI

/// 统一的单词定义查询ViewModel，消除重复代码
@MainActor
class WordDefinitionViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var simpleDefinition: String = ""
    @Published var simplePhonetic: String? = nil
    @Published var detailedDefinition: DetailedWordDefinition?
    @Published var errorMessage: String?
    
    private var dictionaryService: DictionaryServiceProtocol?
    private var lastQueriedWord: String = ""
    private var isQuerying = false
    
    init(dictionaryService: DictionaryServiceProtocol? = nil) {
        self.dictionaryService = dictionaryService
    }
    
    func setDictionaryService(_ service: DictionaryServiceProtocol) {
        self.dictionaryService = service
    }
    
    // MARK: - 简单定义查询（用于弹窗显示）
    /// 加载单词的简单定义（用于tooltip显示）
    func loadDefinition(for word: String) async {
        // 防止重复查询同一个单词
        if word == lastQueriedWord && !simpleDefinition.isEmpty {
            print("[DEBUG][WordDefinitionViewModel] 跳过重复查询: \(word)")
            return
        }
        
        // 防止并发查询
        if isQuerying {
            print("[DEBUG][WordDefinitionViewModel] 正在查询中，跳过: \(word)")
            return
        }
        
        isQuerying = true
        lastQueriedWord = word
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        guard let dictionaryService = dictionaryService else {
            await MainActor.run {
                errorMessage = "词典服务未初始化"
                isLoading = false
                isQuerying = false
            }
            return
        }
        
        // 优先查找考研词典
        if let kaoyanDetails = dictionaryService.getKaoyanWordDetails(word) {
            await MainActor.run {
                simpleDefinition = kaoyanDetails.translations.first?.tranCn ?? "暂无释义"
                let us = kaoyanDetails.usPhone ?? ""
                let uk = kaoyanDetails.ukPhone ?? ""
                simplePhonetic = !us.isEmpty || !uk.isEmpty ? "[US] \(us) [UK] \(uk)" : nil
                isLoading = false
                isQuerying = false
            }
        } else {
            // 回退到普通词典
            if let dictWord = dictionaryService.lookupWord(word, context: ""),
               let definition = dictWord.definitions.first {
                await MainActor.run {
                    simpleDefinition = definition.meaning
                    simplePhonetic = dictWord.phonetic
                    isLoading = false
                    isQuerying = false
                }
            } else {
                await MainActor.run {
                    simpleDefinition = "未找到释义"
                    simplePhonetic = nil
                    isLoading = false
                    isQuerying = false
                }
            }
        }
    }
    
    // MARK: - 详细定义查询（用于详细页面显示）
    func loadDetailedDefinition(for word: String) async {
        guard let dictionaryService = dictionaryService else {
            errorMessage = "服务未初始化"
            return
        }
        
        isLoading = true
        errorMessage = nil
        detailedDefinition = nil
        
        // 优先查找考研词典
        if let kaoyanDetails = dictionaryService.getKaoyanWordDetails(word) {
            detailedDefinition = DetailedWordDefinition(
                word: word,
                isKaoyanWord: true,
                kaoyanDetails: kaoyanDetails,
                basicDefinition: nil,
                masteryLevel: 0, // 默认未掌握
                queryCount: 1, // 默认查询次数为1
                lastViewed: getCurrentTimeString()
            )
        } else {
            // 回退到普通词典
            if let dictWord = dictionaryService.lookupWord(word, context: "") ,
               let definition = dictWord.definitions.first {
                detailedDefinition = DetailedWordDefinition(
                    word: word,
                    isKaoyanWord: false,
                    kaoyanDetails: nil,
                    basicDefinition: definition.meaning,
                    masteryLevel: 0,
                    queryCount: 1,
                    lastViewed: getCurrentTimeString()
                )
            } else {
                detailedDefinition = DetailedWordDefinition(
                    word: word,
                    isKaoyanWord: false,
                    kaoyanDetails: nil,
                    basicDefinition: "未找到释义",
                    masteryLevel: 0,
                    queryCount: 1,
                    lastViewed: getCurrentTimeString()
                )
            }
        }
        
        isLoading = false
    }
    
    // MARK: - 重置状态
    func reset() {
        isLoading = false
        isQuerying = false
        simpleDefinition = ""
        simplePhonetic = nil
        detailedDefinition = nil
        errorMessage = nil
        lastQueriedWord = ""
        print("[DEBUG][WordDefinitionViewModel] 重置状态")
    }
    
    // MARK: - 辅助方法
    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "今天 HH:mm"
        return formatter.string(from: Date())
    }
}