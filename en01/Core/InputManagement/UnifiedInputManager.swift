//
//  UnifiedInputManager.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import SwiftUI
import UIKit
import Combine

/// 统一输入系统管理器，整合键盘管理、焦点管理和约束冲突解决
@MainActor
class UnifiedInputManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isInputSystemActive: Bool = false
    @Published var currentInputMode: InputMode = .none
    @Published var systemHealth: SystemHealth = .healthy
    @Published var errorCount: Int = 0
    @Published var lastErrorTime: Date? = nil
    
    // MARK: - Managers
    private let keyboardManager = KeyboardManager.shared
    private let focusManager = InputFocusManager.shared
    private let conflictResolver = ConstraintConflictResolver.shared
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var healthCheckTimer: Timer?
    private var errorRecoveryTimer: Timer?
    private var sessionManager: InputSessionManager
    
    // 配置参数
    private let healthCheckInterval: TimeInterval = 2.0
    private let errorRecoveryDelay: TimeInterval = 1.0
    private let maxErrorCount = 10
    
    // MARK: - Singleton
    static let shared = UnifiedInputManager()
    
    private init() {
        self.sessionManager = InputSessionManager()
        setupInputSystemIntegration()
        startSystemHealthMonitoring()
    }
    
    deinit {
        // 使用nonisolated cleanup避免deinit中的并发问题
        cleanup()
    }
    
    // MARK: - Public Methods
    
    /// 初始化输入系统
    func initializeInputSystem() {
        print("[UnifiedInputManager] 初始化输入系统")
        
        // 启动各个管理器
        conflictResolver.startMonitoring()
        
        // 设置系统状态
        isInputSystemActive = true
        currentInputMode = .ready
        systemHealth = .healthy
        
        print("[UnifiedInputManager] 输入系统初始化完成")
    }
    
    /// 关闭输入系统
    func shutdownInputSystem() {
        print("[UnifiedInputManager] 关闭输入系统")
        
        // 停止监控
        conflictResolver.stopMonitoring()
        stopSystemHealthMonitoring()
        
        // 清理所有输入状态
        focusManager.clearAllFocus()
        keyboardManager.endInputSession()
        
        // 重置状态
        isInputSystemActive = false
        currentInputMode = .none
        systemHealth = .shutdown
        
        print("[UnifiedInputManager] 输入系统已关闭")
    }
    
    /// 开始输入会话
    func beginInputSession(fieldId: String, priority: Int = 0, inputType: InputType = .text) {
        print("[UnifiedInputManager] 开始输入会话: \(fieldId)")
        
        // 检查系统健康状态
        if systemHealth == .critical {
            print("[UnifiedInputManager] 系统状态异常，拒绝输入会话")
            return
        }
        
        // 创建输入会话
        let session = InputSession(
            fieldId: fieldId,
            priority: priority,
            inputType: inputType,
            startTime: Date()
        )
        
        sessionManager.startSession(session)
        
        // 协调各个管理器
        focusManager.requestFocus(for: fieldId, priority: priority)
        keyboardManager.beginInputSession(for: fieldId)
        
        // 预防性约束调整
        if let currentView = getCurrentInputView() {
            conflictResolver.preventiveAdjustment(for: currentView)
        }
        
        // 更新系统状态
        currentInputMode = .active
    }
    
    /// 结束输入会话
    func endInputSession(fieldId: String) {
        print("[UnifiedInputManager] 结束输入会话: \(fieldId)")
        
        // 结束会话
        sessionManager.endSession(fieldId: fieldId)
        
        // 协调各个管理器
        focusManager.releaseFocus(for: fieldId)
        
        // 如果没有其他活跃会话，结束键盘会话
        if !sessionManager.hasActiveSessions {
            keyboardManager.endInputSession()
            currentInputMode = .ready
        }
    }
    
    /// 结束当前输入会话（不需要fieldId参数）
    func endInputSession() {
        print("[UnifiedInputManager] 结束当前输入会话")
        
        // 获取当前焦点字段
        if let currentField = focusManager.currentFocusedField {
            endInputSession(fieldId: currentField)
        } else {
            // 如果没有当前焦点字段，直接结束键盘会话
            keyboardManager.endInputSession()
            currentInputMode = .ready
        }
    }
    
    /// 处理输入错误
    func handleInputError(_ error: InputError) {
        print("[UnifiedInputManager] 处理输入错误: \(error.type)")
        
        errorCount += 1
        lastErrorTime = Date()
        
        // 根据错误类型执行相应处理
        switch error.type {
        case .keyboardSessionError:
            handleKeyboardSessionError(error)
        case .constraintConflict:
            handleConstraintConflictError(error)
        case .focusManagementError:
            handleFocusManagementError(error)
        case .systemInputAssistantError:
            handleSystemInputAssistantError(error)
        }
        
        // 更新系统健康状态
        updateSystemHealth()
        
        // 启动错误恢复
        scheduleErrorRecovery()
    }
    
    /// 强制重置输入系统
    func forceResetInputSystem() {
        print("[UnifiedInputManager] 强制重置输入系统")
        
        // 停止所有活动
        shutdownInputSystem()
        
        // 清理错误状态
        errorCount = 0
        lastErrorTime = nil
        
        // 延迟重新初始化
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            self.initializeInputSystem()
        }
    }
    
    /// 获取系统状态报告
    func getSystemStatusReport() -> SystemStatusReport {
        let keyboardStatus = KeyboardStatus(
            isVisible: keyboardManager.isKeyboardVisible,
            height: keyboardManager.keyboardHeight,
            hasActiveSession: keyboardManager.inputSessionActive
        )
        
        let focusStatus = FocusStatus(
            currentField: focusManager.currentFocusedField,
            pendingRequests: focusManager.pendingFocusCount,
            isTransitioning: focusManager.isFocusTransitioning
        )
        
        let conflictStatus = ConflictStatus(
            hasActiveConflicts: conflictResolver.hasActiveConflicts,
            conflictCount: conflictResolver.conflictCount,
            statistics: conflictResolver.getConflictStatistics()
        )
        
        return SystemStatusReport(
            isActive: isInputSystemActive,
            inputMode: currentInputMode,
            systemHealth: systemHealth,
            errorCount: errorCount,
            lastErrorTime: lastErrorTime,
            keyboardStatus: keyboardStatus,
            focusStatus: focusStatus,
            conflictStatus: conflictStatus,
            activeSessions: sessionManager.getActiveSessionCount()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupInputSystemIntegration() {
        print("[UnifiedInputManager] 设置输入系统集成")
        
        // 监听键盘管理器状态变化
        keyboardManager.$isKeyboardVisible
            .sink { [weak self] isVisible in
                self?.handleKeyboardVisibilityChange(isVisible)
            }
            .store(in: &cancellables)
        
        // 监听焦点管理器状态变化
        focusManager.$currentFocusedField
            .sink { [weak self] fieldId in
                self?.handleFocusChange(fieldId)
            }
            .store(in: &cancellables)
        
        // 监听约束冲突解决器状态变化
        conflictResolver.$hasActiveConflicts
            .sink { [weak self] hasConflicts in
                self?.handleConflictStatusChange(hasConflicts)
            }
            .store(in: &cancellables)
    }
    
    private func startSystemHealthMonitoring() {
        print("[UnifiedInputManager] 启动系统健康监控")
        
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performHealthCheck()
            }
        }
    }
    
    private func stopSystemHealthMonitoring() {
        print("[UnifiedInputManager] 停止系统健康监控")
        
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    private func performHealthCheck() {
        // 检查各个组件的健康状态
        let keyboardHealthy = checkKeyboardManagerHealth()
        let focusHealthy = checkFocusManagerHealth()
        let conflictHealthy = checkConflictResolverHealth()
        
        // 计算整体健康状态
        let overallHealthy = keyboardHealthy && focusHealthy && conflictHealthy
        
        // 更新系统健康状态
        if !overallHealthy {
            if errorCount > maxErrorCount {
                systemHealth = .critical
            } else {
                systemHealth = .degraded
            }
        } else if errorCount == 0 {
            systemHealth = .healthy
        } else {
            systemHealth = .recovering
        }
    }
    
    private func checkKeyboardManagerHealth() -> Bool {
        // 检查键盘管理器健康状态
        return keyboardManager.inputSessionActive == keyboardManager.isKeyboardVisible
    }
    
    private func checkFocusManagerHealth() -> Bool {
        // 检查焦点管理器健康状态
        return !focusManager.isFocusTransitioning || focusManager.pendingFocusCount < 5
    }
    
    private func checkConflictResolverHealth() -> Bool {
        // 检查约束冲突解决器健康状态
        return !conflictResolver.hasActiveConflicts
    }
    
    private func handleKeyboardVisibilityChange(_ isVisible: Bool) {
        print("[UnifiedInputManager] 键盘可见性变化: \(isVisible)")
        
        // 使用异步状态更新避免视图更新冲突
        Task { @MainActor in
            if isVisible {
                currentInputMode = .active
            } else if !sessionManager.hasActiveSessions {
                currentInputMode = .ready
            }
        }
    }
    
    private func handleFocusChange(_ fieldId: String?) {
        print("[UnifiedInputManager] 焦点变化: \(fieldId ?? "nil")")
        
        // 使用异步状态更新避免视图更新冲突
        Task { @MainActor in
            if let fieldId = fieldId {
                sessionManager.updateActiveSession(fieldId: fieldId)
            }
        }
    }
    
    private func handleConflictStatusChange(_ hasConflicts: Bool) {
        print("[UnifiedInputManager] 约束冲突状态变化: \(hasConflicts)")
        
        // 使用异步状态更新避免视图更新冲突
        Task { @MainActor in
            if hasConflicts {
                // 记录约束冲突错误
                let error = InputError(
                    type: .constraintConflict,
                    description: "Constraint conflict detected",
                    context: [:]
                )
                handleInputError(error)
            }
        }
    }
    
    private func handleKeyboardSessionError(_ error: InputError) {
        print("[UnifiedInputManager] 处理键盘会话错误")
        
        // 重置键盘会话
        keyboardManager.endInputSession()
        
        // 延迟重新开始会话
        if let currentField = focusManager.currentFocusedField {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.keyboardManager.beginInputSession(for: currentField)
            }
        }
    }
    
    private func handleConstraintConflictError(_ error: InputError) {
        print("[UnifiedInputManager] 处理约束冲突错误")
        
        // 触发约束冲突解决
        conflictResolver.resolveConflict(
            type: .general,
            context: ConflictContext(
                viewDescription: error.description,
                constraintDescription: "Input system constraint conflict",
                additionalInfo: error.context
            )
        )
    }
    
    private func handleFocusManagementError(_ error: InputError) {
        print("[UnifiedInputManager] 处理焦点管理错误")
        
        // 清理焦点状态
        focusManager.clearAllFocus()
    }
    
    private func handleSystemInputAssistantError(_ error: InputError) {
        print("[UnifiedInputManager] 处理SystemInputAssistant错误")
        
        // 触发SystemInputAssistant特定的修复
        conflictResolver.resolveConflict(
            type: .systemInputAssistant,
            context: ConflictContext(
                viewDescription: "SystemInputAssistantView",
                constraintDescription: error.description,
                additionalInfo: error.context
            )
        )
    }
    
    private func updateSystemHealth() {
        if errorCount > maxErrorCount {
            systemHealth = .critical
        } else if errorCount > maxErrorCount / 2 {
            systemHealth = .degraded
        } else {
            systemHealth = .recovering
        }
    }
    
    private func scheduleErrorRecovery() {
        errorRecoveryTimer?.invalidate()
        errorRecoveryTimer = Timer.scheduledTimer(withTimeInterval: errorRecoveryDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performErrorRecovery()
            }
        }
    }
    
    private func performErrorRecovery() {
        print("[UnifiedInputManager] 执行错误恢复")
        
        // 减少错误计数
        if errorCount > 0 {
            errorCount = max(0, errorCount - 1)
        }
        
        // 如果错误计数为0，恢复健康状态
        if errorCount == 0 {
            systemHealth = .healthy
        }
    }
    
    private func getCurrentInputView() -> UIView? {
        // 获取当前输入视图 - 使用现代API支持多窗口
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return nil }
        
        return windowScene.windows.first?.firstResponder as? UIView
    }
    
    nonisolated private func cleanup() {
        print("[UnifiedInputManager] 清理资源")
        
        Task { @MainActor in
            shutdownInputSystem()
            cancellables.removeAll()
            errorRecoveryTimer?.invalidate()
        }
    }
}

// MARK: - Data Models

struct InputSession {
    let id = UUID()
    let fieldId: String
    let priority: Int
    let inputType: InputType
    let startTime: Date
    var endTime: Date?
    var isActive: Bool = true
}

struct InputError {
    let type: InputErrorType
    let description: String
    let context: [String: Any]
    let timestamp: Date = Date()
}

struct SystemStatusReport {
    let isActive: Bool
    let inputMode: InputMode
    let systemHealth: SystemHealth
    let errorCount: Int
    let lastErrorTime: Date?
    let keyboardStatus: KeyboardStatus
    let focusStatus: FocusStatus
    let conflictStatus: ConflictStatus
    let activeSessions: Int
}

struct KeyboardStatus {
    let isVisible: Bool
    let height: CGFloat
    let hasActiveSession: Bool
}

struct FocusStatus {
    let currentField: String?
    let pendingRequests: Int
    let isTransitioning: Bool
}

struct ConflictStatus {
    let hasActiveConflicts: Bool
    let conflictCount: Int
    let statistics: ConflictStatistics
}

enum InputMode {
    case none
    case ready
    case active
    case transitioning
    case search
    case text
    case form
}

enum SystemHealth {
    case healthy
    case recovering
    case degraded
    case critical
    case shutdown
    case warning
}

enum InputType {
    case text
    case search
    case numeric
    case email
    case password
    case form
}

enum InputErrorType {
    case keyboardSessionError
    case constraintConflict
    case focusManagementError
    case systemInputAssistantError
}

// MARK: - Input Session Manager

class InputSessionManager {
    private var activeSessions: [String: InputSession] = [:]
    private var sessionHistory: [InputSession] = []
    
    func startSession(_ session: InputSession) {
        activeSessions[session.fieldId] = session
        print("[InputSessionManager] 开始会话: \(session.fieldId)")
    }
    
    func endSession(fieldId: String) {
        if var session = activeSessions[fieldId] {
            session.endTime = Date()
            session.isActive = false
            sessionHistory.append(session)
            activeSessions.removeValue(forKey: fieldId)
            print("[InputSessionManager] 结束会话: \(fieldId)")
        }
    }
    
    func updateActiveSession(fieldId: String) {
        // 更新活跃会话状态
        if activeSessions[fieldId] != nil {
            print("[InputSessionManager] 更新会话: \(fieldId)")
        }
    }
    
    var hasActiveSessions: Bool {
        return !activeSessions.isEmpty
    }
    
    func getActiveSessionCount() -> Int {
        return activeSessions.count
    }
}

// MARK: - UIResponder Extension

extension UIResponder {
    var firstResponder: UIResponder? {
        guard !isFirstResponder else { return self }
        
        for subview in (self as? UIView)?.subviews ?? [] {
            if let firstResponder = subview.firstResponder {
                return firstResponder
            }
        }
        
        return nil
    }
}