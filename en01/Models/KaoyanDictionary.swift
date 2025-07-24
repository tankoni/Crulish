//
//  KaoyanDictionary.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import Foundation
import SwiftData

// MARK: - 考研词典数据模型

/// 考研词典单词模型
@Model
class KaoyanWord {
    @Attribute(.unique) var wordId: String
    var wordRank: Int
    var headWord: String
    var bookId: String
    
    // 基本信息
    var usPhone: String?
    var ukPhone: String?
    var usPhoneParam: String?
    var ukPhoneParam: String?
    
    // 翻译信息
    var translations: [KaoyanTranslation]
    
    // 例句
    var sentences: [KaoyanSentence]
    
    // 同近义词
    var synonyms: [KaoyanSynonym]
    
    // 短语
    var phrases: [KaoyanPhrase]
    
    // 同根词
    var relatedWords: [KaoyanRelatedWord]
    
    // 考试题目
    var exams: [KaoyanExam]
    
    init(wordId: String, wordRank: Int, headWord: String, bookId: String) {
        self.wordId = wordId
        self.wordRank = wordRank
        self.headWord = headWord
        self.bookId = bookId
        self.translations = []
        self.sentences = []
        self.synonyms = []
        self.phrases = []
        self.relatedWords = []
        self.exams = []
    }
}

/// 翻译信息
@Model
class KaoyanTranslation {
    var pos: String // 词性
    var tranCn: String // 中文释义
    var tranOther: String? // 英英释义
    var descCn: String?
    var descOther: String?
    
    @Relationship(inverse: \KaoyanWord.translations)
    var word: KaoyanWord?
    
    init(pos: String, tranCn: String, tranOther: String? = nil, descCn: String? = nil, descOther: String? = nil) {
        self.pos = pos
        self.tranCn = tranCn
        self.tranOther = tranOther
        self.descCn = descCn
        self.descOther = descOther
    }
}

/// 例句
@Model
class KaoyanSentence {
    var sContent: String // 英文例句
    var sCn: String // 中文翻译
    
    @Relationship(inverse: \KaoyanWord.sentences)
    var word: KaoyanWord?
    
    init(sContent: String, sCn: String) {
        self.sContent = sContent
        self.sCn = sCn
    }
}

/// 同近义词
@Model
class KaoyanSynonym {
    var pos: String // 词性
    var tran: String // 对应词义
    var synonymWords: [String] // 同近义词列表
    
    @Relationship(inverse: \KaoyanWord.synonyms)
    var word: KaoyanWord?
    
    init(pos: String, tran: String, synonymWords: [String]) {
        self.pos = pos
        self.tran = tran
        self.synonymWords = synonymWords
    }
}

/// 短语
@Model
class KaoyanPhrase {
    var pContent: String // 英文短语
    var pCn: String // 中文翻译
    
    @Relationship(inverse: \KaoyanWord.phrases)
    var word: KaoyanWord?
    
    init(pContent: String, pCn: String) {
        self.pContent = pContent
        self.pCn = pCn
    }
}

/// 同根词
@Model
class KaoyanRelatedWord {
    var pos: String // 词性
    var hwd: String // 单词
    var tran: String // 翻译
    
    @Relationship(inverse: \KaoyanWord.relatedWords)
    var word: KaoyanWord?
    
    init(pos: String, hwd: String, tran: String) {
        self.pos = pos
        self.hwd = hwd
        self.tran = tran
    }
}

/// 考试题目
@Model
class KaoyanExam {
    var question: String // 题目
    var examType: Int // 考试类型
    var rightIndex: Int // 正确答案索引
    var explain: String // 解释
    var choices: [KaoyanChoice] // 选项
    
    @Relationship(inverse: \KaoyanWord.exams)
    var word: KaoyanWord?
    
    init(question: String, examType: Int, rightIndex: Int, explain: String) {
        self.question = question
        self.examType = examType
        self.rightIndex = rightIndex
        self.explain = explain
        self.choices = []
    }
}

/// 考试选项
@Model
class KaoyanChoice {
    var choiceIndex: Int
    var choice: String
    
    @Relationship(inverse: \KaoyanExam.choices)
    var exam: KaoyanExam?
    
    init(choiceIndex: Int, choice: String) {
        self.choiceIndex = choiceIndex
        self.choice = choice
    }
}

// MARK: - JSON解析模型

/// 用于解析JSON的临时结构体
struct KaoyanWordJSON: Codable {
    let wordRank: Int
    let headWord: String
    let content: KaoyanContentJSON
    let bookId: String
}

struct KaoyanContentJSON: Codable {
    let word: KaoyanWordDetailJSON
}

struct KaoyanWordDetailJSON: Codable {
    let wordHead: String
    let wordId: String
    let content: KaoyanWordContentJSON
}

struct KaoyanWordContentJSON: Codable {
    let exam: [KaoyanExamJSON]?
    let sentence: KaoyanSentenceGroupJSON?
    let usphone: String?
    let syno: KaoyanSynonymGroupJSON?
    let ukphone: String?
    let ukspeech: String?
    let phrase: KaoyanPhraseGroupJSON?
    let relWord: KaoyanRelatedWordGroupJSON?
    let usspeech: String?
    let trans: [KaoyanTranslationJSON]?
}

struct KaoyanExamJSON: Codable {
    let question: String
    let answer: KaoyanAnswerJSON
    let examType: Int
    let choices: [KaoyanChoiceJSON]
}

struct KaoyanAnswerJSON: Codable {
    let explain: String
    let rightIndex: Int
}

struct KaoyanChoiceJSON: Codable {
    let choiceIndex: Int
    let choice: String
}

struct KaoyanSentenceGroupJSON: Codable {
    let sentences: [KaoyanSentenceJSON]
    let desc: String
}

struct KaoyanSentenceJSON: Codable {
    let sContent: String
    let sCn: String
}

struct KaoyanSynonymGroupJSON: Codable {
    let synos: [KaoyanSynonymJSON]
    let desc: String
}

struct KaoyanSynonymJSON: Codable {
    let pos: String
    let tran: String
    let hwds: [KaoyanSynonymWordJSON]
}

struct KaoyanSynonymWordJSON: Codable {
    let w: String
}

struct KaoyanPhraseGroupJSON: Codable {
    let phrases: [KaoyanPhraseJSON]
    let desc: String
}

struct KaoyanPhraseJSON: Codable {
    let pContent: String
    let pCn: String
}

struct KaoyanRelatedWordGroupJSON: Codable {
    let rels: [KaoyanRelatedWordJSON]
    let desc: String
}

struct KaoyanRelatedWordJSON: Codable {
    let pos: String
    let words: [KaoyanRelatedWordDetailJSON]
}

struct KaoyanRelatedWordDetailJSON: Codable {
    let hwd: String
    let tran: String
}

struct KaoyanTranslationJSON: Codable {
    let tranCn: String
    let descOther: String?
    let pos: String
    let descCn: String?
    let tranOther: String?
}