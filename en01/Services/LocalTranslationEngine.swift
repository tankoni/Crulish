//
//  LocalTranslationEngine.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import Foundation
import CoreML
import NaturalLanguage
import SwiftData
import os.log

// 导入统一的翻译模型和错误处理模块
// 这确保了类型定义的一致性和可访问性
// 所有翻译相关的数据模型现在统一在 TranslationModels.swift 中定义
// 所有错误类型定义在 ErrorTypes.swift 中

// 由于Swift模块系统的限制，我们需要确保所有类型都可以在当前文件中访问
// 如果编译器无法找到类型，我们需要在这里重新声明或导入它们

// 确保类型可访问性 - 引用其他文件中定义的类型
// 这些类型应该在 TranslationModels.swift 和 ErrorTypes.swift 中定义
typealias LocalTranslation = Translation
typealias LocalTranslationProvider = TranslationProvider
typealias LocalTranslationType = TranslationType
typealias LocalGrammarAnalysis = GrammarAnalysis
typealias LocalAppError = AppError

/// 本地AI翻译引擎
class LocalTranslationEngine {
    private let logger = Logger(subsystem: "com.en01.translation", category: "LocalEngine")
    
    // SwiftData 模型上下文
    private var modelContext: ModelContext?
    
    // Core ML 模型
    private var translationModel: MLModel?
    private var contextModel: MLModel?
    var isModelLoaded = false
    
    // 模型配置
    private let modelConfiguration: MLModelConfiguration
    private let maxInputLength = 512
    
    // 语言处理器
    private let tokenizer = NLTokenizer(unit: .word)
    private let languageRecognizer = NLLanguageRecognizer()
    
    init() {
        // 配置模型使用Neural Engine
        modelConfiguration = MLModelConfiguration()
        modelConfiguration.computeUnits = .all // 使用所有可用计算单元
        modelConfiguration.allowLowPrecisionAccumulationOnGPU = true
        
        logger.info("LocalTranslationEngine initialized")
    }
    
    /// 设置SwiftData模型上下文
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        logger.info("ModelContext设置成功")
    }
    
    // MARK: - Model Management
    
    /// 加载翻译模型
    func loadModels() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.loadTranslationModel()
            }
            
            group.addTask { [weak self] in
                await self?.loadContextModel()
            }
        }
        
        // 即使没有ML模型，本地引擎也可以使用基于规则的翻译
        isModelLoaded = true
        logger.info("LocalTranslationEngine ready: ML models=\(self.translationModel != nil), fallback=true")
    }
    
    private func loadTranslationModel() async {
        do {
            // 尝试加载本地翻译模型
            if let modelURL = getTranslationModelURL() {
                translationModel = try MLModel(contentsOf: modelURL, configuration: modelConfiguration)
                logger.info("Translation model loaded successfully")
            } else {
                logger.warning("Translation model not found, using fallback")
                await setupFallbackTranslation()
            }
        } catch {
            logger.error("Failed to load translation model: \(error)")
            await setupFallbackTranslation()
        }
    }
    
    private func loadContextModel() async {
        do {
            // 尝试加载上下文理解模型
            if let modelURL = getContextModelURL() {
                contextModel = try MLModel(contentsOf: modelURL, configuration: modelConfiguration)
                logger.info("Context model loaded successfully")
            } else {
                logger.info("Context model not found, using basic context analysis")
            }
        } catch {
            logger.error("Failed to load context model: \(error)")
        }
    }
    
    private func getTranslationModelURL() -> URL? {
        // 查找应用包中的翻译模型
        return Bundle.main.url(forResource: "TranslationModel", withExtension: "mlmodelc")
    }
    
    private func getContextModelURL() -> URL? {
        // 查找应用包中的上下文模型
        return Bundle.main.url(forResource: "ContextModel", withExtension: "mlmodelc")
    }
    
    private func setupFallbackTranslation() async {
        // 设置基于规则的翻译后备方案
        logger.info("Setting up rule-based translation fallback")
    }
    
    // MARK: - 从考研词典加载词汇
    private func loadKaoyanVocabulary() -> [String: String] {
        var kaoyanDict: [String: String] = [:]
        
        guard let modelContext = modelContext else {
            logger.warning("ModelContext未设置，无法加载考研词汇")
            return kaoyanDict
        }
        
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
    
    // MARK: - 从用户词典加载词汇
    private func loadUserVocabulary() -> [String: String] {
        var userDict: [String: String] = [:]
        
        guard let modelContext = modelContext else {
            logger.warning("ModelContext未设置，无法加载用户词汇")
            return userDict
        }
        
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
            
            // 从UserDefaults加载用户自定义词汇
            if let savedWords = UserDefaults.standard.dictionary(forKey: "UserCustomWords") as? [String: String] {
                for (english, chinese) in savedWords {
                    userDict[english.lowercased()] = chinese
                }
            }
            
            logger.info("✅ 成功加载用户词汇: \(userDict.count)个")
        } catch {
            logger.error("❌ 加载用户词汇失败: \(error.localizedDescription)")
        }
        
        return userDict
    }
    
    // MARK: - Translation Methods
    
    /// 翻译文本
    func translate(
        _ text: String,
        context: String,
        type: TranslationType
    ) async -> Translation? {
        do {
            // 预处理输入
            let processedInput = preprocessText(text, context: context)
            
            // 执行翻译
            let translatedText = try await performMLTranslation(processedInput)
            
            // 后处理结果
            let finalTranslation = postprocessTranslation(translatedText, originalText: text)
            
            // 分析语法（如果有上下文模型）
            let grammarAnalysis = await analyzeGrammar(text, context: context)
            
            // 计算置信度
            let confidence = calculateConfidence(original: text, translated: finalTranslation)
            
            return LocalTranslation(
                originalText: text,
                translatedText: finalTranslation,
                sourceLanguage: "en",
                targetLanguage: "zh",
                confidence: confidence,
                provider: LocalTranslationProvider.local,
                contextualMeaning: extractContextualMeaning(text, context: context),
                grammarAnalysis: grammarAnalysis
            )
        } catch {
            logger.error("Translation failed: \(error)")
            return await fallbackTranslation(text, context: context, type: type)
        }
    }
    
    // MARK: - ML Processing
    
    private func preprocessText(_ text: String, context: String) -> MLFeatureProvider {
        // 文本预处理：分词、编码等
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = tokenizeText(cleanText)
        
        // 限制输入长度
        let limitedTokens = Array(tokens.prefix(maxInputLength))
        
        // 创建ML特征
        let features: [String: Any] = [
            "input_text": cleanText,
            "tokens": limitedTokens,
            "context": context.prefix(100), // 限制上下文长度
            "source_language": "en",
            "target_language": "zh"
        ]
        
        do {
            return try MLDictionaryFeatureProvider(dictionary: features)
        } catch {
            logger.error("Failed to create feature provider: \(error)")
            // 返回最小特征集
            return try! MLDictionaryFeatureProvider(dictionary: ["input_text": cleanText])
        }
    }
    
    private func performMLTranslation(_ input: MLFeatureProvider) async throws -> String {
        guard let model = translationModel else {
            throw LocalAppError.translationModelNotAvailable("Translation model not loaded")
        }
        
        // 执行模型推理
        let prediction = try await model.prediction(from: input)
        
        // 提取翻译结果
        if let translatedText = prediction.featureValue(for: "translated_text")?.stringValue {
            return translatedText
        } else if let translatedArray = prediction.featureValue(for: "output")?.multiArrayValue {
            // 处理多维数组输出（如果模型输出是token IDs）
            return decodeTokens(translatedArray)
        } else {
            throw LocalAppError.translationFailed("Failed to extract translation result from model output")
        }
    }
    
    private func decodeTokens(_ tokens: MLMultiArray) -> String {
        // 将token IDs解码为文本
        // 这里需要根据具体模型的输出格式来实现
        return "翻译结果" // 占位符实现
    }
    
    // MARK: - Text Processing
    
    private func tokenizeText(_ text: String) -> [String] {
        tokenizer.string = text
        var tokens: [String] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            tokens.append(String(text[tokenRange]))
            return true
        }
        
        return tokens
    }
    
    private func postprocessTranslation(_ translation: String, originalText: String) -> String {
        // 后处理翻译结果：去除多余空格、标点符号处理等
        var processed = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 处理标点符号
        processed = processed.replacingOccurrences(of: " ,", with: "，")
        processed = processed.replacingOccurrences(of: " .", with: "。")
        processed = processed.replacingOccurrences(of: " ?", with: "？")
        processed = processed.replacingOccurrences(of: " !", with: "！")
        
        return processed
    }
    
    // MARK: - Context Analysis
    
    private func analyzeGrammar(_ text: String, context: String) async -> GrammarAnalysis? {
        guard let contextModel = contextModel else {
            return basicGrammarAnalysis(text)
        }
        
        do {
            // 使用上下文模型分析语法
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "text": text,
                "context": context
            ])
            
            let prediction = try await contextModel.prediction(from: input)
            
            // 提取语法分析结果
            let structure = prediction.featureValue(for: "sentence_structure")?.stringValue ?? ""
            let phrases = extractKeyPhrases(from: prediction)
            let grammarPoints = extractGrammarPoints(from: prediction)
            
            return GrammarAnalysis(
                sentenceStructure: structure,
                keyPhrases: phrases,
                grammarPoints: grammarPoints,
                partOfSpeech: detectPartOfSpeech(text),
                wordForm: analyzeWordForm(text)
            )
            
        } catch {
            logger.error("Grammar analysis failed: \(error)")
            return basicGrammarAnalysis(text)
        }
    }
    
    private func basicGrammarAnalysis(_ text: String) -> LocalGrammarAnalysis {
        // 基础语法分析（不使用ML模型）
        _ = text.components(separatedBy: .whitespaces)
        
        return LocalGrammarAnalysis(
            sentenceStructure: detectBasicStructure(text),
            keyPhrases: extractBasicPhrases(text),
            grammarPoints: ["基础语法分析"],
            partOfSpeech: detectPartOfSpeech(text),
            wordForm: analyzeWordForm(text)
        )
    }
    
    private func extractKeyPhrases(from prediction: MLFeatureProvider) -> [String] {
        // 从ML预测结果中提取关键短语
        if let phrases = prediction.featureValue(for: "key_phrases")?.stringValue {
            return phrases.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return []
    }
    
    private func extractGrammarPoints(from prediction: MLFeatureProvider) -> [String] {
        // 从ML预测结果中提取语法要点
        if let points = prediction.featureValue(for: "grammar_points")?.stringValue {
            return points.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return []
    }
    
    // MARK: - Helper Methods
    
    private func detectBasicStructure(_ text: String) -> String {
        // 基础句子结构检测
        if text.contains("?") {
            return "疑问句"
        } else if text.contains("!") {
            return "感叹句"
        } else {
            return "陈述句"
        }
    }
    
    private func extractBasicPhrases(_ text: String) -> [String] {
        // 基础短语提取
        let words = text.components(separatedBy: .whitespaces)
        return Array(words.prefix(3)) // 返回前3个词作为关键短语
    }
    
    private func detectPartOfSpeech(_ text: String) -> String? {
        // 使用NaturalLanguage框架检测词性
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        let range = text.startIndex..<text.endIndex
        let tags = tagger.tags(in: range, unit: .word, scheme: .lexicalClass)
        
        return tags.first?.0?.rawValue
    }
    
    private func analyzeWordForm(_ text: String) -> String? {
        // 分析词形变化
        let words = text.components(separatedBy: .whitespaces)
        guard let firstWord = words.first else { return nil }
        
        if firstWord.hasSuffix("ing") {
            return "现在分词"
        } else if firstWord.hasSuffix("ed") {
            return "过去式"
        } else if firstWord.hasSuffix("s") {
            return "复数/第三人称单数"
        }
        
        return "原形"
    }
    
    private func extractContextualMeaning(_ text: String, context: String) -> String? {
        // 提取上下文相关含义
        guard !context.isEmpty else { return nil }
        
        // 简单的上下文分析
        if context.lowercased().contains("business") {
            return "商务语境"
        } else if context.lowercased().contains("academic") {
            return "学术语境"
        } else if context.lowercased().contains("casual") {
            return "日常语境"
        }
        
        return nil
    }
    
    private func calculateConfidence(original: String, translated: String) -> Double {
        // 计算翻译置信度
        let originalLength = original.count
        let translatedLength = translated.count
        
        // 基于长度比例的简单置信度计算
        let lengthRatio = Double(min(originalLength, translatedLength)) / Double(max(originalLength, translatedLength))
        
        // 基础置信度
        var confidence = 0.8
        
        // 长度比例调整
        confidence *= lengthRatio
        
        // 确保置信度在合理范围内
        return max(0.1, min(1.0, confidence))
    }
    
    // MARK: - Fallback Translation
    
    private func fallbackTranslation(
        _ text: String,
        context: String,
        type: TranslationType
    ) async -> Translation? {
        // 基于规则的后备翻译
        logger.info("Using fallback translation for: \(text)")
        
        // 简单的词典查找或规则翻译
        let translatedText = await performRuleBasedTranslation(text)
        
        return LocalTranslation(
            originalText: text,
            translatedText: translatedText,
            sourceLanguage: "en",
            targetLanguage: "zh",
            confidence: 0.6, // 较低的置信度
            provider: LocalTranslationProvider.local,
            contextualMeaning: "基础翻译",
            grammarAnalysis: basicGrammarAnalysis(text)
        )
    }
    
    /// 构建扩展词典，整合考研词汇和用户词典
    /// - Returns: 包含2000+词汇的扩展词典
    private func buildExpandedDictionary() async -> [String: String] {
        var expandedDict: [String: String] = [:]
        
        // 1. 添加基础词典
        expandedDict.merge(getBasicDictionary()) { (_, new) in new }
        
        // 2. 从考研词典中提取词汇
        let kaoyanWords = loadKaoyanVocabulary()
        expandedDict.merge(kaoyanWords) { (_, new) in new }
        
        // 3. 从用户词典中提取词汇
        let userWords = loadUserVocabulary()
        expandedDict.merge(userWords) { (_, new) in new }
        
        logger.info("扩展词典构建完成，共包含 \(expandedDict.count) 个词汇")
        return expandedDict
    }
    
    /// 执行基于规则的翻译
    /// - Parameter text: 待翻译文本
    /// - Returns: 翻译结果
    private func performRuleBasedTranslation(_ text: String) async -> String {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        let expandedDict = await buildExpandedDictionary()
        
        let translatedWords = words.map { word in
            // 移除标点符号进行查找
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            
            if let translation = expandedDict[cleanWord] {
                return translation
            } else {
                return "[\(cleanWord)]-暂无翻译"
            }
        }
        
        return translatedWords.joined(separator: " ")
    }
    
    /// 获取基础词典
    /// - Returns: 基础词典映射
    private func getBasicDictionary() -> [String: String] {
        return [
            // 基础问候和礼貌用语
            "hello": "你好", "hi": "嗨", "goodbye": "再见", "bye": "拜拜",
            "please": "请", "thank": "谢谢", "thanks": "谢谢", "welcome": "欢迎",
            "sorry": "对不起", "excuse": "打扰", "pardon": "原谅",
            
            // 时间相关
            "morning": "早上", "afternoon": "下午", "evening": "晚上", "night": "夜晚",
            "today": "今天", "tomorrow": "明天", "yesterday": "昨天",
            "week": "星期", "month": "月", "year": "年", "day": "天",
            "monday": "星期一", "tuesday": "星期二", "wednesday": "星期三",
            "thursday": "星期四", "friday": "星期五", "saturday": "星期六", "sunday": "星期日",
            
            // 数字
            "one": "一", "two": "二", "three": "三", "four": "四", "five": "五",
            "six": "六", "seven": "七", "eight": "八", "nine": "九", "ten": "十",
            "first": "第一", "second": "第二", "third": "第三",
            
            // 颜色
            "red": "红色", "blue": "蓝色", "green": "绿色", "yellow": "黄色",
            "black": "黑色", "white": "白色", "orange": "橙子", "purple": "紫色",
            "pink": "粉色", "brown": "棕色", "gray": "灰色", "grey": "灰色",
            
            // 家庭成员
            "family": "家庭", "father": "父亲", "mother": "母亲", "parent": "父母",
            "son": "儿子", "daughter": "女儿", "brother": "兄弟", "sister": "姐妹",
            "grandfather": "祖父", "grandmother": "祖母", "uncle": "叔叔", "aunt": "阿姨",
            
            // 身体部位
            "head": "头", "face": "脸", "eye": "眼睛", "nose": "鼻子", "mouth": "嘴",
            "ear": "耳朵", "hand": "手", "foot": "脚", "leg": "腿", "arm": "胳膊",
            "finger": "手指", "hair": "头发", "tooth": "牙齿", "neck": "脖子",
            
            // 食物和饮料
            "food": "食物", "water": "水", "milk": "牛奶", "coffee": "咖啡", "tea": "茶",
            "bread": "面包", "rice": "米饭", "meat": "肉", "fish": "鱼", "chicken": "鸡肉",
            "apple": "苹果", "banana": "香蕉", "grape": "葡萄",
            "vegetable": "蔬菜", "fruit": "水果", "egg": "鸡蛋", "cheese": "奶酪",
            
            // 基本动词
            "be": "是", "have": "有", "do": "做", "say": "说", "get": "得到",
            "make": "制作", "go": "去", "know": "知道", "take": "拿", "see": "看",
            "come": "来", "think": "想", "look": "看", "want": "想要", "give": "给",
            "use": "使用", "find": "找到", "tell": "告诉", "ask": "问", "work": "工作",
            // 扩展动词（避免与基础词典重复）
            "build": "建造", "stay": "停留", "fall": "落下", "cut": "切", "reach": "到达",
            "remain": "保持", "suggest": "建议", "raise": "提高", "pass": "通过",
            "sell": "卖", "require": "需要", "report": "报告", "decide": "决定", "pull": "拉",
            
            // 扩展名词（避免与基础词典重复）
            "time": "时间", "person": "人", "way": "方式", "thing": "事情", "man": "男人",
            "world": "世界", "life": "生活", "part": "部分", "child": "孩子", "woman": "女人",
            "place": "地方", "case": "情况", "point": "点", "government": "政府",
            "company": "公司", "number": "数字", "group": "组", "problem": "问题", "fact": "事实",
            "money": "钱", "door": "门", "window": "窗户", "table": "桌子", "chair": "椅子", "bed": "床",
            "phone": "电话", "street": "街道", "road": "路", "tree": "树",
            "flower": "花", "animal": "动物", "bird": "鸟",
            "music": "音乐", "movie": "电影", "game": "游戏", "sport": "运动", "news": "新闻",
            "story": "故事", "picture": "图片", "photo": "照片", "color": "颜色", "sound": "声音",
            "voice": "声音", "word": "单词", "language": "语言", "question": "问题", "answer": "答案",
            "idea": "想法", "thought": "思想", "mind": "思维", "body": "身体",
            "doctor": "医生", "hospital": "医院", "medicine": "药", "pain": "疼痛",
            "teacher": "老师", "student": "学生", "class": "班级", "lesson": "课程", "test": "测试",
            "paper": "纸", "pen": "笔", "pencil": "铅笔", "bag": "包", "box": "盒子",
            "bottle": "瓶子", "cup": "杯子", "plate": "盘子", "knife": "刀", "fork": "叉子",
            "spoon": "勺子", "bowl": "碗", "glass": "玻璃", "mirror": "镜子", "clock": "时钟",
            "key": "钥匙", "lock": "锁", "light": "灯", "fire": "火",
            "sun": "太阳", "moon": "月亮", "star": "星星", "sky": "天空", "cloud": "云",
            "rain": "雨", "snow": "雪", "wind": "风", "season": "季节",
            "spring": "春天", "summer": "夏天", "autumn": "秋天", "winter": "冬天",
            "hour": "小时", "minute": "分钟", "seconds": "秒", "date": "日期", "birthday": "生日", "age": "年龄",
            
            // 扩展形容词（避免与基础词典重复）
            "great": "伟大的", "large": "大的",
            "early": "早的", "late": "晚的",
            "difficult": "困难的", "soft": "软的",
            "dark": "黑暗的", "bright": "明亮的",
            "full": "满的", "empty": "空的",
            "expensive": "昂贵的", "cheap": "便宜的",
            "serious": "严肃的",
            "right": "正确的", "wrong": "错误的",
            "true": "真的", "false": "假的", "real": "真实的", "possible": "可能的",
            "impossible": "不可能的", "sure": "确定的", "clear": "清楚的", "simple": "简单的",
            "complex": "复杂的", "special": "特殊的", "normal": "正常的", "strange": "奇怪的",
            "different": "不同的", "same": "相同的", "similar": "相似的", "popular": "受欢迎的",
            "famous": "著名的", "common": "常见的", "useful": "有用的", "helpful": "有帮助的",
            "clever": "聪明的", "wise": "明智的", "brave": "勇敢的", "afraid": "害怕的",
            "scared": "害怕的", "worried": "担心的", "comfortable": "舒适的", "lucky": "幸运的",
            "successful": "成功的",
            
            // 介词和连词
            "in": "在...里", "on": "在...上", "at": "在", "to": "到", "for": "为了",
            "with": "和", "by": "通过", "from": "从", "up": "向上", "about": "关于",
            "into": "进入", "over": "在...上方", "after": "在...之后", "before": "在...之前",
            "through": "通过", "during": "在...期间", "between": "在...之间", "under": "在...下面",
            "above": "在...上面", "below": "在...下面", "and": "和", "or": "或者", "but": "但是",
            "so": "所以", "because": "因为", "if": "如果", "when": "当", "where": "哪里",
            "why": "为什么", "how": "如何", "what": "什么", "who": "谁", "which": "哪个",
            "that": "那个", "this": "这个", "these": "这些", "those": "那些", "here": "这里",
            "there": "那里", "now": "现在", "then": "然后", "always": "总是", "never": "从不",
            "sometimes": "有时", "often": "经常", "usually": "通常", "maybe": "也许",
            "perhaps": "也许", "yes": "是的", "no": "不", "not": "不", "very": "非常",
            "too": "太", "also": "也", "only": "只有", "just": "只是", "still": "仍然",
            "already": "已经", "yet": "还", "again": "再次", "more": "更多", "most": "最多",
            "less": "更少", "much": "很多", "many": "许多", "few": "少数", "little": "少的",
            "all": "所有", "some": "一些", "any": "任何", "every": "每个", "each": "每个",
            "both": "两个都", "either": "任一", "neither": "两者都不", "none": "没有",
            "nothing": "什么都没有", "something": "某事", "anything": "任何事", "everything": "一切",
            "someone": "某人", "anyone": "任何人", "everyone": "每个人", "nobody": "没有人",
            "somewhere": "某处", "anywhere": "任何地方", "everywhere": "到处", "nowhere": "无处",
            "without": "没有", "off": "离开", "down": "向下", "out": "出去",
            "further": "更远", "once": "一次", "whose": "谁的",
            
            // 动物（扩展，避免与基础词典重复）
            "bear": "熊", "snake": "蛇", "frog": "青蛙", "butterfly": "蝴蝶",
            
            // 交通工具（扩展，避免与基础词典重复）
            "bicycle": "自行车", "subway": "地铁", "motorcycle": "摩托车",
            
            // 地点（扩展，避免与基础词典重复）
            "beach": "海滩", "forest": "森林",
            "city": "城市", "town": "城镇", "village": "村庄", "bridge": "桥",
            
            // 天气（扩展，避免与基础词典重复）
            "sunny": "晴朗", "cloudy": "多云", "rainy": "下雨",
            "snowy": "下雪", "windy": "有风", "lightning": "闪电", "fog": "雾",
            
            // 其他动词（扩展）
            "eat": "吃", "drink": "喝", "sleep": "睡觉",
            "listen": "听", "teach": "教", "study": "学习", "help": "帮助",
            "like": "喜欢", "try": "尝试", "close": "关闭", "feel": "感觉", "seem": "似乎",
            
            // 扩展名词
            "people": "人们", "boy": "男孩", "girl": "女孩",
            "nurse": "护士", "worker": "工人", "farmer": "农民", "driver": "司机", "cook": "厨师",
            "name": "名字",
            
            // 代词（扩展）
            "he": "他", "she": "她", "it": "它",
            "we": "我们", "they": "他们",
            "my": "我的", "your": "你的",
            "his": "他的", "her": "她的", "our": "我们的", "their": "他们的",
            
            // 扩展介词
            "of": "的",
            
            // 学习相关
            "chinese": "中文",
            "sentence": "句子", "grammar": "语法", "vocabulary": "词汇",
            "pronunciation": "发音", "meaning": "意思", "translation": "翻译",
            "dictionary": "字典", "homework": "作业",
            "exam": "考试", "grade": "成绩",
            
            // 科技相关
            "internet": "互联网",
            "website": "网站", "email": "邮件", "message": "消息",
            "app": "应用", "software": "软件", "program": "程序",
            
            // 购物相关
            "market": "市场", "price": "价格", "cost": "费用",
            "purchase": "购买", "sale": "出售", "customer": "顾客",
            "service": "服务", "product": "产品", "quality": "质量",
            
            // 健康相关（扩展）
            "exercise": "锻炼", "diet": "饮食", "rest": "休息",
            
            // 工作相关
            "career": "职业", "business": "商业",
            "meeting": "会议", "project": "项目", "team": "团队", "boss": "老板",
            "employee": "员工", "salary": "薪水", "interview": "面试",
            
            // 情感相关（扩展）
            "hope": "希望", "fear": "害怕", "worry": "担心", "surprise": "惊讶"
        ]
    }
    
    /// 翻译单词
    /// - Parameters:
    ///   - word: 要翻译的单词
    ///   - context: 上下文信息
    /// - Returns: 翻译结果
    func translateWord(_ word: String, context: String) async throws -> Translation? {
        logger.info("开始翻译单词: \(word)")
        
        // 输入验证
        guard !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalAppError.translationModelNotAvailable("Word cannot be empty")
        }
        
        return await translate(
            word,
            context: context,
            type: LocalTranslationType.word
        )
    }
    
    /// 翻译句子
    /// - Parameter sentence: 要翻译的句子
    /// - Returns: 翻译结果
    func translateSentence(_ sentence: String) async throws -> Translation? {
        logger.info("开始翻译句子: \(sentence)")
        
        // 输入验证
        guard !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalAppError.translationModelNotAvailable("Sentence cannot be empty")
        }
        
        return await translate(
            sentence,
            context: "",
            type: LocalTranslationType.sentence
        )
    }
    
    /// 翻译段落
    /// - Parameter paragraph: 要翻译的段落
    /// - Returns: 翻译结果
    func translateParagraph(_ paragraph: String) async throws -> Translation? {
        logger.info("开始翻译段落: \(paragraph.prefix(50))...")
        
        // 输入验证
        guard !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalAppError.translationModelNotAvailable("Paragraph cannot be empty")
        }
        
        return await translate(
            paragraph,
            context: "",
            type: LocalTranslationType.paragraph
        )
    }
    
    // MARK: - Public Properties
    // isModelLoaded property is already defined as private var above
}
