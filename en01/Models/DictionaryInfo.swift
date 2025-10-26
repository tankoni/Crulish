//
//  DictionaryInfo.swift
//  en01
//
//  Created by SOLO Coding on 2025/01/20.
//

import Foundation
import SwiftData
import CryptoKit

// 词典信息结构
struct DictionaryInfo: Codable, Identifiable, Equatable {
    
    let id: UUID
    let name: String // 词典名称
    let displayName: String // 显示名称
    let fileName: String // 文件名
    let filePath: String // 文件路径
    let version: String // 版本号
    let description: String // 描述
    let language: String // 语言
    let totalWords: Int // 总词数
    let difficultyLevels: [Int] // 包含的难度级别
    let categories: [String] // 词汇分类
    let createdDate: Date // 创建日期
    let lastModified: Date // 最后修改日期
    let fileSize: Int64 // 文件大小（字节）
    let checksum: String // 文件校验和
    let isEnabled: Bool // 是否启用
    let priority: Int // 优先级（用于排序）
    
    // 词典统计信息
    let statistics: DictionaryStatistics
    
    // 词典配置
    let configuration: DictionaryConfiguration
    
    init(
        name: String,
        displayName: String,
        fileName: String,
        filePath: String,
        version: String = "1.0",
        description: String = "",
        language: String = "en",
        totalWords: Int = 0,
        difficultyLevels: [Int] = [],
        categories: [String] = [],
        fileSize: Int64 = 0,
        checksum: String = "",
        isEnabled: Bool = true,
        priority: Int = 0,
        statistics: DictionaryStatistics? = nil,
        configuration: DictionaryConfiguration? = nil
    ) {
        // 使用基于文件名的稳定ID生成策略
        self.id = Self.generateStableID(fileName: fileName)
        self.name = name
        self.displayName = displayName
        self.fileName = fileName
        self.filePath = filePath
        self.version = version
        self.description = description
        self.language = language
        self.totalWords = totalWords
        self.difficultyLevels = difficultyLevels
        self.categories = categories
        self.createdDate = Date()
        self.lastModified = Date()
        self.fileSize = fileSize
        self.checksum = checksum
        self.isEnabled = isEnabled
        self.priority = priority
        
        // 初始化统计信息
        self.statistics = statistics ?? DictionaryStatistics()
        
        // 初始化配置
        self.configuration = configuration ?? DictionaryConfiguration()
    }
    
    // MARK: - Stable ID Generation
    
    /// 基于文件名生成稳定的UUID
    /// 相同的文件名将始终生成相同的UUID，确保词典ID的一致性
    private static func generateStableID(fileName: String) -> UUID {
        // 使用SHA-1哈希算法生成基于文件名的稳定UUID
        let data = fileName.data(using: .utf8) ?? Data()
        let hash = Insecure.SHA1.hash(data: data)
        
        // 将哈希值转换为UUID格式
        let hashBytes = Array(hash)
        
        // 构造UUID字节数组（16字节）
        var uuidBytes: [UInt8] = Array(hashBytes.prefix(16))
        
        // 设置版本号为5（基于名称的UUID）
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x50
        // 设置变体位
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        
        // 创建UUID
        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }
    
    // MARK: - Computed Properties
    
    /// 文件大小的可读格式
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    /// 难度级别范围
    var difficultyRange: ClosedRange<Int>? {
        guard let min = difficultyLevels.min(), let max = difficultyLevels.max() else {
            return nil
        }
        return min...max
    }
    
    /// 是否为有效词典
    var isValid: Bool {
        return !name.isEmpty && !fileName.isEmpty && totalWords > 0
    }
    
    /// 词典难度级别
    var difficulty: DifficultyLevel {
        guard let range = difficultyRange else {
            return .intermediate
        }
        
        let averageDifficulty = Double(range.lowerBound + range.upperBound) / 2.0
        
        if averageDifficulty <= 1.5 {
            return .beginner
        } else if averageDifficulty <= 2.5 {
            return .intermediate
        } else {
            return .advanced
        }
    }
    
    /// 词典类型
    var dictionaryType: DictionaryType {
        if categories.contains("考研") || categories.contains("GRE") || categories.contains("TOEFL") {
            return .exam
        } else if categories.contains("基础") || categories.contains("初级") {
            return .basic
        } else if categories.contains("高级") || categories.contains("专业") {
            return .advanced
        } else {
            return .general
        }
    }
    
    /// 推荐使用场景
    var recommendedUsage: [UsageScenario] {
        var scenarios: [UsageScenario] = []
        
        if dictionaryType == .exam {
            scenarios.append(.examPreparation)
        }
        
        if totalWords <= 1000 {
            scenarios.append(.beginnerLearning)
        } else if totalWords <= 5000 {
            scenarios.append(.intermediateLearning)
        } else {
            scenarios.append(.advancedLearning)
        }
        
        if categories.contains("阅读") {
            scenarios.append(.readingComprehension)
        }
        
        if categories.contains("写作") {
            scenarios.append(.writingImprovement)
        }
        
        return scenarios
    }
    
    // MARK: - Methods
    
    /// 更新统计信息
    func updatedStatistics(_ newStats: DictionaryStatistics) -> DictionaryInfo {
        return DictionaryInfo(
            name: name,
            displayName: displayName,
            fileName: fileName,
            filePath: filePath,
            version: version,
            description: description,
            language: language,
            totalWords: totalWords,
            difficultyLevels: difficultyLevels,
            categories: categories,
            fileSize: fileSize,
            checksum: checksum,
            isEnabled: isEnabled,
            priority: priority,
            statistics: newStats,
            configuration: configuration
        )
    }
    
    /// 更新配置
    func updatedConfiguration(_ newConfig: DictionaryConfiguration) -> DictionaryInfo {
        return DictionaryInfo(
            name: name,
            displayName: displayName,
            fileName: fileName,
            filePath: filePath,
            version: version,
            description: description,
            language: language,
            totalWords: totalWords,
            difficultyLevels: difficultyLevels,
            categories: categories,
            fileSize: fileSize,
            checksum: checksum,
            isEnabled: isEnabled,
            priority: priority,
            statistics: statistics,
            configuration: newConfig
        )
    }
    
    /// 检查文件完整性
    func verifyIntegrity() -> Bool {
        guard FileManager.default.fileExists(atPath: filePath) else {
            return false
        }
        
        // 检查文件大小
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            let actualSize = attributes[.size] as? Int64 ?? 0
            
            if actualSize != fileSize {
                return false
            }
        } catch {
            return false
        }
        
        // 如果有校验和，验证校验和
        if !checksum.isEmpty {
            return calculateChecksum() == checksum
        }
        
        return true
    }
    
    /// 计算文件校验和
    private func calculateChecksum() -> String {
        guard let data = FileManager.default.contents(atPath: filePath) else {
            return ""
        }
        
        return data.sha256
    }
}

// MARK: - Supporting Types

/// 词典类型
enum DictionaryType: String, CaseIterable, Codable {
    case basic = "基础词典"
    case general = "通用词典"
    case advanced = "高级词典"
    case exam = "考试词典"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .basic: return "book.fill"
        case .general: return "books.vertical.fill"
        case .advanced: return "graduationcap.fill"
        case .exam: return "doc.text.fill"
        }
    }
    
    var color: String {
        switch self {
        case .basic: return "green"
        case .general: return "blue"
        case .advanced: return "purple"
        case .exam: return "orange"
        }
    }
}

/// 使用场景
enum UsageScenario: String, CaseIterable, Codable {
    case beginnerLearning = "初学者学习"
    case intermediateLearning = "中级学习"
    case advancedLearning = "高级学习"
    case examPreparation = "考试准备"
    case readingComprehension = "阅读理解"
    case writingImprovement = "写作提升"
    case vocabularyExpansion = "词汇扩展"
    case professionalDevelopment = "专业发展"
    
    var displayName: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .beginnerLearning:
            return "适合英语初学者，包含基础常用词汇"
        case .intermediateLearning:
            return "适合中级学习者，词汇量适中，难度递进"
        case .advancedLearning:
            return "适合高级学习者，包含复杂和专业词汇"
        case .examPreparation:
            return "专为各类英语考试设计，针对性强"
        case .readingComprehension:
            return "提升阅读理解能力，包含阅读常见词汇"
        case .writingImprovement:
            return "提升写作水平，包含写作常用词汇"
        case .vocabularyExpansion:
            return "扩展词汇量，丰富表达方式"
        case .professionalDevelopment:
            return "专业领域词汇，适合职业发展需要"
        }
    }
}

/// 词典统计信息
struct DictionaryStatistics: Codable, Equatable {
    let usageCount: Int // 使用次数
    let lastUsedDate: Date? // 最后使用日期
    let averageTestScore: Double // 平均测试分数
    let totalTestsUsing: Int // 使用该词典的测试总数
    let popularWords: [String] // 热门单词
    let difficultyDistribution: [Int: Int] // 难度分布 [难度级别: 单词数]
    let categoryDistribution: [String: Int] // 分类分布 [分类: 单词数]
    let userRating: Double // 用户评分
    let downloadCount: Int // 下载次数
    
    init(
        usageCount: Int = 0,
        lastUsedDate: Date? = nil,
        averageTestScore: Double = 0,
        totalTestsUsing: Int = 0,
        popularWords: [String] = [],
        difficultyDistribution: [Int: Int] = [:],
        categoryDistribution: [String: Int] = [:],
        userRating: Double = 0,
        downloadCount: Int = 0
    ) {
        self.usageCount = usageCount
        self.lastUsedDate = lastUsedDate
        self.averageTestScore = averageTestScore
        self.totalTestsUsing = totalTestsUsing
        self.popularWords = popularWords
        self.difficultyDistribution = difficultyDistribution
        self.categoryDistribution = categoryDistribution
        self.userRating = userRating
        self.downloadCount = downloadCount
    }
    
    /// 是否为热门词典
    var isPopular: Bool {
        return usageCount > 10 && userRating > 4.0
    }
    
    /// 推荐度
    var recommendationScore: Double {
        var score: Double = 0
        
        // 基于使用次数
        score += min(Double(usageCount) / 100.0, 1.0) * 30
        
        // 基于用户评分
        score += (userRating / 5.0) * 40
        
        // 基于测试表现
        score += min(averageTestScore / 100.0, 1.0) * 20
        
        // 基于下载量
        score += min(Double(downloadCount) / 1000.0, 1.0) * 10
        
        return min(score, 100.0)
    }
}

/// 词典配置
struct DictionaryConfiguration: Codable, Equatable {
    let enabledForTesting: Bool // 是否用于测试
    let enabledForReading: Bool // 是否用于阅读
    let enabledForReview: Bool // 是否用于复习
    let weightInTesting: Double // 在测试中的权重
    let maxWordsPerTest: Int // 每次测试最大单词数
    let preferredDifficulty: ClosedRange<Int>? // 偏好难度范围
    let excludedCategories: [String] // 排除的分类

    
    init(
        enabledForTesting: Bool = true,
        enabledForReading: Bool = true,
        enabledForReview: Bool = true,
        weightInTesting: Double = 1.0,
        maxWordsPerTest: Int = 50,
        preferredDifficulty: ClosedRange<Int>? = nil,
        excludedCategories: [String] = [],

    ) {
        self.enabledForTesting = enabledForTesting
        self.enabledForReading = enabledForReading
        self.enabledForReview = enabledForReview
        self.weightInTesting = weightInTesting
        self.maxWordsPerTest = maxWordsPerTest
        self.preferredDifficulty = preferredDifficulty
        self.excludedCategories = excludedCategories

    }
    
    // 由于 Any 类型不能直接 Codable，需要自定义编解码
    enum CodingKeys: String, CodingKey {
        case enabledForTesting, enabledForReading, enabledForReview
        case weightInTesting, maxWordsPerTest, preferredDifficulty
        case excludedCategories
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        enabledForTesting = try container.decode(Bool.self, forKey: .enabledForTesting)
        enabledForReading = try container.decode(Bool.self, forKey: .enabledForReading)
        enabledForReview = try container.decode(Bool.self, forKey: .enabledForReview)
        weightInTesting = try container.decode(Double.self, forKey: .weightInTesting)
        maxWordsPerTest = try container.decode(Int.self, forKey: .maxWordsPerTest)
        
        // 处理可选的 ClosedRange
        if let difficultyArray = try container.decodeIfPresent([Int].self, forKey: .preferredDifficulty),
           difficultyArray.count == 2 {
            preferredDifficulty = difficultyArray[0]...difficultyArray[1]
        } else {
            preferredDifficulty = nil
        }
        
        excludedCategories = try container.decode([String].self, forKey: .excludedCategories)

    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(enabledForTesting, forKey: .enabledForTesting)
        try container.encode(enabledForReading, forKey: .enabledForReading)
        try container.encode(enabledForReview, forKey: .enabledForReview)
        try container.encode(weightInTesting, forKey: .weightInTesting)
        try container.encode(maxWordsPerTest, forKey: .maxWordsPerTest)
        
        // 处理 ClosedRange
        if let range = preferredDifficulty {
            try container.encode([range.lowerBound, range.upperBound], forKey: .preferredDifficulty)
        }
        
        try container.encode(excludedCategories, forKey: .excludedCategories)
    }
}

// MARK: - Extensions

// MARK: - Data扩展已在CryptoExtensions.swift中定义

extension DictionaryInfo {
    /// 创建示例词典信息
    static func example() -> DictionaryInfo {
        return DictionaryInfo(
            name: "gre_vocabulary",
            displayName: "GRE核心词汇",
            fileName: "gre_vocabulary.json",
            filePath: "/path/to/gre_vocabulary.json",
            version: "2.1",
            description: "GRE考试核心词汇，包含3000个高频单词",
            language: "en",
            totalWords: 3000,
            difficultyLevels: [6, 7, 8, 9, 10],
            categories: ["考研", "GRE", "高级"],
            fileSize: 2048000,
            checksum: "abc123def456",
            isEnabled: true,
            priority: 1
        )
    }
    
    /// 创建基础词典信息
    static func basicExample() -> DictionaryInfo {
        return DictionaryInfo(
            name: "basic_english",
            displayName: "基础英语词汇",
            fileName: "basic_english.json",
            filePath: "/path/to/basic_english.json",
            version: "1.0",
            description: "适合初学者的基础英语词汇",
            language: "en",
            totalWords: 1000,
            difficultyLevels: [1, 2, 3, 4],
            categories: ["基础", "初级", "日常"],
            fileSize: 512000,
            checksum: "xyz789uvw012",
            isEnabled: true,
            priority: 0
        )
    }
}