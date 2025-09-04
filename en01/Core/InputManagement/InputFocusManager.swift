//
//  InputFocusManager.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import SwiftUI
import UIKit
import Combine

/// 输入焦点管理器，处理多个输入字段的焦点协调
@MainActor
class InputFocusManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentFocusedField: String? = nil
    @Published var focusHistory: [String] = []
    @Published var isFocusTransitioning: Bool = false
    
    // MARK: - Private Properties
    private var focusStates: [String: Bool] = [:]
    private var fieldPriorities: [String: Int] = [:]
    private var focusQueue: [String] = []
    private var transitionTimer: Timer?
    
    // 防抖机制
    private var focusDebounceTimer: Timer?
    private let focusDebounceInterval: TimeInterval = 0.1
    
    // MARK: - Singleton
    static let shared = InputFocusManager()
    
    private init() {
        setupFocusManagement()
    }
    
    // MARK: - Public Methods
    
    /// 请求焦点
    func requestFocus(for fieldId: String, priority: Int = 0) {
        print("[InputFocusManager] 请求焦点: \(fieldId), 优先级: \(priority)")
        
        // 取消之前的防抖计时器
        focusDebounceTimer?.invalidate()
        
        // 设置防抖计时器
        focusDebounceTimer = Timer.scheduledTimer(withTimeInterval: focusDebounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.processFocusRequest(fieldId: fieldId, priority: priority)
            }
        }
    }
    
    /// 释放焦点
    func releaseFocus(for fieldId: String) {
        print("[InputFocusManager] 释放焦点: \(fieldId)")
        
        focusStates[fieldId] = false
        fieldPriorities.removeValue(forKey: fieldId)
        
        if currentFocusedField == fieldId {
            currentFocusedField = nil
            processNextFocusRequest()
        }
        
        // 从队列中移除
        focusQueue.removeAll { $0 == fieldId }
    }
    
    /// 强制清除所有焦点
    func clearAllFocus() {
        print("[InputFocusManager] 清除所有焦点")
        
        focusStates.removeAll()
        fieldPriorities.removeAll()
        focusQueue.removeAll()
        currentFocusedField = nil
        isFocusTransitioning = false
        
        // 取消所有计时器
        focusDebounceTimer?.invalidate()
        transitionTimer?.invalidate()
        
        // 强制隐藏键盘
        KeyboardManager.shared.hideKeyboard()
    }
    
    /// 检查字段是否有焦点
    func hasFocus(_ fieldId: String) -> Bool {
        return currentFocusedField == fieldId
    }
    
    /// 获取焦点状态绑定
    func focusBinding(for fieldId: String) -> Binding<Bool> {
        return Binding(
            get: { [weak self] in
                self?.hasFocus(fieldId) ?? false
            },
            set: { [weak self] focused in
                if focused {
                    self?.requestFocus(for: fieldId)
                } else {
                    self?.releaseFocus(for: fieldId)
                }
            }
        )
    }
    
    /// 设置字段优先级
    func setPriority(_ priority: Int, for fieldId: String) {
        fieldPriorities[fieldId] = priority
    }
    
    /// 获取下一个应该获得焦点的字段
    func getNextFocusField() -> String? {
        // 按优先级排序
        let sortedFields = focusQueue.sorted { fieldId1, fieldId2 in
            let priority1 = fieldPriorities[fieldId1] ?? 0
            let priority2 = fieldPriorities[fieldId2] ?? 0
            return priority1 > priority2
        }
        
        return sortedFields.first
    }
    
    // MARK: - Private Methods
    
    private func setupFocusManagement() {
        print("[InputFocusManager] 初始化焦点管理")
    }
    
    private func processFocusRequest(fieldId: String, priority: Int) {
        print("[InputFocusManager] 处理焦点请求: \(fieldId)")
        
        // 设置优先级
        fieldPriorities[fieldId] = priority
        
        // 检查是否已经有焦点
        if currentFocusedField == fieldId {
            print("[InputFocusManager] 字段已有焦点: \(fieldId)")
            return
        }
        
        // 检查是否需要抢占当前焦点
        if let currentField = currentFocusedField {
            let currentPriority = fieldPriorities[currentField] ?? 0
            if priority <= currentPriority {
                // 优先级不够，加入队列
                if !focusQueue.contains(fieldId) {
                    focusQueue.append(fieldId)
                }
                print("[InputFocusManager] 优先级不够，加入队列: \(fieldId)")
                return
            }
        }
        
        // 执行焦点切换
        performFocusTransition(to: fieldId)
    }
    
    private func performFocusTransition(to fieldId: String) {
        print("[InputFocusManager] 执行焦点切换到: \(fieldId)")
        
        // 标记正在转换
        isFocusTransitioning = true
        
        // 释放当前焦点
        if let currentField = currentFocusedField {
            focusStates[currentField] = false
            
            // 添加到历史记录
            if !focusHistory.contains(currentField) {
                focusHistory.append(currentField)
                
                // 限制历史记录长度
                if focusHistory.count > 10 {
                    focusHistory.removeFirst()
                }
            }
        }
        
        // 设置新焦点
        currentFocusedField = fieldId
        focusStates[fieldId] = true
        
        // 从队列中移除
        focusQueue.removeAll { $0 == fieldId }
        
        // 通知键盘管理器
        KeyboardManager.shared.beginInputSession(for: fieldId)
        
        // 延迟结束转换状态
        transitionTimer?.invalidate()
        transitionTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isFocusTransitioning = false
            }
        }
    }
    
    private func processNextFocusRequest() {
        guard let nextField = getNextFocusField() else {
            print("[InputFocusManager] 没有待处理的焦点请求")
            return
        }
        
        print("[InputFocusManager] 处理下一个焦点请求: \(nextField)")
        performFocusTransition(to: nextField)
    }
}

// MARK: - InputFocusManager Extensions

extension InputFocusManager {
    /// 获取当前焦点字段的优先级
    var currentFocusPriority: Int {
        guard let currentField = currentFocusedField else { return 0 }
        return fieldPriorities[currentField] ?? 0
    }
    
    /// 获取等待焦点的字段数量
    var pendingFocusCount: Int {
        return focusQueue.count
    }
    
    /// 检查是否有高优先级的焦点请求
    func hasHigherPriorityRequest(than priority: Int) -> Bool {
        return focusQueue.contains { fieldId in
            let fieldPriority = fieldPriorities[fieldId] ?? 0
            return fieldPriority > priority
        }
    }
}

// MARK: - SwiftUI Integration

/// SwiftUI视图修饰符，用于集成焦点管理
struct FocusManaged: ViewModifier {
    let fieldId: String
    let priority: Int
    @StateObject private var focusManager = InputFocusManager.shared
    @FocusState private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: isFocused) { oldValue, newValue in
                if newValue {
                    focusManager.requestFocus(for: fieldId, priority: priority)
                } else {
                    focusManager.releaseFocus(for: fieldId)
                }
            }
            .onReceive(focusManager.$currentFocusedField) { currentField in
                isFocused = (currentField == fieldId)
            }
            .onDisappear {
                focusManager.releaseFocus(for: fieldId)
            }
    }
}

extension View {
    /// 应用焦点管理
    func focusManaged(fieldId: String, priority: Int = 0) -> some View {
        self.modifier(FocusManaged(fieldId: fieldId, priority: priority))
    }
}