//
//  RetestModeView.swift
//  en01
//
//  Created by Assistant on 2025-01-23.
//

import SwiftUI
import SwiftData
import Combine

/// 重测模式主界面
struct RetestModeView: View {
    @StateObject private var viewModel: RetestModeViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Animation States
    @State private var isContentVisible = false
    @State private var loadingRotation: Double = 0
    @State private var isDataLoaded = false
    
    init(
        retestModeService: RetestModeService,
        dictionaryService: DictionaryServiceProtocol,
        errorHandler: ErrorHandlerProtocol,
        appCoordinator: AppCoordinator
    ) {
        self._viewModel = StateObject(wrappedValue: RetestModeViewModel(
            retestModeService: retestModeService,
            dictionaryService: dictionaryService,
            errorHandler: errorHandler,
            appCoordinator: appCoordinator
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isRetestActive {
                    retestActiveView
                } else {
                    retestConfigurationView
                }
            }
            .navigationTitle("重测模式")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            if !isDataLoaded {
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    isContentVisible = true
                }
                viewModel.loadAvailableDictionaries()
                isDataLoaded = true
            }
        }
    }
    
    // MARK: - 重测配置界面
    
    private var retestConfigurationView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 头部说明
                headerSection
                
                // 词典选择区域
                dictionarySelectionSection
                
                // 掌握程度筛选区域
                if !viewModel.selectedDictionaries.isEmpty {
                    masteryLevelSelectionSection
                }
                
                // 测试模式选择
                if !viewModel.selectedDictionaries.isEmpty && !viewModel.selectedMasteryLevels.isEmpty {
                    testModeSelectionSection
                }
                
                // 结果覆盖模式选择
                if !viewModel.selectedDictionaries.isEmpty && !viewModel.selectedMasteryLevels.isEmpty {
                    resultOverwriteModeSection
                }
                
                // 开始重测按钮
                if viewModel.canStartRetest {
                    startRetestButton
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("重测模式")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("选择词典和掌握程度，重新测试特定范围的单词\n支持多词典组合和结果覆盖选项")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
    }
    
    private var dictionarySelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("选择词典")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(viewModel.isAllDictionariesSelected ? "取消全选" : "全选") {
                    viewModel.toggleAllDictionaries()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if viewModel.isLoading {
                loadingView
            } else if viewModel.availableDictionaries.isEmpty {
                emptyDictionariesView
            } else {
                dictionaryListView
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(loadingRotation))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: loadingRotation)
            }
            
            VStack(spacing: 8) {
                Text("加载词典中...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("正在准备重测模式")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .onAppear {
            withAnimation {
                loadingRotation = 360
            }
        }
    }
    
    private var emptyDictionariesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("暂无可用词典")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button("重新加载") {
                viewModel.loadAvailableDictionaries()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var dictionaryListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.availableDictionaries) { dictionary in
                RetestDictionarySelectionCard(
                    dictionary: dictionary,
                    isSelected: viewModel.selectedDictionaries.contains(dictionary.id),
                    testedWordsCount: viewModel.getTestedWordsCount(for: dictionary.id),
                    onToggle: {
                        viewModel.toggleDictionarySelection(dictionary.id)
                    }
                )
            }
        }
    }
    
    private var masteryLevelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("选择掌握程度")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(viewModel.isAllMasteryLevelsSelected ? "取消全选" : "全选") {
                    viewModel.toggleAllMasteryLevels()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(MasteryLevel.allCases, id: \.self) { level in
                    RetestMasteryLevelCard(
                        masteryLevel: level,
                        isSelected: viewModel.selectedMasteryLevels.contains(level),
                        wordsCount: viewModel.getWordsCount(for: level),
                        onToggle: {
                            viewModel.toggleMasteryLevelSelection(level)
                        }
                    )
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var testModeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("测试模式")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                let testModes = [VocabularyTestMode.englishToChinese, VocabularyTestMode.chineseToEnglish]
                ForEach(testModes, id: \.self) { mode in
                    RetestModeCard(
                        mode: mode,
                        isSelected: viewModel.selectedTestMode == mode,
                        onSelect: {
                            viewModel.selectTestMode(mode)
                        }
                    )
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var resultOverwriteModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("结果处理方式")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(ResultOverwriteMode.allCases, id: \.self) { mode in
                    ResultOverwriteModeCard(
                        mode: mode,
                        isSelected: viewModel.selectedOverwriteMode == mode,
                        onSelect: {
                            viewModel.selectOverwriteMode(mode)
                        }
                    )
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var startRetestButton: some View {
        Button(action: {
            viewModel.startRetest()
        }) {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.title3)
                
                Text("开始重测")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 重测进行中界面
    
    private var retestActiveView: some View {
        VStack {
            Text("重测进行中...")
                .font(.title)
                .fontWeight(.bold)
            
            Text("正在使用现有测试界面进行重测")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 重测词典选择卡片

struct RetestDictionarySelectionCard: View {
    let dictionary: DictionaryInfo
    let isSelected: Bool
    let testedWordsCount: Int
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 选择指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .orange : .secondary)
                
                // 词典信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(dictionary.displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("总词汇: \(dictionary.totalWords) | 已测试: \(testedWordsCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if testedWordsCount > 0 {
                        HStack {
                            Label("\(testedWordsCount) 个已测试", systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Spacer()
                            
                            if isSelected {
                                Text("已选择")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    } else {
                        Text("暂无测试记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(testedWordsCount == 0)
        .opacity(testedWordsCount == 0 ? 0.5 : 1.0)
    }
}

// MARK: - 重测掌握程度卡片

struct RetestMasteryLevelCard: View {
    let masteryLevel: MasteryLevel
    let isSelected: Bool
    let wordsCount: Int
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                // 掌握程度图标和颜色
                Circle()
                    .fill(masteryLevel.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: isSelected ? "checkmark" : masteryLevel.iconName)
                            .font(.title3)
                            .foregroundColor(.white)
                    )
                
                Text(masteryLevel.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(wordsCount) 个单词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? masteryLevel.color.opacity(0.1) : Color(UIColor.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? masteryLevel.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(wordsCount == 0)
        .opacity(wordsCount == 0 ? 0.5 : 1.0)
    }
}

// MARK: - 重测模式卡片

struct RetestModeCard: View {
    let mode: VocabularyTestMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .orange : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 结果覆盖模式卡片

struct ResultOverwriteModeCard: View {
    let mode: ResultOverwriteMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .orange : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let mockModelContainer = try! ModelContainer(for: VocabularyTest.self, TestedWord.self)
    let mockModelContext = ModelContext(mockModelContainer)
    let mockDictionaryService = MockDictionaryService()
    let mockAppCoordinator = AppCoordinator(serviceContainer: ServiceContainer.shared)
    let mockRetestService = RetestModeService(
        modelContext: mockModelContext,
        testDataService: MockTestDataService(),
        dictionaryService: mockDictionaryService
    )
    
    RetestModeView(
        retestModeService: mockRetestService,
        dictionaryService: mockDictionaryService,
        errorHandler: MockErrorHandler(),
        appCoordinator: mockAppCoordinator
    )
}