//
//  SettingsView.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    @State private var isShowingResetAlert = false
    @State private var isShowingExportSheet = false
    @State private var isShowingImportSheet = false
    @State private var isShowingAbout = false
    @State private var settings: AppSettings?
    @State private var exportData: Data?
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
                viewModel.resetAllData()
            }
        } message: {
            Text("此操作将删除所有学习数据，包括词汇记录、阅读进度和统计信息。此操作不可撤销。")
        }
        .sheet(isPresented: $isShowingExportSheet) {
            ExportDataView(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingImportSheet) {
            ImportDataView(viewModel: viewModel)
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
                Text("\(Int(viewModel.readingSettings.fontSize))")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: $viewModel.readingSettings.fontSize,
                in: 12...24,
                step: 1
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 8, trailing: 16))
            
            // 字体家族
            Picker("字体", selection: $viewModel.readingSettings.fontFamily) {
                Text("系统字体").tag("System")
                Text("苹方").tag("PingFang SC")
                Text("宋体").tag("Songti SC")
            }
            .pickerStyle(MenuPickerStyle())
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            
            // 行间距
            HStack {
                Label("行间距", systemImage: "line.3.horizontal")
                Spacer()
                Text("\(viewModel.readingSettings.lineSpacing, specifier: "%.1f")")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: $viewModel.readingSettings.lineSpacing,
                in: 4...12,
                step: 1
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 8, trailing: 16))
            
            // 自动滚动速度
            HStack {
                Label("自动滚动速度", systemImage: "speedometer")
                Spacer()
                Text("\(viewModel.readingSettings.autoScrollSpeed, specifier: "%.1f")")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: $viewModel.readingSettings.autoScrollSpeed,
                in: 0.5...3.0,
                step: 0.1
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 8, trailing: 16))
            
            // 启用自动滚动
            Toggle("启用自动滚动", isOn: $viewModel.readingSettings.enableAutoScroll)
            
            // 显示字数统计
            Toggle("显示字数统计", isOn: $viewModel.readingSettings.showWordCount)
            
            // 显示阅读时间
            Toggle("显示阅读时间", isOn: $viewModel.readingSettings.showReadingTime)
        }
    }
    
    // MARK: - 主题设置
    
    private var themeSection: some View {
        Section("主题设置") {
            // 颜色方案
            Picker("外观", selection: $viewModel.appearanceSettings.colorScheme) {
                Text("跟随系统").tag(ColorSchemePreference.system)
                Text("浅色模式").tag(ColorSchemePreference.light)
                Text("深色模式").tag(ColorSchemePreference.dark)
            }
            .pickerStyle(MenuPickerStyle())
            
            // 启用动态字体
            Toggle("启用动态字体", isOn: $viewModel.appearanceSettings.enableDynamicType)
            
            // 启用减少动画
            Toggle("减少动画效果", isOn: $viewModel.appearanceSettings.enableReduceMotion)
            
            // 启用高对比度
            Toggle("高对比度", isOn: $viewModel.appearanceSettings.enableHighContrast)
        }
    }
    
    // MARK: - 学习设置
    
    private var learningSection: some View {
        Section("学习设置") {
            // 启用自动查词
            Toggle("启用自动查词", isOn: $viewModel.vocabularySettings.enableAutoLookup)
            
            // 显示发音
            Toggle("显示发音", isOn: $viewModel.vocabularySettings.showPronunciation)
            
            // 显示例句
            Toggle("显示例句", isOn: $viewModel.vocabularySettings.showExamples)
            
            // 启用间隔重复
            Toggle("启用间隔重复", isOn: $viewModel.vocabularySettings.enableSpacedRepetition)
            
            // 每日新词数量
            HStack {
                Label("每日新词数量", systemImage: "target")
                Spacer()
                Text("\(viewModel.vocabularySettings.maxNewWordsPerDay)个")
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: Binding(
                    get: { Double(viewModel.vocabularySettings.maxNewWordsPerDay) },
                    set: { viewModel.vocabularySettings.maxNewWordsPerDay = Int($0) }
                ),
                in: 5...50,
                step: 5
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 8, trailing: 16))
        }
    }
    
    // MARK: - 通知设置
    
    private var notificationSection: some View {
        Section("通知设置") {
            // 学习提醒
            Toggle("学习提醒", isOn: $viewModel.notificationSettings.enableDailyReminder)
            
            if viewModel.notificationSettings.enableDailyReminder {
                DatePicker(
                    "提醒时间",
                    selection: $viewModel.notificationSettings.dailyReminderTime,
                    displayedComponents: .hourAndMinute
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 32, bottom: 8, trailing: 16))
            }
            
            // 复习提醒
            Toggle("复习提醒", isOn: $viewModel.notificationSettings.enableReviewReminder)
            
            // 成就通知
            Toggle("成就通知", isOn: $viewModel.notificationSettings.enableAchievementNotifications)
        }
    }
    
    // MARK: - 数据管理
    
    private var dataSection: some View {
        Section("数据管理") {
            // 考研词典状态
            NavigationLink(destination: KaoyanDictionaryStatusView()) {
                Label("考研词典状态", systemImage: "book.fill")
            }
            
            // 重新导入PDF
            Button {
                Task {
                    await reimportPDFs()
                }
            } label: {
                Label("重新导入PDF文章", systemImage: "doc.text.fill")
                    .foregroundColor(.blue)
            }
            
            // 性能监控
            NavigationLink(destination: PerformanceMonitorView()) {
                Label("性能监控", systemImage: "speedometer")
            }
            
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
            Toggle("自动备份", isOn: $viewModel.dataSettings.enableAutoBackup)
            
            if viewModel.dataSettings.enableAutoBackup {
                Picker("备份频率", selection: $viewModel.dataSettings.backupFrequency) {
                    Text("每日").tag(BackupFrequency.daily)
                    Text("每周").tag(BackupFrequency.weekly)
                    Text("每月").tag(BackupFrequency.monthly)
                }
                .pickerStyle(MenuPickerStyle())
                .listRowInsets(EdgeInsets(top: 8, leading: 32, bottom: 8, trailing: 16))
            }
            
            // 清除缓存
            Button {
                Task {
                    await viewModel.clearCache()
                }
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
    @ObservedObject var viewModel: SettingsViewModel
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
                    SwiftUI.ProgressView()
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
            let success = await viewModel.exportData(types: selectedDataTypes)
            await MainActor.run {
                isExporting = false
                exportSuccess = success
            }
        }
    }
}

// MARK: - 导入数据视图

struct ImportDataView: View {
    @ObservedObject var viewModel: SettingsViewModel
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
                            SwiftUI.ProgressView()
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
            // 这里应该使用文件选择器获取URL，暂时使用模拟URL
            let mockURL = URL(fileURLWithPath: "/tmp/mock_data.json")
            let result = await viewModel.importData(from: mockURL)
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
    
    /// 加载设置
    private func loadSettings() {
        viewModel.loadSettings()
    }
    
    /// 重新导入PDF文章
    private func reimportPDFs() async {
        await viewModel.reimportPDFs()
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(
        userProgressService: MockUserProgressService(),
        errorHandler: MockErrorHandler(),
        cacheManager: MockCacheManager()
    ))
}

#Preview("ExportDataView") {
    ExportDataView(viewModel: SettingsViewModel(
        userProgressService: MockUserProgressService(),
        errorHandler: MockErrorHandler(),
        cacheManager: MockCacheManager()
    ))
}

#Preview("ImportDataView") {
    ImportDataView(viewModel: SettingsViewModel(
        userProgressService: MockUserProgressService(),
        errorHandler: MockErrorHandler(),
        cacheManager: MockCacheManager()
    ))
}