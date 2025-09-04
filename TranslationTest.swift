//
//  TranslationTest.swift
//  Simple test to verify AI translation functionality
//
//  Created by AI Assistant on 2025/1/8.
//

import Foundation
@testable import en01

/// 简单的翻译功能测试
class TranslationTest {
    
    static func testBasicTranslation() async {
        print("🧪 开始测试AI翻译功能...")
        
        // 创建翻译服务配置
        let config = TranslationConfig(
            primaryProvider: .gemini,
            fallbackProviders: [.openai, .gpt4],
            enableLocalModel: false,
            apiKeys: [
                .gemini: "AIzaSyCuGzUTUY_s_lB4NmKULmDqD2Z_gWsSN8w",
                .openai: "test-key"
            ]
        )
        
        // 创建翻译服务实例
        let translationService = TranslationServiceImpl(config: config)
        
        // 测试用例
        let testCases = [
            ("Hello", "简单问候"),
            ("How are you?", "日常对话"),
            ("The weather is nice today.", "天气描述")
        ]
        
        var successCount = 0
        var totalCount = testCases.count
        
        for (text, context) in testCases {
            do {
                print("\n📝 测试翻译: \"\(text)\"")
                print("🔍 上下文: \(context)")
                
                let translation = try await translationService.translateWord(text, context: context)
                
                if let translation = translation {
                    print("✅ 翻译成功!")
                    print("   原文: \(translation.originalText)")
                    print("   译文: \(translation.translatedText)")
                    print("   提供商: \(translation.provider.displayName)")
                    print("   置信度: \(String(format: "%.2f", translation.confidence))")
                    
                    if let contextualMeaning = translation.contextualMeaning {
                        print("   上下文含义: \(contextualMeaning)")
                    }
                    
                    successCount += 1
                } else {
                    print("❌ 翻译失败: 返回结果为空")
                }
                
            } catch {
                print("❌ 翻译失败: \(error.localizedDescription)")
                if let appError = error as? AppError {
                    print("   错误类型: \(appError)")
                }
            }
            
            // 添加延迟避免API限制
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        }
        
        print("\n📊 测试结果统计:")
        print("   总测试数: \(totalCount)")
        print("   成功数: \(successCount)")
        print("   失败数: \(totalCount - successCount)")
        print("   成功率: \(String(format: "%.1f", Double(successCount) / Double(totalCount) * 100))%")
        
        if successCount == totalCount {
            print("🎉 所有翻译测试通过! AI翻译功能正常工作")
        } else if successCount > 0 {
            print("⚠️ 部分翻译测试通过，AI翻译功能部分可用")
        } else {
            print("🚨 所有翻译测试失败，AI翻译功能不可用")
        }
    }
    
    static func testProviderAvailability() {
        print("\n🔍 检查翻译提供商可用性...")
        
        let config = TranslationConfig(
            primaryProvider: .gemini,
            fallbackProviders: [.openai, .gpt4],
            enableLocalModel: false,
            apiKeys: [
                .gemini: "AIzaSyCuGzUTUY_s_lB4NmKULmDqD2Z_gWsSN8w",
                .openai: "test-key"
            ]
        )
        
        let translationService = TranslationServiceImpl(config: config)
        let availableProviders = translationService.getAvailableProviders()
        
        print("可用的翻译提供商:")
        for provider in availableProviders {
            print("   ✅ \(provider.displayName)")
        }
        
        if availableProviders.isEmpty {
            print("   ❌ 没有可用的翻译提供商")
        }
    }
    
    static func runAllTests() async {
        print("🚀 开始运行翻译功能测试套件...")
        print("=" * 50)
        
        testProviderAvailability()
        await testBasicTranslation()
        
        print("\n" + "=" * 50)
        print("✨ 翻译功能测试套件完成")
    }
}

// 扩展String以支持重复操作符
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}