//
//  ErrorTypes.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

import Foundation

// MARK: - Error Severity

/// 错误严重程度
public enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
}

// MARK: - Translation Errors

/// 翻译相关错误已统一到 AppError 枚举中

// MARK: - Dictionary Errors

/// 词典相关错误
enum DictionaryError: LocalizedError {
    case wordNotFound
    case importFailed(String)
    case exportFailed(String)
    case databaseError(Error)
    case invalidFormat
    case fileNotFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .wordNotFound:
            return "未找到单词"
        case .importFailed(let reason):
            return "导入失败: \(reason)"
        case .exportFailed(let reason):
            return "导出失败: \(reason)"
        case .databaseError(let error):
            return "数据库错误: \(error.localizedDescription)"
        case .invalidFormat:
            return "文件格式无效"
        case .fileNotFound:
            return "文件未找到"
        case .permissionDenied:
            return "权限被拒绝"
        }
    }
}

// MARK: - App Errors

/// 应用程序通用错误
public enum AppError: LocalizedError {
    case networkError(Error)
    case dataCorruption
    case fileNotFound(String)
    case invalidInput(String)
    case serviceUnavailable(String)
    case authenticationFailed
    case permissionDenied
    case storageError(Error)
    case parsingError(Error)
    case unknown(Error)
    case initializationFailed
    case configurationError(String)
    case unexpectedError(Error)
    case serviceNotAvailable
    
    // MARK: - Translation Errors
    case translationInvalidInput(String)
    case translationInvalidURL(String)
    case translationInvalidResponse(String)
    case translationInvalidProvider(String)
    case translationProviderNotConfigured(String)
    case translationFailed(String)
    case translationUnsupportedLanguage(String)
    case translationModelNotAvailable(String)
    case translationApiKeyMissing(String)
    case translationRateLimitExceeded(String)
    case translationServiceUnavailable(String)
    case translationInvalidConfiguration(String)
    case translationInvalidRequest(String)
    case translationApiError(Int, String)
}

// MARK: - AppError Extensions

public extension AppError {
    /// 错误键值，用于本地化
    var errorKey: String {
        switch self {
        case .networkError:
            return "network_error"
        case .dataCorruption:
            return "data_corruption"
        case .fileNotFound:
            return "file_not_found"
        case .invalidInput:
            return "invalid_input"
        case .serviceUnavailable:
            return "service_unavailable"
        case .authenticationFailed:
            return "authentication_failed"
        case .permissionDenied:
            return "permission_denied"
        case .storageError:
            return "storage_error"
        case .parsingError:
            return "parsing_error"
        case .initializationFailed:
            return "initialization_failed"
        case .configurationError:
            return "configuration_error"
        case .unexpectedError:
            return "unexpected_error"
        case .serviceNotAvailable:
            return "service_not_available"
        case .unknown:
            return "unknown_error"
            
        // MARK: - Translation Error Keys
        case .translationInvalidInput:
            return "translation_invalid_input"
        case .translationInvalidURL:
            return "translation_invalid_url"
        case .translationInvalidResponse:
            return "translation_invalid_response"
        case .translationInvalidProvider:
            return "translation_invalid_provider"
        case .translationProviderNotConfigured:
            return "translation_provider_not_configured"
        case .translationFailed:
            return "translation_failed"
        case .translationUnsupportedLanguage:
            return "translation_unsupported_language"
        case .translationModelNotAvailable:
            return "translation_model_not_available"
        case .translationApiKeyMissing:
            return "translation_api_key_missing"
        case .translationRateLimitExceeded:
            return "translation_rate_limit_exceeded"
        case .translationServiceUnavailable:
            return "translation_service_unavailable"
        case .translationInvalidConfiguration:
            return "translation_invalid_configuration"
        case .translationInvalidRequest:
            return "translation_invalid_request"
        case .translationApiError:
            return "translation_api_error"
        }
    }
    
    /// 错误严重程度
    var severity: ErrorSeverity {
        switch self {
        case .networkError, .serviceUnavailable, .translationServiceUnavailable:
            return .warning
        case .serviceNotAvailable:
            return .warning
        case .dataCorruption, .storageError, .initializationFailed:
            return .critical
        case .authenticationFailed, .permissionDenied, .translationApiKeyMissing:
            return .error
        case .fileNotFound, .invalidInput, .configurationError,
             .translationInvalidInput, .translationInvalidURL, .translationInvalidResponse,
             .translationInvalidProvider, .translationProviderNotConfigured,
             .translationUnsupportedLanguage, .translationInvalidConfiguration,
             .translationInvalidRequest:
            return .warning
        case .parsingError, .translationFailed, .translationModelNotAvailable,
             .translationRateLimitExceeded, .translationApiError:
            return .error
        case .unexpectedError, .unknown:
            return .critical
        }
    }
    
    /// 错误描述
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .dataCorruption:
            return "数据损坏"
        case .fileNotFound(let fileName):
            return "文件未找到: \(fileName)"
        case .invalidInput(let message):
            return "输入无效: \(message)"
        case .serviceUnavailable(let service):
            return "服务不可用: \(service)"
        case .authenticationFailed:
            return "身份验证失败"
        case .permissionDenied:
            return "权限被拒绝"
        case .storageError(let error):
            return "存储错误: \(error.localizedDescription)"
        case .parsingError(let error):
            return "解析错误: \(error.localizedDescription)"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        case .initializationFailed:
            return "应用初始化失败"
        case .configurationError(let message):
            return "配置错误: \(message)"
        case .unexpectedError(let error):
            return "意外错误: \(error.localizedDescription)"
        case .serviceNotAvailable:
            return "服务不可用"
            
        // MARK: - Translation Error Descriptions
        case .translationInvalidInput(let message):
            return "翻译输入无效: \(message)"
        case .translationInvalidURL(let message):
            return "翻译URL无效: \(message)"
        case .translationInvalidResponse(let message):
            return "翻译响应无效: \(message)"
        case .translationInvalidProvider(let message):
            return "翻译提供商无效: \(message)"
        case .translationProviderNotConfigured(let message):
            return "翻译提供商未配置: \(message)"
        case .translationFailed(let message):
            return "翻译失败: \(message)"
        case .translationUnsupportedLanguage(let message):
            return "不支持的翻译语言: \(message)"
        case .translationModelNotAvailable(let message):
            return "翻译模型不可用: \(message)"
        case .translationApiKeyMissing(let message):
            return "翻译API密钥缺失: \(message)"
        case .translationRateLimitExceeded(let message):
            return "翻译请求频率超限: \(message)"
        case .translationServiceUnavailable(let message):
            return "翻译服务不可用: \(message)"
        case .translationInvalidConfiguration(let message):
            return "翻译配置无效: \(message)"
        case .translationInvalidRequest(let message):
            return "翻译请求无效: \(message)"
        case .translationApiError(let code, let message):
            return "翻译API错误 (\(code)): \(message)"
        }
    }
}



// MARK: - File Operation Errors

/// 文件操作错误
enum FileOperationError: LocalizedError {
    case readFailed(String)
    case writeFailed(String)
    case deleteFailed(String)
    case invalidPath
    case insufficientSpace
    
    var errorDescription: String? {
        switch self {
        case .readFailed(let path):
            return "读取文件失败: \(path)"
        case .writeFailed(let path):
            return "写入文件失败: \(path)"
        case .deleteFailed(let path):
            return "删除文件失败: \(path)"
        case .invalidPath:
            return "无效的文件路径"
        case .insufficientSpace:
            return "存储空间不足"
        }
    }
}

// MARK: - Network Errors

/// 网络相关错误
enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "无网络连接"
        case .timeout:
            return "请求超时"
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .serverError(let code):
            return "服务器错误: \(code)"
        case .rateLimitExceeded:
            return "请求频率超限"
        }
    }
}

// MARK: - Validation Errors

/// 数据验证错误
enum ValidationError: LocalizedError {
    case emptyInput
    case invalidFormat
    case tooLong(Int)
    case tooShort(Int)
    case invalidCharacters
    
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "输入不能为空"
        case .invalidFormat:
            return "格式无效"
        case .tooLong(let maxLength):
            return "输入过长，最大长度为 \(maxLength)"
        case .tooShort(let minLength):
            return "输入过短，最小长度为 \(minLength)"
        case .invalidCharacters:
            return "包含无效字符"
        }
    }
}