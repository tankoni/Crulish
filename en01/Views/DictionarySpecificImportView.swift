//
//  DictionarySpecificImportView.swift
//  en01
//
//  Created by AI Assistant on 2025/01/28.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Combine

struct DictionarySpecificImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dictionaryService: DictionaryService
    @Environment(UnifiedErrorHandler.self) private var errorHandler
    
    // 导入服务
    private let importExportService: DictionarySpecificImportExportService
    
    // 状态管理
    @State private var availableDictionaries: [DictionaryInfo] = []
    @State private var selectedDictionary: DictionaryInfo?
    @State private var selectedImportMode: ImportMode = .merge
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    @State private var importResult: ImportResult?
    @State private var importError: String?
    @State private var showFileImporter = false
    @State private var showManualInput = false
    @State private var manualInputText = ""
    
    // Combine cancellables
    @State private var cancellables = Set<AnyCancellable>()
    
    // 导入模式选项
    private let importModes: [ImportMode] = [.merge, .overwrite, .skip]
    
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
                    
                    // 导入模式选择
                    importModeSection
                    
                    // 导入方式选择
                    importMethodSection
                    
                    // 导入进度
                    if isImporting {
                        importProgressSection
                    }
                    
                    // 导入结果
                    if let result = importResult {
                        importResultSection(result)
                    }
                    
                    // 错误信息
                    if let error = importError {
                        errorSection(error)
                    }
                }
                .padding()
            }
            .navigationTitle("词典专属导入")
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
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.plainText, .commaSeparatedText, .json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showManualInput) {
                ManualInputView(
                    text: $manualInputText,
                    onImport: { text in
                        importManualText(text)
                    }
                )
            }
        }
    }
    
    // MARK: - 头部说明
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("词典专属导入")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("将单词导入到指定词典，支持文本文件、CSV文件和JSON文件格式")
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
                Text("选择目标词典")
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
    
    // MARK: - 导入模式选择
    
    private var importModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gearshape")
                    .foregroundColor(.orange)
                Text("导入模式")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(importModes, id: \.self) { mode in
                    ImportModeRow(
                        mode: mode,
                        isSelected: selectedImportMode == mode
                    ) {
                        selectedImportMode = mode
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 导入方式选择
    
    private var importMethodSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.badge.plus")
                    .foregroundColor(.green)
                Text("选择导入方式")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 文件导入按钮
                Button {
                    showFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("从文件导入")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canImport)
                
                // 手动输入按钮
                Button {
                    showManualInput = true
                } label: {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("手动输入单词")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canImport)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 导入进度
    
    private var importProgressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
                Text("导入进度")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ProgressView(value: importProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("正在导入单词...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 导入结果
    
    private func importResultSection(_ result: ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("导入完成")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("成功导入:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(result.successCount) 个单词")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                if !result.duplicateWords.isEmpty {
                    HStack {
                        Text("重复单词:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(result.duplicateWords.count) 个")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                
                if !result.failedWords.isEmpty {
                    HStack {
                        Text("导入失败:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(result.failedWords.count) 个")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Button("完成") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
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
                Text("导入失败")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("重试") {
                importError = nil
                importResult = nil
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
    
    private var canImport: Bool {
        selectedDictionary != nil && !isImporting
    }
    
    // MARK: - 方法
    
    private func setupService() {
        importExportService.setModelContext(modelContext)
    }
    
    private func loadAvailableDictionaries() {
        dictionaryService.getAvailableDictionaries()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.importError = "加载词典列表失败: \(error.localizedDescription)"
                    }
                },
                receiveValue: { dictionaries in
                    self.availableDictionaries = dictionaries
                    if let first = dictionaries.first {
                        self.selectedDictionary = first
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  let dictionary = selectedDictionary else { return }
            
            importFromFile(url: url, dictionary: dictionary)
            
        case .failure(let error):
            importError = "文件选择失败: \(error.localizedDescription)"
        }
    }
    
    private func importFromFile(url: URL, dictionary: DictionaryInfo) {
        Task {
            await MainActor.run {
                isImporting = true
                importProgress = 0.0
                importError = nil
                importResult = nil
            }
            
            do {
                let result = try await importExportService.importWordsFromFile(
                    fileURL: url,
                    dictionaryFileName: dictionary.fileName,
                    importMode: selectedImportMode
                )
                
                await MainActor.run {
                    self.isImporting = false
                    self.importResult = result
                }
            } catch {
                await MainActor.run {
                    self.isImporting = false
                    self.importError = "导入失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func importManualText(_ text: String) {
        guard let dictionary = selectedDictionary else { return }
        
        let words = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        Task {
            await MainActor.run {
                isImporting = true
                importProgress = 0.0
                importError = nil
                importResult = nil
            }
            
            do {
                let result = try await importExportService.importWordsToSpecificDictionary(
                    words: words,
                    dictionaryFileName: dictionary.fileName,
                    importMode: selectedImportMode
                )
                
                await MainActor.run {
                    self.isImporting = false
                    self.importResult = result
                    self.manualInputText = ""
                }
            } catch {
                await MainActor.run {
                    self.isImporting = false
                    self.importError = "导入失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - 导入模式行组件

struct ImportModeRow: View {
    let mode: ImportMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(mode.description)
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

// MARK: - 手动输入视图

struct ManualInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onImport: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("请输入要导入的单词，每行一个单词")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Button("导入") {
                    onImport(text)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationTitle("手动输入单词")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 扩展

extension ImportMode {
    var displayName: String {
        switch self {
        case .merge:
            return "合并模式"
        case .overwrite:
            return "覆盖模式"
        case .skip:
            return "跳过模式"
        }
    }
    
    var description: String {
        switch self {
        case .merge:
            return "跳过重复单词，只导入新单词"
        case .overwrite:
            return "覆盖已存在的单词记录"
        case .skip:
            return "遇到重复单词时跳过导入"
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
    
    DictionarySpecificImportView()
        .modelContainer(container)
        .environmentObject(mockDictionaryService)
        .environment(mockErrorHandler)
}