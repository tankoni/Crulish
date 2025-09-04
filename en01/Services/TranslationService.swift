//
//  TranslationService.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import Foundation
import CoreML

// 导入统一的翻译模型定义
// 所有翻译相关的数据模型现在统一在 TranslationModels.swift 中定义
// 这确保了类型定义的一致性和可访问性

// MARK: - Translation Service Protocol

protocol TranslationServiceProtocol {
    // 基础翻译功能
    func translateWord(_ word: String, context: String) async throws -> Translation?
    func translateSentence(_ sentence: String) async throws -> Translation?
    func translateParagraph(_ paragraph: String) async throws -> Translation?
    
    // 翻译配置
    func setTranslationProvider(_ provider: TranslationProvider)
    func getAvailableProviders() -> [TranslationProvider]
    func isLocalModelAvailable() -> Bool
    
    // 缓存管理
    func clearTranslationCache()
    func getCacheStatistics() -> TranslationCacheStats
}

// MARK: - Translation Models
// 注意：所有翻译相关的数据模型已移动到 TranslationModels.swift
// 这里不再重复定义，避免类型冲突

// 翻译错误处理已统一到 AppError 体系中