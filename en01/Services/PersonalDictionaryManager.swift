//
//  PersonalDictionaryManager.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import Foundation
import SwiftData

/// 个人学习词典信息
struct PersonalDictionary {
    let id: String
    let name: String
    let description: String
    let wordCount: Int
    let importDate: Date
    let sourceType: DictionarySourceType
}

/// 词典来源类型
enum DictionarySourceType: String, CaseIterable {
    case kaoyan = "考研词汇"
    case custom = "自定义词典"
    case imported = "导入词典"
}

/// 个人学习词典管理器
class PersonalDictionaryManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// 获取用户的个人学习词典列表
    func getPersonalDictionaries() async throws -> [PersonalDictionary] {
        var dictionaries: [PersonalDictionary] = []
        
        // 获取已导入的考研词典
        let kaoyanDictionaries = try await getImportedKaoyanDictionaries()
        dictionaries.append(contentsOf: kaoyanDictionaries)
        
        // 获取用户自定义词典（基于用户查词记录）
        let customDictionary = try await getUserCustomDictionary()
        if let custom = customDictionary {
            dictionaries.append(custom)
        }
        
        return dictionaries
    }
    
    /// 获取已导入的考研词典
    private func getImportedKaoyanDictionaries() async throws -> [PersonalDictionary] {
        var dictionaries: [PersonalDictionary] = []
        
        // 获取所有不同的bookId
        let descriptor = FetchDescriptor<KaoyanWord>()
        let allWords = try modelContext.fetch(descriptor)
        let uniqueBookIds = Set(allWords.map { $0.bookId })
        
        for bookId in uniqueBookIds {
            let wordCount = allWords.filter { $0.bookId == bookId }.count
            
            // 根据bookId获取词典名称
            let dictionaryName = getDictionaryName(for: bookId)
            
            let dictionary = PersonalDictionary(
                id: bookId,
                name: dictionaryName,
                description: "已导入的\(dictionaryName)，共\(wordCount)个单词",
                wordCount: wordCount,
                importDate: Date(), // 实际应该从数据库获取
                sourceType: .kaoyan
            )
            dictionaries.append(dictionary)
        }
        
        return dictionaries
    }
    
    /// 获取用户自定义词典（基于查词记录）
    private func getUserCustomDictionary() async throws -> PersonalDictionary? {
        let descriptor = FetchDescriptor<UserWord>()
        let userWords = try modelContext.fetch(descriptor)
        
        guard !userWords.isEmpty else { return nil }
        
        return PersonalDictionary(
            id: "user_custom",
            name: "我的学习词汇",
            description: "基于阅读记录的个人词汇库，共\(userWords.count)个单词",
            wordCount: userWords.count,
            importDate: userWords.map { $0.firstLookupDate }.min() ?? Date(),
            sourceType: .custom
        )
    }
    
    /// 根据bookId获取词典名称
    private func getDictionaryName(for bookId: String) -> String {
        let dictionaryMap = [
            "kaoyan_1": "考研核心词汇 1",
            "kaoyan_2": "考研核心词汇 2",
            "kaoyan_3": "考研核心词汇 3",
            "kaoyan_luan_1": "考研乱序词汇 1"
        ]
        
        return dictionaryMap[bookId] ?? "未知词典 (\(bookId))"
    }
    
    /// 获取特定词典的单词列表
    func getWordsFromDictionary(_ dictionaryId: String) async throws -> [Any] {
        if dictionaryId == "user_custom" {
            // 返回用户自定义词汇
            let descriptor = FetchDescriptor<UserWord>()
            return try modelContext.fetch(descriptor)
        } else {
            // 返回考研词典词汇
            let descriptor = FetchDescriptor<KaoyanWord>(
                predicate: #Predicate { $0.bookId == dictionaryId }
            )
            return try modelContext.fetch(descriptor)
        }
    }
    
    /// 删除特定词典
    func deleteDictionary(_ dictionaryId: String) async throws {
        if dictionaryId == "user_custom" {
            // 删除用户自定义词汇
            try modelContext.delete(model: UserWord.self)
        } else {
            // 删除特定考研词典
            let descriptor = FetchDescriptor<KaoyanWord>(
                predicate: #Predicate { $0.bookId == dictionaryId }
            )
            let wordsToDelete = try modelContext.fetch(descriptor)
            for word in wordsToDelete {
                modelContext.delete(word)
            }
        }
        
        try modelContext.save()
    }
    
    /// 获取词典统计信息
    func getDictionaryStats(_ dictionaryId: String) async throws -> DictionaryStats {
        if dictionaryId == "user_custom" {
            return try await getUserDictionaryStats()
        } else {
            return try await getKaoyanDictionaryStats(dictionaryId)
        }
    }
    
    /// 获取用户词典统计
    private func getUserDictionaryStats() async throws -> DictionaryStats {
        let descriptor = FetchDescriptor<UserWord>()
        let userWords = try modelContext.fetch(descriptor)
        
        let totalWords = userWords.count
        let masteredWords = userWords.filter { $0.masteryLevel == .mastered }.count
        let familiarWords = userWords.filter { $0.masteryLevel == .familiar }.count
        let unfamiliarWords = userWords.filter { $0.masteryLevel == .unfamiliar }.count
        
        return DictionaryStats(
            totalWords: totalWords,
            masteredWords: masteredWords,
            familiarWords: familiarWords,
            unfamiliarWords: unfamiliarWords,
            averageLookupCount: userWords.isEmpty ? 0 : Double(userWords.map { $0.lookupCount }.reduce(0, +)) / Double(totalWords)
        )
    }
    
    /// 获取考研词典统计
    private func getKaoyanDictionaryStats(_ dictionaryId: String) async throws -> DictionaryStats {
        let descriptor = FetchDescriptor<KaoyanWord>(
            predicate: #Predicate { $0.bookId == dictionaryId }
        )
        let kaoyanWords = try modelContext.fetch(descriptor)
        
        let totalWords = kaoyanWords.count
        
        // 获取用户对这些单词的学习记录
        let userWordDescriptor = FetchDescriptor<UserWord>()
        let userWords = try modelContext.fetch(userWordDescriptor)
        let userWordDict = Dictionary(uniqueKeysWithValues: userWords.map { ($0.word, $0) })
        
        var masteredWords = 0
        var familiarWords = 0
        var unfamiliarWords = 0
        var totalLookupCount = 0
        
        for kaoyanWord in kaoyanWords {
            if let userWord = userWordDict[kaoyanWord.headWord.lowercased()] {
                switch userWord.masteryLevel {
                case .mastered:
                    masteredWords += 1
                case .familiar:
                    familiarWords += 1
                case .unfamiliar:
                    unfamiliarWords += 1
                }
                totalLookupCount += userWord.lookupCount
            } else {
                unfamiliarWords += 1
            }
        }
        
        return DictionaryStats(
            totalWords: totalWords,
            masteredWords: masteredWords,
            familiarWords: familiarWords,
            unfamiliarWords: unfamiliarWords,
            averageLookupCount: totalWords > 0 ? Double(totalLookupCount) / Double(totalWords) : 0
        )
    }
}

/// 词典统计信息
struct DictionaryStats {
    let totalWords: Int
    let masteredWords: Int
    let familiarWords: Int
    let unfamiliarWords: Int
    let averageLookupCount: Double
    
    var masteryPercentage: Double {
        return totalWords > 0 ? Double(masteredWords) / Double(totalWords) * 100 : 0
    }
    
    var familiarPercentage: Double {
        return totalWords > 0 ? Double(familiarWords) / Double(totalWords) * 100 : 0
    }
    
    var unfamiliarPercentage: Double {
        return totalWords > 0 ? Double(unfamiliarWords) / Double(totalWords) * 100 : 0
    }
}