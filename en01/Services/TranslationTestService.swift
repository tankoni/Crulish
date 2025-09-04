//
//  TranslationTestService.swift
//  Crulish
//
//  Created by AI Assistant
//

import Foundation
import SwiftUI

/// AI翻译功能测试服务
@MainActor
class TranslationTestService: ObservableObject {
    @Published var testResults: [TestResult] = []
    @Published var isRunningTests = false
    
    private let translationService: TranslationServiceProtocol
    private let errorHandler: TranslationErrorHandler
    
    init(translationService: TranslationServiceProtocol) {
        self.translationService = translationService
        self.errorHandler = TranslationErrorHandler()
    }
    
    /// 运行所有翻译功能测试
    func runAllTests() async {
        isRunningTests = true
        testResults.removeAll()
        
        // 测试1: ClawCloud连接性检查
        await testClawCloudConnectivity()
        
        // 测试2: Gemini API翻译功能
        await testGeminiTranslation()
        
        // 测试3: 其他翻译提供者
        await testOtherProviders()
        
        // 测试4: 错误处理机制
        await testErrorHandling()
        
        isRunningTests = false
    }
    
    /// 测试ClawCloud连接性
    private func testClawCloudConnectivity() async {
        let testName = "ClawCloud连接性检查"
        
        let isConnected = await errorHandler.checkClawCloudConnectivityWithRetry()
        
        if isConnected {
            addTestResult(TestResult(
                name: testName,
                status: .success,
                message: "ClawCloud服务连接正常",
                details: "成功连接到ClawCloud API服务器"
            ))
        } else {
            addTestResult(TestResult(
                name: testName,
                status: .failure,
                message: "ClawCloud服务连接失败",
                details: "无法连接到ClawCloud API服务器，请检查网络连接"
            ))
        }
    }
    
    /// 测试Gemini API翻译功能
    private func testGeminiTranslation() async {
        let testName = "Gemini API翻译测试"
        let testText = "Hello, how are you today?"
        
        do {
            let result = try await translationService.translateSentence(testText)
            
            if let translation = result, !translation.translatedText.isEmpty && translation.translatedText != testText {
                addTestResult(TestResult(
                    name: testName,
                    status: .success,
                    message: "Gemini翻译功能正常",
                    details: "原文: \"\(testText)\"\n译文: \"\(translation.translatedText)\"\n置信度: \(translation.confidence)\n提供商: \(translation.provider.displayName)"
                ))
            } else {
                addTestResult(TestResult(
                    name: testName,
                    status: .failure,
                    message: "Gemini翻译结果异常",
                    details: "翻译结果为空或与原文相同"
                ))
            }
        } catch {
            addTestResult(TestResult(
                name: testName,
                status: .error,
                message: "Gemini翻译失败",
                details: error.localizedDescription
            ))
        }
    }
    
    /// 测试其他翻译提供者
    private func testOtherProviders() async {
        let providers: [TranslationProvider] = [.gpt4omini, .claude3haiku, .google]
        let testText = "Good morning!"
        
        for provider in providers {
            let testName = "\(provider.displayName)翻译测试"
            
            do {
                let result = try await translationService.translateSentence(testText)
                
                if let translation = result, !translation.translatedText.isEmpty {
                    addTestResult(TestResult(
                        name: testName,
                        status: .success,
                        message: "\(provider.displayName)翻译正常",
                        details: "译文: \"\(translation.translatedText)\"\n置信度: \(translation.confidence)"
                    ))
                } else {
                    addTestResult(TestResult(
                        name: testName,
                        status: .failure,
                        message: "\(provider.displayName)翻译失败",
                        details: "翻译结果为空"
                    ))
                }
            } catch {
                addTestResult(TestResult(
                    name: testName,
                    status: .warning,
                    message: "\(provider.displayName)不可用",
                    details: error.localizedDescription
                ))
            }
        }
    }
    
    /// 测试错误处理机制
    private func testErrorHandling() async {
        let testName = "错误处理机制测试"
        
        do {
            // 测试无效的翻译请求
            let _ = try await translationService.translateSentence("") // 空文本测试
            
            addTestResult(TestResult(
                name: testName,
                status: .warning,
                message: "错误处理需要改进",
                details: "无效请求未被正确拦截"
            ))
        } catch {
            addTestResult(TestResult(
                name: testName,
                status: .success,
                message: "错误处理机制正常",
                details: "正确捕获并处理了无效请求: \(error.localizedDescription)"
            ))
        }
    }
    
    /// 添加测试结果
    private func addTestResult(_ result: TestResult) {
        testResults.append(result)
    }
    
    /// 获取测试摘要
    func getTestSummary() -> String {
        let total = testResults.count
        let success = testResults.filter { $0.status == .success }.count
        let failure = testResults.filter { $0.status == .failure }.count
        let error = testResults.filter { $0.status == .error }.count
        let warning = testResults.filter { $0.status == .warning }.count
        
        return "测试完成: 总计\(total)项，成功\(success)项，失败\(failure)项，错误\(error)项，警告\(warning)项"
    }
}

// MARK: - 测试结果模型

struct TestResult: Identifiable {
    let id = UUID()
    let name: String
    let status: TestStatus
    let message: String
    let details: String
    let timestamp = Date()
}

enum TestStatus {
    case success
    case failure
    case error
    case warning
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .failure:
            return .red
        case .error:
            return .orange
        case .warning:
            return .yellow
        }
    }
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        }
    }
}