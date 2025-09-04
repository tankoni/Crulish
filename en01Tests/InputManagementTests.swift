//
//  InputManagementTests.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import XCTest
import SwiftUI
@testable import en01

/// 输入管理系统测试
@MainActor
class InputManagementTests: XCTestCase {
    var inputManager: UnifiedInputManager!
    var keyboardManager: KeyboardManager!
    var focusManager: InputFocusManager!
    var conflictResolver: ConstraintConflictResolver!
    
    override func setUp() {
        super.setUp()
        inputManager = UnifiedInputManager.shared
        keyboardManager = KeyboardManager.shared
        focusManager = InputFocusManager.shared
        conflictResolver = ConstraintConflictResolver.shared
    }
    
    override func tearDown() {
        inputManager.shutdownInputSystem()
        super.tearDown()
    }
    
    // MARK: - 基础功能测试
    
    func testInputManagerInitialization() {
        XCTAssertNotNil(inputManager)
        XCTAssertFalse(inputManager.isInputSystemActive)
        XCTAssertEqual(inputManager.currentInputMode, .none)
        XCTAssertEqual(inputManager.systemHealth, .healthy)
    }
    
    func testInputSessionManagement() {
        // 测试开始输入会话
        inputManager.beginInputSession(fieldId: "test_field")
        XCTAssertTrue(inputManager.isInputSystemActive)
        
        // 测试结束输入会话
        inputManager.endInputSession()
        XCTAssertFalse(inputManager.isInputSystemActive)
    }
    
    func testMultipleInputSessions() {
        // 测试多个输入会话
        inputManager.beginInputSession(fieldId: "field1")
        inputManager.beginInputSession(fieldId: "field2")
        
        XCTAssertTrue(inputManager.isInputSystemActive)
        
        inputManager.endInputSession()
        XCTAssertFalse(inputManager.isInputSystemActive)
    }
    
    // MARK: - 键盘管理测试
    
    func testKeyboardManagerFunctionality() {
        XCTAssertNotNil(keyboardManager)
        XCTAssertFalse(keyboardManager.isKeyboardVisible)
        XCTAssertEqual(keyboardManager.keyboardHeight, 0)
    }
    
    func testKeyboardSessionManagement() {
        keyboardManager.beginInputSession(for: "test_keyboard_field")
        XCTAssertTrue(keyboardManager.inputSessionActive)
        
        keyboardManager.endInputSession()
        XCTAssertFalse(keyboardManager.inputSessionActive)
    }
    
    // MARK: - 焦点管理测试
    
    func testFocusManagerFunctionality() {
        XCTAssertNotNil(focusManager)
        XCTAssertNil(focusManager.currentFocusedField)
        XCTAssertFalse(focusManager.isFocusTransitioning)
    }
    
    func testFocusRequestAndRelease() {
        focusManager.requestFocus(for: "test_focus_field", priority: 1)
        XCTAssertEqual(focusManager.currentFocusedField, "test_focus_field")
        
        focusManager.releaseFocus(for: "test_focus_field")
        XCTAssertNil(focusManager.currentFocusedField)
    }
    
    func testFocusPriority() {
        focusManager.requestFocus(for: "low_priority", priority: 1)
        focusManager.requestFocus(for: "high_priority", priority: 5)
        
        XCTAssertEqual(focusManager.currentFocusedField, "high_priority")
    }
    
    // MARK: - 约束冲突解决测试
    
    func testConflictResolverFunctionality() {
        XCTAssertNotNil(conflictResolver)
        XCTAssertFalse(conflictResolver.hasActiveConflicts)
    }
    
    func testConflictDetectionAndResolution() {
        // 模拟约束冲突
        conflictResolver.startMonitoring()
        
        // 这里可以添加更具体的约束冲突测试
        // 由于需要实际的UI环境，这里主要测试基础功能
        
        conflictResolver.stopMonitoring()
    }
    
    // MARK: - 错误处理测试
    
    func testErrorHandling() {
        let initialErrorCount = inputManager.errorCount
        
        // 模拟输入错误
        let error = InputError(
            type: .keyboardSessionError,
            description: "Test error",
            context: [:]
        )
        
        inputManager.handleInputError(error)
        
        XCTAssertEqual(inputManager.errorCount, initialErrorCount + 1)
        XCTAssertNotNil(inputManager.lastErrorTime)
    }
    
    func testSystemHealthMonitoring() {
        // 测试系统健康状态
        XCTAssertEqual(inputManager.systemHealth, .healthy)
        
        // 模拟多个错误以触发健康状态变化
        for _ in 0..<5 {
            let error = InputError(
                type: .constraintConflict,
                description: "Test conflict",
                context: [:]
            )
            inputManager.handleInputError(error)
        }
        
        // 检查健康状态是否变化
        XCTAssertNotEqual(inputManager.systemHealth, .healthy)
    }
    
    // MARK: - 性能测试
    
    func testInputSessionPerformance() {
        measure {
            for i in 0..<100 {
                inputManager.beginInputSession(fieldId: "performance_test_\(i)")
                inputManager.endInputSession()
            }
        }
    }
    
    func testFocusManagementPerformance() {
        measure {
            for i in 0..<100 {
                focusManager.requestFocus(for: "perf_field_\(i)", priority: i % 10)
                focusManager.releaseFocus(for: "perf_field_\(i)")
            }
        }
    }
    
    // MARK: - 集成测试
    
    func testFullInputWorkflow() {
        // 测试完整的输入工作流程
        
        // 1. 初始化输入系统
        inputManager.initializeInputSystem()
        
        // 2. 开始输入会话
        inputManager.beginInputSession(
            fieldId: "integration_test_field",
            priority: 2,
            inputType: .search
        )
        
        XCTAssertTrue(inputManager.isInputSystemActive)
        XCTAssertEqual(inputManager.currentInputMode, .active)
        
        // 3. 模拟焦点变化
        focusManager.requestFocus(for: "integration_test_field", priority: 2)
        XCTAssertEqual(focusManager.currentFocusedField, "integration_test_field")
        
        // 4. 结束输入会话
        inputManager.endInputSession()
        
        XCTAssertFalse(inputManager.isInputSystemActive)
        XCTAssertEqual(inputManager.currentInputMode, .none)
    }
    
    func testConcurrentInputSessions() {
        // 测试并发输入会话处理
        let expectation = XCTestExpectation(description: "Concurrent sessions")
        
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            inputManager.beginInputSession(fieldId: "concurrent_field_\(index)")
            
            // 模拟一些处理时间
            Thread.sleep(forTimeInterval: 0.01)
            
            inputManager.endInputSession()
            
            if index == 9 {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // 验证系统状态正常
        XCTAssertFalse(inputManager.isInputSystemActive)
        XCTAssertEqual(inputManager.systemHealth, .healthy)
    }
}

// MARK: - 模拟数据和辅助方法

extension InputManagementTests {
    
    /// 创建模拟的输入错误
    private func createMockInputError(type: InputErrorType) -> InputError {
        return InputError(
            type: type,
            description: "Mock error for testing",
            context: ["test": true]
        )
    }
    
    /// 验证系统状态
    private func verifySystemState(
        isActive: Bool,
        mode: InputMode,
        health: SystemHealth
    ) {
        XCTAssertEqual(inputManager.isInputSystemActive, isActive)
        XCTAssertEqual(inputManager.currentInputMode, mode)
        XCTAssertEqual(inputManager.systemHealth, health)
    }
}