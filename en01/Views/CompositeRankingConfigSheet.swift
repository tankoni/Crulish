//
//  CompositeRankingConfigSheet.swift
//  en01
//
//  Created by AI Assistant on 2024
//

import SwiftUI

struct CompositeRankingConfigSheet: View {
    @Binding var config: CompositeRankingConfig
    let availableDictionaries: [DictionaryInfo]
    let availableTests: [VocabularyTest]
    let onConfigUpdate: (CompositeRankingConfig) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var workingConfig: CompositeRankingConfig
    @State private var showingAddCriteria = false
    @State private var newCriteriaOption: RankingSortOption = .matchScore
    @State private var newCriteriaWeight: Double = 1.0
    @State private var newCriteriaDirection: SortDirection = .descending
    @State private var selectedDictionaryId: String = ""
    @State private var selectedTestId: String = ""
    
    init(config: Binding<CompositeRankingConfig>,
         availableDictionaries: [DictionaryInfo],
         availableTests: [VocabularyTest],
         onConfigUpdate: @escaping (CompositeRankingConfig) -> Void) {
        self._config = config
        self.availableDictionaries = availableDictionaries
        self.availableTests = availableTests
        self.onConfigUpdate = onConfigUpdate
        self._workingConfig = State(initialValue: config.wrappedValue)
        self._selectedDictionaryId = State(initialValue: config.wrappedValue.selectedDictionaryId?.uuidString ?? "")
        self._selectedTestId = State(initialValue: config.wrappedValue.selectedTestId?.uuidString ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 排序条件配置
                sortCriteriaSection
                
                // 词典集成配置
                dictionaryIntegrationSection
                
                // 测试结果集成配置
                testResultsIntegrationSection
                
                // 高级设置
                advancedSettingsSection
            }
            .navigationTitle("排序配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveConfiguration()
                    }
                    .disabled(!isConfigurationValid)
                }
            }
            .sheet(isPresented: $showingAddCriteria) {
                AddCriteriaSheet(
                    selectedOption: $newCriteriaOption,
                    weight: $newCriteriaWeight,
                    direction: $newCriteriaDirection,
                    existingOptions: workingConfig.criteria.map { $0.option },
                    onAdd: { addNewCriteria() }
                )
            }
        }
    }
    
    // MARK: - Sort Criteria Section
    
    @ViewBuilder
    private var sortCriteriaSection: some View {
        Section {
            if workingConfig.criteria.isEmpty {
                Text("暂无排序条件")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(workingConfig.criteria.enumerated()), id: \.offset) { index, criteria in
                    CriteriaRow(
                        criteria: criteria,
                        onWeightChange: { newWeight in
                            workingConfig.criteria[index] = SortCriteria(
                                option: criteria.option,
                                direction: criteria.direction,
                                weight: newWeight,
                                isEnabled: criteria.isEnabled
                            )
                        },
                        onDirectionChange: { newDirection in
                            workingConfig.criteria[index] = SortCriteria(
                                option: criteria.option,
                                direction: CompositeRankingSortDirection(rawValue: newDirection.rawValue) ?? .descending,
                                weight: criteria.weight,
                                isEnabled: criteria.isEnabled
                            )
                        },
                        onRemove: {
                            workingConfig.criteria.remove(at: index)
                        }
                    )
                }
                .onDelete { indexSet in
                    workingConfig.criteria.remove(atOffsets: indexSet)
                }
            }
            
            Button(action: { showingAddCriteria = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("添加排序条件")
                        .foregroundColor(.blue)
                }
            }
        } header: {
            Text("排序条件")
        } footer: {
            if !workingConfig.criteria.isEmpty {
                Text("权重决定各条件的重要性，方向决定升序或降序排列")
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Dictionary Integration Section
    
    @ViewBuilder
    private var dictionaryIntegrationSection: some View {
        Section {
            Toggle("启用词典集成", isOn: $workingConfig.useDictionaryIntegration)
            
            if workingConfig.useDictionaryIntegration {
                if availableDictionaries.isEmpty {
                    Text("暂无可用词典")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Picker("选择词典", selection: $selectedDictionaryId) {
                        Text("请选择词典").tag("")
                        ForEach(availableDictionaries, id: \.id) { dictionary in
                            VStack(alignment: .leading) {
                                Text(dictionary.displayName)
                                Text("\(dictionary.totalWords) 词")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(dictionary.id.uuidString)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedDictionaryId) { _, newValue in
                        workingConfig.selectedDictionaryId = newValue.isEmpty ? nil : UUID(uuidString: newValue)
                    }
                }
            }
        } header: {
            Text("词典集成")
        } footer: {
            if workingConfig.useDictionaryIntegration {
                Text("词典集成将根据文章与所选词典的词汇重合度调整排序")
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Test Results Integration Section
    
    @ViewBuilder
    private var testResultsIntegrationSection: some View {
        Section {
            Toggle("启用测试结果集成", isOn: $workingConfig.useTestResults)
            
            if workingConfig.useTestResults {
                if availableTests.isEmpty {
                    Text("暂无可用测试记录")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Picker("选择测试记录", selection: $selectedTestId) {
                        Text("请选择测试记录").tag("")
                        ForEach(availableTests, id: \.id) { test in
                            VStack(alignment: .leading) {
                                Text(test.dictionaryName)
                                HStack {
                                    Text("准确率: \(String(format: "%.1f", test.accuracyPercentage))%")
                                    Text("•")
                                    Text("词汇量: \(test.estimatedVocabularySize)")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .tag(test.id.uuidString)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedTestId) { _, newValue in
                        workingConfig.selectedTestId = newValue.isEmpty ? nil : UUID(uuidString: newValue)
                    }
                }
            }
        } header: {
            Text("测试结果集成")
        } footer: {
            if workingConfig.useTestResults {
                Text("测试结果集成将根据词汇掌握情况调整文章推荐优先级")
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Advanced Settings Section
    
    @ViewBuilder
    private var advancedSettingsSection: some View {
        Section {
            Toggle("启用缓存", isOn: .constant(true))
        } header: {
            Text("高级设置")
        }
    }
    
    // MARK: - Helper Methods
    
    private var isConfigurationValid: Bool {
        !workingConfig.criteria.isEmpty
    }
    
    private func addNewCriteria() {
        let newCriteria = SortCriteria(
            option: newCriteriaOption,
            direction: CompositeRankingSortDirection(rawValue: newCriteriaDirection.rawValue) ?? .descending,
            weight: newCriteriaWeight
        )
        workingConfig.criteria.append(newCriteria)
        showingAddCriteria = false
        
        // 重置新条件的默认值
        newCriteriaWeight = 1.0
        newCriteriaDirection = .descending
    }
    
    private func saveConfiguration() {
        config = workingConfig
        onConfigUpdate(workingConfig)
        dismiss()
    }
}

// MARK: - Supporting Views

struct CriteriaRow: View {
    let criteria: SortCriteria
    let onWeightChange: (Double) -> Void
    let onDirectionChange: (SortDirection) -> Void
    let onRemove: () -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(criteria.option.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("权重: \(String(format: "%.1f", criteria.weight)) • \(criteria.direction.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingDetails.toggle() }) {
                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
                
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            if showingDetails {
                VStack(spacing: 12) {
                    // 权重调整
                    VStack(alignment: .leading, spacing: 4) {
                        Text("权重: \(String(format: "%.1f", criteria.weight))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(
                            value: Binding(
                                get: { criteria.weight },
                                set: onWeightChange
                            ),
                            in: 0.1...3.0,
                            step: 0.1
                        )
                    }
                    
                    // 排序方向
                    Picker("排序方向", selection: Binding(
                        get: { 
                            SortDirection(rawValue: criteria.direction.rawValue) ?? .descending
                        },
                        set: onDirectionChange
                    )) {
                        ForEach([SortDirection.ascending, .descending], id: \.self) { direction in
                            Text(direction.displayName).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddCriteriaSheet: View {
    @Binding var selectedOption: RankingSortOption
    @Binding var weight: Double
    @Binding var direction: SortDirection
    let existingOptions: [RankingSortOption]
    let onAdd: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("排序条件", selection: $selectedOption) {
                        ForEach(availableOptions, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.wheel)
                } header: {
                    Text("选择排序条件")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("权重: \(String(format: "%.1f", weight))")
                            .font(.subheadline)
                        
                        Slider(value: $weight, in: 0.1...3.0, step: 0.1)
                        
                        Text("权重越高，该条件对最终排序的影响越大")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("权重设置")
                }
                
                Section {
                    Picker("排序方向", selection: $direction) {
                        ForEach([SortDirection.descending, .ascending], id: \.self) { dir in
                            Text(dir.displayName).tag(dir)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("排序方向")
                } footer: {
                    Text(directionDescription)
                        .font(.caption)
                }
            }
            .navigationTitle("添加排序条件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        onAdd()
                        dismiss()
                    }
                    .disabled(existingOptions.contains(selectedOption))
                }
            }
        }
    }
    
    private var availableOptions: [RankingSortOption] {
        RankingSortOption.allCases.filter { !existingOptions.contains($0) }
    }
    
    private var directionDescription: String {
        switch selectedOption {
        case .matchScore, .recommendation:
            return direction == .descending ? "高分优先" : "低分优先"
        case .difficulty:
            return direction == .descending ? "难度高优先" : "难度低优先"
        case .unknownWords:
            return direction == .descending ? "生词多优先" : "生词少优先"
        case .articleLength:
            return direction == .descending ? "长文章优先" : "短文章优先"
        case .keywordReading, .keywordTranslation, .keywordWriting, .keywordKnowledge:
            return direction == .descending ? "匹配度高优先" : "匹配度低优先"
        }
    }
}

struct PresetSelectionSheet: View {
    @Binding var selectedPreset: SortPreset
    let onPresetSelected: (SortPreset) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(SortPreset.allCases, id: \.self) { preset in
                    PresetRow(
                        preset: preset,
                        isSelected: selectedPreset == preset,
                        onSelect: {
                            selectedPreset = preset
                            onPresetSelected(preset)
                            dismiss()
                        }
                    )
                }
            }
            .navigationTitle("选择预设")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PresetRow: View {
    let preset: SortPreset
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(preset.presetDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Text("条件数: \(preset.config.criteria.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Extensions

extension SortDirection {
    var displayName: String {
        switch self {
        case .ascending: return "升序"
        case .descending: return "降序"
        }
    }
}

extension SortPreset {
    var presetDescription: String {
        switch self {
        case .balanced: return "平衡各项指标，适合大多数学习场景"
        case .vocabularyFocused: return "重点关注词汇掌握情况和生词数量"
        case .difficultyProgressive: return "按难度递进，适合系统性学习"
        case .lengthOptimized: return "优先推荐适中长度的文章"
        case .testBased: return "基于测试结果优化，提高学习效率"
        case .custom: return "自定义排序条件和权重"
        }
    }
}