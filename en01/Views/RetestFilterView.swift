//
//  RetestFilterView.swift
//  en01
//
//  Created by AI Assistant on 2025/01/28.
//

import SwiftUI
import SwiftData

struct RetestFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dictionaryService: DictionaryService
    @Environment(UnifiedErrorHandler.self) private var errorHandler
    @EnvironmentObject private var appCoordinator: AppCoordinator
    
    let retestModeService: RetestModeService
    let onStartRetest: (RetestFilterConfiguration) -> Void
    
    // 筛选状态
    @State private var selectedDictionaries: Set<UUID> = []
    @State private var selectedMasteryLevels: Set<MasteryLevel> = []
    @State private var selectedWordCount: Int = 20
    @State private var isRandomOrder: Bool = true
    
    // 数据状态
    @State private var availableDictionaries: [DictionaryInfo] = []
    @State private var masteryStats: [MasteryLevel: Int] = [:]
    @State private var isLoading = false
    
    // 预设选项
    private let wordCountOptions = [10, 20, 30, 50, 100]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 词典选择区域
                    dictionarySelectionSection
                    
                    // 掌握程度筛选区域
                    masteryLevelSection
                    
                    // 测试设置区域
                    testSettingsSection
                    
                    // 预览统计区域
                    previewStatsSection
                    
                    // 开始重测按钮
                    startRetestButton
                }
                .padding()
            }
            .navigationTitle("重测筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadData()
            }
        }
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
                            isSelected: selectedDictionaries.contains(dictionary.id)
                        ) {
                            toggleDictionarySelection(dictionary.id)
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
    
    // MARK: - 掌握程度筛选区域
    
    private var masteryLevelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.orange)
                Text("掌握程度")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(MasteryLevel.allCases, id: \.self) { mastery in
                    MasteryFilterButton(
                        mastery: mastery,
                        count: masteryStats[mastery] ?? 0,
                        isSelected: selectedMasteryLevels.contains(mastery)
                    ) {
                        toggleMasterySelection(mastery)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 测试设置区域
    
    private var testSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.green)
                Text("测试设置")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // 单词数量选择
            VStack(alignment: .leading, spacing: 8) {
                Text("测试单词数量")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(wordCountOptions, id: \.self) { count in
                            Button("\(count)") {
                                selectedWordCount = count
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedWordCount == count ? Color.blue : Color(.systemGray5))
                            .foregroundColor(selectedWordCount == count ? .white : .primary)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 随机顺序开关
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("随机顺序")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("打乱单词出现顺序")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isRandomOrder)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 预览统计区域
    
    private var previewStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.purple)
                Text("预览统计")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在计算...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                let totalWords = calculateTotalAvailableWords()
                let actualTestWords = min(selectedWordCount, totalWords)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("可用单词总数")
                            .font(.subheadline)
                        Spacer()
                        Text("\(totalWords)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("实际测试数量")
                            .font(.subheadline)
                        Spacer()
                        Text("\(actualTestWords)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(actualTestWords > 0 ? .blue : .red)
                    }
                    
                    if totalWords < selectedWordCount {
                        Text("可用单词不足，将测试全部 \(totalWords) 个单词")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 开始重测按钮
    
    private var startRetestButton: some View {
        Button {
            startRetest()
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                Text("开始重测")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canStartRetest ? Color.blue : Color(.systemGray4))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canStartRetest)
    }
    
    // MARK: - 计算属性
    
    private var canStartRetest: Bool {
        !selectedDictionaries.isEmpty && 
        !selectedMasteryLevels.isEmpty && 
        calculateTotalAvailableWords() > 0
    }
    
    // MARK: - 方法
    
    private func loadData() {
        isLoading = true
        
        Task {
            do {
                // 加载可用词典（可能抛出错误）
                let dictionaries = try await retestModeService.getAvailableDictionaries()
                
                // 加载掌握程度统计（不抛出错误）
                let stats = await retestModeService.getMasteryStats()
                
                await MainActor.run {
                    self.availableDictionaries = dictionaries
                    self.masteryStats = stats
                    
                    // 默认选择所有词典和掌握程度
                    self.selectedDictionaries = Set(dictionaries.map { $0.id })
                    self.selectedMasteryLevels = Set(MasteryLevel.allCases)
                    
                    self.isLoading = false
                }
            } catch {
                print("❌ [RetestFilterView] 加载数据失败: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("错误详情: \(nsError.userInfo)")
                }
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func toggleDictionarySelection(_ dictionaryId: UUID) {
        if selectedDictionaries.contains(dictionaryId) {
            selectedDictionaries.remove(dictionaryId)
        } else {
            selectedDictionaries.insert(dictionaryId)
        }
    }
    
    private func toggleMasterySelection(_ mastery: MasteryLevel) {
        if selectedMasteryLevels.contains(mastery) {
            selectedMasteryLevels.remove(mastery)
        } else {
            selectedMasteryLevels.insert(mastery)
        }
    }
    
    private func calculateTotalAvailableWords() -> Int {
        var total = 0
        for mastery in selectedMasteryLevels {
            total += masteryStats[mastery] ?? 0
        }
        return total
    }
    
    private func startRetest() {
        let configuration = RetestFilterConfiguration(
            selectedDictionaries: selectedDictionaries.map { $0.uuidString },
            selectedMasteryLevels: Array(selectedMasteryLevels),
            wordCount: selectedWordCount,
            isRandomOrder: isRandomOrder
        )
        
        onStartRetest(configuration)
        dismiss()
    }
}

// MARK: - 支持组件

struct DictionarySelectionRow: View {
    let dictionary: DictionaryInfo
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dictionary.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(dictionary.totalWords) 词汇")
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

struct MasteryFilterButton: View {
    let mastery: MasteryLevel
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : mastery.color)
                
                Text(mastery.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mastery.color : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(mastery.color, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 重测配置模型
/// 重测筛选配置
struct RetestFilterConfiguration {
    let selectedDictionaries: [String]
    let selectedMasteryLevels: [MasteryLevel]
    let wordCount: Int
    let isRandomOrder: Bool
}

// MARK: - 预览

#Preview {
    let container = try! ModelContainer(for: UserWord.self)
    let mockContext = ModelContext(container)
    let mockCacheManager = MockCacheManager()
    let mockErrorHandler = UnifiedErrorHandler()
    let mockAppCoordinator = AppCoordinator(serviceContainer: ServiceContainer.shared)
    
    let mockDictionaryService = DictionaryService(
        modelContext: mockContext,
        cacheManager: mockCacheManager,
        errorHandler: mockErrorHandler
    )
    
    let mockTestDataService = TestDataService(
        modelContext: mockContext,
        cacheManager: mockCacheManager,
        errorHandler: mockErrorHandler
    )
    let mockRetestService = RetestModeService(
        modelContext: mockContext,
        testDataService: mockTestDataService,
        dictionaryService: mockDictionaryService
    )
    
    RetestFilterView(
        retestModeService: mockRetestService,
        onStartRetest: { _ in }
    )
    .modelContainer(container)
    .environmentObject(mockDictionaryService)
    .environmentObject(mockAppCoordinator)
    .environment(mockErrorHandler)
}