//
//  UnifiedErrorHandler.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation
import SwiftUI
import os.log

/// 统一错误处理器，提供全局错误管理和用户友好的错误展示
@Observable
class UnifiedErrorHandler: ErrorHandlerProtocol {
    
    // MARK: - 错误状态
    
    private(set) var currentError: AppError?
    private(set) var isShowingError: Bool = false
    private(set) var errorHistory: [ErrorRecord] = []
    private(set) var errorStatistics = ErrorStatistics(totalErrors: 0, recentErrors: 0, todayErrors: 0, errorTypeCount: [:], mostCommonError: nil)

    
    // MARK: - 配置
    
    private let maxErrorHistory: Int
    private let errorThrottleInterval: TimeInterval
    private let logger: Logger
    
    // MARK: - 错误节流
    
    private var lastErrorTimes: [String: Date] = [:]
    private let throttleQueue = DispatchQueue(label: "com.en01.error.throttle", attributes: .concurrent)
    
    // MARK: - 错误恢复策略
    
    private var recoveryStrategies: [String: ErrorRecoveryStrategy] = [:]
    
    // MARK: - 初始化
    
    init(
        maxErrorHistory: Int = 100,
        errorThrottleInterval: TimeInterval = 5.0,
        subsystem: String = "com.en01.errors",
        category: String = "UnifiedErrorHandler"
    ) {
        self.maxErrorHistory = maxErrorHistory
        self.errorThrottleInterval = errorThrottleInterval
        self.logger = Logger(subsystem: subsystem, category: category)

        setupDefaultRecoveryStrategies()
    }
    
    // MARK: - ErrorHandlerProtocol
    
    func handle(_ error: Error, context: String) {
        let appError: AppError
        
        if let existingAppError = error as? AppError {
            appError = existingAppError
        } else if let serviceError = error as? ServiceError {
            appError = convertServiceError(serviceError)
        } else {
            appError = AppError.unknown(error)
        }
        
        handle(appError, context: context)
    }
    
    func handle(_ appError: AppError) {
        handle(appError, context: "")
    }
    
    func logSuccess(_ message: String) {
        logger.info("✅ \(message)")
    }
    
    func handle(_ appError: AppError, context: String = "") {
        // 错误节流检查
        if shouldThrottleError(appError) {
            logger.debug("错误被节流: \(appError.localizedDescription)")
            return
        }
        
        // 记录错误
        recordError(appError, context: context)
        
        // 更新统计信息
        updateStatistics(for: appError)
        
        // 记录日志
        logError(appError, context: context)
        
        // 尝试自动恢复
        if tryAutoRecovery(for: appError) {
            logger.info("错误已自动恢复: \(appError.localizedDescription)")
            return
        }
        
        // 决定是否显示给用户
        if shouldShowToUser(appError) {
            showError(appError)
        }
        
        // 报告严重错误
        if shouldReportError(appError) {
            reportError(appError, context: context)
        }
    }
    
    func dismissError() {
        currentError = nil
        isShowingError = false
        logger.debug("用户已关闭错误提示")
    }
    
    func clearAllErrors() {
        currentError = nil
        isShowingError = false
        errorHistory.removeAll()
        errorStatistics = ErrorStatistics(totalErrors: 0, recentErrors: 0, todayErrors: 0, errorTypeCount: [:], mostCommonError: nil)
        lastErrorTimes.removeAll()
        logger.info("所有错误已清除")
    }
    
    // MARK: - 扩展功能
    
    /// 注册错误恢复策略
    func registerRecoveryStrategy(_ strategy: ErrorRecoveryStrategy, for errorType: String) {
        recoveryStrategies[errorType] = strategy
        logger.debug("已注册恢复策略: \(errorType)")
    }
    
    /// 获取错误历史
    func getErrorHistory(limit: Int? = nil) -> [ErrorRecord] {
        if let limit = limit {
            return Array(errorHistory.prefix(limit))
        }
        return errorHistory
    }
    
    /// 获取错误统计信息
    func getErrorStatistics() -> ErrorStatistics {
        return errorStatistics
    }
    
    /// 导出错误报告
    func exportErrorReport() -> ErrorReport {
        return ErrorReport(
            timestamp: Date(),
            statistics: errorStatistics,
            recentErrors: Array(errorHistory.prefix(20)),
            systemInfo: collectSystemInfo()
        )
    }
    
    // MARK: - 私有方法
    
    private func shouldThrottleError(_ error: AppError) -> Bool {
        return throttleQueue.sync {
            let errorKey = error.errorKey
            let now = Date()
            
            if let lastTime = lastErrorTimes[errorKey] {
                let timeSinceLastError = now.timeIntervalSince(lastTime)
                if timeSinceLastError < errorThrottleInterval {
                    return true
                }
            }
            
            lastErrorTimes[errorKey] = now
            return false
        }
    }
    
    private func recordError(_ error: AppError, context: String) {
        let record = ErrorRecord(
            error: error,
            context: context,
            timestamp: Date()
        )
        
        errorHistory.insert(record, at: 0)
        
        // 限制历史记录数量
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeLast(errorHistory.count - maxErrorHistory)
        }
    }
    
    private func updateStatistics(for error: AppError) {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let oneDayAgo = now.addingTimeInterval(-86400)
        
        let recentErrorsCount = errorHistory.filter { $0.timestamp > oneHourAgo }.count
        let todayErrorsCount = errorHistory.filter { $0.timestamp > oneDayAgo }.count
        
        let errorTypeCount = Dictionary(grouping: errorHistory) { $0.error.errorKey }
            .mapValues { $0.count }
        
        errorStatistics.totalErrors = errorHistory.count
        errorStatistics.recentErrors = recentErrorsCount
        errorStatistics.todayErrors = todayErrorsCount
        errorStatistics.errorTypeCount = errorTypeCount
        errorStatistics.mostCommonError = errorTypeCount.max(by: { $0.value < $1.value })?.key
    }
    
    private func logError(_ error: AppError, context: String) {
        let contextInfo = context.isEmpty ? "" : " [\(context)]"
        
        switch error.severity {
        case .info:
            logger.info("\(error.localizedDescription)\(contextInfo)")
        case .warning:
            logger.warning("\(error.localizedDescription)\(contextInfo)")
        case .error:
            logger.error("\(error.localizedDescription)\(contextInfo)")
        case .critical:
            logger.error("\(error.localizedDescription)\(contextInfo)")
        }
    }
    
    private func shouldShowToUser(_ error: AppError) -> Bool {
        switch error.severity {
        case .info:
            return false // 信息级错误通常不显示给用户
        case .warning:
            return true  // 警告级错误显示给用户
        case .error:
            return true  // 错误级别必须显示给用户
        case .critical:
            return true  // 严重错误必须显示给用户
        }
    }
    
    private func shouldReportError(_ error: AppError) -> Bool {
        switch error.severity {
        case .info, .warning:
            return false
        case .error, .critical:
            return true
        }
    }
    
    private func showError(_ error: AppError) {
        currentError = error
        isShowingError = true
        logger.debug("向用户显示错误: \(error.localizedDescription)")
    }
    
    private func reportError(_ error: AppError, context: String) {
        // 这里可以集成崩溃报告服务（如 Crashlytics）
        logger.error("严重错误需要报告: \(error.localizedDescription), 上下文: \(context)")
        
        // TODO: 集成第三方错误报告服务
        // CrashlyticsService.shared.recordError(error, context: context)
    }
    
    private func tryAutoRecovery(for error: AppError) -> Bool {
        let errorType = String(describing: type(of: error))
        
        guard let strategy = recoveryStrategies[errorType] else {
            return false
        }
        
        do {
            try strategy.recover(from: error)
            logger.info("自动恢复成功: \(errorType)")
            return true
        } catch {
            logger.error("自动恢复失败: \(errorType), 错误: \(error.localizedDescription)")
            return false
        }
    }
    
    private func convertServiceError(_ serviceError: ServiceError) -> AppError {
        switch serviceError {
        case .networkError(let error):
            return AppError.networkError(error)
        case .storageError(let error):
            return AppError.storageError(error)
        case .validationError(let message):
            return AppError.invalidInput(message)
        case .notFound(let resource):
            return AppError.fileNotFound(resource)
        case .unauthorized:
            return AppError.authenticationFailed
        case .forbidden:
            return AppError.permissionDenied
        case .serverError(_, let message):
            return AppError.serviceUnavailable(message)
        case .timeout:
            return AppError.networkError(NSError(domain: "TimeoutError", code: -1001, userInfo: [NSLocalizedDescriptionKey: "请求超时"]))
        case .cancelled:
            return AppError.unknown(NSError(domain: "CancelledError", code: -999, userInfo: [NSLocalizedDescriptionKey: "请求已取消"]))
        case .processingFailed(let message):
            return AppError.unknown(NSError(domain: "ProcessingError", code: -1002, userInfo: [NSLocalizedDescriptionKey: message]))
        case .databaseError(let error):
            return AppError.storageError(error)
        case .encodingError(let error):
            return AppError.parsingError(error)
        case .decodingError(let error):
            return AppError.parsingError(error)
        case .unknown(let error):
            return AppError.unknown(error)
        }
    }
    
    private func setupDefaultRecoveryStrategies() {
        // 网络错误恢复策略
        registerRecoveryStrategy(
            NetworkErrorRecoveryStrategy(),
            for: "NetworkError"
        )
        
        // 存储错误恢复策略
        registerRecoveryStrategy(
            StorageErrorRecoveryStrategy(),
            for: "StorageError"
        )
    }
    
    private func collectSystemInfo() -> SystemInfo {
        return SystemInfo(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: ProcessInfo.processInfo.machineIdentifier,
            memoryUsage: ProcessInfo.processInfo.physicalMemory,
            timestamp: Date()
        )
    }
}

// MARK: - 错误恢复策略

protocol ErrorRecoveryStrategy {
    func recover(from error: AppError) throws
}

struct NetworkErrorRecoveryStrategy: ErrorRecoveryStrategy {
    func recover(from error: AppError) throws {
        // 实现网络错误的自动恢复逻辑
        // 例如：重试网络请求、切换网络配置等
    }
}

struct StorageErrorRecoveryStrategy: ErrorRecoveryStrategy {
    func recover(from error: AppError) throws {
        // 实现存储错误的自动恢复逻辑
        // 例如：清理缓存、重新初始化数据库等
    }
}

// MARK: - 数据结构

struct ErrorReport {
    let timestamp: Date
    let statistics: ErrorStatistics
    let recentErrors: [ErrorRecord]
    let systemInfo: SystemInfo
}

struct SystemInfo {
    let appVersion: String
    let buildNumber: String
    let systemVersion: String
    let deviceModel: String
    let memoryUsage: UInt64
    let timestamp: Date
}

// MARK: - ProcessInfo 扩展

extension ProcessInfo {
    var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }
}