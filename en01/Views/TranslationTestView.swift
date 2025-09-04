//
//  TranslationTestView.swift
//  Crulish
//
//  Created by AI Assistant
//

import SwiftUI

/// AI翻译功能测试界面
struct TranslationTestView: View {
    @StateObject private var testService: TranslationTestService
    @Environment(\.dismiss) private var dismiss
    
    init(translationService: TranslationServiceProtocol) {
        self._testService = StateObject(wrappedValue: TranslationTestService(translationService: translationService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 标题和说明
                VStack(spacing: 8) {
                    Text("AI翻译功能测试")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("验证各个翻译服务提供者的连接性和功能状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // 测试按钮
                Button(action: {
                    Task {
                        await testService.runAllTests()
                    }
                }) {
                    HStack {
                        if testService.isRunningTests {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle.fill")
                        }
                        
                        Text(testService.isRunningTests ? "测试进行中..." : "开始测试")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(testService.isRunningTests)
                .padding(.horizontal)
                
                // 测试结果列表
                if !testService.testResults.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("测试结果")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(testService.testResults) { result in
                                    TranslationTestResultCard(result: result)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 测试摘要
                        Text(testService.getTestSummary())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                } else {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("点击上方按钮开始测试")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("翻译功能测试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 测试结果卡片

struct TranslationTestResultCard: View {
    let result: TestResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 测试名称和状态
            HStack {
                Image(systemName: result.status.icon)
                    .foregroundColor(result.status.color)
                    .font(.system(size: 16, weight: .medium))
                
                Text(result.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(formatTime(result.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 测试消息
            Text(result.message)
                .font(.caption)
                .foregroundColor(result.status.color)
            
            // 详细信息（可展开）
            if isExpanded {
                Text(result.details)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - 预览

#Preview {
    TranslationTestView(translationService: TranslationServiceImpl())
}