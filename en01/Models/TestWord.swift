//
//  TestWord.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation

// MARK: - 词汇测试单词数据模型

/// 用于词汇量测试的单词数据结构
struct TestWord: Identifiable, Codable {
    let id: UUID
    let word: String
    let pronunciation: String?
    let definitions: [String]
    let examples: [String]?
    let difficulty: WordDifficulty
    let frequency: Int
    
    init(word: String, pronunciation: String? = nil, definitions: [String], examples: [String]? = nil, difficulty: WordDifficulty = .medium, frequency: Int = 1) {
        self.id = UUID()
        self.word = word
        self.pronunciation = pronunciation
        self.definitions = definitions
        self.examples = examples
        self.difficulty = difficulty
        self.frequency = frequency
    }
    
    // 自定义编码解码以处理UUID
    enum CodingKeys: String, CodingKey {
        case id, word, pronunciation, definitions, examples, difficulty, frequency
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.word = try container.decode(String.self, forKey: .word)
        self.pronunciation = try container.decodeIfPresent(String.self, forKey: .pronunciation)
        self.definitions = try container.decode([String].self, forKey: .definitions)
        self.examples = try container.decodeIfPresent([String].self, forKey: .examples)
        self.difficulty = try container.decode(WordDifficulty.self, forKey: .difficulty)
        self.frequency = try container.decode(Int.self, forKey: .frequency)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(word, forKey: .word)
        try container.encodeIfPresent(pronunciation, forKey: .pronunciation)
        try container.encode(definitions, forKey: .definitions)
        try container.encodeIfPresent(examples, forKey: .examples)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(frequency, forKey: .frequency)
    }
    
    /// 从DictionaryWordData创建TestWord
    init(from dictionaryWord: DictionaryWordData) {
        self.id = UUID()
        self.word = dictionaryWord.word
        self.pronunciation = dictionaryWord.phonetic
        self.definitions = dictionaryWord.definitions.map { $0.meaning }
        self.examples = dictionaryWord.definitions.flatMap { $0.examples }
        self.difficulty = dictionaryWord.difficulty
        self.frequency = dictionaryWord.frequency
    }
    
    /// 主要释义（第一个释义）
    var primaryDefinition: String {
        definitions.first ?? "暂无释义"
    }
    
    /// 格式化的音标
    var formattedPronunciation: String {
        if let pronunciation = pronunciation, !pronunciation.isEmpty {
            return pronunciation.hasPrefix("/") ? pronunciation : "/\(pronunciation)/"
        }
        return ""
    }
}

// MARK: - 预览数据

extension TestWord {
    static let preview = TestWord(
        word: "example",
        pronunciation: "/ɪɡˈzæmpəl/",
        definitions: ["例子；实例", "榜样；典型"],
        examples: ["For example, this is a sample sentence."],
        difficulty: .medium,
        frequency: 5
    )
    
    static let previewList = [
        TestWord(
            word: "apple",
            pronunciation: "/ˈæpəl/",
            definitions: ["苹果"],
            examples: ["I eat an apple every day."],
            difficulty: .basic,
            frequency: 8
        ),
        TestWord(
            word: "sophisticated",
            pronunciation: "/səˈfɪstɪkeɪtɪd/",
            definitions: ["复杂的；精密的", "老练的；见多识广的"],
            examples: ["This is a sophisticated system."],
            difficulty: .advanced,
            frequency: 2
        )
    ]
}