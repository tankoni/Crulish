//
//  KaoyanDictionaryImporter.swift
//  en01
//
//  Created by Assistant on 2024-12-19.
//

import Foundation
import SwiftData

/// 词典库信息
struct DictionaryInfo {
    let id: String
    let name: String
    let fileName: String
    let description: String
    let wordCount: Int
    let isImported: Bool
    
    static let availableDictionaries = [
        DictionaryInfo(id: "kaoyan_1", name: "考研核心词汇 1", fileName: "KaoYan_1.json", description: "考研英语核心词汇第一册", wordCount: 1500, isImported: false),
        DictionaryInfo(id: "kaoyan_2", name: "考研核心词汇 2", fileName: "KaoYan_2.json", description: "考研英语核心词汇第二册", wordCount: 1500, isImported: false),
        DictionaryInfo(id: "kaoyan_3", name: "考研核心词汇 3", fileName: "KaoYan_3.json", description: "考研英语核心词汇第三册", wordCount: 1500, isImported: false),
        DictionaryInfo(id: "kaoyan_luan_1", name: "考研乱序词汇 1", fileName: "KaoYanluan_1.json", description: "考研英语乱序词汇第一册", wordCount: 2000, isImported: false)
    ]
}

/// 考研词典导入服务
class KaoyanDictionaryImporter {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// 获取可用的词典列表
    func getAvailableDictionaries() async throws -> [DictionaryInfo] {
        var dictionaries = DictionaryInfo.availableDictionaries
        
        // 检查每个词典的导入状态
        for i in 0..<dictionaries.count {
            let isImported = try await isDictionaryImported(dictionaries[i].id)
            dictionaries[i] = DictionaryInfo(
                id: dictionaries[i].id,
                name: dictionaries[i].name,
                fileName: dictionaries[i].fileName,
                description: dictionaries[i].description,
                wordCount: dictionaries[i].wordCount,
                isImported: isImported
            )
        }
        
        return dictionaries
    }
    
    /// 检查特定词典是否已导入
    private func isDictionaryImported(_ dictionaryId: String) async throws -> Bool {
        let descriptor = FetchDescriptor<KaoyanWord>(
            predicate: #Predicate { $0.bookId == dictionaryId }
        )
        let count = try modelContext.fetchCount(descriptor)
        return count > 0
    }
    
    /// 导入选定的词典
    func importSelectedDictionaries(_ dictionaryIds: [String]) async throws {
        let availableDictionaries = DictionaryInfo.availableDictionaries
        let selectedDictionaries = availableDictionaries.filter { dictionaryIds.contains($0.id) }
        
        print("[INFO][KaoyanDictionaryImporter] 准备导入 \(selectedDictionaries.count) 个词典文件")
        
        for dictionary in selectedDictionaries {
            // 检查是否已导入
            let isImported = try await isDictionaryImported(dictionary.id)
            if isImported {
                print("[INFO][KaoyanDictionaryImporter] 词典 \(dictionary.name) 已导入，跳过")
                continue
            }
            
            print("[INFO][KaoyanDictionaryImporter] 开始导入词典: \(dictionary.name)")
            try await importDictionary(fileName: dictionary.fileName, dictionaryId: dictionary.id)
        }
        
        print("[INFO][KaoyanDictionaryImporter] 选定词典导入完成")
    }
    
    /// 导入所有考研词典文件（保持向后兼容）
    func importAllDictionaries() async throws {
        let allDictionaryIds = DictionaryInfo.availableDictionaries.map { $0.id }
        try await importSelectedDictionaries(allDictionaryIds)
    }
    
    /// 导入单个词典文件
    func importDictionary(fileName: String, dictionaryId: String? = nil) async throws {
        let resourceName = fileName.replacingOccurrences(of: ".json", with: "")
        print("[INFO][KaoyanDictionaryImporter] 查找文件: \(resourceName).json 在 bundle 根目录")
        
        guard let fileURL = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            print("[ERROR][KaoyanDictionaryImporter] 找不到文件: \(fileName) 在 bundle 根目录")
            
            // 尝试列出bundle根目录下的所有JSON文件
            if let resourcesPath = Bundle.main.resourcePath {
                print("[DEBUG][KaoyanDictionaryImporter] Bundle根目录路径: \(resourcesPath)")
                
                do {
                    let files = try FileManager.default.contentsOfDirectory(atPath: resourcesPath)
                    let jsonFiles = files.filter { $0.hasSuffix(".json") }
                    print("[DEBUG][KaoyanDictionaryImporter] Bundle根目录中的JSON文件: \(jsonFiles)")
                } catch {
                    print("[ERROR][KaoyanDictionaryImporter] 无法读取bundle根目录内容: \(error)")
                }
            }
            
            throw ImportError.fileNotFound(fileName)
        }
        
        print("[INFO][KaoyanDictionaryImporter] 找到文件: \(fileURL.path)")
        
        let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = fileContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        print("开始导入 \(fileName)，共 \(lines.count) 个单词")
        
        for (index, line) in lines.enumerated() {
            do {
                let processedLine = replaceFrenchCharacters(line)
                let wordData = try JSONDecoder().decode(KaoyanWordJSON.self, from: processedLine.data(using: .utf8)!)
                
                // 检查是否已存在
                let existingWord = try await findExistingWord(wordId: wordData.content.word.wordId)
                if existingWord != nil {
                    continue // 跳过已存在的单词
                }
                
                let kaoyanWord = createKaoyanWord(from: wordData, dictionaryId: dictionaryId)
                modelContext.insert(kaoyanWord)
                
                // 每100个单词保存一次
                if (index + 1) % 100 == 0 {
                    try modelContext.save()
                    print("已导入 \(index + 1)/\(lines.count) 个单词")
                }
            } catch {
                print("导入第 \(index + 1) 行失败: \(error)")
                continue
            }
        }
        
        // 最终保存
        try modelContext.save()
        print("\(fileName) 导入完成")
    }
    
    /// 查找已存在的单词
    private func findExistingWord(wordId: String) async throws -> KaoyanWord? {
        let descriptor = FetchDescriptor<KaoyanWord>(
            predicate: #Predicate { $0.wordId == wordId }
        )
        let results = try modelContext.fetch(descriptor)
        return results.first
    }
    
    /// 从JSON数据创建KaoyanWord对象
    private func createKaoyanWord(from wordData: KaoyanWordJSON, dictionaryId: String? = nil) -> KaoyanWord {
        let word = KaoyanWord(
            wordId: wordData.content.word.wordId,
            wordRank: wordData.wordRank,
            headWord: wordData.headWord,
            bookId: dictionaryId ?? wordData.bookId
        )
        
        let content = wordData.content.word.content
        
        // 设置音标信息
        word.usPhone = content.usphone
        word.ukPhone = content.ukphone
        word.usPhoneParam = content.usspeech
        word.ukPhoneParam = content.ukspeech
        
        // 添加翻译
        if let translations = content.trans {
            for transData in translations {
                let translation = KaoyanTranslation(
                    pos: transData.pos,
                    tranCn: transData.tranCn,
                    tranOther: transData.tranOther,
                    descCn: transData.descCn,
                    descOther: transData.descOther
                )
                translation.word = word
                word.translations.append(translation)
            }
        }
        
        // 添加例句
        if let sentenceGroup = content.sentence {
            for sentenceData in sentenceGroup.sentences {
                let sentence = KaoyanSentence(
                    sContent: sentenceData.sContent,
                    sCn: sentenceData.sCn
                )
                sentence.word = word
                word.sentences.append(sentence)
            }
        }
        
        // 添加同近义词
        if let synonymGroup = content.syno {
            for synoData in synonymGroup.synos {
                let synonymWords = synoData.hwds.map { $0.w }
                let synonym = KaoyanSynonym(
                    pos: synoData.pos,
                    tran: synoData.tran,
                    synonymWords: synonymWords
                )
                synonym.word = word
                word.synonyms.append(synonym)
            }
        }
        
        // 添加短语
        if let phraseGroup = content.phrase {
            for phraseData in phraseGroup.phrases {
                let phrase = KaoyanPhrase(
                    pContent: phraseData.pContent,
                    pCn: phraseData.pCn
                )
                phrase.word = word
                word.phrases.append(phrase)
            }
        }
        
        // 添加同根词
        if let relWordGroup = content.relWord {
            for relData in relWordGroup.rels {
                for wordDetail in relData.words {
                    let relatedWord = KaoyanRelatedWord(
                        pos: relData.pos,
                        hwd: wordDetail.hwd,
                        tran: wordDetail.tran
                    )
                    relatedWord.word = word
                    word.relatedWords.append(relatedWord)
                }
            }
        }
        
        // 添加考试题目
        if let exams = content.exam {
            for examData in exams {
                let exam = KaoyanExam(
                    question: examData.question,
                    examType: examData.examType,
                    rightIndex: examData.answer.rightIndex,
                    explain: examData.answer.explain
                )
                
                for choiceData in examData.choices {
                    let choice = KaoyanChoice(
                        choiceIndex: choiceData.choiceIndex,
                        choice: choiceData.choice
                    )
                    choice.exam = exam
                    exam.choices.append(choice)
                }
                
                exam.word = word
                word.exams.append(exam)
            }
        }
        
        return word
    }
    
    /// 替换法语字符
    private func replaceFrenchCharacters(_ text: String) -> String {
        let frenchToEnglish: [(String, String)] = [
            ("é", "e"), ("ê", "e"), ("è", "e"), ("ë", "e"),
            ("à", "a"), ("â", "a"), ("ç", "c"), ("î", "i"),
            ("ï", "i"), ("ô", "o"), ("ù", "u"), ("û", "u"),
            ("ü", "u"), ("ÿ", "y")
        ]
        
        var result = text
        for (french, english) in frenchToEnglish {
            result = result.replacingOccurrences(of: french, with: english)
        }
        return result
    }
    
    /// 检查是否需要导入
    func needsImport() async throws -> Bool {
        let descriptor = FetchDescriptor<KaoyanWord>()
        let count = try modelContext.fetchCount(descriptor)
        return count == 0
    }
    
    /// 清空所有考研词典数据
    func clearAllData() throws {
        try modelContext.delete(model: KaoyanWord.self)
        try modelContext.save()
    }
}

// MARK: - 错误类型

enum ImportError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidJSON(String)
    case databaseError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "找不到文件: \(fileName)"
        case .invalidJSON(let details):
            return "JSON格式错误: \(details)"
        case .databaseError(let details):
            return "数据库错误: \(details)"
        }
    }
}