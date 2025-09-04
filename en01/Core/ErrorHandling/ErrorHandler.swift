//
//  ErrorHandler.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftUI
import Observation

// 导入统一错误处理模块
// 这确保了AppError类型能够被正确识别
// 注意：这是架构优化的一部分，统一了错误处理方式

/// 错误处理器实现
@Observable
class ErrorHandler: ErrorHandlerProtocol {
    @ObservationIgnored
    private let logger = Logger(subsystem: "com.en01.app", category: "ErrorHandler")
    
    // MARK: - 公开属性
    
    private(set) var currentError: AppError?
    private(set) var isShowingError: Bool = false
    
    // 错误历史记录
    private var errorHistory: [ErrorRecord] = []
    private let maxHistoryCount = 50
    
    // 错误频率限制
    private var errorCounts: [String: Int] = [:]
    private var lastErrorTimes: [String: Date] = [:]
    private let maxErrorsPerMinute = 5
    
    init() {
        // 启动清理定时器
        startCleanupTimer()
    }
    
    // MARK: - ErrorHandlerProtocol
    
    func handle(_ error: Error, context: String = "") {
        let appError: AppError
        
        if let existingAppError = error as? AppError {
            appError = existingAppError
        } else {
            appError = AppError.unknown(error)
        }
        
        handle(appError, context: context)
    }
    
    func handle(_ appError: AppError) {
        handle(appError, context: "")
    }
    
    func dismissError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.isShowingError = false
        }
    }
    
    func clearAllErrors() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.isShowingError = false
            self.errorHistory.removeAll()
            self.errorCounts.removeAll()
            self.lastErrorTimes.removeAll()
        }
    }
    
    func logSuccess(_ message: String) {
        logger.info("✅ \(message)")
    }
    
    // MARK: - 扩展功能
    
    /// 处理错误（带上下文）
    func handle(_ appError: AppError, context: String) {
        let errorKey = appError.errorKey
        
        // 检查错误频率限制
        if shouldThrottleError(errorKey) {
            logger.warning("Error throttled: \(errorKey)")
            return
        }
        
        // 记录错误
        recordError(appError, context: context)
        
        // 根据错误严重程度决定是否显示给用户
        if shouldShowToUser(appError) {
            DispatchQueue.main.async {
                self.currentError = appError
                self.isShowingError = true
            }
        }
        
        // 记录日志
        logError(appError, context: context)
        
        // 发送错误报告（如果需要）
        if shouldReportError(appError) {
            reportError(appError, context: context)
        }
    }
    
    /// 获取错误历史记录
    func getErrorHistory() -> [ErrorRecord] {
        return errorHistory
    }
    
    /// 获取错误统计信息
    func getErrorStatistics() -> ErrorStatistics {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let oneDayAgo = now.addingTimeInterval(-86400)
        
        let recentErrors = errorHistory.filter { $0.timestamp > oneHourAgo }
        let todayErrors = errorHistory.filter { $0.timestamp > oneDayAgo }
        
        let errorTypeCount = Dictionary(grouping: errorHistory) { $0.error.errorKey }
            .mapValues { $0.count }
        
        return ErrorStatistics(
            totalErrors: errorHistory.count,
            recentErrors: recentErrors.count,
            todayErrors: todayErrors.count,
            errorTypeCount: errorTypeCount,
            mostCommonError: errorTypeCount.max(by: { $0.value < $1.value })?.key
        )
    }
    
    /// 清理旧的错误记录
    func cleanupOldErrors() {
        let cutoffDate = Date().addingTimeInterval(-86400 * 7) // 保留7天
        errorHistory.removeAll { $0.timestamp < cutoffDate }
        
        // 清理错误计数
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        for (key, time) in lastErrorTimes {
            if time < oneMinuteAgo {
                errorCounts.removeValue(forKey: key)
                lastErrorTimes.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func shouldThrottleError(_ errorKey: String) -> Bool {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        
        // 清理过期的错误计数
        if let lastTime = lastErrorTimes[errorKey], lastTime < oneMinuteAgo {
            errorCounts.removeValue(forKey: errorKey)
            lastErrorTimes.removeValue(forKey: errorKey)
        }
        
        let currentCount = errorCounts[errorKey] ?? 0
        if currentCount >= maxErrorsPerMinute {
            return true
        }
        
        // 更新计数
        errorCounts[errorKey] = currentCount + 1
        lastErrorTimes[errorKey] = now
        
        return false
    }
    
    private func shouldShowToUser(_ error: AppError) -> Bool {
        switch error {
        case .networkError, .fileNotFound, .invalidInput, .authenticationFailed, .permissionDenied:
            return true
        case .dataCorruption, .serviceUnavailable, .storageError, .parsingError:
            return true
        case .initializationFailed, .configurationError:
            return true
        case .translationFailed, .translationUnsupportedLanguage,
             .translationModelNotAvailable, .translationApiKeyMissing,
             .translationRateLimitExceeded, .translationServiceUnavailable,
             .translationInvalidConfiguration, .translationInvalidRequest,
             .translationApiError:
            return true
        case .translationInvalidInput, .translationInvalidURL, .translationInvalidResponse,
             .translationInvalidProvider, .translationProviderNotConfigured:
            return false
        case .unknown, .unexpectedError:
            return false // 未知错误通常不显示给用户
        }
    }
    
    private func shouldReportError(_ error: AppError) -> Bool {
        switch error {
        case .dataCorruption, .unknown, .unexpectedError:
            return true
        case .storageError, .parsingError, .initializationFailed:
            return true
        default:
            return false
        }
    }
    
    private func recordError(_ error: AppError, context: String) {
        let record = ErrorRecord(
            error: error,
            context: context,
            timestamp: Date()
        )
        
        errorHistory.append(record)
        
        // 限制历史记录数量
        if errorHistory.count > maxHistoryCount {
            errorHistory.removeFirst(errorHistory.count - maxHistoryCount)
        }
    }
    
    private func logError(_ error: AppError, context: String) {
        let contextInfo = context.isEmpty ? "" : " [Context: \(context)]"
        
        switch error {
        case .networkError(let underlyingError):
            logger.error("Network error: \(underlyingError.localizedDescription)\(contextInfo)")
        case .dataCorruption:
            logger.error("Data corruption detected\(contextInfo)")
        case .fileNotFound(let fileName):
            logger.error("File not found: \(fileName)\(contextInfo)")
        case .invalidInput(let message):
            logger.warning("Invalid input: \(message)\(contextInfo)")
        case .serviceUnavailable(let service):
            logger.error("Service unavailable: \(service)\(contextInfo)")
        case .authenticationFailed:
            logger.error("Authentication failed\(contextInfo)")
        case .permissionDenied:
            logger.error("Permission denied\(contextInfo)")
        case .storageError(let underlyingError):
            logger.error("Storage error: \(underlyingError.localizedDescription)\(contextInfo)")
        case .parsingError(let underlyingError):
            logger.error("Parsing error: \(underlyingError.localizedDescription)\(contextInfo)")
        case .initializationFailed:
            logger.error("Initialization failed\(contextInfo)")
        case .configurationError(let message):
            logger.error("Configuration error: \(message)\(contextInfo)")
        case .translationFailed(let message):
            logger.error("Translation failed: \(message)\(contextInfo)")
        case .translationUnsupportedLanguage(let language):
            logger.error("Translation unsupported language: \(language)\(contextInfo)")
        case .translationModelNotAvailable(let model):
            logger.error("Translation model not available: \(model)\(contextInfo)")
        case .translationApiKeyMissing:
            logger.error("Translation API key missing\(contextInfo)")
        case .translationRateLimitExceeded:
            logger.error("Translation rate limit exceeded\(contextInfo)")
        case .translationServiceUnavailable:
            logger.error("Translation service unavailable\(contextInfo)")
        case .translationInvalidConfiguration(let message):
            logger.error("Translation invalid configuration: \(message)\(contextInfo)")
        case .translationInvalidRequest(let message):
            logger.error("Translation invalid request: \(message)\(contextInfo)")
        case .translationApiError(let code, let message):
            logger.error("Translation API error (\(code)): \(message)\(contextInfo)")
        case .translationInvalidInput(let message):
            logger.warning("Translation invalid input: \(message)\(contextInfo)")
        case .translationInvalidURL(let url):
            logger.error("Translation invalid URL: \(url)\(contextInfo)")
        case .translationInvalidResponse(let message):
            logger.error("Translation invalid response: \(message)\(contextInfo)")
        case .translationInvalidProvider(let provider):
            logger.error("Translation invalid provider: \(provider)\(contextInfo)")
        case .translationProviderNotConfigured(let provider):
            logger.error("Translation provider not configured: \(provider)\(contextInfo)")
        case .unexpectedError(let underlyingError):
            logger.error("Unexpected error: \(underlyingError.localizedDescription)\(contextInfo)")
        case .unknown(let underlyingError):
            logger.error("Unknown error: \(underlyingError.localizedDescription)\(contextInfo)")
        }
    }
    
    private func reportError(_ error: AppError, context: String) {
        // 这里可以实现错误报告功能，比如发送到分析服务
        // 目前只是记录日志
        logger.info("Error reported: \(error.errorKey) - \(context)")
    }
    
    private func startCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.cleanupOldErrors()
        }
    }
}

// MARK: - 应用错误类型 (已移至 Models/ErrorTypes.swift)

// MARK: - 支持类型

/// 错误记录
struct ErrorRecord {
    let error: AppError
    let context: String
    let timestamp: Date
    
    var id: String {
        return "\(error.errorKey)_\(timestamp.timeIntervalSince1970)"
    }
}

/// 错误统计信息
@Observable
class ErrorStatistics {
    var totalErrors: Int
    var recentErrors: Int
    var todayErrors: Int
    var errorTypeCount: [String: Int]
    var mostCommonError: String?

    init(totalErrors: Int = 0, recentErrors: Int = 0, todayErrors: Int = 0, errorTypeCount: [String: Int] = [:], mostCommonError: String? = nil) {
        self.totalErrors = totalErrors
        self.recentErrors = recentErrors
        self.todayErrors = todayErrors
        self.errorTypeCount = errorTypeCount
        self.mostCommonError = mostCommonError
    }
}



/// 日志记录器
struct Logger {
    let subsystem: String
    let category: String
    
    func debug(_ message: String) {
        print("[DEBUG][\(category)] \(message)")
    }
    
    func info(_ message: String) {
        print("[INFO][\(category)] \(message)")
    }
    
    func warning(_ message: String) {
        print("[WARNING][\(category)] \(message)")
    }
    
    func error(_ message: String) {
        print("[ERROR][\(category)] \(message)")
    }
}