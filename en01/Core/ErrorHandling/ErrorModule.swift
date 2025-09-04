//
//  ErrorModule.swift
//  en01
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation

// MARK: - 错误模块统一导出
// 这个文件作为错误处理的统一入口点，确保所有错误类型都能被正确访问

// 重新导出 ErrorTypes 中的所有错误类型
// 注意：在同一模块内，不需要模块前缀
// 这些类型别名确保错误类型在整个项目中的一致性

// MARK: - 错误处理工具函数

/// 错误处理工具类
public struct ErrorUtils {
    
    /// 将通用错误转换为AppError
    /// - Parameter error: 原始错误
    /// - Returns: 转换后的AppError
    public static func convertToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        return AppError.unknown(error)
    }
    
    /// 创建翻译相关错误
    /// - Parameters:
    ///   - type: 错误类型
    ///   - message: 错误消息
    /// - Returns: AppError实例
    public static func createTranslationError(type: TranslationErrorType, message: String) -> AppError {
        switch type {
        case .modelNotAvailable:
            return AppError.translationModelNotAvailable(message)
        case .failed:
            return AppError.translationFailed(message)
        case .invalidInput:
            return AppError.translationInvalidInput(message)
        case .unsupportedLanguage:
            return AppError.translationUnsupportedLanguage(message)
        case .serviceUnavailable:
            return AppError.translationServiceUnavailable(message)
        }
    }
}

/// 翻译错误类型枚举
public enum TranslationErrorType {
    case modelNotAvailable
    case failed
    case invalidInput
    case unsupportedLanguage
    case serviceUnavailable
}

// MARK: - 错误处理协议扩展

extension ErrorHandlerProtocol {
    
    /// 处理翻译错误的便捷方法
    /// - Parameters:
    ///   - type: 翻译错误类型
    ///   - message: 错误消息
    ///   - context: 上下文信息
    public func handleTranslationError(type: TranslationErrorType, message: String, context: String = "") {
        let appError = ErrorUtils.createTranslationError(type: type, message: message)
        handle(appError, context: context)
    }
    
    /// 处理通用错误的便捷方法
    /// - Parameters:
    ///   - error: 原始错误
    ///   - context: 上下文信息
    public func handleGenericError(_ error: Error, context: String = "") {
        let appError = ErrorUtils.convertToAppError(error)
        handle(appError, context: context)
    }
}