//
//  ContextAnalyzer.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import Foundation
import NaturalLanguage
import OSLog

/// 上下文分析器
class ContextAnalyzer: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.en01.translation", category: "ContextAnalyzer")
    
    // NaturalLanguage 组件
    private let languageRecognizer = NLLanguageRecognizer()
    private let tokenizer = NLTokenizer(unit: .word)
    private let sentimentAnalyzer = NLTagger(tagSchemes: [.sentimentScore])
    private let entityRecognizer = NLTagger(tagSchemes: [.nameType])
    
    // 上下文缓存
    private var contextCache: [String: ContextAnalysis] = [:]
    private let cacheQueue = DispatchQueue(label: "com.en01.context.cache")
    
    // 领域词典
    private var domainDictionaries: [ContextDomain: Set<String>] = [:]
    
    init() {
        setupDomainDictionaries()
        logger.info("ContextAnalyzer initialized")
    }
    
    // MARK: - Public Methods
    
    /// 分析文本上下文
    func analyzeContext(
        text: String,
        surroundingText: String = "",
        articleContext: String = ""
    ) async -> ContextAnalysis {
        let cacheKey = generateCacheKey(text: text, surrounding: surroundingText, article: articleContext)
        
        // 检查缓存
        if let cached = await getCachedAnalysis(key: cacheKey) {
            logger.debug("Using cached context analysis for: \(text.prefix(20))")
            return cached
        }
        
        // 执行分析
        let analysis = await performContextAnalysis(
            text: text,
            surroundingText: surroundingText,
            articleContext: articleContext
        )
        
        // 缓存结果
        await cacheAnalysis(key: cacheKey, analysis: analysis)
        
        return analysis
    }
    
    /// 提取关键信息
    func extractKeyInformation(from text: String) -> KeyInformation {
        let entities = extractNamedEntities(from: text)
        let keywords = extractKeywords(from: text)
        let phrases = extractKeyPhrases(from: text)
        let topics = identifyTopics(from: text)
        
        return KeyInformation(
            entities: entities,
            keywords: keywords,
            keyPhrases: phrases,
            topics: topics
        )
    }
    
    /// 检测文本领域
    func detectDomain(from text: String) -> ContextDomain {
        let words = tokenizeText(text).map { $0.lowercased() }
        var domainScores: [ContextDomain: Int] = [:]
        
        // 计算每个领域的匹配分数
        for (domain, dictionary) in domainDictionaries {
            let matches = words.filter { dictionary.contains($0) }
            domainScores[domain] = matches.count
        }
        
        // 返回得分最高的领域
        let bestMatch = domainScores.max { $0.value < $1.value }
        return bestMatch?.key ?? .general
    }
    
    /// 分析语言风格
    func analyzeLanguageStyle(text: String) -> LanguageStyle {
        let formalityScore = calculateFormalityScore(text)
        let complexityScore = calculateComplexityScore(text)
        let sentimentScore = analyzeSentiment(text)
        
        return LanguageStyle(
            formality: formalityScore,
            complexity: complexityScore,
            sentiment: sentimentScore,
            register: determineRegister(formality: formalityScore, complexity: complexityScore)
        )
    }
    
    // MARK: - Private Analysis Methods
    
    private func performContextAnalysis(
        text: String,
        surroundingText: String,
        articleContext: String
    ) async -> ContextAnalysis {
        // 基础文本分析
        let textType = classifyTextType(text)
        let domain = detectDomain(from: text + " " + surroundingText + " " + articleContext)
        let languageStyle = analyzeLanguageStyle(text: text)
        let keyInfo = extractKeyInformation(from: text)
        
        // 上下文相关性分析
        let contextRelevance = calculateContextRelevance(
            text: text,
            surrounding: surroundingText,
            article: articleContext
        )
        
        // 语义关系分析
        let semanticRelations = analyzeSemanticRelations(
            text: text,
            context: surroundingText
        )
        
        // 翻译建议
        let translationHints = generateTranslationHints(
            text: text,
            domain: domain,
            style: languageStyle,
            type: textType
        )
        
        return ContextAnalysis(
            textType: textType,
            domain: domain,
            languageStyle: languageStyle,
            keyInformation: keyInfo,
            contextRelevance: contextRelevance,
            semanticRelations: semanticRelations,
            translationHints: translationHints,
            confidence: calculateAnalysisConfidence(
                textLength: text.count,
                contextLength: surroundingText.count + articleContext.count,
                domainClarity: domain != .general
            )
        )
    }
    
    // MARK: - Text Classification
    
    private func classifyTextType(_ text: String) -> TextType {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = tokenizeText(trimmedText).count
        
        // 基于长度和结构判断文本类型
        if wordCount == 1 {
            return .word
        } else if wordCount <= 3 {
            return .phrase
        } else if trimmedText.contains(".") || trimmedText.contains("!") || trimmedText.contains("?") {
            let sentenceCount = trimmedText.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.isEmpty }.count
            return sentenceCount > 1 ? .paragraph : .sentence
        } else if wordCount <= 20 {
            return .sentence
        } else {
            return .paragraph
        }
    }
    
    // MARK: - Named Entity Recognition
    
    private func extractNamedEntities(from text: String) -> [NamedEntity] {
        entityRecognizer.string = text
        var entities: [NamedEntity] = []
        
        entityRecognizer.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let entityText = String(text[range])
                let entityType = mapNLTagToEntityType(tag)
                
                entities.append(NamedEntity(
                    text: entityText,
                    type: entityType,
                    range: range,
                    confidence: 0.8 // NaturalLanguage框架的默认置信度
                ))
            }
            return true
        }
        
        return entities
    }
    
    private func mapNLTagToEntityType(_ tag: NLTag) -> EntityType {
        switch tag {
        case .personalName:
            return .person
        case .placeName:
            return .location
        case .organizationName:
            return .organization
        default:
            return .other
        }
    }
    
    // MARK: - Keyword Extraction
    
    private func extractKeywords(from text: String) -> [String] {
        let words = tokenizeText(text)
        let filteredWords = words.filter { word in
            // 过滤停用词和短词
            word.count > 2 && !isStopWord(word.lowercased())
        }
        
        // 计算词频
        var wordFreq: [String: Int] = [:]
        for word in filteredWords {
            let lowercased = word.lowercased()
            wordFreq[lowercased, default: 0] += 1
        }
        
        // 返回频率最高的词
        return wordFreq.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    private func isStopWord(_ word: String) -> Bool {
        let stopWords: Set<String> = [
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "is", "are", "was", "were", "be", "been", "have",
            "has", "had", "do", "does", "did", "will", "would", "could", "should",
            "may", "might", "can", "this", "that", "these", "those", "i", "you",
            "he", "she", "it", "we", "they", "me", "him", "her", "us", "them"
        ]
        return stopWords.contains(word)
    }
    
    // MARK: - Key Phrase Extraction
    
    private func extractKeyPhrases(from text: String) -> [String] {
        let words = tokenizeText(text)
        var phrases: [String] = []
        
        // 提取2-3词的短语
        for i in 0..<words.count {
            // 2词短语
            if i + 1 < words.count {
                let phrase = "\(words[i]) \(words[i + 1])"
                if isSignificantPhrase(phrase) {
                    phrases.append(phrase)
                }
            }
            
            // 3词短语
            if i + 2 < words.count {
                let phrase = "\(words[i]) \(words[i + 1]) \(words[i + 2])"
                if isSignificantPhrase(phrase) {
                    phrases.append(phrase)
                }
            }
        }
        
        return Array(Set(phrases)).prefix(3).map { String($0) }
    }
    
    private func isSignificantPhrase(_ phrase: String) -> Bool {
        let words = phrase.components(separatedBy: .whitespaces)
        // 至少包含一个非停用词
        return words.contains { !isStopWord($0.lowercased()) }
    }
    
    // MARK: - Topic Identification
    
    private func identifyTopics(from text: String) -> [String] {
        let keywords = extractKeywords(from: text)
        let domain = detectDomain(from: text)
        
        var topics: [String] = []
        
        // 基于领域添加主题
        switch domain {
        case .academic:
            topics.append("学术")
        case .business:
            topics.append("商务")
        case .technology:
            topics.append("技术")
        case .medical:
            topics.append("医学")
        case .legal:
            topics.append("法律")
        case .literature:
            topics.append("文学")
        case .science:
            topics.append("科学")
        case .general:
            topics.append("通用")
        }
        
        // 基于关键词添加更具体的主题
        for keyword in keywords.prefix(2) {
            topics.append(keyword)
        }
        
        return topics
    }
    
    // MARK: - Language Style Analysis
    
    private func calculateFormalityScore(_ text: String) -> Double {
        let words = tokenizeText(text)
        var formalityScore = 0.5 // 基础分数
        
        // 正式词汇指标
        let formalWords = ["therefore", "however", "furthermore", "consequently", "nevertheless"]
        let formalCount = words.filter { formalWords.contains($0.lowercased()) }.count
        
        // 非正式词汇指标
        let informalWords = ["gonna", "wanna", "yeah", "ok", "cool", "awesome"]
        let informalCount = words.filter { informalWords.contains($0.lowercased()) }.count
        
        // 调整分数
        formalityScore += Double(formalCount) * 0.1
        formalityScore -= Double(informalCount) * 0.1
        
        return max(0.0, min(1.0, formalityScore))
    }
    
    private func calculateComplexityScore(_ text: String) -> Double {
        let words = tokenizeText(text)
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.isEmpty }
        
        // 平均句长
        let avgSentenceLength = sentences.isEmpty ? 0 : Double(words.count) / Double(sentences.count)
        
        // 长词比例
        let longWords = words.filter { $0.count > 6 }
        let longWordRatio = words.isEmpty ? 0 : Double(longWords.count) / Double(words.count)
        
        // 复杂度分数
        let complexityScore = (avgSentenceLength / 20.0) * 0.6 + longWordRatio * 0.4
        
        return max(0.0, min(1.0, complexityScore))
    }
    
    private func analyzeSentiment(_ text: String) -> Double {
        sentimentAnalyzer.string = text
        
        var sentimentScore = 0.0
        var tokenCount = 0
        
        sentimentAnalyzer.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                sentimentScore += score
                tokenCount += 1
            }
            return true
        }
        
        return tokenCount > 0 ? sentimentScore / Double(tokenCount) : 0.0
    }
    
    private func determineRegister(formality: Double, complexity: Double) -> String {
        if formality > 0.7 && complexity > 0.7 {
            return "学术正式"
        } else if formality > 0.6 {
            return "正式"
        } else if formality < 0.4 {
            return "非正式"
        } else {
            return "中性"
        }
    }
    
    // MARK: - Context Relevance
    
    private func calculateContextRelevance(
        text: String,
        surrounding: String,
        article: String
    ) -> Double {
        let textWords = Set(tokenizeText(text).map { $0.lowercased() })
        let surroundingWords = Set(tokenizeText(surrounding).map { $0.lowercased() })
        let articleWords = Set(tokenizeText(article).map { $0.lowercased() })
        
        // 计算词汇重叠度
        let surroundingOverlap = textWords.intersection(surroundingWords)
        let articleOverlap = textWords.intersection(articleWords)
        
        let surroundingRelevance = surroundingWords.isEmpty ? 0 : Double(surroundingOverlap.count) / Double(surroundingWords.count)
        let articleRelevance = articleWords.isEmpty ? 0 : Double(articleOverlap.count) / Double(articleWords.count)
        
        return (surroundingRelevance * 0.6 + articleRelevance * 0.4)
    }
    
    // MARK: - Semantic Relations
    
    private func analyzeSemanticRelations(
        text: String,
        context: String
    ) -> [SemanticRelation] {
        var relations: [SemanticRelation] = []
        
        let textWords = tokenizeText(text)
        let contextWords = tokenizeText(context)
        
        // 查找同义词关系
        for textWord in textWords {
            for contextWord in contextWords {
                if areSynonyms(textWord, contextWord) {
                    relations.append(SemanticRelation(
                        type: .synonym,
                        word1: textWord,
                        word2: contextWord,
                        strength: 0.8
                    ))
                }
            }
        }
        
        return relations
    }
    
    private func areSynonyms(_ word1: String, _ word2: String) -> Bool {
        // 简单的同义词检测（实际应用中可以使用更复杂的词典）
        let synonymPairs: [(String, String)] = [
            ("big", "large"),
            ("small", "little"),
            ("good", "excellent"),
            ("bad", "terrible"),
            ("happy", "joyful"),
            ("sad", "unhappy")
        ]
        
        let w1 = word1.lowercased()
        let w2 = word2.lowercased()
        
        return synonymPairs.contains { ($0.0 == w1 && $0.1 == w2) || ($0.0 == w2 && $0.1 == w1) }
    }
    
    // MARK: - Translation Hints
    
    private func generateTranslationHints(
        text: String,
        domain: ContextDomain,
        style: LanguageStyle,
        type: TextType
    ) -> [TranslationHint] {
        var hints: [TranslationHint] = []
        
        // 基于领域的提示
        switch domain {
        case .academic:
            hints.append(TranslationHint(
                type: .domain,
                content: "学术文本，注意专业术语的准确翻译",
                priority: .high
            ))
        case .business:
            hints.append(TranslationHint(
                type: .domain,
                content: "商务文本，保持正式语调",
                priority: .medium
            ))
        case .technology:
            hints.append(TranslationHint(
                type: .domain,
                content: "技术文本，保留专业术语",
                priority: .high
            ))
        default:
            break
        }
        
        // 基于语言风格的提示
        if style.formality > 0.7 {
            hints.append(TranslationHint(
                type: .style,
                content: "正式语体，使用书面语",
                priority: .medium
            ))
        } else if style.formality < 0.3 {
            hints.append(TranslationHint(
                type: .style,
                content: "非正式语体，可使用口语化表达",
                priority: .low
            ))
        }
        
        // 基于文本类型的提示
        switch type {
        case .word:
            hints.append(TranslationHint(
                type: .structure,
                content: "单词翻译，注意词性和语境",
                priority: .high
            ))
        case .sentence:
            hints.append(TranslationHint(
                type: .structure,
                content: "句子翻译，注意语法结构",
                priority: .medium
            ))
        case .paragraph:
            hints.append(TranslationHint(
                type: .structure,
                content: "段落翻译，保持逻辑连贯性",
                priority: .medium
            ))
        default:
            break
        }
        
        return hints
    }
    
    // MARK: - Helper Methods
    
    private func tokenizeText(_ text: String) -> [String] {
        tokenizer.string = text
        var tokens: [String] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            tokens.append(String(text[tokenRange]))
            return true
        }
        
        return tokens
    }
    
    private func calculateAnalysisConfidence(
        textLength: Int,
        contextLength: Int,
        domainClarity: Bool
    ) -> Double {
        var confidence = 0.5
        
        // 文本长度影响
        if textLength > 50 {
            confidence += 0.2
        } else if textLength < 10 {
            confidence -= 0.1
        }
        
        // 上下文长度影响
        if contextLength > 100 {
            confidence += 0.2
        }
        
        // 领域清晰度影响
        if domainClarity {
            confidence += 0.1
        }
        
        return max(0.1, min(1.0, confidence))
    }
    
    // MARK: - Domain Dictionary Setup
    
    private func setupDomainDictionaries() {
        domainDictionaries[.academic] = Set([
            "research", "study", "analysis", "theory", "hypothesis", "methodology",
            "literature", "academic", "scholar", "university", "dissertation", "thesis"
        ])
        
        domainDictionaries[.business] = Set([
            "business", "company", "market", "profit", "revenue", "investment",
            "strategy", "management", "corporate", "finance", "economy", "commercial"
        ])
        
        domainDictionaries[.technology] = Set([
            "technology", "software", "computer", "digital", "algorithm", "data",
            "programming", "system", "network", "artificial", "intelligence", "machine"
        ])
        
        domainDictionaries[.medical] = Set([
            "medical", "health", "patient", "treatment", "diagnosis", "therapy",
            "clinical", "hospital", "doctor", "medicine", "disease", "symptom"
        ])
        
        domainDictionaries[.legal] = Set([
            "legal", "law", "court", "judge", "lawyer", "contract", "agreement",
            "regulation", "statute", "jurisdiction", "litigation", "attorney"
        ])
        
        domainDictionaries[.science] = Set([
            "science", "experiment", "laboratory", "research", "discovery", "scientific",
            "physics", "chemistry", "biology", "mathematics", "formula", "equation"
        ])
        
        domainDictionaries[.literature] = Set([
            "literature", "novel", "poetry", "author", "writer", "book", "story",
            "character", "plot", "narrative", "fiction", "literary"
        ])
    }
    
    // MARK: - Cache Management
    
    private func generateCacheKey(text: String, surrounding: String, article: String) -> String {
        let combined = "\(text)|\(surrounding)|\(article)"
        return String(combined.hashValue)
    }
    
    private func getCachedAnalysis(key: String) async -> ContextAnalysis? {
        return await withCheckedContinuation { continuation in
            cacheQueue.async {
                continuation.resume(returning: self.contextCache[key])
            }
        }
    }
    
    private func cacheAnalysis(key: String, analysis: ContextAnalysis) async {
        await withCheckedContinuation { continuation in
            cacheQueue.async {
                self.contextCache[key] = analysis
                
                // 限制缓存大小
                if self.contextCache.count > 100 {
                    let keysToRemove = Array(self.contextCache.keys.prefix(20))
                    for keyToRemove in keysToRemove {
                        self.contextCache.removeValue(forKey: keyToRemove)
                    }
                }
                
                continuation.resume()
            }
        }
    }
}

// MARK: - Supporting Types

struct ContextAnalysis {
    let textType: TextType
    let domain: ContextDomain
    let languageStyle: LanguageStyle
    let keyInformation: KeyInformation
    let contextRelevance: Double
    let semanticRelations: [SemanticRelation]
    let translationHints: [TranslationHint]
    let confidence: Double
}

struct KeyInformation {
    let entities: [NamedEntity]
    let keywords: [String]
    let keyPhrases: [String]
    let topics: [String]
}

struct NamedEntity {
    let text: String
    let type: EntityType
    let range: Range<String.Index>
    let confidence: Double
}

struct LanguageStyle {
    let formality: Double // 0.0 = 非正式, 1.0 = 正式
    let complexity: Double // 0.0 = 简单, 1.0 = 复杂
    let sentiment: Double // -1.0 = 负面, 1.0 = 正面
    let register: String // 语域描述
}

struct SemanticRelation {
    let type: RelationType
    let word1: String
    let word2: String
    let strength: Double
}

struct TranslationHint {
    let type: HintType
    let content: String
    let priority: HintPriority
}

enum TextType {
    case word
    case phrase
    case sentence
    case paragraph
}

enum ContextDomain: String, CaseIterable {
    case academic = "academic"
    case business = "business"
    case technology = "technology"
    case medical = "medical"
    case legal = "legal"
    case literature = "literature"
    case science = "science"
    case general = "general"
}

enum EntityType {
    case person
    case location
    case organization
    case other
}

enum RelationType {
    case synonym
    case antonym
    case hypernym
    case hyponym
}

enum HintType {
    case domain
    case style
    case structure
    case cultural
}

enum HintPriority {
    case low
    case medium
    case high
}