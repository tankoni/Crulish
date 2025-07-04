//
//  SettingsView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var isShowingResetAlert = false
    @State private var isShowingExportSheet = false
    @State private var isShowingImportSheet = false
    @State private var isShowingAbout = false
    @State private var settings: AppSettings?
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingResetAlert = false
    @State private var exportData: Data?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isDataLoaded = false
    
    var body: some View {
        NavigationView {
            List {
                // 阅读设置
                readingSection
                
                // 主题设置
                themeSection
                
                // 学习设置
                learningSection
                
                // 通知设置
                notificationSection
                
                // 数据管理
                dataSection
                
                // 关于应用
                aboutSection
            }
            .navigationTitle("设置")
    
        }
        .alert("重置所有数据", isPresented: $isShowingResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                appViewModel.resetAllData()
            }
        } message: {
            Text("此操作将删除所有学习数据，包括词汇记录、阅读进度和统计信息。此操作不可撤销。")
        }
        .sheet(isPresented: $isShowingExportSheet) {
            ExportDataView()
        }
        .sheet(isPresented: $isShowingImportSheet) {
            ImportDataView()
        }
        .sheet(isPresented: $isShowingAbout) {
            AboutView()
        }
        .onAppear {
            // 避免重复加载数据
            if !isDataLoaded {
                loadSettings()
                isDataLoaded = true
            }
        }
    }
    
    // MARK: - 阅读设置
    
    private var readingSection: some View {
        Section("阅读设置") {
            // 字体大小
            HStack {
                Label("字体大小", systemImage: "textformat.size")
                Spacer()
                Text("\(Int(appViewModel.settings.fontSize))")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: Binding(
                    get: { appViewModel.settings.fontSize },
                    set: { appViewModel.settings.fontSize = $0 }
                ),
                in: 12...24,
                step: 1
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 8, trailing: 16))
            
            // 字体家族
            Picker("字体", selection: Binding(
                get: { appViewModel.settings.fontFamily },
                set: { appViewModel.settings.fontFamily = $0 }
            )) {
                ForEach(FontFamily.allCases, id: \.self) { font in
                    Text(font.displayName).tag(font)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            
            // 行间距
            HStack {
                Label("行间距", systemImage: "line.3.horizontal")
                Spacer()
                Text("\(Int(appViewModel.settings.lineSpacing))")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: Binding(
                    get: { appViewModel.settings.lineSpacing },
                    set: { appViewModel.settings.lineSpacing = $0 }
                ),
                in: 4...12,
                step: 1
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 8, trailing: 16))
            
            // 段落间距
            HStack {
                Label("段落间距", systemImage: "text.alignleft")
                Spacer()
                Text("\(Int(appViewModel.settings.paragraphSpacing))")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: Binding(
                    get: { appViewModel.settings.paragraphSpacing },
                    set: { appViewModel.settings.paragraphSpacing = $0 }
                ),
                in: 8...24,
                step: 2
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 8, trailing: 16))
            
            // 页边距
            HStack {
                Label("页边距", systemImage: "rectangle.inset.filled")
                Spacer()
                Text("\(Int(appViewModel.settings.readingMargin))")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: Binding(
                    get: { appViewModel.settings.readingMargin },
                    set: { appViewModel.settings.readingMargin = $0 }
                ),
                in: 16...32,
                step: 4
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 8, trailing: 16))
            
            // 文本对齐
            Picker("文本对齐", selection: Binding(
                get: { appViewModel.settings.textAlignment },
                set: { appViewModel.settings.textAlignment = $0 }
            )) {
                ForEach(TextAlignment.allCases, id: \.self) { alignment in
                    Label(alignment.displayName, systemImage: alignment.iconName).tag(alignment)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    // MARK: - 主题设置
    
    private var themeSection: some View {
        Section("主题设置") {
            // 颜色方案
            Picker("外观", selection: Binding(
                get: { appViewModel.settings.colorScheme },
                set: { appViewModel.settings.colorScheme = $0 }
            )) {
                ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                    Label(scheme.displayName, systemImage: scheme.iconName).tag(scheme)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            // 主题色
            Picker("主题色", selection: Binding(
                get: { appViewModel.settings.accentColor },
                set: { appViewModel.settings.accentColor = $0 }
            )) {
                ForEach(AccentColor.allCases, id: \.self) { color in
                    HStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 16, height: 16)
                        Text(color.displayName)
                    }
                    .tag(color)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            // 护眼模式
            Toggle("护眼模式", isOn: Binding(
                get: { appViewModel.settings.eyeCareMode },
                set: { appViewModel.settings.eyeCareMode = $0 }
            ))
            
            // 自动夜间模式
            Toggle("自动夜间模式", isOn: Binding(
                get: { appViewModel.settings.autoNightMode },
                set: { appViewModel.settings.autoNightMode = $0 }
            ))
        }
    }
    
    // MARK: - 学习设置
    
    private var learningSection: some View {
        Section("学习设置") {
            // 释义语言
            Picker("释义语言", selection: Binding(
                get: { appViewModel.settings.definitionLanguage },
                set: { appViewModel.settings.definitionLanguage = $0 }
            )) {
                ForEach(DefinitionLanguage.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            // 自动保存查词
            Toggle("自动保存查词", isOn: Binding(
                get: { appViewModel.settings.autoSaveWords },
                set: { appViewModel.settings.autoSaveWords = $0 }
            ))
            
            // 智能复习提醒
            Toggle("智能复习提醒", isOn: Binding(
                get: { appViewModel.settings.smartReviewReminder },
                set: { appViewModel.settings.smartReviewReminder = $0 }
            ))
            
            // 显示词性
            Toggle("显示词性", isOn: Binding(
                get: { appViewModel.settings.showPartOfSpeech },
                set: { appViewModel.settings.showPartOfSpeech = $0 }
            ))
            
            // 显示例句
            Toggle("显示例句", isOn: Binding(
                get: { appViewModel.settings.showExamples },
                set: { appViewModel.settings.showExamples = $0 }
            ))
            
            // 每日学习目标
            HStack {
                Label("每日学习目标", systemImage: "target")
                Spacer()
                Text("\(appViewModel.settings.dailyGoalMinutes)分钟")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: Binding(
                    get: { Double(appViewModel.settings.dailyGoalMinutes) },
                    set: { appViewModel.settings.dailyGoalMinutes = Int($0) }
                ),
                in: 15...120,
                step: 15
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 8, trailing: 16))
        }
    }
    
    // MARK: - 通知设置
    
    private var notificationSection: some View {
        Section("通知设置") {
            // 学习提醒
            Toggle("学习提醒", isOn: Binding(
                get: { appViewModel.settings.studyReminder },
                set: { appViewModel.settings.studyReminder = $0 }
            ))
            
            if appViewModel.settings.studyReminder {
                DatePicker(
                    "提醒时间",
                    selection: Binding(
                        get: { appViewModel.settings.reminderTime },
                        set: { appViewModel.settings.reminderTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 32, bottom: 8, trailing: 16))
            }
            
            // 复习提醒
            Toggle("复习提醒", isOn: Binding(
                get: { appViewModel.settings.reviewReminder },
                set: { appViewModel.settings.reviewReminder = $0 }
            ))
            
            // 成就通知
            Toggle("成就通知", isOn: Binding(
                get: { appViewModel.settings.achievementNotification },
                set: { appViewModel.settings.achievementNotification = $0 }
            ))
        }
    }
    
    // MARK: - 数据管理
    
    private var dataSection: some View {
        Section("数据管理") {
            // 导出数据
            Button {
                isShowingExportSheet = true
            } label: {
                Label("导出数据", systemImage: "square.and.arrow.up")
            }
            
            // 导入数据
            Button {
                isShowingImportSheet = true
            } label: {
                Label("导入数据", systemImage: "square.and.arrow.down")
            }
            
            // 自动备份
            Toggle("自动备份", isOn: Binding(
                get: { appViewModel.settings.autoBackup },
                set: { appViewModel.settings.autoBackup = $0 }
            ))
            
            if appViewModel.settings.autoBackup {
                Picker("备份频率", selection: Binding(
                    get: { appViewModel.settings.backupFrequency },
                    set: { appViewModel.settings.backupFrequency = $0 }
                )) {
                    ForEach(BackupFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .listRowInsets(EdgeInsets(top: 8, leading: 32, bottom: 8, trailing: 16))
            }
            
            // 清除缓存
            Button {
                appViewModel.clearCache()
            } label: {
                Label("清除缓存", systemImage: "trash")
                    .foregroundColor(.orange)
            }
            
            // 重置所有数据
            Button {
                isShowingResetAlert = true
            } label: {
                Label("重置所有数据", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - 关于应用
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关于")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                // 应用版本
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Divider()
                
                // 关于应用
                Button("关于应用") {
                    isShowingAbout = true
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

// MARK: - 导出数据视图

struct ExportDataView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDataTypes: Set<DataType> = []
    @State private var isExporting = false
    @State private var exportSuccess = false
    
    var body: some View {
        NavigationView {
            exportContent
        }
        .alert("导出成功", isPresented: $exportSuccess) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("数据已成功导出到文件")
        }
    }
    
    private var exportContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            dataTypesList
            exportButton
            Spacer()
        }
        .navigationTitle("导出数据")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("导出数据")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("选择要导出的数据类型")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private var dataTypesList: some View {
        List {
            ForEach(DataType.allCases, id: \.self) { dataType in
                dataTypeRow(dataType)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func dataTypeRow(_ dataType: DataType) -> some View {
        HStack {
            Image(systemName: selectedDataTypes.contains(dataType) ? "checkmark.circle.fill" : "circle")
                .foregroundColor(selectedDataTypes.contains(dataType) ? .blue : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dataType.displayName)
                     .font(.subheadline)
                 
                 Text(dataType.description)
                     .font(.caption)
                     .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedDataTypes.contains(dataType) {
                selectedDataTypes.remove(dataType)
            } else {
                selectedDataTypes.insert(dataType)
            }
        }
    }
    
    private var exportButton: some View {
        Button {
            exportData()
        } label: {
            if isExporting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("导出中...")
                }
            } else {
                Text("导出数据")
            }
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
        .disabled(selectedDataTypes.isEmpty || isExporting)
        .padding(.horizontal)
    }
    

     
     private func exportData() {
         isExporting = true
        
        Task {
            let success = await appViewModel.exportData(types: selectedDataTypes)
            await MainActor.run {
                isExporting = false
                exportSuccess = success
            }
        }
    }
}

// MARK: - 导入数据视图

struct ImportDataView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var importSuccess = false
    @State private var importError: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("导入数据")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("选择要导入的数据文件。导入的数据将与现有数据合并。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button {
                    importData()
                } label: {
                    if isImporting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("导入中...")
                        }
                    } else {
                        Text("选择文件")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting)
                
                Spacer()
            }
            .padding()
            .navigationTitle("导入数据")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .alert("导入成功", isPresented: $importSuccess) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("数据已成功导入")
        }
        .alert("导入失败", isPresented: .constant(importError != nil)) {
            Button("确定") {
                importError = nil
            }
        } message: {
            Text(importError ?? "")
        }
    }
    
    private func importData() {
        isImporting = true
        
        Task {
            let result = await appViewModel.importData()
            await MainActor.run {
                isImporting = false
                switch result {
                case .success:
                    importSuccess = true
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - 关于应用视图

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 应用图标和名称
                    VStack(spacing: 16) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("考研英语无痛阅读器")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("版本 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 应用介绍
                    VStack(alignment: .leading, spacing: 12) {
                        Text("关于应用")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text("考研英语无痛阅读器是一款专为考研英语学习设计的阅读应用。通过智能的上下文词义匹配技术，帮助用户在阅读过程中准确理解单词含义，构建个人专属词汇宝典，实现无痛英语学习。")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // 核心功能
                    VStack(alignment: .leading, spacing: 12) {
                        Text("核心功能")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "book.fill", title: "智能阅读", description: "上下文精准释义，消除一词多义干扰")
                            FeatureRow(icon: "brain.head.profile", title: "个人词典", description: "自动构建专属词汇宝典")
                            FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "学习分析", description: "详细的学习统计和进度追踪")
                            FeatureRow(icon: "trophy.fill", title: "成就系统", description: "激励学习，记录成长历程")
                        }
                    }
                    
                    // 开发信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text("开发信息")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text("本应用采用 SwiftUI 和 SwiftData 技术开发，完全离线运行，保护用户隐私。所有数据均存储在本地设备上。")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("关于")

            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - SettingsView 扩展

extension SettingsView {
    // MARK: - 数据操作
    
    /// 异步加载设置（带性能优化）
    private func loadSettings() {
        Task {
            let loadedSettings = await loadUserSettings()
            
            await MainActor.run {
                self.settings = loadedSettings
            }
        }
    }
    
    /// 异步加载用户设置
    private func loadUserSettings() async -> AppSettings? {
        // 模拟异步加载设置
        return AppSettings()
    }
}

#Preview {
    SettingsView()
        .environment(AppViewModel())
}