//
//  KaoyanDictionaryStatusView.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import SwiftUI
import SwiftData

struct KaoyanDictionaryStatusView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dictionaryService: DictionaryService
    
    @State private var wordCount: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastUpdateTime: Date?
    @State private var sampleWords: [KaoyanWord] = []
    @State private var isReimporting = false
    
    var body: some View {
        NavigationView {
            List {
                statusSection
                statisticsSection
                sampleWordsSection
                actionsSection
            }
            .navigationTitle("考研词典状态")
            .refreshable {
                await loadDictionaryStatus()
            }
        }
        .onAppear {
            Task {
                await loadDictionaryStatus()
            }
        }
    }
    
    // MARK: - 状态部分
    
    private var statusSection: some View {
        Section("词典状态") {
            HStack {
                Image(systemName: wordCount > 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(wordCount > 0 ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(wordCount > 0 ? "词典已导入" : "词典未导入")
                        .font(.headline)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if wordCount > 0 {
                        Text("词典数据完整")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 统计信息部分
    
    private var statisticsSection: some View {
        Section("统计信息") {
            HStack {
                Label("总词汇数", systemImage: "textformat.123")
                Spacer()
                Text("\(wordCount)")
                    .foregroundColor(.secondary)
            }
            
            if let lastUpdateTime = lastUpdateTime {
                HStack {
                    Label("最后更新", systemImage: "clock")
                    Spacer()
                    Text(lastUpdateTime, style: .relative)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label("数据文件", systemImage: "doc.text")
                Spacer()
                Text("4个JSON文件")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 示例单词部分
    
    private var sampleWordsSection: some View {
        Section("示例单词") {
            if sampleWords.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(sampleWords, id: \.wordId) { word in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(word.headWord)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("排名: \(word.wordRank)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let usPhone = word.usPhone, !usPhone.isEmpty {
                            Text("/\(usPhone)/")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        if let firstTranslation = word.translations.first {
                            Text("\(firstTranslation.pos) \(firstTranslation.tranCn)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    // MARK: - 操作部分
    
    private var actionsSection: some View {
        Section("操作") {
            Button {
                Task {
                    await reimportDictionary()
                }
            } label: {
                HStack {
                    if isReimporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    
                    Text(isReimporting ? "重新导入中..." : "重新导入词典")
                }
            }
            .disabled(isReimporting)
            
            Button {
                Task {
                    await testDictionaryLookup()
                }
            } label: {
                Label("测试词典查询", systemImage: "magnifyingglass")
            }
            .disabled(wordCount == 0)
        }
    }
    
    // MARK: - 私有方法
    
    private func loadDictionaryStatus() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 获取词汇总数
            let descriptor = FetchDescriptor<KaoyanWord>()
            let count = try modelContext.fetchCount(descriptor)
            
            // 获取示例单词（前5个）
            var sampleDescriptor = FetchDescriptor<KaoyanWord>(
                sortBy: [SortDescriptor(\.wordRank)]
            )
            sampleDescriptor.fetchLimit = 5
            let samples = try modelContext.fetch(sampleDescriptor)
            
            await MainActor.run {
                self.wordCount = count
                self.sampleWords = samples
                self.lastUpdateTime = Date() // 简化处理，实际应该从数据库获取
                self.isLoading = false
            }
            
            print("[INFO][KaoyanDictionaryStatusView] 词典状态检查完成: \(count) 个单词")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "加载失败: \(error.localizedDescription)"
                self.isLoading = false
            }
            
            print("[ERROR][KaoyanDictionaryStatusView] 加载词典状态失败: \(error)")
        }
    }
    
    private func reimportDictionary() async {
        await MainActor.run {
            isReimporting = true
            errorMessage = nil
        }
        
        do {
            // 清空现有数据
            try modelContext.delete(model: KaoyanWord.self)
            try modelContext.save()
            
            // 重新导入
            await dictionaryService.initializeKaoyanDictionary()
            
            // 重新加载状态
            await loadDictionaryStatus()
            
            await MainActor.run {
                isReimporting = false
            }
            
            print("[INFO][KaoyanDictionaryStatusView] 词典重新导入完成")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "重新导入失败: \(error.localizedDescription)"
                self.isReimporting = false
            }
            
            print("[ERROR][KaoyanDictionaryStatusView] 重新导入失败: \(error)")
        }
    }
    
    private func testDictionaryLookup() async {
        guard !sampleWords.isEmpty else { return }
        
        let testWord = sampleWords.first!.headWord
        
        if let result = dictionaryService.lookupKaoyanWord(testWord) {
            print("[INFO][KaoyanDictionaryStatusView] 测试查询成功: \(testWord) -> \(result.headWord)")
            
            await MainActor.run {
                // 可以显示一个成功的提示
            }
        } else {
            print("[ERROR][KaoyanDictionaryStatusView] 测试查询失败: \(testWord)")
            
            await MainActor.run {
                errorMessage = "词典查询测试失败"
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: KaoyanWord.self)
    let mockCacheManager = MockCacheManager()
    let mockErrorHandler = MockErrorHandler()
    let dictionaryService = DictionaryService(
        modelContext: container.mainContext,
        cacheManager: mockCacheManager,
        errorHandler: mockErrorHandler
    )
    
    return KaoyanDictionaryStatusView()
        .modelContainer(container)
        .environmentObject(dictionaryService)
}