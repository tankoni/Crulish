//
//  VocabularyTestView.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import SwiftData
import Combine
import UIKit

/// 词汇量测试主界面
struct VocabularyTestView: View {
    @StateObject private var viewModel: VocabularyTestViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appCoordinator: AppCoordinator
    
    // MARK: - Animation States
    @State private var isContentVisible = false
    @State private var selectedCardScale: CGFloat = 1.0
    @State private var loadingRotation: Double = 0
    @State private var progressBarAnimation: Bool = false
    
    // MARK: - Retest Mode Support
    let isRetestMode: Bool
    let retestConfig: RetestConfig?
    
    init(
        vocabularyTestService: VocabularyTestServiceProtocol,
        dictionaryService: DictionaryServiceProtocol,
        errorHandler: ErrorHandlerProtocol,
        testResultExportService: TestResultExportService,
        appCoordinator: AppCoordinator,
        isRetestMode: Bool = false,
        retestConfig: RetestConfig? = nil
    ) {
        self.isRetestMode = isRetestMode
        self.retestConfig = retestConfig
        self._viewModel = StateObject(wrappedValue: VocabularyTestViewModel(
            vocabularyTestService: vocabularyTestService,
            dictionaryService: dictionaryService,
            errorHandler: errorHandler,
            testResultExportService: testResultExportService,
            appCoordinator: appCoordinator,
            isRetestMode: isRetestMode,
            retestConfig: retestConfig
        ))
    }
    
    // MARK: - Lifecycle
    private func setupExportService() {
        // 从环境中获取导出服务并注入到ViewModel
        let exportService = appCoordinator.getTestResultExportService()
        viewModel.setExportService(exportService)
    }
    
    @State private var isDataLoaded = false // 防止重复加载数据
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isRetestMode && !viewModel.isTestActive {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("正在准备重测...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isTestActive {
                    testActiveView
                } else {
                    testPreparationView
                }
            }
            .navigationTitle(isRetestMode ? "重测模式" : "词汇量测试")
            .navigationBarTitleDisplayMode(.large)
        }
            .alert("错误", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { newValue in if !newValue { viewModel.clearError() } })) {
                Button("确定") {
                    viewModel.clearError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        .alert("继续测试", isPresented: Binding(
            get: { viewModel.testStateManager.showTestContinuationAlert },
            set: { viewModel.testStateManager.showTestContinuationAlert = $0 }
        )) {
            Button("删除记录并重新开始", role: .destructive) {
                viewModel.startNewTest()
            }
            if viewModel.incompleteTest != nil {
                Button("继续上次测试") {
                    viewModel.continueIncompleteTest()
                }
            }
            Button("取消", role: .cancel) {
                viewModel.testStateManager.showTestContinuationAlert = false
            }
        } message: {
            if let progress = viewModel.testStateManager.incompleteTestProgress {
                Text("检测到词典 \(progress.dictionaryName) 有未完成测试：进度 \(progress.progressText)。继续上次测试将从第 \(progress.currentIndex + 1) 个单词继续。重新开始将删除现有记录并创建新测试。")
            } else {
                Text("检测到未完成的测试。继续将恢复当前进度；重新开始将删除现有记录并创建新测试。")
            }
        }
        .alert("分组测试完成", isPresented: Binding(
            get: { viewModel.testStateManager.showGroupCompletionAlert },
            set: { viewModel.testStateManager.showGroupCompletionAlert = $0 }
        )) {
            Button("继续下一组") {
                viewModel.moveToNextWord()
            }
            Button("完成测试") {
                viewModel.finishTest()
            }
            Button("取消", role: .cancel) {
                viewModel.testStateManager.showGroupCompletionAlert = false
            }
        } message: {
            Text("当前分组测试已完成！您可以继续测试下一组，或者结束当前测试查看结果。")
        }
        .onAppear {
            // 防止重复加载数据
            if !isDataLoaded {
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    isContentVisible = true
                }
                setupExportService()
                viewModel.loadTestHistory()
                isDataLoaded = true
            }
            if isRetestMode && !viewModel.isTestActive {
                viewModel.selectTestMode(.chineseToEnglish)
                Task {
                    await viewModel.configurationManager.loadAvailableDictionaries()
                    let dictionaries = viewModel.availableDictionaries
                    var targetDictionary: DictionaryInfo?
                    if let config = retestConfig, let selected = config.selectedDictionaries {
                        targetDictionary = dictionaries.first { selected.contains($0.id.uuidString) }
                    }
                    if targetDictionary == nil {
                        targetDictionary = dictionaries.first { $0.isVirtual && $0.name == "my_learning_records" } ?? dictionaries.first
                    }
                    if let dict = targetDictionary {
                        await viewModel.configurationManager.selectDictionary(dict)
                        viewModel.setTestSize(.all)
                        viewModel.startTest()
                    }
                }
            }
        }
        .onDisappear {
            if viewModel.isTestActive {
                Task { @MainActor in
                    viewModel.cancelAllTasks()
                }
            }
        }
    }
    
    // MARK: - Test Preparation View
    private var testPreparationView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 标题和描述
                headerSection
                
                // 词典选择
                dictionarySelectionSection
                
                // 测试历史
                if viewModel.hasTestHistory {
                    testHistorySection
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("词汇量测试")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("通过测试了解您的词汇掌握情况，\n帮助制定个性化学习计划")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
    }
    
    private var dictionarySelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择词典")
                .font(.headline)
                .fontWeight(.semibold)
            
            if viewModel.isLoading {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(loadingRotation))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: loadingRotation)
                    }
                    
                    VStack(spacing: 8) {
                        Text("加载词典中...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("正在准备词汇量测试")
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
            } else if viewModel.availableDictionaries.isEmpty {
                emptyDictionariesView
            } else {
                dictionaryListView
            }
            
            // 测试模式选择
            if viewModel.selectedDictionary != nil {
                testModeSelectionView
                
                groupSelectionView
                
                testSizeSelectionView
                    
                    // 分组进度显示
                if viewModel.testSizeMode == .grouped && viewModel.totalGroups > 1 {
                    groupProgressView
                }
            }
            
            // 开始测试按钮
            if viewModel.canStartTest {
                startTestButton
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
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
                TestDictionarySelectionCard(
                    dictionary: dictionary,
                    isSelected: viewModel.selectedDictionary?.id == dictionary.id,
                    onSelect: {
                        viewModel.selectDictionary(dictionary)
                    }
                )
            }
        }
    }
    
    private var testModeSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("测试模式")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                let testModes = [VocabularyTestMode.englishToChinese, VocabularyTestMode.chineseToEnglish]
                ForEach(testModes, id: \.self) { mode in
                    TestModeCard(
                        mode: mode,
                        isSelected: viewModel.selectedTestMode == mode,
                        onSelect: {
                            viewModel.selectTestMode(mode)
                        }
                    )
                }
            }
        }
        .padding(.top, 8)
    }
    
    private var groupSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("测试分组")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    viewModel.toggleAllGroups()
                }) {
                    Text(viewModel.isAllGroupsSelected ? "取消全选" : "全选")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if viewModel.availableGroups.isEmpty {
                Text("该词典暂无分组信息")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(viewModel.availableGroups, id: \.self) { group in
                        GroupSelectionCard(
                            groupName: group,
                            isSelected: viewModel.selectedGroups.contains(group),
                            onToggle: {
                                viewModel.toggleGroupSelection(group)
                            }
                        )
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    private var testSizeSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("测试数量")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                // 全部测试选项
                TestSizeCard(
                    title: "全部测试",
                    subtitle: "一次性测试选择词典的所有单词",
                    count: viewModel.selectedDictionary?.totalWords ?? 0,
                    isSelected: viewModel.testSizeMode == .all,
                    onSelect: {
                        viewModel.selectTestSizeMode(.all)
                    }
                )
                
                // 分组测试选项
                TestSizeCard(
                    title: "分组测试",
                    subtitle: "将词典分为多组，每组测试指定数量的单词",
                    count: viewModel.configurationManager.estimatedWordsCount,
                    isSelected: viewModel.testSizeMode == .grouped,
                    onSelect: {
                        viewModel.selectTestSizeMode(.grouped)
                    }
                )
                
                // 分组大小选择
                if viewModel.testSizeMode == .grouped {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("每组单词数")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach([50, 100, 200, 300], id: \.self) { size in
                                Button(action: {
                                    viewModel.selectTestSize(size)
                                }) {
                                    Text("\(size) 个")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(viewModel.configurationManager.testSize.wordCount == size ? .white : .primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(viewModel.configurationManager.testSize.wordCount == size ? Color.blue : Color(UIColor.systemGray6))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        if viewModel.totalGroups > 0 {
                            Text("总共 \(viewModel.totalGroups) 组")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
         .padding(.top, 8)
     }
    
    // MARK: - 分组进度视图
    private var groupProgressView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("测试进度")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("当前分组:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.currentGroupIndex + 1) / \(viewModel.totalGroups)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // 进度条
                ProgressView(value: Double(viewModel.currentGroupIndex + 1), total: Double(viewModel.totalGroups))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 2)
                
                HStack {
                    Text("每组单词数:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.configurationManager.estimatedWordsCount) 个")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                )
        )
    }
    
    private var startTestButton: some View {
        Button(action: {
            viewModel.startTest()
        }) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                Text("开始测试")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(!viewModel.canStartTest)
        .padding(.top, 8)
    }
    
    private var testHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("测试历史")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // 导出按钮
                if viewModel.hasExportableData(for: viewModel.selectedDictionary?.name ?? "") {
                    Menu {
                        Button(action: {
                            viewModel.exportVocabularyTestWords(format: .markdown)
                        }) {
                            Label("导出为 Markdown", systemImage: "doc.text")
                        }
                        
                        Button(action: {
                            viewModel.exportVocabularyTestWords(format: .pdf)
                        }) {
                            Label("导出为 PDF", systemImage: "doc.richtext")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                            Text("导出单词")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .disabled(viewModel.isExporting)
                    .opacity(viewModel.isExporting ? 0.6 : 1.0)
                }
            }
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.testHistory.prefix(5)) { test in
                    TestHistoryCard(test: test) {
                        viewModel.deleteTestFromHistory(test)
                    }
                }
            }
            
            if viewModel.testHistory.count > 0 {
                NavigationLink("查看全部历史记录") {
                    TestHistoryListView(viewModel: viewModel)
                }
                .font(.footnote)
                .foregroundColor(.blue)
            }
            
            // 导出进度和错误提示
            if viewModel.isExporting {
                VStack(spacing: 8) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在导出单词数据...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if viewModel.exportProgress > 0 {
                        ProgressView(value: viewModel.exportProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 4)
                    }
                }
                .padding(.top, 8)
            }
            
            if let exportError = viewModel.exportError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text(exportError)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("重试") {
                        viewModel.clearExportError()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Test Active View
    private var testActiveView: some View {
        VStack(spacing: 0) {
            // 进度条
            testProgressView
            
            if viewModel.isPaused {
                // 暂停状态
                pausedStateView
            } else {
                // 测试内容
                testContentView
                
                // 控制按钮区域
                testControlButtonsView
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Test Control Buttons
    private var testControlButtonsView: some View {
        HStack(spacing: 16) {
            // 暂停按钮
            Button(action: {
                viewModel.pauseTest()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 16, weight: .medium))
                    Text("暂停")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange, lineWidth: 1)
                        )
                )
            }
            
            Spacer()
            
            // 结束测试按钮
            Button(action: {
                viewModel.stopTest()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 16, weight: .medium))
                    Text("结束测试")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red, lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var testProgressView: some View {
        VStack(spacing: 12) {
            // 进度条
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, CGFloat(viewModel.testProgress) * UIScreen.main.bounds.width * 0.8), height: 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.testProgress)
                    .scaleEffect(y: progressBarAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: progressBarAnimation)
            }
            .onChange(of: viewModel.testProgress) { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    progressBarAnimation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        progressBarAnimation = false
                    }
                }
            }
            
            // 进度信息
            HStack {
                Text("\(viewModel.currentWordIndex + 1) / \(viewModel.testWords.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                
                Spacer()
                
                Text(viewModel.progressPercentage)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.testProgress)
            }
            
            // 统计信息
            HStack(spacing: 20) {
                StatisticItem(title: "掌握", count: viewModel.masteredCount, color: .green)
                StatisticItem(title: "眼熟", count: viewModel.familiarCount, color: .orange)
                StatisticItem(title: "陌生", count: viewModel.unfamiliarCount, color: .red)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var pausedStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("测试已暂停")
                .font(.title)
                .fontWeight(.bold)
            
            Text("点击继续按钮恢复测试")
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button("继续测试") {
                    viewModel.resumeTest()
                }
                .buttonStyle(.borderedProminent)
                
                Button("结束测试") {
                    viewModel.stopTest()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding(20)
    }
    
    private var testContentView: some View {
        VStack(spacing: 0) {
            if let currentWord = viewModel.currentWord {
                // 根据测试模式显示不同的测试卡片
                switch viewModel.selectedTestMode {
                case .englishToChinese:
                    if let question = viewModel.currentQuestion {
                        QuestionTestCard(
                            question: question,
                            selectedAnswer: viewModel.selectedAnswer,
                            onAnswerSelected: { option in
                                viewModel.selectAnswer(option)
                            },
                            onSubmitAnswer: {
                                viewModel.submitAnswer()
                            },
                            showResult: viewModel.showResult
                        )
                        .padding(20)
                    }
                case .chineseToEnglish:
                    WordTestCard(
                        word: currentWord,
                        testMode: viewModel.selectedTestMode,
                        onMasterySelected: { mastery in
                            viewModel.selectMasteryLevel(mastery)
                        }
                    )
                    .padding(20)
                }
                
                // 导航按钮区域
                navigationButtonsView
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
            } else {
                // 加载状态
                ProgressView("加载单词中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var navigationButtonsView: some View {
        HStack(spacing: 16) {
            // 上一个按钮
            Button(action: {
                viewModel.moveToPreviousWord()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("上一个")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(viewModel.canMoveToPrevious ? .blue : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.canMoveToPrevious ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(viewModel.canMoveToPrevious ? Color.blue : Color.gray, lineWidth: 1)
                        )
                )
            }
            .disabled(!viewModel.canMoveToPrevious)
            
            Spacer()
            
            // 下一个按钮
            Button(action: {
                viewModel.moveToNextWord()
            }) {
                HStack(spacing: 8) {
                    Text("下一个")
                        .font(.system(size: 16, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(viewModel.canMoveToNext ? .blue : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.canMoveToNext ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(viewModel.canMoveToNext ? Color.blue : Color.gray, lineWidth: 1)
                        )
                )
            }
            .disabled(!viewModel.canMoveToNext)
        }
    }
}

// MARK: - Supporting Views

// MARK: - Dictionary Selection Card for Test View
// 为测试视图定制的词典选择卡片（单选模式）
struct TestDictionarySelectionCard: View {
    let dictionary: DictionaryInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 选择指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                // 词典信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(dictionary.displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !dictionary.description.isEmpty {
                        Text(dictionary.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    HStack {
                        Label("\(dictionary.totalWords) 个单词", systemImage: "book.closed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("测试模式")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
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
                            .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TestHistoryCard: View {
    let test: VocabularyTest
    let onDelete: () -> Void
    
    @State private var isPressed = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(test.dictionaryName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("测试时间: \(test.createdAt, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Label("\(test.masteredCount)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Label("\(test.familiarCount)", systemImage: "eye.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Label("\(test.unfamiliarCount)", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("词汇量")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(test.estimatedVocabularySize)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
                    .scaleEffect(isPressed ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }, perform: {})
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(
                    color: .black.opacity(isPressed ? 0.15 : 0.1),
                    radius: isPressed ? 6 : 4,
                    x: 0,
                    y: isPressed ? 3 : 2
                )
                .animation(.easeInOut(duration: 0.2), value: isPressed)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .alert("删除测试记录", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onDelete()
                }
            }
        } message: {
            Text("确定要删除这条测试记录吗？此操作无法撤销。")
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

struct StatisticItem: View {
    let title: String
    let count: Int
    let color: Color
    
    @State private var animatedValue: Int = 0
    @State private var isHighlighted = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(animatedValue)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .scaleEffect(isHighlighted ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHighlighted)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(isHighlighted ? 0.2 : 0.1))
                .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        )
        .onChange(of: count) { oldValue, newValue in
            // 更新动画值
            withAnimation(.easeInOut(duration: 0.3)) {
                animatedValue = newValue
            }
            
            // 如果数值增加，触发高亮效果
            if newValue > oldValue {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHighlighted = true
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒延迟
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isHighlighted = false
                    }
                }
            }
        }
        .onAppear {
            animatedValue = count
        }
    }
}

// MARK: - TestSizeCard Component
struct TestSizeCard: View {
    let title: String
    let subtitle: String
    let count: Int
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 选择指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                // 内容区域
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        Label("\(count) 个单词", systemImage: "number.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if isSelected {
                            Text("已选择")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
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
                            .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
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
    
    VocabularyTestView(
        vocabularyTestService: MockVocabularyTestService(dictionaryService: mockDictionaryService),
        dictionaryService: mockDictionaryService,
        errorHandler: MockErrorHandler(),
        testResultExportService: TestResultExportService(modelContext: mockModelContext, dictionaryService: mockDictionaryService),
        appCoordinator: mockAppCoordinator
    )
}
