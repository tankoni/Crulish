//
//  YoudaoDictionaryParser.swift
//  en01
//
//  Created by SOLO Coding on 2025/01/26.
//

import Foundation
import OSLog

/// 有道词典解析器
/// 用于解析有道词典的JSON格式并转换为应用内部的DictionaryWord格式
class YoudaoDictionaryParser {
    private let logger = Logger(subsystem: "com.crulish.en01", category: "YoudaoDictionaryParser")
    
    /// 解析有道词典文件
    /// - Parameter fileURL: 词典文件URL
    /// - Returns: 解析后的词典信息和单词列表
    @MainActor
    func parseDictionaryFile(_ fileURL: URL) async throws -> (DictionaryInfo, [DictionaryWord]) {
        logger.info("开始解析有道词典文件: \(fileURL.lastPathComponent)")
        
        do {
            // 读取文件内容
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            logger.info("文件包含 \(lines.count) 行数据")
            
            var words: [DictionaryWord] = []
            var parseErrors = 0
            
            // 逐行解析JSON
            for (index, line) in lines.enumerated() {
                do {
                    let youdaoWord = try parseYoudaoWordLine(line)
                    if let dictionaryWord = convertToDictionaryWord(youdaoWord) {
                        words.append(dictionaryWord)
                    }
                } catch {
                    parseErrors += 1
                    logger.warning("解析第 \(index + 1) 行失败: \(error.localizedDescription)")
                    // 继续解析其他行，不因单行错误而中断
                }
            }
            
            logger.info("成功解析 \(words.count) 个单词，失败 \(parseErrors) 个")
            
            // 创建词典信息
            let dictionaryInfo = createDictionaryInfo(from: fileURL, wordCount: words.count)
            
            return (dictionaryInfo, words)
        } catch {
            logger.error("解析词典文件失败: \(error.localizedDescription)")
            throw YoudaoParserError.fileReadError(error.localizedDescription)
        }
    }
    
    /// 解析单行有道词典JSON
    private func parseYoudaoWordLine(_ line: String) throws -> YoudaoWord {
        guard let data = line.data(using: .utf8) else {
            throw YoudaoParserError.invalidEncoding
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(YoudaoWord.self, from: data)
    }
    
    /// 将有道词典格式转换为应用内部格式
    private func convertToDictionaryWord(_ youdaoWord: YoudaoWord) -> DictionaryWord? {
        guard let content = youdaoWord.content?.word?.content else {
            logger.warning("单词 \(youdaoWord.headWord) 缺少内容数据")
            return nil
        }
        
        // 提取音标
        let phonetic = extractPhonetic(from: content)
        
        // 提取词义和例句
        let definitions = extractDefinitions(from: content)
        
        // 确定难度级别
        let difficulty = determineDifficulty(from: youdaoWord.bookId)
        
        // 提取标签
        let tags = extractTags(from: youdaoWord.bookId)
        
        return DictionaryWord(
            word: youdaoWord.headWord,
            phonetic: phonetic,
            definitions: definitions,
            frequency: youdaoWord.wordRank,
            difficulty: difficulty,
            tags: tags,
            categories: extractCategories(from: youdaoWord.bookId)
        )
    }
    
    /// 提取音标信息
    private func extractPhonetic(from content: YoudaoWordContent) -> String? {
        // 优先使用美音，其次英音
        return content.usphone ?? content.ukphone ?? content.phone
    }
    
    /// 提取词义定义
    private func extractDefinitions(from content: YoudaoWordContent) -> [WordDefinition] {
        var definitions: [WordDefinition] = []
        
        // 从trans字段提取主要词义
        if let trans = content.trans {
            for translation in trans {
                let partOfSpeech = mapPartOfSpeech(translation.pos)
                let meaning = translation.tranCn
                let englishMeaning = translation.tranOther
                
                // 提取例句
                let examples = extractExamples(from: content)
                
                // 提取上下文关键词
                let contextKeywords = extractContextKeywords(from: content)
                
                let definition = WordDefinition(
                    partOfSpeech: partOfSpeech,
                    meaning: meaning,
                    englishMeaning: englishMeaning,
                    examples: examples,
                    contextKeywords: contextKeywords
                )
                
                definitions.append(definition)
            }
        }
        
        // 如果没有找到词义，创建一个默认的
        if definitions.isEmpty {
            definitions.append(WordDefinition(
                partOfSpeech: .noun,
                meaning: "暂无释义",
                englishMeaning: nil,
                examples: extractExamples(from: content),
                contextKeywords: []
            ))
        }
        
        return definitions
    }
    
    /// 提取例句
    private func extractExamples(from content: YoudaoWordContent) -> [String] {
        var examples: [String] = []
        
        // 从sentence字段提取例句
        if let sentence = content.sentence {
            for sentenceItem in sentence.sentences {
                examples.append(sentenceItem.sContent)
            }
        }
        
        return examples
    }
    
    /// 提取上下文关键词
    private func extractContextKeywords(from content: YoudaoWordContent) -> [String] {
        var keywords: [String] = []
        
        // 从短语中提取关键词
        if let phrase = content.phrase {
            for phraseItem in phrase.phrases {
                keywords.append(phraseItem.pContent)
            }
        }
        
        // 从同义词中提取关键词
        if let syno = content.syno {
            for synoItem in syno.synos {
                for hwd in synoItem.hwds {
                    keywords.append(hwd.w)
                }
            }
        }
        
        return keywords
    }
    
    /// 映射词性
    private func mapPartOfSpeech(_ pos: String?) -> PartOfSpeech {
        guard let pos = pos?.lowercased() else { return .noun }
        
        switch pos {
        case "n", "noun":
            return .noun
        case "v", "verb", "vt", "vi":
            return .verb
        case "adj", "adjective":
            return .adjective
        case "adv", "adverb":
            return .adverb
        case "prep", "preposition":
            return .preposition
        case "conj", "conjunction":
            return .conjunction
        case "pron", "pronoun":
            return .pronoun
        case "int", "interjection":
            return .interjection
        case "art", "article":
            return .article
        default:
            return .noun
        }
    }
    
    /// 根据bookId确定难度级别
    private func determineDifficulty(from bookId: String) -> WordDifficulty {
        let bookIdLower = bookId.lowercased()
        
        if bookIdLower.contains("cet4") {
            return .basic
        } else if bookIdLower.contains("cet6") {
            return .medium
        } else if bookIdLower.contains("kaoyan") {
            return .advanced
        } else if bookIdLower.contains("gre") || bookIdLower.contains("toefl") {
            return .expert
        } else {
            return .basic
        }
    }
    
    /// 提取标签
    private func extractTags(from bookId: String) -> [String] {
        var tags: [String] = []
        
        let bookIdLower = bookId.lowercased()
        
        if bookIdLower.contains("cet4") {
            tags.append("CET4")
        }
        if bookIdLower.contains("cet6") {
            tags.append("CET6")
        }
        if bookIdLower.contains("kaoyan") {
            tags.append("考研")
        }
        if bookIdLower.contains("gre") {
            tags.append("GRE")
        }
        if bookIdLower.contains("toefl") {
            tags.append("TOEFL")
        }
        
        if tags.isEmpty {
            tags.append("通用词汇")
        }
        
        return tags
    }
    
    /// 创建词典信息
    private func createDictionaryInfo(from fileURL: URL, wordCount: Int) -> DictionaryInfo {
        let fileName = fileURL.lastPathComponent
        let name = fileURL.deletingPathExtension().lastPathComponent
        
        // 根据文件名生成显示名称
        let displayName = generateDisplayName(from: name)
        
        // 获取文件大小
        let fileSize = getFileSize(fileURL)
        
        return DictionaryInfo(
            name: name,
            displayName: displayName,
            fileName: fileName,
            filePath: fileURL.path,
            version: "1.0",
            description: "有道词典 - \(displayName)",
            language: "en",
            totalWords: wordCount,
            difficultyLevels: [1, 2, 3, 4],
            categories: extractCategories(from: name),
            fileSize: fileSize,
            checksum: "",
            isEnabled: true,
            priority: 0
        )
    }
    
    /// 生成显示名称
    private func generateDisplayName(from name: String) -> String {
        let nameLower = name.lowercased()
        
        if nameLower.contains("cet4") {
            return "大学英语四级词汇"
        } else if nameLower.contains("cet6") {
            return "大学英语六级词汇"
        } else if nameLower.contains("kaoyan") {
            return "考研英语词汇"
        } else if nameLower.contains("gre") {
            return "GRE词汇"
        } else if nameLower.contains("toefl") {
            return "TOEFL词汇"
        } else {
            return name
        }
    }
    
    /// 提取分类
    private func extractCategories(from name: String) -> [String] {
        var categories: [String] = []
        
        let nameLower = name.lowercased()
        
        if nameLower.contains("cet") {
            categories.append("大学英语")
        }
        if nameLower.contains("kaoyan") {
            categories.append("考研")
        }
        if nameLower.contains("gre") || nameLower.contains("toefl") {
            categories.append("出国考试")
        }
        
        if categories.isEmpty {
            categories.append("通用")
        }
        
        return categories
    }
    
    /// 获取文件大小
    private func getFileSize(_ fileURL: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            logger.warning("无法获取文件大小: \(error.localizedDescription)")
            return 0
        }
    }
}

// MARK: - 有道词典数据结构

/// 有道词典单词结构
struct YoudaoWord: Codable {
    let wordRank: Int
    let headWord: String
    let content: YoudaoWordWrapper?
    let bookId: String
}

/// 有道词典内容包装器
struct YoudaoWordWrapper: Codable {
    let word: YoudaoWordDetail?
}

/// 有道词典单词详情
struct YoudaoWordDetail: Codable {
    let wordHead: String
    let wordId: String
    let content: YoudaoWordContent
}

/// 有道词典单词内容
struct YoudaoWordContent: Codable {
    let sentence: YoudaoSentence?
    let usphone: String?
    let syno: YoudaoSynonym?
    let ukphone: String?
    let ukspeech: String?
    let phrase: YoudaoPhrase?
    let phone: String?
    let relWord: YoudaoRelatedWord?
    let usspeech: String?
    let trans: [YoudaoTranslation]?
}

/// 有道词典例句
struct YoudaoSentence: Codable {
    let sentences: [YoudaoSentenceItem]
    let desc: String
}

/// 有道词典例句项
struct YoudaoSentenceItem: Codable {
    let sContent: String
    let sCn: String
}

/// 有道词典同义词
struct YoudaoSynonym: Codable {
    let synos: [YoudaoSynonymItem]
    let desc: String
}

/// 有道词典同义词项
struct YoudaoSynonymItem: Codable {
    let pos: String
    let tran: String
    let hwds: [YoudaoSynonymWord]
}

/// 有道词典同义词单词
struct YoudaoSynonymWord: Codable {
    let w: String
}

/// 有道词典短语
struct YoudaoPhrase: Codable {
    let phrases: [YoudaoPhraseItem]
    let desc: String
}

/// 有道词典短语项
struct YoudaoPhraseItem: Codable {
    let pContent: String
    let pCn: String
}

/// 有道词典相关词
struct YoudaoRelatedWord: Codable {
    let rels: [YoudaoRelatedWordItem]
    let desc: String
}

/// 有道词典相关词项
struct YoudaoRelatedWordItem: Codable {
    let pos: String
    let words: [YoudaoRelatedWordDetail]
}

/// 有道词典相关词详情
struct YoudaoRelatedWordDetail: Codable {
    let hwd: String
    let tran: String
}

/// 有道词典翻译
struct YoudaoTranslation: Codable {
    let tranCn: String
    let descOther: String?
    let pos: String?
    let descCn: String?
    let tranOther: String?
}

// MARK: - 错误定义

/// 有道词典解析错误
enum YoudaoParserError: LocalizedError {
    case fileReadError(String)
    case invalidEncoding
    case jsonParseError(String)
    case missingContent
    case invalidWordFormat
    
    var errorDescription: String? {
        switch self {
        case .fileReadError(let details):
            return "文件读取错误: \(details)"
        case .invalidEncoding:
            return "文件编码无效"
        case .jsonParseError(let details):
            return "JSON解析错误: \(details)"
        case .missingContent:
            return "缺少单词内容"
        case .invalidWordFormat:
            return "单词格式无效"
        }
    }
}