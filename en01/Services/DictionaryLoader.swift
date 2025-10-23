//
//  DictionaryLoader.swift
//  en01
//
//  Created by SOLO Coding on 2025/01/20.
//

import Foundation
import OSLog
import CryptoKit

/// 词典加载器服务
@Observable
class DictionaryLoader {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.crulish.en01", category: "DictionaryLoader")
    private let youdaoParser = YoudaoDictionaryParser()
    
    // 缓存的词典数据
    private var loadedDictionaries: [String: [DictionaryWord]] = [:]
    private var dictionaryInfos: [DictionaryInfo] = []
    private var isLoaded: Bool = false
    
    // 文件缓存：避免重复解析JSON文件
    private var fileCache: [String: (info: DictionaryInfo, words: [DictionaryWord])] = [:]
    private var fileCacheTimestamps: [String: Date] = [:]
    private let cacheValidityDuration: TimeInterval = 3600 // 1小时缓存有效期
    
    // 当前使用的词典
    private var currentDictionaryName: String = ""
    
    // 词典文件路径
    private let dictionariesPath: String
    
    // 加载状态
    var isLoading: Bool = false
    var loadingProgress: Double = 0.0
    var loadingError: Error?
    
    // MARK: - Initialization
    
    init() {
        // 获取词典文件路径 - 修复路径配置
        // 词典文件直接在Bundle的根目录下，不需要额外的Resources路径
        if let resourcePath = Bundle.main.resourcePath {
            self.dictionariesPath = resourcePath
        } else {
            self.dictionariesPath = ""
        }
        
        logger.info("DictionaryLoader initialized with path: \(self.dictionariesPath)")
    }
    
    // MARK: - Public Methods

    /// 加载所有词典文件
    @MainActor
    func loadDictionaries() async throws {
        guard !isLoading else {
            logger.warning("Dictionary loading already in progress")
            return
        }
        
        isLoading = true
        loadingProgress = 0.0
        loadingError = nil
        
        defer {
            isLoading = false
        }
        
        do {
            logger.info("Starting to load dictionaries")
            
            // 扫描词典文件
            let dictionaryFiles = try scanDictionaryFiles()
            logger.info("Found \(dictionaryFiles.count) dictionary files")
            
            if dictionaryFiles.isEmpty {
                throw DictionaryLoaderError.noDictionariesFound
            }
            
            // 清空之前的数据
            loadedDictionaries.removeAll()
            dictionaryInfos.removeAll()
            
            // 加载每个词典文件
            for (index, file) in dictionaryFiles.enumerated() {
                loadingProgress = Double(index) / Double(dictionaryFiles.count)
                
                do {
                    let (info, words) = try await loadDictionaryFile(file)
                    dictionaryInfos.append(info)
                    loadedDictionaries[info.name] = words
                    
                    logger.info("Loaded dictionary: \(info.displayName) with \(words.count) words")
                } catch {
                    logger.error("Failed to load dictionary file \(file): \(error.localizedDescription)")
                    // 继续加载其他词典，不因单个文件失败而中断
                }
            }
            
            loadingProgress = 1.0
            isLoaded = true
            
            // 设置默认词典
            if let firstDictionary = dictionaryInfos.first {
                currentDictionaryName = firstDictionary.name
            }
            
            logger.info("Successfully loaded \(dictionaryInfos.count) dictionaries")
            
        } catch {
            loadingError = error
            logger.error("Failed to load dictionaries: \(error.localizedDescription)")
            throw error
        }
    }

    /// 仅加载词典信息（轻量级，不解析词条内容）
    @MainActor
    func loadDictionaryInfosOnly() async throws {
        guard !isLoading else {
            logger.warning("Dictionary loading already in progress (infos-only)")
            return
        }

        isLoading = true
        loadingProgress = 0.0
        loadingError = nil

        defer { isLoading = false }

        do {
            logger.info("[InfosOnly] Starting to load dictionary infos")

            let dictionaryFiles = try scanDictionaryFiles()
            logger.info("[InfosOnly] Found \(dictionaryFiles.count) dictionary files")

            if dictionaryFiles.isEmpty {
                throw DictionaryLoaderError.noDictionariesFound
            }

            // 不触碰已解析的词条缓存，清理仅限信息集合
            dictionaryInfos.removeAll()

            for (index, fileURL) in dictionaryFiles.enumerated() {
                loadingProgress = Double(index) / Double(dictionaryFiles.count)

                let fileName = fileURL.lastPathComponent

                // 若缓存已有完整解析结果，直接复用其信息部分，避免重复解析
                if let cached = fileCache[fileName] {
                    dictionaryInfos.append(cached.0)
                    logger.info("[InfosOnly] Using cached info for: \(fileName) with \(cached.0.totalWords) words")
                    continue
                }

                do {
                    // 轻量统计：基于逐行计数估算词条数量（适用于考研行分隔 JSON）
                    let info = try buildInfoByLineCounting(fileURL)
                    dictionaryInfos.append(info)
                    logger.info("[InfosOnly] Counted \(info.totalWords) words for: \(fileName)")
                } catch {
                    logger.error("[InfosOnly] Failed to build info for \(fileName): \(error.localizedDescription)")
                }
            }

            loadingProgress = 1.0
            isLoaded = true

            if let first = dictionaryInfos.first { currentDictionaryName = first.name }
            logger.info("[InfosOnly] Successfully loaded \(dictionaryInfos.count) dictionary infos")
        } catch {
            loadingError = error
            logger.error("[InfosOnly] Failed to load dictionary infos: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 获取所有单词（来自所有启用的词典）
    func getAllWords() -> [DictionaryWord] {
        let enabledDictionaries = dictionaryInfos.filter { $0.isEnabled }
        var allWords: [DictionaryWord] = []
        
        for dictionary in enabledDictionaries {
            if let words = loadedDictionaries[dictionary.name] {
                allWords.append(contentsOf: words)
            }
        }
        
        return allWords
    }
    
    /// 根据词典名称获取单词
    func getWords(from dictionaryName: String) -> [DictionaryWord] {
        return loadedDictionaries[dictionaryName] ?? []
    }
    
    /// 搜索单词
    func searchWords(query: String, in dictionaryName: String? = nil) -> [DictionaryWord] {
        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }
        
        var wordsToSearch: [DictionaryWord] = []
        
        if let dictionaryName = dictionaryName {
            wordsToSearch = getWords(from: dictionaryName)
        } else {
            wordsToSearch = getAllWords()
        }
        
        return wordsToSearch.filter { word in
            word.word.lowercased().contains(searchQuery) ||
            word.definitions.contains { (definition: WordDefinition) in
                definition.meaning.contains(searchQuery) ||
                definition.englishMeaning?.lowercased().contains(searchQuery) == true
            }
        }
    }
    
    /// 根据难度获取单词
    func getWordsByDifficulty(_ difficulty: WordDifficulty, from dictionaryName: String? = nil) -> [DictionaryWord] {
        var wordsToFilter: [DictionaryWord] = []
        
        if let dictionaryName = dictionaryName {
            wordsToFilter = getWords(from: dictionaryName)
        } else {
            wordsToFilter = getAllWords()
        }
        
        return wordsToFilter.filter { $0.difficulty == difficulty }
    }
    
    /// 随机获取单词
    func getRandomWords(count: Int, from dictionaryName: String? = nil, difficultyRange: ClosedRange<Int>? = nil) -> [DictionaryWord] {
        var wordsToSample: [DictionaryWord] = []
        
        if let dictionaryName = dictionaryName {
            wordsToSample = getWords(from: dictionaryName)
        } else {
            wordsToSample = getAllWords()
        }
        
        // 根据难度范围过滤
        if let range = difficultyRange {
            wordsToSample = wordsToSample.filter { word in
                let difficulty = word.difficulty
                return range.contains(difficulty.level)
            }
        }
        
        return Array(wordsToSample.shuffled().prefix(count))
    }
    
    /// 获取词典信息列表
    func getDictionaryInfos() -> [DictionaryInfo] {
        return dictionaryInfos
    }
    
    /// 获取启用的词典信息
    func getEnabledDictionaryInfos() -> [DictionaryInfo] {
        return dictionaryInfos.filter { $0.isEnabled }
    }
    
    /// 获取当前词典名称
    func getCurrentDictionaryName() -> String {
        return currentDictionaryName
    }
    
    /// 设置当前词典
    func setCurrentDictionary(_ name: String) {
        if dictionaryInfos.contains(where: { $0.name == name }) {
            currentDictionaryName = name
            logger.info("Current dictionary set to: \(name)")
        }
    }
    
    /// 重新加载词典
    @MainActor
    func reloadDictionaries() async throws {
        // 清除缓存，强制重新加载
        fileCache.removeAll()
        fileCacheTimestamps.removeAll()
        isLoaded = false
        try await loadDictionaries()
    }

    /// 按需加载指定词典的词条并缓存（不影响其它词典）
    @MainActor
    func loadWords(for fileName: String) async throws -> [DictionaryWord] {
        // 直接通过 Bundle 查找文件
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: nil) ??
                Bundle.main.url(forResource: (fileName as NSString).deletingPathExtension, withExtension: (fileName as NSString).pathExtension.isEmpty ? "json" : (fileName as NSString).pathExtension) else {
            throw DictionaryLoaderError.noDictionariesFound
        }

        let (info, words) = try await loadDictionaryFile(fileURL)
        // 维护 loadedDictionaries，键使用 info.name 以与既有接口一致
        loadedDictionaries[info.name] = words

        // 若信息集合未包含该词典，补充信息（避免后续获取列表缺项）
        if !dictionaryInfos.contains(where: { $0.fileName == fileName || $0.name == info.name }) {
            dictionaryInfos.append(info)
        }

        logger.info("[OnDemand] Loaded words for \(fileName): \(words.count) words")
        return words
    }
    
    /// 检查是否已加载
    func isDictionaryLoaded() -> Bool {
        return isLoaded && !dictionaryInfos.isEmpty
    }
    
    // MARK: - Private Methods
    
    /// 扫描词典文件
    private func scanDictionaryFiles() throws -> [URL] {
        var jsonFiles: [URL] = []
        
        // 首先尝试直接查找已知的词典文件
        let knownDictionaryFiles = ["KaoYan_1", "KaoYan_2", "KaoYan_3", "KaoYanluan_1"]
        for fileName in knownDictionaryFiles {
            if let fileURL = Bundle.main.url(forResource: fileName, withExtension: "json") {
                logger.info("Found dictionary file using Bundle.main.url: \(fileURL.lastPathComponent)")
                jsonFiles.append(fileURL)
            }
        }
        
        // 如果直接查找成功，返回结果
        if !jsonFiles.isEmpty {
            logger.info("Successfully found \(jsonFiles.count) dictionary files using direct Bundle lookup")
            return jsonFiles
        }
        
        // 尝试多种路径查找策略
        let pathStrategies: [() -> URL?] = [
            // 策略1: Bundle.main.resourceURL + Resources/dict (最常见的情况)
            { Bundle.main.resourceURL?.appendingPathComponent("Resources/dict") },
            // 策略2: Bundle.main.resourcePath + Resources/dict
            { 
                guard let resourcePath = Bundle.main.resourcePath else { return nil }
                return URL(fileURLWithPath: (resourcePath as NSString).appendingPathComponent("Resources/dict"))
            },
            // 策略3: Bundle根目录直接查找dict文件夹（iOS应用中Resources文件会被复制到Bundle根目录）
            { Bundle.main.resourceURL?.appendingPathComponent("dict") },
            // 策略4: Bundle.main.resourcePath + dict
            { 
                guard let resourcePath = Bundle.main.resourcePath else { return nil }
                return URL(fileURLWithPath: (resourcePath as NSString).appendingPathComponent("dict"))
            },
            // 策略5: Bundle根目录直接查找词典文件（iOS应用中Resources文件会被复制到Bundle根目录）
            { Bundle.main.resourceURL },
            // 策略6: Bundle.main.resourcePath 直接查找
            { 
                guard let resourcePath = Bundle.main.resourcePath else { return nil }
                return URL(fileURLWithPath: resourcePath)
            },
            // 策略7: Bundle.main.bundleURL + Contents/Resources/dict (for macOS)
            { Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/dict") },
            // 策略8: Bundle.main.bundleURL + dict (直接查找)
            { Bundle.main.bundleURL.appendingPathComponent("dict") },
            // 策略9: 查找特定的dict路径
            {
                let bundlePath = Bundle.main.bundlePath
                return URL(fileURLWithPath: bundlePath).appendingPathComponent("dict")
            }
        ]
        
        let fileManager = FileManager.default
        
        for strategy in pathStrategies {
            guard let searchURL = strategy() else { continue }
            
            logger.info("Trying search path: \(searchURL.path)")
            
            if fileManager.fileExists(atPath: searchURL.path) {
                do {
                    let contents = try fileManager.contentsOfDirectory(
                        at: searchURL,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles]
                    )
                    
                    // 查找所有JSON文件，特别是有道词典格式的文件（KaoYan_*.json等）
                    let foundJsonFiles = contents.filter { url in
                        let fileName = url.lastPathComponent
                        return url.pathExtension == "json" && 
                               (fileName.hasPrefix("KaoYan") || fileName.hasPrefix("CET") || fileName.contains("luan"))
                    }
                    
                    logger.info("Found \(foundJsonFiles.count) dictionary JSON files in \(searchURL.path)")
                    if foundJsonFiles.isEmpty {
                        logger.info("Available files in directory: \(contents.map { $0.lastPathComponent }.joined(separator: ", "))")
                    }
                    
                    if !foundJsonFiles.isEmpty {
                        jsonFiles = foundJsonFiles
                        foundJsonFiles.forEach { file in
                            logger.info("Found dictionary file: \(file.lastPathComponent)")
                        }
                        
                        logger.info("Successfully found \(jsonFiles.count) dictionary files at \(searchURL.path)")
                        break
                    }
                } catch {
                    logger.warning("Failed to access directory at \(searchURL.path): \(error.localizedDescription)")
                    continue
                }
            } else {
                logger.warning("Directory does not exist at: \(searchURL.path)")
            }
        }
        
        if jsonFiles.isEmpty {
            logger.error("No dictionary files found in any of the attempted paths")
            // 打印调试信息
            if let resourcePath = Bundle.main.resourcePath {
                logger.info("Bundle.main.resourcePath: \(resourcePath)")
            }
            if let resourceURL = Bundle.main.resourceURL {
                logger.info("Bundle.main.resourceURL: \(resourceURL.path)")
            }
            logger.info("Bundle.main.bundlePath: \(Bundle.main.bundlePath)")
            logger.info("Bundle.main.bundleURL: \(Bundle.main.bundleURL.path)")
            
            throw DictionaryLoaderError.noDictionariesFound
        }
        
        return jsonFiles
    }
    
    /// 加载单个词典文件
    @MainActor
    private func loadDictionaryFile(_ fileURL: URL) async throws -> (DictionaryInfo, [DictionaryWord]) {
        let fileName = fileURL.lastPathComponent
        
        // 检查缓存是否有效
        if let cachedData = fileCache[fileName],
           let timestamp = fileCacheTimestamps[fileName],
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            logger.info("Using cached data for dictionary file: \(fileName)")
            return cachedData
        }
        
        logger.info("Loading dictionary file: \(fileName)")
        
        do {
            // 首先尝试使用有道词典解析器
            if let (youdaoInfo, youdaoWords) = try? await youdaoParser.parseDictionaryFile(fileURL) {
                logger.info("Successfully loaded \(youdaoWords.count) words from Youdao format: \(fileName)")
                
                // 缓存结果
                let result = (youdaoInfo, youdaoWords)
                fileCache[fileName] = result
                fileCacheTimestamps[fileName] = Date()
                
                return result
            }
            
            // 如果有道格式解析失败，尝试原有格式
            // 读取文件数据
            let data = try Data(contentsOf: fileURL)
            logger.debug("Successfully read \(data.count) bytes from file")
            
            // 解析JSON
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let dictionaryData = try decoder.decode(DictionaryFileFormat.self, from: data)
            logger.debug("Successfully decoded JSON data")
            
            // 验证数据
            try validateDictionaryData(dictionaryData)
            logger.debug("Data validation passed")
            
            // 创建词典信息
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            
            // 转换为DictionaryWord模型
            let words = dictionaryData.words.map { wordData in
                let wordDefinitions = wordData.definitions.map { defData in
                    WordDefinition(
                        partOfSpeech: defData.partOfSpeech,
                        meaning: defData.meaning,
                        englishMeaning: defData.englishMeaning,
                        examples: defData.examples,
                        contextKeywords: defData.contextKeywords
                    )
                }
                
                return DictionaryWord(
                    word: wordData.word,
                    phonetic: wordData.phonetic,
                    definitions: wordDefinitions,
                    frequency: wordData.frequency,
                    difficulty: wordData.difficulty,
                    tags: wordData.tags,
                    categories: wordData.categories
                )
            }
            
            let dictionaryInfo = DictionaryInfo(
                name: dictionaryData.metadata?.name ?? fileURL.deletingPathExtension().lastPathComponent,
                displayName: dictionaryData.metadata?.displayName ?? fileURL.deletingPathExtension().lastPathComponent,
                fileName: fileURL.lastPathComponent,
                filePath: fileURL.path,
                version: dictionaryData.metadata?.version ?? "1.0",
                description: dictionaryData.metadata?.description ?? "",
                language: dictionaryData.metadata?.language ?? "en",
                totalWords: words.count,
                difficultyLevels: extractDifficultyLevels(from: words),
                categories: dictionaryData.metadata?.categories ?? [],
                fileSize: fileSize,
                checksum: data.sha256,
                isEnabled: true,
                priority: dictionaryData.metadata?.priority ?? 0
            )
            
            logger.info("Successfully loaded dictionary: \(dictionaryInfo.displayName) with \(words.count) words")
            
            // 缓存结果
            let result = (dictionaryInfo, words)
            fileCache[fileName] = result
            fileCacheTimestamps[fileName] = Date()
            
            return result
        } catch {
            logger.error("Failed to load dictionary file: \(fileName). Error: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                logger.error("Decoding error details: \(decodingError)")
            }
            throw error
        }
    }

    /// 基于逐行计数构建词典信息（不解析词条内容）
    private func buildInfoByLineCounting(_ fileURL: URL) throws -> DictionaryInfo {
        let fileName = fileURL.lastPathComponent

        // 文件大小用于信息展示与粗略成本估计
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0

        // 行计数（跳过空行），适配考研行分隔 JSON；对数组 JSON 格式，计数可能偏差，但不解析词条可避免高内存占用
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let totalWords = content.split(whereSeparator: { $0.isNewline }).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count

        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let dictionaryInfo = DictionaryInfo(
            name: baseName,
            displayName: baseName,
            fileName: fileName,
            filePath: fileURL.path,
            version: "1.0",
            description: "",
            language: "en",
            totalWords: totalWords,
            difficultyLevels: [],
            categories: [],
            fileSize: fileSize,
            checksum: "",
            isEnabled: true,
            priority: 0
        )
        return dictionaryInfo
    }
    
    /// 提取难度级别
    private func extractDifficultyLevels(from words: [DictionaryWord]) -> [Int] {
        let levels = Set(words.map { $0.difficulty.level })
        return Array(levels).sorted()
    }
    
    /// 验证词典数据
    private func validateDictionaryData(_ data: DictionaryFileFormat) throws {
        guard !data.words.isEmpty else {
            throw DictionaryLoaderError.emptyDictionary
        }
        
        // 检查单词格式
        for word in data.words {
            guard !word.word.isEmpty else {
                throw DictionaryLoaderError.invalidWordFormat
            }
            
            guard !word.definitions.isEmpty else {
                throw DictionaryLoaderError.invalidWordFormat
            }
        }
    }
}

// MARK: - Supporting Types

/// 词典文件格式
struct DictionaryFileFormat: Codable {
    let metadata: DictionaryMetadata?
    let words: [DictionaryWordData]
    
    enum CodingKeys: String, CodingKey {
        case metadata
        case words
    }
}



/// 词典元数据
struct DictionaryMetadata: Codable {
    let name: String
    let displayName: String
    let version: String
    let description: String
    let language: String
    let categories: [String]
    let priority: Int
    let author: String?
    let createdDate: String?
    let lastModified: String?
    
    enum CodingKeys: String, CodingKey {
        case name, displayName, version, description, language, categories, priority
        case author, createdDate, lastModified
    }
}

/// 词典加载错误
enum DictionaryLoaderError: LocalizedError {
    case dictionaryPathNotFound
    case noDictionariesFound
    case fileReadError(String)
    case jsonParseError(String)
    case emptyDictionary
    case invalidWordFormat
    case unsupportedFileFormat
    case networkError
    case checksumMismatch
    
    var errorDescription: String? {
        switch self {
        case .dictionaryPathNotFound:
            return "词典文件路径不存在"
        case .noDictionariesFound:
            return "未找到任何词典文件"
        case .fileReadError(let details):
            return "文件读取错误: \(details)"
        case .jsonParseError(let details):
            return "JSON解析错误: \(details)"
        case .emptyDictionary:
            return "词典文件为空"
        case .invalidWordFormat:
            return "单词格式无效"
        case .unsupportedFileFormat:
            return "不支持的文件格式"
        case .networkError:
            return "网络连接错误"
        case .checksumMismatch:
            return "文件校验和不匹配"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .dictionaryPathNotFound:
            return "请检查应用程序包中是否包含词典文件"
        case .noDictionariesFound:
            return "请确保Resources目录中包含有效的JSON词典文件"
        case .fileReadError:
            return "请检查文件权限和磁盘空间"
        case .jsonParseError:
            return "请检查JSON文件格式是否正确"
        case .emptyDictionary:
            return "请使用包含单词数据的词典文件"
        case .invalidWordFormat:
            return "请检查单词数据格式是否符合要求"
        case .unsupportedFileFormat:
            return "请使用支持的JSON格式词典文件"
        case .networkError:
            return "请检查网络连接后重试"
        case .checksumMismatch:
            return "文件可能已损坏，请重新下载"
        }
    }
}

// MARK: - Extensions

extension DictionaryLoader {
    
    /// 获取词典统计信息
    func getDictionaryStatistics() -> DictionaryLoaderStatistics {
        let totalWords = getAllWords().count
        let totalDictionaries = dictionaryInfos.count
        let enabledDictionaries = getEnabledDictionaryInfos().count
        
        var difficultyDistribution: [Int: Int] = [:]
        var categoryDistribution: [String: Int] = [:]
        
        for word in getAllWords() {
            let difficulty = word.difficulty
            difficultyDistribution[difficulty.level, default: 0] += 1
        }
        
        for dictionary in dictionaryInfos {
            for category in dictionary.categories {
                categoryDistribution[category, default: 0] += 1
            }
        }
        
        return DictionaryLoaderStatistics(
            totalWords: totalWords,
            totalDictionaries: totalDictionaries,
            enabledDictionaries: enabledDictionaries,
            difficultyDistribution: difficultyDistribution,
            categoryDistribution: categoryDistribution,
            isLoaded: isLoaded,
            loadingProgress: loadingProgress
        )
    }
    
    /// 导出词典信息
    func exportDictionaryInfo() -> Data? {
        let exportData = DictionaryExportData(
            dictionaries: dictionaryInfos,
            statistics: getDictionaryStatistics(),
            exportDate: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(exportData)
        } catch {
            logger.error("Failed to export dictionary info: \(error.localizedDescription)")
            return nil
        }
    }
}

/// 词典加载器统计信息
struct DictionaryLoaderStatistics: Codable {
    let totalWords: Int
    let totalDictionaries: Int
    let enabledDictionaries: Int
    let difficultyDistribution: [Int: Int]
    let categoryDistribution: [String: Int]
    let isLoaded: Bool
    let loadingProgress: Double
}

/// 词典导出数据
struct DictionaryExportData: Codable {
    let dictionaries: [DictionaryInfo]
    let statistics: DictionaryLoaderStatistics
    let exportDate: Date
}