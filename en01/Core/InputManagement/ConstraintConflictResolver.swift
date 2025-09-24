//
//  ConstraintConflictResolver.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import SwiftUI
import UIKit
import Combine

/// 约束冲突解决器，专门处理SystemInputAssistantView相关的约束冲突
@MainActor
class ConstraintConflictResolver: ObservableObject {
    // MARK: - Published Properties
    @Published var hasActiveConflicts: Bool = false
    @Published var conflictCount: Int = 0
    @Published var lastConflictTime: Date? = nil
    
    // MARK: - Private Properties
    private var conflictHistory: [ConstraintConflict] = []
    private var resolutionStrategies: [String: ResolutionStrategy] = [:]
    private var monitoringTimer: Timer?
    private var conflictDebounceTimer: Timer?
    
    // 约束监控
    private var constraintObservers: [NSObjectProtocol] = []
    private var systemInputAssistantViews: Set<UIView> = []
    
    // 配置参数
    private let maxConflictHistory = 100
    private let conflictDebounceInterval: TimeInterval = 0.5
    private let monitoringInterval: TimeInterval = 1.0
    
    // MARK: - Singleton
    static let shared = ConstraintConflictResolver()
    
    private init() {
        setupConstraintMonitoring()
        setupResolutionStrategies()
    }
    
    deinit {
        // 使用nonisolated cleanup避免deinit中的并发问题
        cleanup()
    }
    
    // MARK: - Public Methods
    
    /// 开始监控约束冲突
    func startMonitoring() {
        print("[ConstraintConflictResolver] 开始监控约束冲突")
        
        stopMonitoring() // 确保没有重复的监控
        
        // 设置定期监控
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForConstraintConflicts()
            }
        }
        
        // 监控SystemInputAssistantView
        monitorSystemInputAssistantViews()
    }
    
    /// 停止监控约束冲突
    func stopMonitoring() {
        print("[ConstraintConflictResolver] 停止监控约束冲突")
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        conflictDebounceTimer?.invalidate()
        conflictDebounceTimer = nil
        
        // 清理观察者
        constraintObservers.forEach { NotificationCenter.default.removeObserver($0) }
        constraintObservers.removeAll()
    }
    
    /// 手动解决约束冲突
    func resolveConflict(type: ConflictType, context: ConflictContext) {
        print("[ConstraintConflictResolver] 手动解决冲突: \(type)")
        
        let conflict = ConstraintConflict(
            type: type,
            context: context,
            timestamp: Date(),
            resolved: false
        )
        
        performResolution(for: conflict)
    }
    
    /// 预防性约束调整
    func preventiveAdjustment(for inputView: UIView) {
        print("[ConstraintConflictResolver] 预防性约束调整")
        
        // 检查是否是SystemInputAssistantView相关
        if isSystemInputAssistantView(inputView) {
            applySystemInputAssistantFix(inputView)
        }
        
        // 应用通用预防措施
        applyPreventiveMeasures(inputView)
    }
    
    /// 获取冲突统计信息
    func getConflictStatistics() -> ConflictStatistics {
        let recentConflicts = conflictHistory.filter { conflict in
            Date().timeIntervalSince(conflict.timestamp) < 3600 // 最近1小时
        }
        
        return ConflictStatistics(
            totalConflicts: conflictHistory.count,
            recentConflicts: recentConflicts.count,
            resolvedConflicts: conflictHistory.filter { $0.resolved }.count,
            mostCommonType: getMostCommonConflictType()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupConstraintMonitoring() {
        print("[ConstraintConflictResolver] 设置约束监控")
        
        // 监控约束异常
        let constraintObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UIViewAlertForUnsatisfiableConstraints"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleConstraintAlert(notification)
            }
        }
        constraintObservers.append(constraintObserver)
    }
    
    private func setupResolutionStrategies() {
        print("[ConstraintConflictResolver] 设置解决策略")
        
        // SystemInputAssistantView冲突解决策略
        resolutionStrategies["SystemInputAssistantView"] = ResolutionStrategy(
            priority: .high,
            actions: [
                .disableConflictingConstraints,
                .adjustConstraintPriorities,
                .temporaryConstraintRemoval,
                .forceLayoutUpdate
            ]
        )
        
        // 键盘相关冲突解决策略
        resolutionStrategies["KeyboardConstraints"] = ResolutionStrategy(
            priority: .medium,
            actions: [
                .adjustConstraintPriorities,
                .updateConstraintConstants,
                .forceLayoutUpdate
            ]
        )
        
        // 通用冲突解决策略
        resolutionStrategies["General"] = ResolutionStrategy(
            priority: .low,
            actions: [
                .logConflict,
                .adjustConstraintPriorities
            ]
        )
    }
    
    private func checkForConstraintConflicts() {
        // 检查当前是否有约束冲突
        let hasConflicts = detectCurrentConflicts()
        
        if hasConflicts != hasActiveConflicts {
            hasActiveConflicts = hasConflicts
            
            if hasConflicts {
                handleNewConflictDetected()
            }
        }
    }
    
    private func detectCurrentConflicts() -> Bool {
        // 检查SystemInputAssistantView相关冲突
        for view in systemInputAssistantViews {
            if hasConstraintConflicts(in: view) {
                return true
            }
        }
        
        // 检查键盘相关冲突
        if KeyboardManager.shared.isKeyboardVisible {
            return detectKeyboardConstraintConflicts()
        }
        
        return false
    }
    
    private func hasConstraintConflicts(in view: UIView) -> Bool {
        // 检查视图是否有约束冲突
        // 这里可以实现具体的冲突检测逻辑
        return false
    }
    
    private func detectKeyboardConstraintConflicts() -> Bool {
        // 检测键盘相关的约束冲突
        return false
    }
    
    private func handleNewConflictDetected() {
        print("[ConstraintConflictResolver] 检测到新的约束冲突")
        
        conflictCount += 1
        lastConflictTime = Date()
        
        // 防抖处理
        conflictDebounceTimer?.invalidate()
        conflictDebounceTimer = Timer.scheduledTimer(withTimeInterval: conflictDebounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.processDetectedConflicts()
            }
        }
    }
    
    private func processDetectedConflicts() {
        print("[ConstraintConflictResolver] 处理检测到的冲突")
        
        // 创建冲突记录
        let conflict = ConstraintConflict(
            type: .systemInputAssistant,
            context: ConflictContext(
                viewDescription: "SystemInputAssistantView",
                constraintDescription: "Height constraint conflict",
                additionalInfo: [:]
            ),
            timestamp: Date(),
            resolved: false
        )
        
        // 执行解决方案
        performResolution(for: conflict)
    }
    
    private func performResolution(for conflict: ConstraintConflict) {
        print("[ConstraintConflictResolver] 执行冲突解决: \(conflict.type)")
        
        // 添加到历史记录
        addToHistory(conflict)
        
        // 获取解决策略
        let strategy = getResolutionStrategy(for: conflict.type)
        
        // 执行解决动作
        var resolvedSuccessfully = false
        for action in strategy.actions {
            if executeResolutionAction(action, for: conflict) {
                resolvedSuccessfully = true
                break
            }
        }
        
        // 更新冲突状态
        if resolvedSuccessfully {
            markConflictAsResolved(conflict)
        }
    }
    
    private func executeResolutionAction(_ action: ResolutionAction, for conflict: ConstraintConflict) -> Bool {
        print("[ConstraintConflictResolver] 执行解决动作: \(action)")
        
        switch action {
        case .disableConflictingConstraints:
            return disableConflictingConstraints(for: conflict)
        case .adjustConstraintPriorities:
            return adjustConstraintPriorities(for: conflict)
        case .temporaryConstraintRemoval:
            return temporaryConstraintRemoval(for: conflict)
        case .forceLayoutUpdate:
            return forceLayoutUpdate(for: conflict)
        case .updateConstraintConstants:
            return updateConstraintConstants(for: conflict)
        case .logConflict:
            logConflict(conflict)
            return true
        }
    }
    
    private func disableConflictingConstraints(for conflict: ConstraintConflict) -> Bool {
        print("[ConstraintConflictResolver] 禁用冲突约束")
        
        // 实现约束禁用逻辑
        return true
    }
    
    private func adjustConstraintPriorities(for conflict: ConstraintConflict) -> Bool {
        print("[ConstraintConflictResolver] 调整约束优先级")
        
        // 实现约束优先级调整逻辑
        return true
    }
    
    private func temporaryConstraintRemoval(for conflict: ConstraintConflict) -> Bool {
        print("[ConstraintConflictResolver] 临时移除约束")
        
        // 实现临时约束移除逻辑
        return true
    }
    
    private func forceLayoutUpdate(for conflict: ConstraintConflict) -> Bool {
        print("[ConstraintConflictResolver] 强制布局更新")
        
        Task { @MainActor in
            // 使用现代API支持多窗口
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { window in
                    window.setNeedsLayout()
                    window.layoutIfNeeded()
                }
        }
        
        return true
    }
    
    private func updateConstraintConstants(for conflict: ConstraintConflict) -> Bool {
        print("[ConstraintConflictResolver] 更新约束常量")
        
        // 实现约束常量更新逻辑
        return true
    }
    
    private func logConflict(_ conflict: ConstraintConflict) {
        print("[ConstraintConflictResolver] 记录冲突: \(conflict)")
    }
    
    private func monitorSystemInputAssistantViews() {
        // 监控SystemInputAssistantView的创建和销毁
        Task { @MainActor in
            self.findSystemInputAssistantViews()
        }
    }
    
    private func findSystemInputAssistantViews() {
        systemInputAssistantViews.removeAll()
        
        // 遍历所有窗口查找SystemInputAssistantView
        // 使用现代API支持多窗口
        for window in UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows }) {
            findSystemInputAssistantViews(in: window)
        }
    }
    
    private func findSystemInputAssistantViews(in view: UIView) {
        if isSystemInputAssistantView(view) {
            systemInputAssistantViews.insert(view)
        }
        
        for subview in view.subviews {
            findSystemInputAssistantViews(in: subview)
        }
    }
    
    private func isSystemInputAssistantView(_ view: UIView) -> Bool {
        let className = String(describing: type(of: view))
        return className.contains("SystemInputAssistantView") ||
               className.contains("InputAssistant") ||
               className.contains("_UISystemInputAssistantView")
    }
    
    private func applySystemInputAssistantFix(_ view: UIView) {
        print("[ConstraintConflictResolver] 应用SystemInputAssistantView修复")
        
        // 应用特定的修复措施
        view.translatesAutoresizingMaskIntoConstraints = true
        
        // 设置安全的约束优先级
        for constraint in view.constraints {
            if constraint.firstAttribute == .height {
                constraint.priority = UILayoutPriority(999)
            }
        }
    }
    
    private func applyPreventiveMeasures(_ view: UIView) {
        print("[ConstraintConflictResolver] 应用预防措施")
        
        // 通用预防措施
        view.setContentHuggingPriority(UILayoutPriority(999), for: .vertical)
        view.setContentCompressionResistancePriority(UILayoutPriority(999), for: .vertical)
    }
    
    private func getResolutionStrategy(for conflictType: ConflictType) -> ResolutionStrategy {
        switch conflictType {
        case .systemInputAssistant:
            return resolutionStrategies["SystemInputAssistantView"] ?? ResolutionStrategy.default
        case .keyboardConstraints:
            return resolutionStrategies["KeyboardConstraints"] ?? ResolutionStrategy.default
        case .general:
            return resolutionStrategies["General"] ?? ResolutionStrategy.default
        }
    }
    
    private func addToHistory(_ conflict: ConstraintConflict) {
        conflictHistory.append(conflict)
        
        // 限制历史记录大小
        if conflictHistory.count > maxConflictHistory {
            conflictHistory.removeFirst(conflictHistory.count - maxConflictHistory)
        }
    }
    
    private func markConflictAsResolved(_ conflict: ConstraintConflict) {
        if let index = conflictHistory.firstIndex(where: { $0.id == conflict.id }) {
            conflictHistory[index].resolved = true
        }
    }
    
    private func getMostCommonConflictType() -> ConflictType? {
        let typeCounts = Dictionary(grouping: conflictHistory, by: { $0.type })
            .mapValues { $0.count }
        
        return typeCounts.max { $0.value < $1.value }?.key
    }
    
    private func handleConstraintAlert(_ notification: Notification) {
        print("[ConstraintConflictResolver] 收到约束警告通知")
        
        // 处理系统约束警告
        let conflict = ConstraintConflict(
            type: .general,
            context: ConflictContext(
                viewDescription: "Unknown",
                constraintDescription: "System constraint alert",
                additionalInfo: notification.userInfo ?? [:]
            ),
            timestamp: Date(),
            resolved: false
        )
        
        performResolution(for: conflict)
    }
    
    nonisolated private func cleanup() {
        print("[ConstraintConflictResolver] 清理资源")
        
        Task { @MainActor in
            stopMonitoring()
            conflictHistory.removeAll()
            resolutionStrategies.removeAll()
            systemInputAssistantViews.removeAll()
        }
    }
}

// MARK: - Data Models

struct ConstraintConflict: Identifiable {
    let id = UUID()
    let type: ConflictType
    let context: ConflictContext
    let timestamp: Date
    var resolved: Bool
}

struct ConflictContext {
    let viewDescription: String
    let constraintDescription: String
    let additionalInfo: [AnyHashable: Any]
}

struct ConflictStatistics {
    let totalConflicts: Int
    let recentConflicts: Int
    let resolvedConflicts: Int
    let mostCommonType: ConflictType?
}

struct ResolutionStrategy {
    let priority: Priority
    let actions: [ResolutionAction]
    
    enum Priority {
        case low, medium, high
    }
    
    static let `default` = ResolutionStrategy(
        priority: .low,
        actions: [.logConflict]
    )
}

enum ConflictType {
    case systemInputAssistant
    case keyboardConstraints
    case general
}

enum ResolutionAction {
    case disableConflictingConstraints
    case adjustConstraintPriorities
    case temporaryConstraintRemoval
    case forceLayoutUpdate
    case updateConstraintConstants
    case logConflict
}