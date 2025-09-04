//
//  TranslationErrorHandler.swift
//  en01
//
//  Created by AI Assistant on 2024-12-30.
//  专门处理翻译相关错误的统一错误处理器
//

import Foundation
import OSLog

// 导入必要的错误类型和翻译模型
// 这些类型定义在项目的其他文件中
// 注意：在实际项目中，这些类型应该通过模块导入或在同一个target中可见

/// 翻译错误处理器 - 提供统一的错误处理、分类和恢复机制
class TranslationErrorHandler {
    private let logger = Logger(subsystem: "com.en01.translation", category: "ErrorHandler")
    
    // MARK: - Error Classification
    
    /// 错误分类枚举
    enum ErrorCategory {
        case network          // 网络相关错误
        case authentication   // 认证相关错误
        case rateLimit       // 速率限制错误
        case apiResponse     // API响应错误
        case configuration   // 配置错误
        case validation      // 输入验证错误
        case unknown         // 未知错误
    }
    
    /// 错误恢复策略
    enum RecoveryStrategy {
        case retry(maxAttempts: Int, delay: TimeInterval)
        case fallback(provider: TranslationProvider)
        case cache
        case none
    }
    
    // MARK: - Error Analysis
    
    /// 分析错误类型并返回分类
    func categorizeError(_ error: Error) -> ErrorCategory {
        if let appError = error as? AppError {
            switch appError {
            case .networkError:
                return .network
            case .translationProviderNotConfigured, .translationInvalidProvider:
                return .configuration
            case .translationRateLimitExceeded:
                return .rateLimit
            case .translationInvalidInput:
                return .validation
            case .translationApiError:
                return .apiResponse
            default:
                return .unknown
            }
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return .network
            case .userAuthenticationRequired, .userCancelledAuthentication:
                return .authentication
            default:
                return .network
            }
        }
        
        return .unknown
    }
    
    /// 确定错误的恢复策略
    func determineRecoveryStrategy(for error: Error, provider: TranslationProvider) -> RecoveryStrategy {
        let category = categorizeError(error)
        
        switch category {
        case .network:
            return .retry(maxAttempts: 3, delay: 2.0)
        case .rateLimit:
            return .retry(maxAttempts: 2, delay: 60.0)
        case .authentication, .configuration:
            return .fallback(provider: getFallbackProvider(excluding: provider))
        case .apiResponse:
            return .retry(maxAttempts: 2, delay: 1.0)
        case .validation:
            return .none
        case .unknown:
            return .retry(maxAttempts: 1, delay: 1.0)
        }
    }
    
    // MARK: - Error Recovery
    
    /// 执行带重试机制的翻译操作
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                let result = try await operation()
                if attempt > 1 {
                    logger.info("Operation succeeded on attempt \(attempt)")
                }
                return result
            } catch {
                lastError = error
                logger.warning("Operation failed on attempt \(attempt): \(error.localizedDescription)")
                
                // 如果不是最后一次尝试，则等待后重试
                if attempt < maxAttempts {
                    let delay = baseDelay * pow(backoffMultiplier, Double(attempt - 1))
                    logger.info("Retrying in \(delay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // 所有重试都失败，抛出最后一个错误
        throw lastError ?? AppError.translationFailed("All retry attempts failed")
    }
    
    /// ClawCloud连通性检查（带重试机制）
    func checkClawCloudConnectivityWithRetry(
        apiKey: String = "tankoni",
        maxAttempts: Int = 3
    ) async -> Bool {
        return await executeWithRetryBool(
            operation: {
                await self.performClawCloudConnectivityCheck(apiKey: apiKey)
            },
            maxAttempts: maxAttempts
        )
    }
    
    /// 执行带重试的布尔操作
    private func executeWithRetryBool(
        operation: @escaping () async -> Bool,
        maxAttempts: Int = 3
    ) async -> Bool {
        for attempt in 1...maxAttempts {
            let result = await operation()
            if result {
                if attempt > 1 {
                    logger.info("Connectivity check succeeded on attempt \(attempt)")
                }
                return true
            }
            
            if attempt < maxAttempts {
                let delay = TimeInterval(attempt) // 递增延迟
                logger.info("Connectivity check failed, retrying in \(delay) seconds...")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        logger.error("ClawCloud connectivity check failed after \(maxAttempts) attempts")
        return false
    }
    
    /// 执行实际的连通性检查
    private func performClawCloudConnectivityCheck(apiKey: String) async -> Bool {
        // 使用与翻译API相同的服务器地址进行连通性检查
        let url = URL(string: "https://xxobadygvwbx.ap-southeast-1.clawcloudrun.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer tankoni", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                let isSuccess = (200...299).contains(httpResponse.statusCode)
                logger.info("ClawCloud connectivity check: \(httpResponse.statusCode) - \(isSuccess ? "Success" : "Failed")")
                return isSuccess
            }
            return false
        } catch {
            logger.error("ClawCloud connectivity check error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Provider Management
    
    /// 获取备用提供商
    private func getFallbackProvider(excluding: TranslationProvider) -> TranslationProvider {
        let allProviders: [TranslationProvider] = [
            .gpt4omini, .gpt35turbo, .claude3haiku, .gemini15flash,
            .deepseekV3, .qwenMax, .doubaoLite, .google, .baidu
        ]
        
        return allProviders.first { $0 != excluding } ?? .google
    }
    
    // MARK: - Error Logging
    
    /// 记录详细的错误信息
    func logError(
        _ error: Error,
        context: String,
        provider: TranslationProvider,
        text: String? = nil
    ) {
        let category = categorizeError(error)
        let errorDescription = error.localizedDescription
        
        logger.error("""
        Translation Error Details:
        - Context: \(context)
        - Provider: \(provider.displayName)
        - Category: \(category)
        - Error: \(errorDescription)
        - Text Length: \(text?.count ?? 0)
        """)
        
        // 如果是网络错误，记录额外信息
        if let urlError = error as? URLError {
            logger.error("URLError Code: \(urlError.code.rawValue), UserInfo: \(urlError.userInfo)")
        }
    }
    
    /// 记录成功的翻译操作
    func logSuccess(
        provider: TranslationProvider,
        duration: TimeInterval,
        textLength: Int,
        attempt: Int = 1
    ) {
        logger.info("""
        Translation Success:
        - Provider: \(provider.displayName)
        - Duration: \(String(format: "%.2f", duration))s
        - Text Length: \(textLength)
        - Attempt: \(attempt)
        """)
    }
    
    // MARK: - Error Conversion
    
    /// 将通用错误转换为AppError
    func convertToAppError(_ error: Error, context: String = "") -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError(urlError)
            case .timedOut:
                return .networkError(urlError)
            case .userAuthenticationRequired:
                return .translationApiError(401, "API认证失败: \(urlError.localizedDescription)")
            default:
                return .networkError(urlError)
            }
        }
        
        return .translationFailed("\(context): \(error.localizedDescription)")
    }
}

// MARK: - Extensions

// displayName属性已在TranslationModels.swift中的TranslationProvider枚举内定义