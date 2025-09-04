//
//  DictionarySelectionView.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI

/// 词典选择视图
struct DictionarySelectionView: View {
    @ObservedObject var viewModel: VocabularyTestViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDictionary: DictionaryInfo?
    @State private var testSampleSize: Int = 100
    @State private var showingTestSizeSheet = false
    @State private var isStartingTest = false
    
    private let sampleSizeOptions = [50, 100, 150, 200, -1] // -1 表示全部单词
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 头部说明
                headerSection
                
                // 词典列表
                dictionaryListSection
                
                // 测试设置
                if selectedDictionary != nil {
                    testSettingsSection
                }
                
                Spacer()
                
                // 开始测试按钮
                startTestButton
            }
            .navigationTitle("选择词典")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadAvailableDictionaries()
        }
        .sheet(isPresented: $showingTestSizeSheet) {
            testSizeSelectionSheet
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("选择测试词典")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("选择一个词典开始词汇量测试，系统将随机抽取单词进行评估")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
    }
    
    private var dictionaryListSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoadingDictionaries {
                    loadingView
                } else if viewModel.availableDictionaries.isEmpty {
                    emptyStateView
                } else {
                    ForEach(viewModel.availableDictionaries) { dictionary in
                        DictionaryCard(
                            dictionary: dictionary,
                            isSelected: selectedDictionary?.id == dictionary.id
                        ) {
                            selectedDictionary = dictionary
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var testSettingsSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("测试设置")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                
                // 测试单词数量设置
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("测试单词数量")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text("建议100-200个单词，测试时间约5-10分钟")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(testSampleSize == -1 ? "全部" : "\(testSampleSize) 个") {
                        showingTestSizeSheet = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                    .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                
                // 预估测试时间
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    
                    Text("预估测试时间: \(estimatedTestTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
            .background(Color(.systemGray6).opacity(0.5))
        }
    }
    
    private var startTestButton: some View {
        VStack(spacing: 12) {
            if let dictionary = selectedDictionary {
                Button(action: startTest) {
                    HStack {
                        if isStartingTest {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        
                        Text(isStartingTest ? "准备中..." : "开始测试")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                    .foregroundColor(.white)
                }
                .disabled(isStartingTest)
                .padding(.horizontal, 20)
                
                Text("测试 \(dictionary.name) (\(dictionary.totalWords) 个单词)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("请先选择一个词典")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
            }
        }
        .padding(.bottom, 34) // 安全区域
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("加载词典列表...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("暂无可用词典")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("请确保词典文件已正确导入")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var testSizeSelectionSheet: some View {
        NavigationView {
            List {
                ForEach(sampleSizeOptions, id: \.self) { size in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(size == -1 ? "全部单词" : "\(size) 个单词")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(size == -1 ? "测试词典中的所有单词" : "约 \(size / 20 + 2)-\(size / 15 + 3) 分钟")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if testSampleSize == size {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        testSampleSize = size
                        showingTestSizeSheet = false
                    }
                }
            }
            .navigationTitle("选择测试数量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingTestSizeSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Computed Properties
    
    private var estimatedTestTime: String {
        if testSampleSize == -1 {
            if let dictionary = selectedDictionary {
                let totalWords = dictionary.totalWords
                let minTime = totalWords / 20 + 2
                let maxTime = totalWords / 15 + 3
                return "\(minTime)-\(maxTime) 分钟 (全部 \(totalWords) 个单词)"
            } else {
                return "根据词典大小而定"
            }
        } else {
            let minTime = testSampleSize / 20 + 2
            let maxTime = testSampleSize / 15 + 3
            return "\(minTime)-\(maxTime) 分钟"
        }
    }
    
    // MARK: - Actions
    
    private func startTest() {
        guard let dictionary = selectedDictionary else { return }
        
        isStartingTest = true
        
        let sampleSize = testSampleSize == -1 ? nil : testSampleSize
        viewModel.startTest(with: dictionary, sampleSize: sampleSize) { success in
            DispatchQueue.main.async {
                isStartingTest = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct DictionaryCard: View {
    let dictionary: DictionaryInfo
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dictionary.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(dictionary.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // 词典信息
            HStack(spacing: 16) {
                InfoItem(
                    icon: "textformat.123",
                    title: "单词数量",
                    value: "\(dictionary.totalWords)"
                )
                
                InfoItem(
                    icon: "chart.bar.fill",
                    title: "难度",
                    value: dictionary.difficulty.displayName
                )
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}

struct InfoItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Extensions

// DifficultyLevel.displayName 已在 CommonTypes.swift 中定义

#Preview {
    DictionarySelectionView(
        viewModel: VocabularyTestViewModel(
            vocabularyTestService: MockVocabularyTestService(),
            dictionaryService: MockDictionaryService(),
            errorHandler: MockErrorHandler()
        )
    )
}