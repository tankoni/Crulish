//
//  InputManagementDemoView.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import SwiftUI

/// 输入管理系统演示视图
struct InputManagementDemoView: View {
    @StateObject private var inputManager = UnifiedInputManager.shared
    @State private var searchText = ""
    @State private var noteText = ""
    @State private var emailText = ""
    @State private var passwordText = ""
    @State private var showingSystemStatus = false
    @State private var showingErrorLog = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 系统状态卡片
                    systemStatusCard
                    
                    // 搜索输入演示
                    searchInputDemo
                    
                    // 文本输入演示
                    textInputDemo
                    
                    // 表单输入演示
                    formInputDemo
                    
                    // 控制按钮
                    controlButtons
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("输入管理演示")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("系统状态") {
                            showingSystemStatus = true
                        }
                        Button("错误日志") {
                            showingErrorLog = true
                        }
                        Button("重置系统") {
                            resetInputSystem()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSystemStatus) {
            SystemStatusView()
        }
        .sheet(isPresented: $showingErrorLog) {
            ErrorLogView()
        }
        .onAppear {
            inputManager.initializeInputSystem()
        }
    }
    
    // MARK: - 系统状态卡片
    
    private var systemStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.blue)
                Text("系统状态")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(healthColor)
                    .frame(width: 12, height: 12)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("输入模式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(inputModeText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("活跃状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(inputManager.isInputSystemActive ? "活跃" : "空闲")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(inputManager.isInputSystemActive ? .green : .gray)
                }
            }
            
            if inputManager.errorCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("\(inputManager.errorCount) 个错误")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button("查看") {
                        showingErrorLog = true
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 搜索输入演示
    
    private var searchInputDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                Text("搜索输入")
                    .font(.headline)
            }
            
            HStack {
                TextField("搜索内容...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onTapGesture {
                        inputManager.beginInputSession(
                            fieldId: "demo_search",
                            priority: 1,
                            inputType: .search
                        )
                    }
                    .onSubmit {
                        inputManager.endInputSession()
                    }
                
                Button("搜索") {
                    performSearch()
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchText.isEmpty)
            }
            
            if !searchText.isEmpty {
                Text("搜索: \"\(searchText)\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - 文本输入演示
    
    private var textInputDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.green)
                Text("文本输入")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("笔记内容")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextEditor(text: $noteText)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onTapGesture {
                        inputManager.beginInputSession(
                            fieldId: "demo_note",
                            priority: 2,
                            inputType: .text
                        )
                    }
            }
            
            HStack {
                Button("清空") {
                    noteText = ""
                    inputManager.endInputSession()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text("\(noteText.count) 字符")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - 表单输入演示
    
    private var formInputDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.purple)
                Text("表单输入")
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("邮箱地址")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("输入邮箱地址", text: $emailText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .onTapGesture {
                            inputManager.beginInputSession(
                                fieldId: "demo_email",
                                priority: 3,
                                inputType: .form
                            )
                        }
                        .onSubmit {
                            // 焦点转移到密码字段
                            inputManager.beginInputSession(
                                fieldId: "demo_password",
                                priority: 3,
                                inputType: .form
                            )
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("密码")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    SecureField("输入密码", text: $passwordText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onTapGesture {
                            inputManager.beginInputSession(
                                fieldId: "demo_password",
                                priority: 3,
                                inputType: .form
                            )
                        }
                        .onSubmit {
                            submitForm()
                        }
                }
            }
            
            HStack {
                Button("重置") {
                    emailText = ""
                    passwordText = ""
                    inputManager.endInputSession()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("提交") {
                    submitForm()
                }
                .buttonStyle(.borderedProminent)
                .disabled(emailText.isEmpty || passwordText.isEmpty)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - 控制按钮
    
    private var controlButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("模拟键盘错误") {
                    simulateKeyboardError()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
                
                Button("模拟约束冲突") {
                    simulateConstraintConflict()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            
            HStack(spacing: 12) {
                Button("强制结束会话") {
                    inputManager.endInputSession()
                }
                .buttonStyle(.bordered)
                
                Button("系统诊断") {
                    showingSystemStatus = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var healthColor: Color {
        switch inputManager.systemHealth {
        case .healthy:
            return .green
        case .recovering:
            return .yellow
        case .degraded:
            return .orange
        case .critical:
            return .red
        case .shutdown:
            return .gray
        case .warning:
            return .orange
        }
    }
    
    private var inputModeText: String {
        switch inputManager.currentInputMode {
        case .none:
            return "无"
        case .ready:
            return "就绪"
        case .active:
            return "活跃"
        case .transitioning:
            return "转换中"
        case .search:
            return "搜索"
        case .text:
            return "文本"
        case .form:
            return "表单"
        }
    }
    
    // MARK: - 方法
    
    private func performSearch() {
        print("执行搜索: \(searchText)")
        inputManager.endInputSession()
    }
    
    private func submitForm() {
        print("提交表单 - 邮箱: \(emailText), 密码: [已隐藏]")
        inputManager.endInputSession()
    }
    
    private func simulateKeyboardError() {
        let error = InputError(
            type: .keyboardSessionError,
            description: "模拟键盘会话错误",
            context: [:]
        )
        inputManager.handleInputError(error)
    }
    
    private func simulateConstraintConflict() {
        let error = InputError(
            type: .constraintConflict,
            description: "模拟的约束冲突错误",
            context: ["demo": true, "view": "InputManagementDemoView"]
        )
        inputManager.handleInputError(error)
    }
    
    private func resetInputSystem() {
        inputManager.shutdownInputSystem()
        inputManager.initializeInputSystem()
        
        // 清空所有输入
        searchText = ""
        noteText = ""
        emailText = ""
        passwordText = ""
    }
}

// MARK: - 系统状态视图

struct SystemStatusView: View {
    @StateObject private var inputManager = UnifiedInputManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("系统状态") {
                    StatusRow(title: "输入系统", value: inputManager.isInputSystemActive ? "活跃" : "空闲")
                    StatusRow(title: "当前模式", value: inputModeText)
                    StatusRow(title: "系统健康", value: healthText)
                    StatusRow(title: "错误计数", value: "\(inputManager.errorCount)")
                }
                
                Section("键盘管理") {
                    StatusRow(title: "键盘可见", value: KeyboardManager.shared.isKeyboardVisible ? "是" : "否")
                    StatusRow(title: "键盘高度", value: "\(Int(KeyboardManager.shared.keyboardHeight))pt")
                    StatusRow(title: "输入会话", value: KeyboardManager.shared.inputSessionActive ? "活跃" : "空闲")
                }
                
                Section("焦点管理") {
                    StatusRow(title: "当前焦点", value: InputFocusManager.shared.currentFocusedField ?? "无")
                    StatusRow(title: "焦点转换", value: InputFocusManager.shared.isFocusTransitioning ? "进行中" : "空闲")
                }
                
                Section("约束冲突") {
                    StatusRow(title: "活跃冲突", value: ConstraintConflictResolver.shared.hasActiveConflicts ? "是" : "否")
                    StatusRow(title: "监控状态", value: "正常")
                }
            }
            .navigationTitle("系统状态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var inputModeText: String {
        switch inputManager.currentInputMode {
        case .none: return "无"
        case .ready: return "就绪"
        case .active: return "活跃"
        case .transitioning: return "转换中"
        case .search: return "搜索"
        case .text: return "文本"
        case .form: return "表单"
        }
    }
    
    private var healthText: String {
        switch inputManager.systemHealth {
        case .healthy: return "健康"
        case .recovering: return "恢复中"
        case .degraded: return "降级"
        case .critical: return "严重"
        case .shutdown: return "关闭"
        case .warning: return "警告"
        }
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 错误日志视图

struct ErrorLogView: View {
    @StateObject private var inputManager = UnifiedInputManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if inputManager.errorCount == 0 {
                    Text("暂无错误记录")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Section("错误统计") {
                        HStack {
                            Text("总错误数")
                            Spacer()
                            Text("\(inputManager.errorCount)")
                                .foregroundColor(.red)
                        }
                        
                        if let lastErrorTime = inputManager.lastErrorTime {
                            HStack {
                                Text("最后错误")
                                Spacer()
                                Text(lastErrorTime, style: .relative)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Section("操作") {
                        Button("清除错误日志") {
                            // 这里可以添加清除错误日志的功能
                        }
                        .foregroundColor(.blue)
                        
                        Button("导出日志") {
                            // 这里可以添加导出日志的功能
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("错误日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    InputManagementDemoView()
}