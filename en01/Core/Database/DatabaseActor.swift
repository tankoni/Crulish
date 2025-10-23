//
//  DatabaseActor.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import Foundation
import SwiftData
import OSLog

/// 数据库操作的 ModelActor，用于安全地处理跨线程的 SwiftData 操作
@ModelActor
actor DatabaseActor {
    private let logger = Logger(subsystem: "com.en01.database", category: "DatabaseActor")
    
    /// 加载考研词汇
    func loadKaoyanVocabulary() -> [String: String] {
        var kaoyanDict: [String: String] = [:]
        
        do {
            let descriptor = FetchDescriptor<KaoyanWord>()
            let kaoyanWords = try modelContext.fetch(descriptor)
            
            for word in kaoyanWords {
                // 使用第一个翻译作为主要翻译
                if let firstTranslation = word.translations.first {
                    let chineseTranslation = firstTranslation.tranCn
                    if !chineseTranslation.isEmpty {
                        kaoyanDict[word.headWord.lowercased()] = chineseTranslation
                    }
                }
            }
            
            logger.info("✅ 成功加载考研词汇: \(kaoyanDict.count)个")
        } catch {
            logger.error("❌ 加载考研词汇失败: \(error.localizedDescription)")
        }
        
        return kaoyanDict
    }
    
    /// 加载用户词汇
    func loadUserVocabulary() -> [String: String] {
        var userDict: [String: String] = [:]
        
        do {
            // 加载DictionaryWord
            let dictionaryDescriptor = FetchDescriptor<DictionaryWord>()
            let dictionaryWords = try modelContext.fetch(dictionaryDescriptor)
            
            for word in dictionaryWords {
                if let firstDefinition = word.definitions.first {
                    let chineseDefinition = firstDefinition.meaning
                    if !chineseDefinition.isEmpty {
                        userDict[word.word.lowercased()] = chineseDefinition
                    }
                }
            }
            
            // 加载UserWord
            let userDescriptor = FetchDescriptor<UserWord>()
            let userWords = try modelContext.fetch(userDescriptor)
            
            for word in userWords {
                if let selectedDefinition = word.selectedDefinition {
                    let meaning = selectedDefinition.meaning
                    if !meaning.isEmpty {
                        userDict[word.word.lowercased()] = meaning
                    }
                }
            }
            
            logger.info("✅ 成功加载用户词汇: \(userDict.count)个")
        } catch {
            logger.error("❌ 加载用户词汇失败: \(error.localizedDescription)")
        }
        
        return userDict
    }
    
    /// 查找考研单词
    func findKaoyanWord(_ word: String) -> KaoyanWord? {
        do {
            let lowercasedWord = word.lowercased()
            let predicate = #Predicate<KaoyanWord> { kaoyanWord in
                kaoyanWord.headWord == lowercasedWord
            }
            let descriptor = FetchDescriptor<KaoyanWord>(predicate: predicate)
            let words = try modelContext.fetch(descriptor)
            
            // 如果没有找到精确匹配，尝试不区分大小写的搜索
            if words.isEmpty {
                let allWords = try modelContext.fetch(FetchDescriptor<KaoyanWord>())
                return allWords.first { $0.headWord.lowercased() == lowercasedWord }
            }
            
            return words.first
        } catch {
            logger.error("查找考研单词失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 查找用户词汇
    func findUserWord(_ word: String) -> UserWord? {
        do {
            let lowercasedWord = word.lowercased()
            let predicate = #Predicate<UserWord> { userWord in
                userWord.word == lowercasedWord
            }
            let descriptor = FetchDescriptor<UserWord>(predicate: predicate)
            let words = try modelContext.fetch(descriptor)
            
            // 如果没有找到精确匹配，尝试不区分大小写的搜索
            if words.isEmpty {
                let allWords = try modelContext.fetch(FetchDescriptor<UserWord>())
                return allWords.first { $0.word.lowercased() == lowercasedWord }
            }
            
            return words.first
        } catch {
            logger.error("查找用户词汇失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 查找词典单词
    func findDictionaryWord(_ word: String) -> DictionaryWord? {
        do {
            let lowercasedWord = word.lowercased()
            let predicate = #Predicate<DictionaryWord> { dictionaryWord in
                dictionaryWord.word == lowercasedWord
            }
            let descriptor = FetchDescriptor<DictionaryWord>(predicate: predicate)
            let words = try modelContext.fetch(descriptor)
            
            // 如果没有找到精确匹配，尝试不区分大小写的搜索
            if words.isEmpty {
                let allWords = try modelContext.fetch(FetchDescriptor<DictionaryWord>())
                return allWords.first { $0.word.lowercased() == lowercasedWord }
            }
            
            return words.first
        } catch {
            logger.error("查找词典单词失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 保存翻译记录
    func saveTranslationRecord(_ translation: Translation, context: String = "") {
        do {
            let record = TranslationRecord(
                originalText: translation.originalText,
                translatedText: translation.translatedText,
                sourceLanguage: translation.sourceLanguage,
                targetLanguage: translation.targetLanguage,
                confidence: translation.confidence,
                provider: translation.provider,
                contextualMeaning: translation.contextualMeaning,
                grammarAnalysis: translation.grammarAnalysis,
                wordContext: context
            )
            
            modelContext.insert(record)
            try modelContext.save()
            logger.info("翻译记录保存成功")
        } catch {
            logger.error("保存翻译记录失败: \(error.localizedDescription)")
        }
    }
    
    /// 更新翻译使用次数
    func updateTranslationUsage(_ translation: Translation) {
        do {
            let predicate = #Predicate<TranslationRecord> { record in
                record.originalText == translation.originalText &&
                record.translatedText == translation.translatedText
            }
            
            let descriptor = FetchDescriptor<TranslationRecord>(predicate: predicate)
            let records = try modelContext.fetch(descriptor)
            
            if let record = records.first {
                record.incrementUsage()
                try modelContext.save()
                logger.info("翻译使用次数更新成功")
            }
        } catch {
            logger.error("更新翻译使用次数失败: \(error.localizedDescription)")
        }
    }
    
    /// 记录翻译统计
    func recordTranslationStatistics(
        type: TranslationType,
        provider: TranslationProvider,
        confidence: Double
    ) {
        do {
            let today = Date()
            let startOfDay = Calendar.current.startOfDay(for: today)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
            let predicate = #Predicate<TranslationStatistics> { stats in
                stats.date >= startOfDay && stats.date < endOfDay
            }
            
            let descriptor = FetchDescriptor<TranslationStatistics>(predicate: predicate)
            let existingStats = try modelContext.fetch(descriptor)
            let stats = existingStats.first ?? TranslationStatistics(date: today)
            
            if existingStats.isEmpty {
                modelContext.insert(stats)
            }
            
            stats.incrementTranslation(type: type, provider: provider, confidence: confidence)
            try modelContext.save()
            logger.info("翻译统计记录成功")
        } catch {
            logger.error("记录翻译统计失败: \(error.localizedDescription)")
        }
    }
}