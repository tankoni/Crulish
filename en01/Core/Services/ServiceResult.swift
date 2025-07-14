//
//  ServiceResult.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation

/// 服务层统一结果类型
public enum ServiceResult<T> {
    case success(T)
    case failure(ServiceError)
    
    /// 获取成功结果的值
    public var value: T? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    /// 获取失败结果的错误
    public var error: ServiceError? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
    
    /// 是否成功
    public var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    /// 是否失败
    public var isFailure: Bool {
        return !isSuccess
    }
    
    /// 映射成功值
    public func map<U>(_ transform: (T) -> U) -> ServiceResult<U> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// 平铺映射
    public func flatMap<U>(_ transform: (T) -> ServiceResult<U>) -> ServiceResult<U> {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// 映射错误
    public func mapError(_ transform: (ServiceError) -> ServiceError) -> ServiceResult<T> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(transform(error))
        }
    }
}

// MARK: - 服务错误类型

public enum ServiceError: Error, LocalizedError {
    case networkError(Error)
    case storageError(Error)
    case validationError(String)
    case notFound(String)
    case unauthorized
    case forbidden
    case serverError(Int, String)
    case timeout
    case cancelled
    case processingFailed(String)
    case databaseError(Error)
    case encodingError(Error)
    case decodingError(Error)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .storageError(let error):
            return "存储错误: \(error.localizedDescription)"
        case .validationError(let message):
            return "验证错误: \(message)"
        case .notFound(let resource):
            return "未找到资源: \(resource)"
        case .unauthorized:
            return "未授权访问"
        case .forbidden:
            return "访问被禁止"
        case .serverError(let code, let message):
            return "服务器错误 (\(code)): \(message)"
        case .timeout:
            return "请求超时"
        case .cancelled:
            return "操作已取消"
        case .processingFailed(let message):
            return "处理失败: \(message)"
        case .databaseError(let error):
            return "数据库错误: \(error.localizedDescription)"
        case .encodingError(let error):
            return "编码错误: \(error.localizedDescription)"
        case .decodingError(let error):
            return "解码错误: \(error.localizedDescription)"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .networkError:
            return "网络连接问题"
        case .storageError:
            return "数据存储问题"
        case .validationError:
            return "输入数据无效"
        case .notFound:
            return "请求的资源不存在"
        case .unauthorized:
            return "需要用户认证"
        case .forbidden:
            return "用户权限不足"
        case .serverError:
            return "服务器内部错误"
        case .timeout:
            return "网络请求超时"
        case .cancelled:
            return "用户取消操作"
        case .processingFailed:
            return "数据处理失败"
        case .databaseError:
            return "数据库操作失败"
        case .encodingError:
            return "数据编码失败"
        case .decodingError:
            return "数据解码失败"
        case .unknown:
            return "系统内部错误"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "请检查网络连接后重试"
        case .storageError:
            return "请检查存储空间后重试"
        case .validationError:
            return "请检查输入数据的格式和内容"
        case .notFound:
            return "请确认资源路径或ID是否正确"
        case .unauthorized:
            return "请登录后重试"
        case .forbidden:
            return "请联系管理员获取访问权限"
        case .serverError:
            return "请稍后重试，如问题持续请联系技术支持"
        case .timeout:
            return "请检查网络连接后重试"
        case .cancelled:
            return "操作已取消，如需继续请重新操作"
        case .processingFailed:
            return "请检查数据格式后重试"
        case .databaseError:
            return "请重启应用或清除缓存后重试"
        case .encodingError:
            return "请检查数据格式后重试"
        case .decodingError:
            return "请检查数据格式后重试"
        case .unknown:
            return "请重启应用后重试"
        }
    }
    
    /// 错误严重程度
    public var severity: ErrorSeverity {
        switch self {
        case .networkError, .timeout:
            return .warning
        case .storageError, .serverError, .unknown:
            return .error
        case .validationError, .notFound:
            return .info
        case .unauthorized, .forbidden:
            return .warning
        case .cancelled:
            return .info
        case .processingFailed:
            return .error
        case .databaseError:
            return .error
        case .encodingError:
            return .warning
        case .decodingError:
            return .warning
        }
    }
    
    /// 是否应该重试
    public var shouldRetry: Bool {
        switch self {
        case .networkError, .timeout, .serverError:
            return true
        case .storageError, .validationError, .notFound, .unauthorized, .forbidden, .cancelled, .processingFailed, .databaseError, .encodingError, .decodingError, .unknown:
            return false
        }
    }
}

// MARK: - 便利扩展

extension ServiceResult {
    
    /// 从可选值创建结果
    public static func fromOptional(_ value: T?, error: ServiceError) -> ServiceResult<T> {
        if let value = value {
            return .success(value)
        } else {
            return .failure(error)
        }
    }
    
    /// 从抛出函数创建结果
    public static func from(_ action: () throws -> T) -> ServiceResult<T> {
        do {
            let value = try action()
            return .success(value)
        } catch {
            let serviceError: ServiceError
            if let existingServiceError = error as? ServiceError {
                serviceError = existingServiceError
            } else {
                serviceError = .unknown(error)
            }
            return .failure(serviceError)
        }
    }
    
    /// 从异步抛出函数创建结果
    public static func fromAsync(_ action: () async throws -> T) async -> ServiceResult<T> {
        do {
            let value = try await action()
            return .success(value)
        } catch {
            let serviceError: ServiceError
            if let existingServiceError = error as? ServiceError {
                serviceError = existingServiceError
            } else {
                serviceError = .unknown(error)
            }
            return .failure(serviceError)
        }
    }
    
    /// 处理结果
    public func handle(
        onSuccess: (T) -> Void,
        onFailure: (ServiceError) -> Void
    ) {
        switch self {
        case .success(let value):
            onSuccess(value)
        case .failure(let error):
            onFailure(error)
        }
    }
    
    /// 异步处理结果
    public func handleAsync(
        onSuccess: (T) async -> Void,
        onFailure: (ServiceError) async -> Void
    ) async {
        switch self {
        case .success(let value):
            await onSuccess(value)
        case .failure(let error):
            await onFailure(error)
        }
    }
    
    /// 获取值或默认值
    public func valueOrDefault(_ defaultValue: T) -> T {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return defaultValue
        }
    }
    
    /// 获取值或执行闭包
    public func valueOrElse(_ provider: () -> T) -> T {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return provider()
        }
    }
}

// MARK: - 空结果类型

public typealias VoidResult = ServiceResult<Void>

extension ServiceResult where T == Void {
    /// 创建成功的空结果
    public static var success: ServiceResult<Void> {
        return .success(())
    }
}