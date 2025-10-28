//
//  StatisticsExportView.swift
//  en01
//
//  Created by AI Assistant on 2024/12/26.
//

import SwiftUI
import SwiftData
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct StatisticsExportView: View {
    @ObservedObject var viewModel: ProgressViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private let statisticsExportService: StatisticsExportServiceProtocol
    
    @State private var selectedDataTypes: Set<StatisticsDataType> = []
    @State private var selectedFormat: StatisticsExportFormat = .markdown
    @State private var includeCharts = false
    @State private var includeDetailedStats = true
    @State private var categorizeVocabularyExport = false  // 新增：是否分类导出词汇
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var exportError: String?
    @State private var exportSuccess = false
    @State private var exportedFileURL: URL?
    
    init(viewModel: ProgressViewModel, statisticsExportService: StatisticsExportServiceProtocol) {
        self.viewModel = viewModel
        self.statisticsExportService = statisticsExportService
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    dataTypeSelectionSection
                    formatSelectionSection
                    optionsSection
                    exportButtonSection
                }
                .padding()
            }
            .navigationTitle("导出学习统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("导出成功", isPresented: $exportSuccess) {
                Button("分享") {
                    if let url = exportedFileURL {
                    shareFile(at: url)
                }
                }
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("统计数据已成功导出")
            }
            .alert("导出失败", isPresented: .constant(exportError != nil)) {
                Button("确定") {
                    exportError = nil
                }
            } message: {
                if let error = exportError {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("导出学习统计")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("选择要导出的数据类型和格式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Data Type Selection Section
    private var dataTypeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择数据类型")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(StatisticsDataType.allCases, id: \.self) { dataType in
                    DataTypeSelectionCard(
                        dataType: dataType,
                        isSelected: selectedDataTypes.contains(dataType)
                    ) {
                        toggleDataType(dataType)
                    }
                }
            }
        }
    }
    
    // MARK: - Format Selection Section
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导出格式")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                FormatSelectionCard(
                    format: StatisticsExportFormat.markdown,
                    isSelected: selectedFormat == StatisticsExportFormat.markdown
                ) {
                    selectedFormat = StatisticsExportFormat.markdown
                }
                
                FormatSelectionCard(
                    format: StatisticsExportFormat.pdf,
                    isSelected: selectedFormat == StatisticsExportFormat.pdf
                ) {
                    selectedFormat = StatisticsExportFormat.pdf
                }
            }
        }
    }
    
    // MARK: - Options Section
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导出选项")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Toggle("包含图表数据", isOn: $includeCharts)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Toggle("包含详细统计", isOn: $includeDetailedStats)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                // 只有选择了词汇统计时才显示分类导出选项
                if selectedDataTypes.contains(.vocabularyStats) {
                    Toggle("分类导出词汇", isOn: $categorizeVocabularyExport)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    if categorizeVocabularyExport {
                        Text("将已掌握、熟悉、陌生单词分别导出到三个文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                    }
                }
                
                // 为测试结果导出选项添加分类导出功能
                if selectedDataTypes.contains(.testResults) {
                    Toggle("分类导出测试词汇", isOn: $categorizeVocabularyExport)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    if categorizeVocabularyExport {
                        Text("将测试中的已掌握、熟悉、陌生单词分别导出到三个文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Export Button Section
    private var exportButtonSection: some View {
        VStack(spacing: 16) {
            if isExporting {
                VStack(spacing: 12) {
                    ProgressView(value: exportProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    Text("正在导出... \(Int(exportProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button {
                startExport()
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    Text(isExporting ? "导出中..." : "开始导出")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canExport ? Color.blue : Color.gray)
                )
                .foregroundColor(.white)
                .fontWeight(.semibold)
            }
            .disabled(!canExport || isExporting)
        }
    }
    
    // MARK: - Helper Properties
    private var canExport: Bool {
        !selectedDataTypes.isEmpty
    }
    
    // MARK: - Helper Methods
    private func toggleDataType(_ dataType: StatisticsDataType) {
        if selectedDataTypes.contains(dataType) {
            selectedDataTypes.remove(dataType)
        } else {
            selectedDataTypes.insert(dataType)
        }
    }
    
    private func startExport() {
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        
        Task {
            do {
                // 模拟导出进度
                await updateProgress(0.2)
                
                let exportData = try await generateExportData()
                await updateProgress(0.6)
                
                let fileURL = try await exportToFile(data: exportData)
                await updateProgress(1.0)
                
                await MainActor.run {
                    isExporting = false
                    exportedFileURL = fileURL
                    exportSuccess = true
                }
                
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            exportProgress = progress
        }
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒延迟
    }
    
    private func generateExportData() async throws -> StatisticsExportData {
        // 生成导出数据
        var exportData = StatisticsExportData()
        
        for dataType in selectedDataTypes {
            switch dataType {
            case .vocabularyStats:
                exportData.vocabularyStats = viewModel.vocabularyStats
            case .readingStats:
                exportData.readingStats = viewModel.readingStats
            case .achievementStats:
                exportData.achievementStats = viewModel.achievementStats
            case .overallStats:
                exportData.overallStats = viewModel.overallStats
            case .testResults:
                exportData.testResults = try await statisticsExportService.getCompletedTestResults()
            }
        }
        
        exportData.includeCharts = includeCharts
        exportData.includeDetailedStats = includeDetailedStats
        exportData.exportDate = Date()
        
        return exportData
    }
    
    // MARK: - 移除不再需要的方法
    // loadTestResults 方法已移除，相关功能已迁移到 StatisticsExportService 中
    
    private func exportToFile(data: StatisticsExportData) async throws -> URL {
        // 优先尝试使用下载目录，这样文件会出现在"文件-下载"中
        let fileManager = FileManager.default
        let documentsPath: URL
        
        if let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            documentsPath = downloadsURL
            print("✅ 使用下载目录: \(documentsPath.path)")
        } else {
            // 如果下载目录不可用，回退到文档目录
            documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            print("⚠️ 下载目录不可用，使用文档目录: \(documentsPath.path)")
        }
        
        // 确保目录存在
        do {
            try fileManager.createDirectory(at: documentsPath, withIntermediateDirectories: true, attributes: nil)
            print("✅ 目录创建/验证成功")
        } catch {
            print("❌ 目录创建失败: \(error.localizedDescription)")
            throw error
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "学习统计_\(dateFormatter.string(from: Date()))"
        print("📝 生成文件名: \(fileName)")
        
        // 检查是否需要分类导出词汇
        if categorizeVocabularyExport && (selectedDataTypes.contains(.vocabularyStats) || selectedDataTypes.contains(.testResults)) {
            return try await exportCategorizedVocabulary(data: data, documentsPath: documentsPath, fileName: fileName)
        }
        
        switch selectedFormat {
        case StatisticsExportFormat.markdown:
            let content = try await generateMarkdownContent(from: data)
            let fileURL = documentsPath.appendingPathComponent("\(fileName).md")
            print("📄 准备写入Markdown文件: \(fileURL.path)")
            
            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                print("✅ Markdown文件写入成功")
                return fileURL
            } catch {
                print("❌ Markdown文件写入失败: \(error.localizedDescription)")
                throw error
            }
            
        case StatisticsExportFormat.pdf:
            // 实现真正的PDF导出功能
            let content = try await generateMarkdownContent(from: data)
            let fileURL = documentsPath.appendingPathComponent("\(fileName).pdf")
            print("📄 准备生成PDF文件: \(fileURL.path)")
            
            do {
                try await generatePDFFile(content: content, outputURL: fileURL)
                print("✅ PDF文件生成成功")
                return fileURL
            } catch {
                print("❌ PDF文件生成失败: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    // MARK: - 分类导出词汇功能
    private func exportCategorizedVocabulary(data: StatisticsExportData, documentsPath: URL, fileName: String) async throws -> URL {
        guard data.vocabularyStats != nil else {
            throw NSError(domain: "ExportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "词汇统计数据不可用"])
        }
        
        let fileExtension = selectedFormat == .markdown ? "md" : "pdf"
        
        // 获取实际的单词列表数据
        let descriptor = FetchDescriptor<TestedWord>(sortBy: [SortDescriptor(\.testedAt, order: .reverse)])
        let testedWords = try modelContext.fetch(descriptor)
        
        // 按掌握程度分类获取单词列表
        let masteredWordsList = testedWords.filter { $0.masteryLevel == MasteryLevel.mastered.rawValue }.map { $0.word }
        let learningWordsList = testedWords.filter { $0.masteryLevel == MasteryLevel.familiar.rawValue }.map { $0.word }
        let reviewWordsList = testedWords.filter { $0.masteryLevel == MasteryLevel.unfamiliar.rawValue }.map { $0.word }
        
        // 生成已掌握单词文件
        let masteredContent = generateCategorizedContent(
            title: "已掌握单词",
            words: masteredWordsList,
            exportDate: data.exportDate
        )
        let masteredFileURL = documentsPath.appendingPathComponent("\(fileName)_已掌握单词.\(fileExtension)")
        
        if selectedFormat == .markdown {
            try masteredContent.write(to: masteredFileURL, atomically: true, encoding: .utf8)
        } else {
            try await generatePDFFile(content: masteredContent, outputURL: masteredFileURL)
        }
        print("✅ 已掌握单词文件写入成功: \(masteredFileURL.path)")
        
        // 生成熟悉单词文件
        let learningContent = generateCategorizedContent(
            title: "熟悉单词",
            words: learningWordsList,
            exportDate: data.exportDate
        )
        let learningFileURL = documentsPath.appendingPathComponent("\(fileName)_熟悉单词.\(fileExtension)")
        
        if selectedFormat == .markdown {
            try learningContent.write(to: learningFileURL, atomically: true, encoding: .utf8)
        } else {
            try await generatePDFFile(content: learningContent, outputURL: learningFileURL)
        }
        print("✅ 熟悉单词文件写入成功: \(learningFileURL.path)")
        
        // 生成陌生单词文件
        let reviewContent = generateCategorizedContent(
            title: "陌生单词",
            words: reviewWordsList,
            exportDate: data.exportDate
        )
        let reviewFileURL = documentsPath.appendingPathComponent("\(fileName)_陌生单词.\(fileExtension)")
        
        if selectedFormat == .markdown {
            try reviewContent.write(to: reviewFileURL, atomically: true, encoding: .utf8)
        } else {
            try await generatePDFFile(content: reviewContent, outputURL: reviewFileURL)
        }
        print("✅ 陌生单词文件写入成功: \(reviewFileURL.path)")
        
        // 返回第一个文件的URL（用于分享功能）
        return masteredFileURL
    }
    
    private func generateCategorizedContent(title: String, words: [String], exportDate: Date) -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale(identifier: "zh_CN")
        
        var content = ""
        if selectedFormat == .markdown {
            content += "# \(title)\n\n"
            content += "生成时间：\(displayFormatter.string(from: exportDate))\n\n"
            content += "## 单词列表\n\n"
            content += "共 \(words.count) 个单词\n\n"
            
            for (index, word) in words.enumerated() {
                content += "\(index + 1). \(word)\n"
            }
        } else {
            content += "\(title)\n\n"
            content += "生成时间：\(displayFormatter.string(from: exportDate))\n\n"
            content += "单词列表\n\n"
            content += "共 \(words.count) 个单词\n\n"
            
            for (index, word) in words.enumerated() {
                content += "\(index + 1). \(word)\n"
            }
        }
        
        return content
    }
    
    // MARK: - PDF生成功能
    private func generatePDFFile(content: String, outputURL: URL) async throws {
        print("🎨 开始PDF渲染...")
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // A4 size
        let margin: CGFloat = 50
        let contentRect = CGRect(x: margin, y: margin, width: pageRect.width - 2 * margin, height: pageRect.height - 2 * margin)
        
        UIGraphicsBeginPDFContextToFile(outputURL.path, pageRect, nil)
        
        guard UIGraphicsGetCurrentContext() != nil else {
            print("❌ 无法创建PDF上下文")
            throw NSError(domain: "PDFError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建PDF上下文"])
        }
        
        UIGraphicsBeginPDFPage()
        var currentY: CGFloat = margin
        
        // 分割内容为行
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            // 检查是否需要新页面
            if currentY > pageRect.height - margin - 50 {
                UIGraphicsBeginPDFPage()
                currentY = margin
            }
            
            // 根据行内容选择字体和样式
            let font: UIFont
            let textColor: UIColor = .black
            
            if line.hasPrefix("# ") {
                // 主标题
                font = UIFont.boldSystemFont(ofSize: 20)
            } else if line.hasPrefix("## ") {
                // 二级标题
                font = UIFont.boldSystemFont(ofSize: 16)
            } else if line.hasPrefix("### ") {
                // 三级标题
                font = UIFont.boldSystemFont(ofSize: 14)
            } else {
                // 普通文本
                font = UIFont.systemFont(ofSize: 12)
            }
            
            // 清理Markdown标记
            let cleanLine = line.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            
            if !cleanLine.trimmingCharacters(in: .whitespaces).isEmpty {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor
                ]
                
                let attributedString = NSAttributedString(string: cleanLine, attributes: attributes)
                let textRect = CGRect(x: margin, y: currentY, width: contentRect.width, height: 30)
                
                attributedString.draw(in: textRect)
                currentY += font.lineHeight + 5
            } else {
                // 空行
                currentY += 10
            }
        }
        
        UIGraphicsEndPDFContext()
        print("✅ PDF渲染完成")
        
        // 验证PDF文件
        if FileManager.default.fileExists(atPath: outputURL.path) {
            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("📊 PDF文件验证成功，大小: \(fileSize) 字节")
        } else {
            print("❌ PDF文件创建失败")
            throw NSError(domain: "PDFError", code: 2, userInfo: [NSLocalizedDescriptionKey: "PDF文件创建失败"])
        }
    }
    
    private func generateMarkdownContent(from data: StatisticsExportData) async throws -> String {
        var content = "# 英语学习统计报告\n\n"
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale(identifier: "zh_CN")
        content += "生成时间：\(displayFormatter.string(from: Date()))\n\n"
        
        // 词汇统计 - 按用户要求的格式生成
        if selectedDataTypes.contains(.vocabularyStats) {
            content += try await generateVocabularyStatsContent(from: data)
        }
        
        // 阅读统计
        if selectedDataTypes.contains(.readingStats) {
            content += "## 阅读统计\n\n"
            content += "- 已完成文章: \(data.readingStats?.completedArticles ?? 0)\n"
            content += "- 进行中文章: \(data.readingStats?.inProgressArticles ?? 0)\n"
            content += "- 收藏文章: \(data.readingStats?.bookmarkedArticles ?? 0)\n"
            content += "- 平均阅读时长: \(formatTime(data.readingStats?.averageReadingTime ?? 0))\n\n"
        }
        
        // 成就统计
        if selectedDataTypes.contains(.achievementStats) {
            content += "## 成就统计\n\n"
            content += "- 总成就数: \(data.achievementStats?.totalAchievements ?? 0)\n"
            content += "- 已解锁: \(data.achievementStats?.unlockedAchievements ?? 0)\n"
            content += "- 最长连续学习天数: \(data.achievementStats?.longestStreak ?? 0)\n\n"
        }
        
        // 总体统计
        if selectedDataTypes.contains(.overallStats) {
            content += "## 总体统计\n\n"
            content += "- 当前连续天数: \(data.overallStats?.currentStreak ?? 0)\n\n"
        }
        
        // 测试结果 - 重点实现词汇测试结果导出
        if selectedDataTypes.contains(.testResults) && !data.testResults.isEmpty {
            content += "## 词汇测试结果\n\n"
            
            for test in data.testResults {
                content += "### \(test.dictionaryName) 词汇测试\n"
                let testDateFormatter = DateFormatter()
                testDateFormatter.dateStyle = .medium
                testDateFormatter.timeStyle = .short
                testDateFormatter.locale = Locale(identifier: "zh_CN")
                content += "- 测试日期：\(testDateFormatter.string(from: test.testDate))\n"
                content += "- 准确率：\(String(format: "%.1f", test.accuracy * 100))%\n"
                content += "- 总单词数：\(test.totalWords)\n"
                content += "- 认识单词数：\(test.knownWords)\n"
                content += "- 不认识单词数：\(test.unknownWords)\n"
                content += "- 估算词汇量：\(test.estimatedVocabulary)\n"
                content += "- 测试用时：\(test.formattedDuration)\n\n"
                
                // 添加单词分类结果详情
                if includeDetailedStats {
                    let details = try await statisticsExportService.generateTestDetailReport(for: test)
                    content += details
                }
            }
        }
        
        return content
    }
    
    // generateWordCategoryDetails 方法已移除，相关功能已迁移到 StatisticsExportService 中
    
    @MainActor
    private func generateVocabularyStatsContent(from data: StatisticsExportData) async throws -> String {
        var content = "## 词汇统计\n\n"
        
        if let vocabStats = data.vocabularyStats {
            // 基本统计信息
            content += "- 总词汇量: \(vocabStats.totalWords)\n"
            content += "- 已掌握: \(vocabStats.masteredWords)\n"
            content += "- 熟悉: \(vocabStats.learningWords)\n"
            content += "- 陌生: \(vocabStats.reviewWords)\n"
            content += "- 掌握率: \(String(format: "%.1f", vocabStats.masteryRate * 100))%\n\n"
            
            // 如果包含详细统计，添加单词列表
            if includeDetailedStats {
                do {
                    // 获取所有已测试的单词
                    let descriptor = FetchDescriptor<TestedWord>(sortBy: [SortDescriptor(\.testedAt, order: .reverse)])
                    let testedWords = try modelContext.fetch(descriptor)
                    
                    // 按掌握程度分类
                    let masteredWords = testedWords.filter { $0.masteryLevel == MasteryLevel.mastered.rawValue }
                    let familiarWords = testedWords.filter { $0.masteryLevel == MasteryLevel.familiar.rawValue }
                    let unfamiliarWords = testedWords.filter { $0.masteryLevel == MasteryLevel.unfamiliar.rawValue }
                    
                    // 已掌握单词
                    content += "### 已掌握单词\n"
                    if masteredWords.isEmpty {
                        content += "暂无已掌握单词\n\n"
                    } else {
                        for word in masteredWords {
                            content += "- \(word.word)\n"
                        }
                        content += "\n"
                    }
                    
                    // 熟悉单词
                    content += "### 熟悉单词\n"
                    if familiarWords.isEmpty {
                        content += "暂无熟悉单词\n\n"
                    } else {
                        for word in familiarWords {
                            content += "- \(word.word)\n"
                        }
                        content += "\n"
                    }
                    
                    // 陌生单词
                    content += "### 陌生单词\n"
                    if unfamiliarWords.isEmpty {
                        content += "暂无陌生单词\n\n"
                    } else {
                        for word in unfamiliarWords {
                            content += "- \(word.word)\n"
                        }
                        content += "\n"
                    }
                    
                } catch {
                    print("❌ 获取单词详情失败: \(error.localizedDescription)")
                    content += "### 已掌握单词\n"
                    content += "获取单词详情时出现错误: \(error.localizedDescription)\n\n"
                    
                    content += "### 熟悉单词\n"
                    content += "获取单词详情时出现错误: \(error.localizedDescription)\n\n"
                    
                    content += "### 陌生单词\n"
                    content += "获取单词详情时出现错误: \(error.localizedDescription)\n\n"
                }
            }
        } else {
            content += "暂无词汇统计数据\n\n"
        }
        
        return content
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    private func shareFile(at url: URL) {
        #if canImport(UIKit)
        // 检查是否在模拟器环境
        #if targetEnvironment(simulator)
        // 模拟器环境下显示文件路径
        let alert = UIAlertController(
            title: "文件已生成",
            message: "文件已保存到:\n\(url.path)\n\n注意：分享功能需要在真机上测试",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
        #else
        // 真机环境下使用正常分享
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // iPad适配
        if let popover = activityViewController.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            // 检查是否已有模态视图
            if window.rootViewController?.presentedViewController == nil {
                window.rootViewController?.present(activityViewController, animated: true)
            } else {
                // 如果有模态视图，先关闭再呈现
                window.rootViewController?.dismiss(animated: false) {
                    window.rootViewController?.present(activityViewController, animated: true)
                }
            }
        }
        #endif
        #endif
    }
}

// MARK: - Supporting Views

struct DataTypeSelectionCard: View {
    let dataType: StatisticsDataType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: dataType.icon)
                    .foregroundColor(isSelected ? .white : .blue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(dataType.displayName)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(dataType.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FormatSelectionCard: View {
    let format: StatisticsExportFormat
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: format == StatisticsExportFormat.markdown ? "doc.text" : "doc.richtext")
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .white : .blue)
                
                VStack(spacing: 4) {
                    Text(format.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(format.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Types

enum StatisticsExportFormat: CaseIterable {
    case markdown
    case pdf
    
    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        }
    }
    
    var description: String {
        switch self {
        case .markdown: return "文本格式，易于编辑"
        case .pdf: return "PDF格式，便于分享"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .pdf: return "pdf"
        }
    }
}

enum StatisticsDataType: CaseIterable {
    case vocabularyStats
    case readingStats
    case achievementStats
    case overallStats
    case testResults
    
    var displayName: String {
        switch self {
        case .vocabularyStats: return "词汇统计"
        case .readingStats: return "阅读统计"
        case .achievementStats: return "成就统计"
        case .overallStats: return "整体统计"
        case .testResults: return "测试结果"
        }
    }
    
    var description: String {
        switch self {
        case .vocabularyStats: return "词汇量、掌握情况等"
        case .readingStats: return "阅读时长、文章数量等"
        case .achievementStats: return "成就解锁、连续天数等"
        case .overallStats: return "学习总览数据"
        case .testResults: return "词汇测试详细结果"
        }
    }
    
    var icon: String {
        switch self {
        case .vocabularyStats: return "book.fill"
        case .readingStats: return "clock.fill"
        case .achievementStats: return "trophy.fill"
        case .overallStats: return "chart.bar.fill"
        case .testResults: return "list.clipboard.fill"
        }
    }
}

struct StatisticsExportData {
    var vocabularyStats: VocabularyProgressStats?
    var readingStats: ReadingStatisticsUI?
    var achievementStats: AchievementStatistics?
    var overallStats: OverallStatistics?
    var testResults: [VocabularyTest] = []
    var includeCharts = false
    var includeDetailedStats = true
    var exportDate = Date()
}

// MARK: - Preview
struct StatisticsExportView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建简化的预览版本
        StatisticsExportView(
            viewModel: ProgressViewModel(
                userProgressService: MockUserProgressService(),
                articleService: MockArticleService(),
                errorHandler: UnifiedErrorHandler(),
                statisticsExportService: PreviewMockStatisticsExportService()
            ),
            statisticsExportService: PreviewMockStatisticsExportService()
        )
    }
}

// MARK: - Preview Mock Services
class PreviewMockStatisticsExportService: StatisticsExportServiceProtocol {
    func getCompletedTestResults() async throws -> [VocabularyTest] {
        return []
    }
    
    func getTestWordDetails(for test: VocabularyTest) async throws -> [TestedWord] {
        return []
    }
    
    func generateMarkdownContent(for tests: [VocabularyTest]) async throws -> String {
        return "# 测试报告\n\n暂无数据"
    }
    
    func generateTestDetailReport(for test: VocabularyTest) async throws -> String {
        return "# 测试详情\n\n暂无数据"
    }
}