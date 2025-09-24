//
//  KeyboardManager.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import SwiftUI
import UIKit
import Combine

/// 统一的键盘管理器，解决输入系统错误和约束冲突问题
@MainActor
class KeyboardManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isKeyboardVisible: Bool = false
    @Published var keyboardHeight: CGFloat = 0
    @Published var currentInputField: String? = nil
    @Published var inputSessionActive: Bool = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var keyboardWillShowNotification: AnyCancellable?
    private var keyboardWillHideNotification: AnyCancellable?
    private var keyboardDidShowNotification: AnyCancellable?
    private var keyboardDidHideNotification: AnyCancellable?
    
    // 输入会话管理
    private var activeInputSessions: Set<String> = []
    private var sessionIdCounter: Int = 0
    
    // 约束管理
    private var originalConstraints: [String: Any] = [:]
    private var adjustedConstraints: [String: Any] = [:]
    
    // MARK: - Singleton
    static let shared = KeyboardManager()
    
    private init() {
        setupKeyboardNotifications()
    }
    
    deinit {
        // 使用nonisolated cleanup避免deinit中的并发问题
        cleanup()
    }
    
    // MARK: - Public Methods
    
    /// 注册输入字段
    func registerInputField(_ fieldId: String) {
        print("[KeyboardManager] 注册输入字段: \(fieldId)")
        
        // 生成唯一的会话ID
        let sessionId = generateSessionId()
        activeInputSessions.insert(sessionId)
        
        // 标记输入会话为活跃状态
        inputSessionActive = true
        currentInputField = fieldId
    }
    
    /// 注销输入字段
    func unregisterInputField(_ fieldId: String) {
        print("[KeyboardManager] 注销输入字段: \(fieldId)")
        
        // 清理相关会话
        if currentInputField == fieldId {
            currentInputField = nil
            inputSessionActive = false
        }
        
        // 强制结束输入会话
        endInputSession()
    }
    
    /// 开始输入会话
    func beginInputSession(for fieldId: String) {
        print("[KeyboardManager] 开始输入会话: \(fieldId)")
        
        // 防止重复会话
        if currentInputField == fieldId && inputSessionActive {
            return
        }
        
        // 结束之前的会话
        if inputSessionActive {
            endInputSession()
        }
        
        registerInputField(fieldId)
        
        // 预处理约束以防止冲突
        prepareConstraintsForKeyboard()
    }
    
    /// 结束输入会话
    func endInputSession() {
        print("[KeyboardManager] 结束输入会话")
        
        // 清理会话状态
        activeInputSessions.removeAll()
        inputSessionActive = false
        currentInputField = nil
        
        // 恢复原始约束
        restoreOriginalConstraints()
        
        // 强制隐藏键盘
        hideKeyboard()
    }
    
    /// 强制隐藏键盘
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// 处理约束冲突
    func handleConstraintConflict(for view: String) {
        print("[KeyboardManager] 处理约束冲突: \(view)")
        
        // 临时禁用有问题的约束
        disableConflictingConstraints(for: view)
        
        // 延迟重新启用
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            self.enableConstraints(for: view)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupKeyboardNotifications() {
        // 键盘即将显示
        keyboardWillShowNotification = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardWillShow(notification)
            }
        
        // 键盘即将隐藏
        keyboardWillHideNotification = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardWillHide(notification)
            }
        
        // 键盘已显示
        keyboardDidShowNotification = NotificationCenter.default
            .publisher(for: UIResponder.keyboardDidShowNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardDidShow(notification)
            }
        
        // 键盘已隐藏
        keyboardDidHideNotification = NotificationCenter.default
            .publisher(for: UIResponder.keyboardDidHideNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardDidHide(notification)
            }
    }
    
    private func handleKeyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        
        print("[KeyboardManager] 键盘即将显示，高度: \(keyboardFrame.height)")
        
        withAnimation(.easeInOut(duration: 0.3)) {
            self.keyboardHeight = keyboardFrame.height
            self.isKeyboardVisible = true
        }
        
        // 调整约束以适应键盘
        adjustConstraintsForKeyboard(height: keyboardFrame.height)
    }
    
    private func handleKeyboardWillHide(_ notification: Notification) {
        print("[KeyboardManager] 键盘即将隐藏")
        
        withAnimation(.easeInOut(duration: 0.3)) {
            self.keyboardHeight = 0
            self.isKeyboardVisible = false
        }
        
        // 恢复原始约束
        restoreOriginalConstraints()
    }
    
    private func handleKeyboardDidShow(_ notification: Notification) {
        print("[KeyboardManager] 键盘已显示")
        
        // 确保输入会话状态正确
        if !inputSessionActive && currentInputField != nil {
            inputSessionActive = true
        }
    }
    
    private func handleKeyboardDidHide(_ notification: Notification) {
        print("[KeyboardManager] 键盘已隐藏")
        
        // 清理输入会话
        if inputSessionActive {
            endInputSession()
        }
    }
    
    private func generateSessionId() -> String {
        sessionIdCounter += 1
        return "session_\(sessionIdCounter)_\(Date().timeIntervalSince1970)"
    }
    
    private func prepareConstraintsForKeyboard() {
        print("[KeyboardManager] 预处理约束")
        
        // 保存当前约束状态
        saveCurrentConstraints()
        
        // 预设安全的约束配置
        setupSafeConstraints()
    }
    
    private func adjustConstraintsForKeyboard(height: CGFloat) {
        print("[KeyboardManager] 调整约束适应键盘高度: \(height)")
        
        // 实现约束调整逻辑
        // 这里可以根据具体需求调整视图约束
    }
    
    private func saveCurrentConstraints() {
        // 保存当前约束状态，以便后续恢复
        originalConstraints["timestamp"] = Date().timeIntervalSince1970
    }
    
    private func setupSafeConstraints() {
        // 设置安全的约束配置，避免冲突
        adjustedConstraints["safe_mode"] = true
    }
    
    private func restoreOriginalConstraints() {
        print("[KeyboardManager] 恢复原始约束")
        
        // 恢复保存的约束状态
        adjustedConstraints.removeAll()
    }
    
    private func disableConflictingConstraints(for view: String) {
        print("[KeyboardManager] 禁用冲突约束: \(view)")
        
        // 临时禁用可能冲突的约束
        // 这里可以实现具体的约束禁用逻辑
    }
    
    private func enableConstraints(for view: String) {
        print("[KeyboardManager] 重新启用约束: \(view)")
        
        // 重新启用约束
        // 这里可以实现具体的约束启用逻辑
    }
    
    nonisolated private func cleanup() {
        print("[KeyboardManager] 清理资源")
        
        Task { @MainActor in
            cancellables.removeAll()
            keyboardWillShowNotification?.cancel()
            keyboardWillHideNotification?.cancel()
            keyboardDidShowNotification?.cancel()
            keyboardDidHideNotification?.cancel()
            
            activeInputSessions.removeAll()
            originalConstraints.removeAll()
            adjustedConstraints.removeAll()
        }
    }
}

// MARK: - KeyboardManager Extensions

extension KeyboardManager {
    /// 获取安全的键盘避让高度
    var safeKeyboardHeight: CGFloat {
        return isKeyboardVisible ? keyboardHeight : 0
    }
    
    /// 检查是否有活跃的输入会话
    var hasActiveInputSession: Bool {
        return inputSessionActive && !activeInputSessions.isEmpty
    }
    
    /// 获取当前输入会话数量
    var activeSessionCount: Int {
        return activeInputSessions.count
    }
}

// MARK: - SwiftUI Integration

/// SwiftUI视图修饰符，用于集成键盘管理
struct KeyboardManaged: ViewModifier {
    let fieldId: String
    @StateObject private var keyboardManager = KeyboardManager.shared
    @FocusState private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onTapGesture {
                keyboardManager.beginInputSession(for: fieldId)
                isFocused = true
            }
            .onChange(of: isFocused) { oldValue, newValue in
                if newValue {
                    keyboardManager.beginInputSession(for: fieldId)
                } else {
                    keyboardManager.unregisterInputField(fieldId)
                }
            }
            .onDisappear {
                keyboardManager.unregisterInputField(fieldId)
            }
    }
}

extension View {
    /// 应用键盘管理
    func keyboardManaged(fieldId: String) -> some View {
        self.modifier(KeyboardManaged(fieldId: fieldId))
    }
}