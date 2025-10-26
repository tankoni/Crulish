import SwiftUI
import SwiftData

struct TestHistorySelectionSheet: View {
    @Binding var isPresented: Bool
    let onTestRecordsSelected: ([VocabularyTest]) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allTests: [VocabularyTest]
    
    @State private var selectedTests: Set<UUID> = []
    @State private var searchText = ""
    
    var filteredTests: [VocabularyTest] {
        if searchText.isEmpty {
            return allTests.sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        } else {
            return allTests.filter { test in
                test.dictionaryName.localizedCaseInsensitiveContains(searchText)
            }.sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                if filteredTests.isEmpty {
                    emptyStateView
                } else {
                    testListView
                }
                
                // 底部操作按钮
                bottomActionButtons
            }
            .navigationTitle("选择测试历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("全选") {
                        if selectedTests.count == filteredTests.count {
                            selectedTests.removeAll()
                        } else {
                            selectedTests = Set(filteredTests.map { $0.id })
                        }
                    }
                    .disabled(filteredTests.isEmpty)
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("暂无测试历史")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("完成词汇测试后，测试记录将显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var testListView: some View {
        List {
            ForEach(filteredTests, id: \.id) { test in
                TestHistoryRow(
                    test: test,
                    isSelected: selectedTests.contains(test.id),
                    onToggle: {
                        if selectedTests.contains(test.id) {
                            selectedTests.remove(test.id)
                        } else {
                            selectedTests.insert(test.id)
                        }
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
    
    @ViewBuilder
    private var bottomActionButtons: some View {
        VStack(spacing: 12) {
            if !selectedTests.isEmpty {
                HStack {
                    Text("已选择 \(selectedTests.count) 个测试记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 16) {
                Button("清除选择") {
                    selectedTests.removeAll()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
                .disabled(selectedTests.isEmpty)
                
                Button("确认选择") {
                    let selectedTestRecords = filteredTests.filter { selectedTests.contains($0.id) }
                    onTestRecordsSelected(selectedTestRecords)
                    isPresented = false
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedTests.isEmpty ? Color(.systemGray4) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(selectedTests.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
    }
}

struct TestHistoryRow: View {
    let test: VocabularyTest
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(test.dictionaryName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text("词汇量: \(test.estimatedVocabulary)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("正确率: \(Int(test.accuracy * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(formatDate(test.completedAt ?? test.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(test.totalWords)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("单词")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜索测试记录...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    TestHistorySelectionSheet(
        isPresented: .constant(true),
        onTestRecordsSelected: { _ in }
    )
}