//
//  TestResultView.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import SwiftUI
import Charts

/// 测试结果展示视图
struct TestResultView: View {
    let testResult: VocabularyTest
    @ObservedObject var viewModel: VocabularyTestViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingShareSheet = false
    @State private var animateProgress = false
    @State private var showingDetailBreakdown = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 头部庆祝区域
                    celebrationHeader
                    
                    // 主要结果卡片
                    mainResultCard
                    
                    // 详细统计图表
                    statisticsChart
                    
                    // 结果分析
                    resultAnalysis
                    
                    // 建议和下一步
                    recommendationsSection
                    
                    // 操作按钮
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
            .navigationTitle("测试结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("分享") {
                        showingShareSheet = true
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
                animateProgress = true
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            shareSheet
        }
    }
    
    private var celebrationHeader: some View {
        VStack(spacing: 16) {
            // 庆祝图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .scaleEffect(animateProgress ? 1.0 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateProgress)
            
            Text("测试完成！")
                .font(.title)
                .fontWeight(.bold)
            
            Text("你的词汇量评估结果已出炉")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }
    
    private var mainResultCard: some View {
        VStack(spacing: 20) {
            // 词汇量结果
            VStack(spacing: 8) {
                Text("估算词汇量")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(testResult.estimatedVocabulary)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                        .contentTransition(.numericText())
                    
                    Text("词")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                .animation(.easeInOut(duration: 0.8), value: animateProgress)
            }
            
            Divider()
            
            // 测试统计
            HStack(spacing: 20) {
                StatItem(
                    title: "测试单词",
                    value: "\(testResult.totalWords)",
                    icon: "book.fill",
                    color: .gray
                )
                
                StatItem(
                    title: "准确率",
                    value: "\(String(format: "%.1f%%", testResult.accuracy * 100))",
                    icon: "percent",
                    color: .green
                )
                
                StatItem(
                    title: "词典",
                    value: testResult.dictionaryName,
                    icon: "books.vertical.fill",
                    color: .orange
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var statisticsChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("掌握程度分布")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 饼图
            Chart {
                SectorMark(
                    angle: .value("掌握", testResult.knownWords),
                    innerRadius: .ratio(0.618),
                    angularInset: 1.5
                )
                .foregroundStyle(.green)
                .opacity(0.8)
                
                SectorMark(
                    angle: .value("陌生", testResult.unknownWords),
                    innerRadius: .ratio(0.618),
                    angularInset: 1.5
                )
                .foregroundStyle(.red)
                .opacity(0.8)
            }
            .frame(height: 200)
            .animation(.easeInOut(duration: 1.0).delay(0.3), value: animateProgress)
            
            // 图例
            HStack(spacing: 20) {
                    LegendItem(
                        color: .green,
                        title: "掌握",
                        count: testResult.knownWords,
                        percentage: Double(testResult.knownWords) / Double(testResult.totalWords) * 100
                    )
                    
                    LegendItem(
                        color: .red,
                        title: "陌生",
                        count: testResult.unknownWords,
                        percentage: Double(testResult.unknownWords) / Double(testResult.totalWords) * 100
                    )
                }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var resultAnalysis: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("结果分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                AnalysisItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "词汇水平",
                    description: vocabularyLevelDescription,
                    color: .blue
                )
                
                AnalysisItem(
                    icon: "target",
                    title: "掌握率",
                    description: masteryRateDescription,
                    color: .green
                )
                
                AnalysisItem(
                    icon: "lightbulb",
                    title: "学习建议",
                    description: learningRecommendation,
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("下一步建议")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                RecommendationCard(
                    recommendation: StudyRecommendation(
                        title: "继续学习",
                        description: "针对陌生单词进行重点学习",
                        priority: .high
                    ) {
                        // TODO: 导航到学习页面
                    }
                )
                
                RecommendationCard(
                    recommendation: StudyRecommendation(
                        title: "重新测试",
                        description: "使用其他词典进行测试对比",
                        priority: .medium
                    ) {
                        // TODO: 开始新测试
                    }
                )
                
                RecommendationCard(
                    recommendation: StudyRecommendation(
                        title: "查看历史",
                        description: "对比历次测试结果和进步",
                        priority: .low
                    ) {
                        // TODO: 显示历史记录
                    }
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button("保存结果") {
                saveResult()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
            .foregroundColor(.white)
            .fontWeight(.semibold)
            
            Button("开始新测试") {
                startNewTest()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .foregroundColor(.blue)
            .fontWeight(.semibold)
        }
    }
    
    private var shareSheet: some View {
        VStack(spacing: 20) {
            Text("分享测试结果")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(generateShareText())
                .font(.body)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            
            HStack(spacing: 16) {
                Button("复制文本") {
                    UIPasteboard.general.string = generateShareText()
                    showingShareSheet = false
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                )
                .foregroundColor(.white)
                
                Button("取消") {
                    showingShareSheet = false
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .foregroundColor(.gray)
            }
        }
        .padding(20)
        .presentationDetents([.medium])
    }
    
    // MARK: - Computed Properties
    
    private var vocabularyLevelDescription: String {
        let size = testResult.estimatedVocabularySize
        switch size {
        case 0..<2000:
            return "初级水平，建议加强基础词汇学习"
        case 2000..<4000:
            return "中级水平，词汇基础较好"
        case 4000..<6000:
            return "中高级水平，词汇量较为丰富"
        case 6000..<8000:
            return "高级水平，词汇掌握良好"
        default:
            return "优秀水平，词汇量非常丰富"
        }
    }
    
    private var masteryRateDescription: String {
        let rate = testResult.accuracy * 100
        switch rate {
        case 0..<60:
            return "掌握率偏低，需要加强词汇记忆"
        case 60..<75:
            return "掌握率一般，继续努力提升"
        case 75..<85:
            return "掌握率良好，词汇基础扎实"
        case 85..<95:
            return "掌握率优秀，词汇能力很强"
        default:
            return "掌握率极佳，词汇水平出色"
        }
    }
    
    private var learningRecommendation: String {
        let unfamiliarRate = Double(testResult.unknownWords) / Double(testResult.totalWords) * 100
        
        if unfamiliarRate > 50 {
            return "建议从基础词汇开始，循序渐进学习"
        } else if unfamiliarRate > 30 {
            return "可以针对性学习陌生词汇，巩固基础"
        } else if unfamiliarRate > 15 {
            return "继续扩展词汇量，学习更高级词汇"
        } else {
            return "词汇基础很好，可以挑战更难的词典"
        }
    }
    
    // MARK: - Actions
    
    private func saveResult() {
        viewModel.saveTestResult(testResult) { success in
            if success {
                // 显示保存成功提示
            }
        }
    }
    
    private func startNewTest() {
        dismiss()
        // TODO: 触发新测试
    }
    
    private func generateShareText() -> String {
        return """
        📚 词汇量测试结果
        
        📊 估算词汇量: \(testResult.estimatedVocabulary) 词
        📖 测试词典: \(testResult.dictionaryName)
        ✅ 准确率: \(String(format: "%.1f%%", testResult.accuracy * 100))
        
        📈 掌握分布:
        • 掌握: \(testResult.knownWords) 词
        • 陌生: \(testResult.unknownWords) 词
        
        💡 \(vocabularyLevelDescription)
        """
    }
}

// MARK: - Supporting Views

struct LegendItem: View {
    let color: Color
    let title: String
    let count: Int
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text("\(String(format: "%.1f%%", percentage))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AnalysisItem: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}



#Preview {
    let mockTest = VocabularyTest(dictionaryName: "考研词汇", sampleSize: 100)
    mockTest.totalWords = 100
    mockTest.knownWords = 85
    mockTest.estimatedVocabulary = 4200
    mockTest.accuracy = 0.85
    mockTest.testDuration = 3600
    mockTest.completeTest()
    
    return TestResultView(
        testResult: mockTest,
        viewModel: VocabularyTestViewModel(
            vocabularyTestService: MockVocabularyTestService(),
            dictionaryService: MockDictionaryService(),
            errorHandler: MockErrorHandler()
        )
    )
}