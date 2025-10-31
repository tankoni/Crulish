//
//  DictionarySpecificExportView.swift
//  en01
//
//  Created by AI Assistant on 2025/01/28.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Combine

struct DictionarySpecificExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dictionaryService: DictionaryService
    @Environment(UnifiedErrorHandler.self) private var errorHandler
    
    // 导出服务
    private let importExportService: DictionarySpecificImportExportService
    
    // 状态管理
    @State private var availableDictionaries: [DictionaryInfo] = []
    @State private var selectedDictionary: DictionaryInfo?
    @State private var selectedExportType: ExportType = .testRecords
    @State private var selectedFormat: ExportFormat = .text
    @State private var selectedMasteryLevels: Set<MasteryLevel> = Set(MasteryLevel.allCases)
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var exportResult: ExportResult?
    @State private var exportError: String?
    @State private var exportedFileURL: URL?
    
    // 导出类型
    enum ExportType: String, CaseIterable {
        case testRecords = "test_records"
        case masteryWords = "mastery_words"
        
        var displayName: String {
            switch self {
            case .testRecords:
                return "测试记录"
            case .masteryWords:
                return "掌握程度单词"
            }
        }
        
        var description: String {
            switch self {
            case .testRecords:
                return "导出该词典的所有测试记录"
            case .masteryWords:
                return "按掌握程度导出单词列表"
            }
        }
        
        var icon: String {
            switch self {
            case .testRecords:
                return "doc.text"
            case .masteryWords:
                return "list.bullet"
            }
        }
    }
    
    init() {
        self.importExportService = DictionarySpecificImportExportService(
            modelContext: nil // 将在 onAppear 中设置
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 头部说明
                    headerSection
                    
                    // 词典选择
                    dictionarySelectionSection
                    
                    // 导出类型选择
                    exportTypeSection
                    
                    // 导出格式选择
                    exportFormatSection
                    
                    // 掌握程度筛选（仅在导出掌握程度单词时显示）
                    if selectedExportType == .masteryWords {
                        masteryFilterSection
                    }
                    
                    // 导出按钮
                    exportButtonSection
                    
                    // 导出进度
                    if isExporting {
                        exportProgressSection
                    }
                    
                    // 导出结果
                    if let result = exportResult {
                        exportResultSection(result)
                    }
                    
                    // 错误信息
                    if let error = exportError {
                        errorSection(error)
                    }
                }
                .padding()
            }
            .navigationTitle("词典专属导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupService()
                loadAvailableDictionaries()
            }
        }
    }
    
    // MARK: - 头部说明
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up.on.square")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("词典专属导出")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("导出指定词典的测试记录或按掌握程度筛选的单词列表")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - 词典选择区域
    
    private var dictionarySelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.closed")
                    .foregroundColor(.blue)
                Text("选择词典")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if availableDictionaries.isEmpty {
                Text("暂无可用词典")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(availableDictionaries, id: \.id) { dictionary in
                        DictionarySelectionRow(
                            dictionary: dictionary,
                            isSelected: selectedDictionary?.id == dictionary.id
                        ) {
                            selectedDictionary = dictionary
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 导出类型选择
    
    private var exportTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.badge.gearshape")
                    .foregroundColor(.orange)
                Text("导出类型")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(ExportType.allCases, id: \.self) { type in
                    ExportTypeRow(
                        type: type,
                        isSelected: selectedExportType == type
                    ) {
                        selectedExportType = type
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 导出格式选择
    
    private var exportFormatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.green)
                Text("导出格式")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    ExportFormatButton(
                        format: format,
                        isSelected: selectedFormat == format
                    ) {
                        selectedFormat = format
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 掌握程度筛选
    
    private var masteryFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text("掌握程度筛选")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(MasteryLevel.allCases, id: \.self) { mastery in
                    MasteryFilterButton(
                        mastery: mastery,
                        count: 0, // 这里可以后续添加统计数据
                        isSelected: selectedMasteryLevels.contains(mastery)
                    ) {
                        toggleMasterySelection(mastery)
                    }
                }
            }
            
            HStack {
                Button("全选") {
                    selectedMasteryLevels = Set(MasteryLevel.allCases)
                }
                .buttonStyle(.bordered)
                
                Button("全不选") {
                    selectedMasteryLevels.removeAll()
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 导出按钮
    
    private var exportButtonSection: some View {
        Button {
            startExport()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("开始导出")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canExport ? Color.blue : Color(.systemGray4))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canExport)
    }
    
    // MARK: - 导出进度
    
    private var exportProgressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(.blue)
                Text("导出进度")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ProgressView(value: exportProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("正在导出数据...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 导出结果
    
    private func exportResultSection(_ result: ExportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("导出完成")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("导出记录数:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(result.exportedCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                if let fileURL = result.fileURL {
                    HStack {
                        Text("文件路径:")
                            .font(.subheadline)
                        Spacer()
                        Text(fileURL.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack(spacing: 12) {
                if let fileURL = result.fileURL {
                    Button("分享文件") {
                        shareFile(fileURL)
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 错误信息
    
    private func errorSection(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("导出失败")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("重试") {
                exportError = nil
                exportResult = nil
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 计算属性
    
    private var canExport: Bool {
        guard selectedDictionary != nil && !isExporting else { return false }
        
        if selectedExportType == .masteryWords {
            return !selectedMasteryLevels.isEmpty
        }
        
        return true
    }
    
    // MARK: - 方法
    
    private func setupService() {
        importExportService.setModelContext(modelContext)
    }
    
    private func loadAvailableDictionaries() {
        Task {
            do {
                // 使用 async/await 处理 Publisher
                let dictionaries = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[DictionaryInfo], Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = dictionaryService.getAvailableDictionaries()
                        .sink(
                            receiveCompletion: { completion in
                                cancellable?.cancel()
                                if case .failure(let error) = completion {
                                    continuation.resume(throwing: error)
                                }
                            },
                            receiveValue: { dictionaries in
                                cancellable?.cancel()
                                continuation.resume(returning: dictionaries)
                            }
                        )
                }
                
                await MainActor.run {
                    self.availableDictionaries = dictionaries
                    if let first = dictionaries.first {
                        self.selectedDictionary = first
                    }
                }
            } catch {
                await MainActor.run {
                    self.exportError = "加载词典列表失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func toggleMasterySelection(_ mastery: MasteryLevel) {
        if selectedMasteryLevels.contains(mastery) {
            selectedMasteryLevels.remove(mastery)
        } else {
            selectedMasteryLevels.insert(mastery)
        }
    }
    
    private func startExport() {
        guard let dictionary = selectedDictionary else { return }
        
        Task {
            await MainActor.run {
                isExporting = true
                exportProgress = 0.0
                exportError = nil
                exportResult = nil
            }
            
            do {
                let result: ExportResult
                
                switch selectedExportType {
                case .testRecords:
                    result = try await importExportService.exportDictionaryTestRecords(
                        dictionaryFileName: dictionary.fileName,
                        format: selectedFormat
                    )
                    
                case .masteryWords:
                    result = try await importExportService.exportWordsByMastery(
                        dictionaryFileName: dictionary.fileName,
                        masteryLevels: Array(selectedMasteryLevels),
                        format: selectedFormat
                    )
                }
                
                await MainActor.run {
                    self.isExporting = false
                    self.exportResult = result
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.exportError = "导出失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func shareFile(_ fileURL: URL) {
        #if canImport(UIKit)
        let activityViewController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
        #endif
    }
}

// MARK: - 导出类型行组件

struct ExportTypeRow: View {
    let type: DictionarySpecificExportView.ExportType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 导出格式按钮组件

struct ExportFormatButton: View {
    let format: ExportFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: format.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(format.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 扩展

extension ExportFormat {
    var icon: String {
        switch self {
        case .text:
            return "doc.text"
        case .csv:
            return "tablecells"
        case .json:
            return "curlybraces"
        case .markdown:
            return "doc.richtext"
        case .pdf:
            return "doc.badge.plus"
        }
    }
}

// MARK: - 预览

#Preview {
    let container = try! ModelContainer(for: UserWord.self)
    let mockContext = ModelContext(container)
    let mockCacheManager = MockCacheManager()
    let mockErrorHandler = UnifiedErrorHandler()
    
    let mockDictionaryService = DictionaryService(
        modelContext: mockContext,
        cacheManager: mockCacheManager,
        errorHandler: mockErrorHandler
    )
    
    DictionarySpecificExportView()
        .modelContainer(container)
        .environmentObject(mockDictionaryService)
        .environment(mockErrorHandler)
}