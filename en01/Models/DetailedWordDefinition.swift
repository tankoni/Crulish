//
//  DetailedWordDefinition.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation

// MARK: - 详细词汇定义数据模型

/// 详细单词定义结构体
struct DetailedWordDefinition {
    let word: String
    let isKaoyanWord: Bool
    let kaoyanDetails: KaoyanWordDetails?
    let basicDefinition: String?
    let masteryLevel: Int?
    let queryCount: Int?
    let lastViewed: String?
    
    var displayTitle: String {
        return word
    }
    
    var displaySubtitle: String {
        return isKaoyanWord ? "考研词汇" : "普通词汇"
    }
    
    var hasPhonetics: Bool {
        return kaoyanDetails?.usPhone != nil || kaoyanDetails?.ukPhone != nil
    }
    
    var pronunciation: String? {
        if let usPhone = kaoyanDetails?.usPhone {
            return "/\(usPhone)/"
        } else if let ukPhone = kaoyanDetails?.ukPhone {
            return "/\(ukPhone)/"
        }
        return nil
    }
    
    var partOfSpeech: String? {
        guard let firstTranslation = kaoyanDetails?.translations.first else {
            return nil
        }
        return "\(firstTranslation.pos). \(firstTranslation.tranCn)"
    }
    
    var usPhonetic: String? {
        return kaoyanDetails?.usPhone
    }
    
    var ukPhonetic: String? {
        return kaoyanDetails?.ukPhone
    }
    
    var translations: [String] {
        return kaoyanDetails?.translations.map { "\($0.pos). \($0.tranCn)" } ?? []
    }
    
    var sentences: [KaoyanWordSentence] {
        return kaoyanDetails?.sentences ?? []
    }
    
    var synonyms: [KaoyanWordSynonym] {
        return kaoyanDetails?.synonyms ?? []
    }
    
    var phrases: [KaoyanWordPhrase] {
        return kaoyanDetails?.phrases ?? []
    }
    
    var relatedWords: [KaoyanWordRelated] {
        return kaoyanDetails?.relatedWords ?? []
    }
}

// MARK: - 考研词典数据结构

/// 考研词典例句
struct KaoyanWordSentence {
    let sContent: String
    let sCn: String
}

/// 考研词典同义词
struct KaoyanWordSynonym {
    let pos: String
    let tran: String
    let synonymWords: [String]
}

/// 考研词典短语
struct KaoyanWordPhrase {
    let pContent: String
    let pCn: String
}

/// 考研词典相关词汇
struct KaoyanWordRelated {
    let pos: String
    let hwd: String
    let tran: String
}

/// 考研词典翻译
struct KaoyanWordTranslation {
    let pos: String
    let tranCn: String
    let tranOther: String?
}

/// 考研词典详细信息
struct KaoyanWordDetails {
    let word: String
    let wordRank: Int
    let bookId: String
    let usPhone: String?
    let ukPhone: String?
    let translations: [KaoyanWordTranslation]
    let sentences: [KaoyanWordSentence]
    let synonyms: [KaoyanWordSynonym]
    let phrases: [KaoyanWordPhrase]
    let relatedWords: [KaoyanWordRelated]
}