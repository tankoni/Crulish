//
//  OnlineTranslationProvider.swift
//  en01
//
//  Created by Solo Coding on 2024/12/19.
//

/*
 Google Gemini API 使用说明
 
 本应用支持两种Gemini翻译方式：
 1. ClawCloud代理服务（推荐）- 自动检测连通性
 2. Google Gemini Direct API - 直接调用Google服务
 
 === Google Gemini API 配置指南 ===
 
 1. 获取 API 密钥：
    - 访问 Google AI Studio: https://aistudio.google.com/
    - 登录您的Google账户
    - 点击"Get API Key"按钮创建新的API密钥
    - 复制生成的API密钥（格式：AIzaSy...）
 
 2. 验证 API 密钥：
    使用curl命令验证您的API密钥是否有效：
    
    curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=YOUR_API_KEY" \
      -H 'Content-Type: application/json' \
      -X POST \
      -d '{
        "contents": [
          {
            "parts": [
              {
                "text": "Explain how AI works in a few words"
              }
            ]
          }
        }
      }'
 
 3. API 密钥安全指南：
    ⚠️ 重要安全提醒：
    - 请妥善保管您的Gemini API密钥
    - 不要将API密钥提交到版本控制系统
    - 建议为API密钥添加使用限制
    - 定期轮换API密钥以确保安全
    - 监控API使用情况，防止异常调用
 
 4. 当前配置的API密钥：
    - 主密钥：AIzaSyCuGzUTUY_s_lB4NmKULmDqD2Z_gWsSN8w
    - 备用密钥：AIzaSyDPnQ0nL6aqJ6mVHTa-BZGbPy2Gd_JqHo0
 
 5. 使用策略：
    - 优先使用ClawCloud代理（更稳定，有连通性检测）
    - ClawCloud不可用时自动切换到Direct API
    - 支持多个API密钥轮换使用
    - 内置速率限制（每分钟60次请求）
 
 6. 错误处理：
    - 401错误：API密钥无效或过期
    - 429错误：请求频率超限
    - 403错误：API密钥权限不足
    - 网络错误：自动重试机制
*/

import Foundation
import OSLog
import CryptoKit

/// 在线翻译提供者管理器
class OnlineTranslationProvider {
    private let logger = Logger(subsystem: "com.en01.translation", category: "OnlineProvider")
    
    // MARK: - Properties
    private let urlSession: URLSession
    private let requestTimeout: TimeInterval = 60.0
    
    // API配置字典
    private var apiConfigurations: [TranslationProvider: APIConfiguration] = [:]
    
    // 当前选择的提供商
    private var currentProvider: TranslationProvider = .openai
    
    // 当前选择的AI模型
    private var selectedAIModel: AIModel?
    
    // 速率限制器
    private let rateLimiter = RateLimiter()
    
    // 错误处理器
    private let errorHandler = TranslationErrorHandler()
    
    init(apiKeys: [TranslationProvider: String]? = nil) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout * 2
        urlSession = URLSession(configuration: config)
        
        setupAPIConfigurations(with: apiKeys)
        logger.info("OnlineTranslationProvider initialized")
    }
    
    // MARK: - Configuration
    
    private func setupAPIConfigurations(with apiKeys: [TranslationProvider: String]? = nil) {
        // 根据新的细粒度提供商架构设置API配置
        // 使用apiKeyName来获取共享的API密钥
        
        // GPT系列模型配置
        setupGPTConfigurations(with: apiKeys)
        
        // Claude系列模型配置
        setupClaudeConfigurations(with: apiKeys)
        
        // Gemini系列模型配置
        setupGeminiConfigurations(with: apiKeys)
        
        // DeepSeek系列模型配置
        setupDeepSeekConfigurations(with: apiKeys)
        
        // Qwen系列模型配置
        setupQwenConfigurations(with: apiKeys)
        
        // 豆包系列模型配置
        setupDoubaoConfigurations(with: apiKeys)
        
        // 传统翻译服务配置
        setupTraditionalTranslationConfigurations(with: apiKeys)
        
        // 兼容性配置（保留旧的通用提供商）
        setupLegacyConfigurations(with: apiKeys)
    }
    
    private func setupGPTConfigurations(with apiKeys: [TranslationProvider: String]?) {
        // 只有在有有效API密钥时才设置配置
        guard let openaiKey = apiKeys?[.openai], !openaiKey.isEmpty else {
            logger.info("OpenAI API密钥未配置，跳过GPT配置")
            return
        }
        
        // GPT-3.5 Turbo
        apiConfigurations[.gpt35turbo] = APIConfiguration(
            baseURL: "https://api.openai.com/v1/chat/completions",
            apiKey: openaiKey,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer {API_KEY}"
            ],
            maxTokens: 1000,
            model: "gpt-3.5-turbo"
        )
        
        // GPT-4
        apiConfigurations[.gpt4] = APIConfiguration(
            baseURL: "https://api.openai.com/v1/chat/completions",
            apiKey: openaiKey,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer {API_KEY}"
            ],
            maxTokens: 1000,
            model: "gpt-4"
        )
        
        // GPT-4 Turbo
        apiConfigurations[.gpt4turbo] = APIConfiguration(
            baseURL: "https://api.openai.com/v1/chat/completions",
            apiKey: openaiKey,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer {API_KEY}"
            ],
            maxTokens: 1000,
            model: "gpt-4-turbo"
        )
        
        // GPT-4o
        apiConfigurations[.gpt4o] = APIConfiguration(
            baseURL: "https://api.openai.com/v1/chat/completions",
            apiKey: openaiKey,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer {API_KEY}"
            ],
            maxTokens: 1000,
            model: "gpt-4o"
        )
        
        // GPT-4o Mini
        apiConfigurations[.gpt4omini] = APIConfiguration(
            baseURL: "https://api.openai.com/v1/chat/completions",
            apiKey: openaiKey,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer {API_KEY}"
            ],
            maxTokens: 1000,
            model: "gpt-4o-mini"
        )
    }
    
    private func setupClaudeConfigurations(with apiKeys: [TranslationProvider: String]?) {
        // Claude 3 Haiku
        if let anthropicKey = apiKeys?[.claude3haiku], !anthropicKey.isEmpty {
            apiConfigurations[.claude3haiku] = APIConfiguration(
                baseURL: "https://api.openai.com/v1/chat/completions", // 通过OpenAI兼容接口
                apiKey: anthropicKey,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ],
                maxTokens: 1000,
                model: "claude-3-haiku-20240307"
            )
            
            // Claude 3 Sonnet
            apiConfigurations[.claude3sonnet] = APIConfiguration(
                baseURL: "https://api.openai.com/v1/chat/completions",
                apiKey: anthropicKey,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ],
                maxTokens: 1000,
                model: "claude-3-sonnet-20240229"
            )
            
            // Claude 3 Opus
            apiConfigurations[.claude3opus] = APIConfiguration(
                baseURL: "https://api.openai.com/v1/chat/completions",
                apiKey: anthropicKey,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ],
                maxTokens: 1000,
                model: "claude-3-opus-20240229"
            )
            
            // Claude 3.5 Sonnet
            apiConfigurations[.claude35sonnet] = APIConfiguration(
                baseURL: "https://api.openai.com/v1/chat/completions",
                apiKey: anthropicKey,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ],
                maxTokens: 1000,
                model: "claude-3-5-sonnet-20241022"
            )
        }
    }
    
    private func setupGeminiConfigurations(with apiKeys: [TranslationProvider: String]?) {
        let geminiKey = apiKeys?[.gemini25pro] ?? getUserGeminiAPIKey()
        
        if !geminiKey.isEmpty {
            // Gemini 2.5 Pro
            apiConfigurations[.gemini25pro] = APIConfiguration(
                baseURL: "https://gemini-api.apifox.cn/v1beta/models/gemini-2.5-pro-001:generateContent",
                apiKey: geminiKey,
                secretKey: getUserGeminiBackupAPIKey(),
                headers: ["Content-Type": "application/json"],
                maxTokens: 2000,
                model: "gemini-2.5-pro-001"
            )
            
            // Gemini 2.5 Flash
            apiConfigurations[.gemini25flash] = APIConfiguration(
                baseURL: "https://gemini-api.apifox.cn/v1beta/models/gemini-2.5-flash-001:generateContent",
                apiKey: geminiKey,
                secretKey: getUserGeminiBackupAPIKey(),
                headers: ["Content-Type": "application/json"],
                maxTokens: 2000,
                model: "gemini-2.5-flash-001"
            )
            
            // Gemini 2.0 Flash
            apiConfigurations[.gemini20flash] = APIConfiguration(
                baseURL: "https://gemini-api.apifox.cn/v1beta/models/gemini-2.0-flash-001:generateContent",
                apiKey: geminiKey,
                secretKey: getUserGeminiBackupAPIKey(),
                headers: ["Content-Type": "application/json"],
                maxTokens: 2000,
                model: "gemini-2.0-flash-001"
            )
            
            // Gemini 2.0 Flash Spark
            apiConfigurations[.gemini20flashSpark] = APIConfiguration(
                baseURL: "https://gemini-api.apifox.cn/v1beta/models/gemini-2.0-flash-spark-001:generateContent",
                apiKey: geminiKey,
                secretKey: getUserGeminiBackupAPIKey(),
                headers: ["Content-Type": "application/json"],
                maxTokens: 2000,
                model: "gemini-2.0-flash-spark-001"
            )
            
            // Gemini 1.5 Pro
            apiConfigurations[.gemini15pro] = APIConfiguration(
                baseURL: "https://gemini-api.apifox.cn/v1beta/models/gemini-1.5-pro-001:generateContent",
                apiKey: geminiKey,
                secretKey: getUserGeminiBackupAPIKey(),
                headers: ["Content-Type": "application/json"],
                maxTokens: 2000,
                model: "gemini-1.5-pro-001"
            )
            
            // Gemini 1.5 Flash
            apiConfigurations[.gemini15flash] = APIConfiguration(
                baseURL: "https://gemini-api.apifox.cn/v1beta/models/gemini-1.5-flash-001:generateContent",
                apiKey: geminiKey,
                secretKey: getUserGeminiBackupAPIKey(),
                headers: ["Content-Type": "application/json"],
                maxTokens: 2000,
                model: "gemini-1.5-flash-001"
            )
        }
    }
    
    private func setupDeepSeekConfigurations(with apiKeys: [TranslationProvider: String]?) {
        if let deepseekKey = apiKeys?[.deepseekV3], !deepseekKey.isEmpty {
            // DeepSeek V3
            apiConfigurations[.deepseekV3] = APIConfiguration(
                baseURL: "https://api.deepseek.com/v1/chat/completions",
                apiKey: deepseekKey,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ],
                maxTokens: 1000,
                model: "deepseek-chat"
            )
        }
    }
    
    private func setupQwenConfigurations(with apiKeys: [TranslationProvider: String]?) {
        // Qwen Max
        if let qwenKey = apiKeys?[.qwenMax], !qwenKey.isEmpty {
            apiConfigurations[.qwenMax] = APIConfiguration(
                baseURL: "https://api.openai.com/v1/chat/completions", // 通过OpenAI兼容接口
                apiKey: qwenKey,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ],
                maxTokens: 1000,
                model: "qwen-max"
            )
        }
    }
    
    private func setupDoubaoConfigurations(with apiKeys: [TranslationProvider: String]?) {
        if let doubaoKey = apiKeys?[.doubaoLite], !doubaoKey.isEmpty {
            // 豆包 Lite
            apiConfigurations[.doubaoLite] = APIConfiguration(
                baseURL: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
                apiKey: doubaoKey,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ],
                maxTokens: 1000,
                model: "doubao-lite-4k"
            )
            
            // 豆包 Pro
            apiConfigurations[.doubaoPro] = APIConfiguration(
                baseURL: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
                apiKey: doubaoKey,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ],
                maxTokens: 1000,
                model: "doubao-pro-4k"
            )
        }
    }
    
    private func setupTraditionalTranslationConfigurations(with apiKeys: [TranslationProvider: String]?) {
        // Google Translate
        if let googleKey = apiKeys?[.google], !googleKey.isEmpty {
            apiConfigurations[.google] = APIConfiguration(
                baseURL: "https://translation.googleapis.com/language/translate/v2",
                apiKey: googleKey,
                headers: ["Content-Type": "application/json"],
                maxTokens: 5000,
                model: "nmt"
            )
        }
        
        // 百度翻译
        if let baiduKey = apiKeys?[.baidu], !baiduKey.isEmpty {
            apiConfigurations[.baidu] = APIConfiguration(
                baseURL: "https://fanyi-api.baidu.com/api/trans/vip/translate",
                apiKey: baiduKey,
                headers: ["Content-Type": "application/x-www-form-urlencoded"],
                maxTokens: 6000,
                model: "standard"
            )
        }
        
        // 腾讯翻译
        if let tencentKey = apiKeys?[.tencent], !tencentKey.isEmpty {
            apiConfigurations[.tencent] = APIConfiguration(
                baseURL: "https://tmt.tencentcloudapi.com",
                apiKey: tencentKey,
                headers: ["Content-Type": "application/json; charset=utf-8"],
                maxTokens: 5000,
                model: "tmt"
            )
        }
    }
    
    private func setupLegacyConfigurations(with apiKeys: [TranslationProvider: String]?) {
        // 兼容性配置 - 保留旧的通用提供商以确保向后兼容
        
        // OpenAI (通用)
        if let openaiKey = apiKeys?[.openai], !openaiKey.isEmpty {
            apiConfigurations[.openai] = APIConfiguration(
                baseURL: "https://api.openai.com/v1/chat/completions",
                apiKey: openaiKey,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ],
                maxTokens: 1000,
                model: "gpt-4"
            )
        }
        
        // Gemini (通用) - ClawCloud
        // 使用tankoni token进行ClawCloud认证
        apiConfigurations[.gemini] = APIConfiguration(
            baseURL: "https://xxobadygvwbx.ap-southeast-1.clawcloudrun.com/v1/chat/completions",
            apiKey: "tankoni",
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer {API_KEY}"
            ],
            maxTokens: 2000,
            model: "gemini-2.0-flash"
        )
        
        // Gemini Direct (通用) - 使用Google API密钥作为备用方案
        let geminiDirectKey = getUserGeminiAPIKey()
        let geminiBackupKey = getUserGeminiBackupAPIKey()
        if !geminiDirectKey.isEmpty {
            apiConfigurations[.geminiDirect] = APIConfiguration(
                baseURL: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
                apiKey: geminiDirectKey,
                secretKey: geminiBackupKey,
                headers: ["Content-Type": "application/json"],
                maxTokens: 2000,
                model: "gemini-2.0-flash"
            )
        }
        
        // DeepSeek (通用)
        if let deepseekKey = apiKeys?[.deepseek], !deepseekKey.isEmpty {
            apiConfigurations[.deepseek] = APIConfiguration(
                baseURL: "https://api.deepseek.com/v1/chat/completions",
                apiKey: deepseekKey,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ],
                maxTokens: 1000,
                model: "deepseek-chat"
            )
        }
        
        // 豆包 (通用)
        if let doubaoKey = apiKeys?[.doubao], !doubaoKey.isEmpty {
            apiConfigurations[.doubao] = APIConfiguration(
                baseURL: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
                apiKey: doubaoKey,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ],
                maxTokens: 1000,
                model: "doubao-lite-4k"
            )
        }
    }
    
    // MARK: - Public Methods
    
    /// 设置API密钥
    func setAPIKey(_ key: String, for provider: TranslationProvider) {
        apiConfigurations[provider]?.apiKey = key
        logger.info("API key set for provider: \(provider)")
    }
    
    /// 设置当前提供者
    func setCurrentProvider(_ provider: TranslationProvider) {
        currentProvider = provider
        logger.info("Current provider set to: \(provider)")
    }
    
    /// 设置选择的AI模型（用于动态模型选择）
    func setSelectedAIModel(_ model: AIModel) {
        selectedAIModel = model
        updateAPIConfigurationsForModel(model)
        logger.info("Selected AI model set to: \(model.displayName)")
    }
    
    /// 获取可用的提供者列表
    func getAvailableProviders() -> [TranslationProvider] {
        return apiConfigurations.compactMap { (provider, config) in
            config.isConfigured ? provider : nil
        }
    }
    
    /// 检查提供者是否可用
    func isProviderAvailable(_ provider: TranslationProvider) -> Bool {
        return apiConfigurations[provider]?.isConfigured ?? false
    }
    
    // MARK: - Translation Methods
    
    /// 翻译文本
    func translate(
        _ text: String,
        context: String,
        type: TranslationType,
        provider: TranslationProvider? = nil
    ) async throws -> Translation {
        let targetProvider = provider ?? currentProvider
        
        // 检查速率限制
        try await rateLimiter.checkLimit(for: targetProvider)
        
        // 获取API配置
        guard let config = apiConfigurations[targetProvider],
              config.isConfigured else {
            throw AppError.translationProviderNotConfigured("Provider \(targetProvider) not configured")
        }
        
        // 执行翻译（带重试机制）
        let startTime = Date()
        
        do {
            let translation = try await errorHandler.executeWithRetry {
                try await self.performTranslation(
                    text: text,
                    context: context,
                    type: type,
                    config: config,
                    provider: targetProvider
                )
            }
            
            let duration = Date().timeIntervalSince(startTime)
            errorHandler.logSuccess(
                provider: targetProvider,
                duration: duration,
                textLength: text.count
            )
            
            return translation
            
        } catch {
            errorHandler.logError(error, context: "translate", provider: targetProvider, text: text)
            
            // 根据错误类型确定恢复策略
            let recoveryStrategy = errorHandler.determineRecoveryStrategy(for: error, provider: targetProvider)
            
            switch recoveryStrategy {
            case .fallback(let fallbackProvider):
                if apiConfigurations[fallbackProvider]?.isConfigured == true {
                    logger.info("Trying fallback provider: \(fallbackProvider)")
                    return try await translate(text, context: context, type: type, provider: fallbackProvider)
                }
            case .cache:
                // 这里可以尝试从缓存获取近似结果
                break
            default:
                break
            }
            
            throw errorHandler.convertToAppError(error, context: "Translation with \(targetProvider)")
        }
    }
    
    // MARK: - Private Translation Methods
    
    private func performTranslation(
        text: String,
        context: String,
        type: TranslationType,
        config: APIConfiguration,
        provider: TranslationProvider
    ) async throws -> Translation {
        switch provider {
        // Gemini系列模型
        case .gemini25pro, .gemini25flash, .gemini20flash, .gemini20flashSpark, .gemini15pro, .gemini15flash:
            return try await translateWithGeminiDirect(text: text, context: context, type: type, config: config)
        
        // GPT系列模型
        case .gpt35turbo, .gpt4, .gpt4turbo, .gpt4o, .gpt4omini:
            return try await translateWithChatAPI(text: text, context: context, type: type, config: config, provider: provider)
        
        // Claude系列模型
        case .claude3haiku, .claude3sonnet, .claude3opus, .claude35sonnet:
            return try await translateWithChatAPI(text: text, context: context, type: type, config: config, provider: provider)
        
        // DeepSeek系列模型
        case .deepseekV3:
            return try await translateWithChatAPI(text: text, context: context, type: type, config: config, provider: provider)
        
        // Qwen系列模型
        case .qwenMax:
            return try await translateWithChatAPI(text: text, context: context, type: type, config: config, provider: provider)
        
        // 豆包系列模型
        case .doubaoLite, .doubaoPro:
            return try await translateWithChatAPI(text: text, context: context, type: type, config: config, provider: provider)
        
        // 传统翻译服务
        case .google:
            return try await translateWithGoogleAPI(text: text, context: context, type: type, config: config)
        case .baidu:
            return try await translateWithBaiduAPI(text: text, context: context, type: type, config: config)
        case .tencent:
            return try await translateWithTencentAPI(text: text, context: context, type: type, config: config)
        
        // 兼容性提供者（保留旧的通用提供商）
        case .gemini:
            return try await translateWithGeminiClawCloud(text: text, context: context, type: type, config: config)
        case .geminiDirect:
            return try await translateWithGeminiDirect(text: text, context: context, type: type, config: config)
        case .openai, .doubao, .deepseek:
            return try await translateWithChatAPI(text: text, context: context, type: type, config: config, provider: provider)
        
        // 本地模型
        case .local:
            throw AppError.translationInvalidProvider("Local provider not supported in online translation")
        
        // 默认情况（用于处理未来可能添加的新provider）
        @unknown default:
            throw AppError.translationInvalidProvider("Unknown provider: \(provider)")
        }
    }
    
    // MARK: - Chat API Translation (OpenAI, Doubao, DeepSeek)
    
    private func translateWithChatAPI(
        text: String,
        context: String,
        type: TranslationType,
        config: APIConfiguration,
        provider: TranslationProvider
    ) async throws -> Translation {
        let prompt = buildTranslationPrompt(text: text, context: context, type: type)
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a professional English-Chinese translator. Provide accurate translations with contextual understanding."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": config.maxTokens,
            "temperature": 0.3,
            "response_format": ["type": "json_object"]
        ]
        
        let response = try await makeAPIRequest(config: config, body: requestBody)
        return try parseChatAPIResponse(response, originalText: text, provider: provider)
    }
    
    private func buildTranslationPrompt(text: String, context: String, type: TranslationType) -> String {
        let typeDescription = switch type {
        case .word: "单词"
        case .sentence: "句子"
        case .paragraph: "段落"
        }
        
        var prompt = """
        请翻译以下英文\(typeDescription)为中文，并提供详细的语法分析。
        
        原文：\(text)
        """
        
        if !context.isEmpty {
            prompt += "\n上下文：\(context)"
        }
        
        prompt += """
        
        请以JSON格式返回结果，包含以下字段：
        {
            "translation": "翻译结果",
            "confidence": 0.95,
            "contextual_meaning": "上下文含义",
            "grammar_analysis": {
                "sentence_structure": "句子结构",
                "key_phrases": ["关键短语1", "关键短语2"],
                "grammar_points": ["语法要点1", "语法要点2"],
                "part_of_speech": "词性",
                "word_form": "词形"
            }
        }
        """
        
        return prompt
    }
    
    // MARK: - Connectivity Check
    
    private func checkClawCloudConnectivity(apiKey: String) async -> Bool {
        return await errorHandler.checkClawCloudConnectivityWithRetry(apiKey: apiKey)
    }
    
    private func parseChatAPIResponse(
        _ response: [String: Any],
        originalText: String,
        provider: TranslationProvider
    ) throws -> Translation {
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AppError.translationInvalidResponse("Invalid chat API response format")
        }
        
        return parseTranslationContent(content, originalText: originalText, provider: provider)
    }
    
    private func parseGeminiDirectResponse(
        _ response: [String: Any],
        originalText: String
    ) throws -> Translation {
        guard let candidates = response["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AppError.translationInvalidResponse("Invalid Gemini Direct response format")
        }
        
        return parseTranslationContent(text, originalText: originalText, provider: .geminiDirect)
    }
    
    private func parseTranslationContent(
        _ content: String,
        originalText: String,
        provider: TranslationProvider
    ) -> Translation {
        // 尝试解析JSON响应
        if let data = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            let translatedText = json["translation"] as? String ?? ""
            let confidence = json["confidence"] as? Double ?? 0.8
            let contextualMeaning = json["contextual_meaning"] as? String
            
            // 解析语法分析
            var grammarAnalysis: GrammarAnalysis?
            if let grammarData = json["grammar_analysis"] as? [String: Any] {
                grammarAnalysis = GrammarAnalysis(
                    sentenceStructure: grammarData["sentence_structure"] as? String ?? "",
                    keyPhrases: grammarData["key_phrases"] as? [String] ?? [],
                    grammarPoints: grammarData["grammar_points"] as? [String] ?? [],
                    partOfSpeech: grammarData["part_of_speech"] as? String,
                    wordForm: grammarData["word_form"] as? String
                )
            }
            
            return Translation(
                originalText: originalText,
                translatedText: translatedText,
                confidence: confidence,
                provider: provider,
                contextualMeaning: contextualMeaning,
                grammarAnalysis: grammarAnalysis
            )
        } else {
            // 如果不是JSON格式，直接使用内容作为翻译结果
            return Translation(
                originalText: originalText,
                translatedText: content,
                confidence: 0.7,
                provider: provider,
                contextualMeaning: nil,
                grammarAnalysis: nil
            )
        }
    }
    
    // MARK: - Google Translate API
    
    private func translateWithGoogleAPI(
        text: String,
        context: String,
        type: TranslationType,
        config: APIConfiguration
    ) async throws -> Translation {
        let requestBody: [String: Any] = [
            "q": text,
            "source": "en",
            "target": "zh",
            "format": "text",
            "key": config.apiKey
        ]
        
        let response = try await makeAPIRequest(config: config, body: requestBody)
        return try parseGoogleResponse(response, originalText: text)
    }
    
    private func parseGoogleResponse(
        _ response: [String: Any],
        originalText: String
    ) throws -> Translation {
        guard let data = response["data"] as? [String: Any],
              let translations = data["translations"] as? [[String: Any]],
              let firstTranslation = translations.first,
              let translatedText = firstTranslation["translatedText"] as? String else {
            throw AppError.translationInvalidResponse("Invalid Google Translate response format")
        }
        
        return Translation(
            originalText: originalText,
            translatedText: translatedText,
            confidence: 0.85,
            provider: .google,
            contextualMeaning: nil,
            grammarAnalysis: nil
        )
    }
    
    // MARK: - Baidu Translate API
    
    private func translateWithBaiduAPI(
        text: String,
        context: String,
        type: TranslationType,
        config: APIConfiguration
    ) async throws -> Translation {
        let appid = config.apiKey
        let salt = String(Int(Date().timeIntervalSince1970))
        let sign = generateBaiduSign(query: text, appid: appid, salt: salt, secretKey: config.secretKey ?? "")
        
        let requestBody: [String: Any] = [
            "q": text,
            "from": "en",
            "to": "zh",
            "appid": appid,
            "salt": salt,
            "sign": sign
        ]
        
        let response = try await makeAPIRequest(config: config, body: requestBody, method: "POST", contentType: "application/x-www-form-urlencoded")
        return try parseBaiduResponse(response, originalText: text)
    }
    
    private func generateBaiduSign(query: String, appid: String, salt: String, secretKey: String) -> String {
        let signString = "\(appid)\(query)\(salt)\(secretKey)"
        return signString.md5
    }
    
    private func parseBaiduResponse(
        _ response: [String: Any],
        originalText: String
    ) throws -> Translation {
        guard let transResult = response["trans_result"] as? [[String: Any]],
              let firstResult = transResult.first,
              let translatedText = firstResult["dst"] as? String else {
            throw AppError.translationInvalidResponse("Invalid Baidu API response format")
        }
        
        return Translation(
            originalText: originalText,
            translatedText: translatedText,
            confidence: 0.82,
            provider: .baidu,
            contextualMeaning: nil,
            grammarAnalysis: nil
        )
    }
    
    // MARK: - Gemini ClawCloud API
    
    private func translateWithGeminiClawCloud(
        text: String,
        context: String,
        type: TranslationType,
        config: APIConfiguration
    ) async throws -> Translation {
        // 检测ClawCloud连通性，使用固定的tankoni token
        let isClawCloudAvailable = await checkClawCloudConnectivity(apiKey: "tankoni")
        if !isClawCloudAvailable {
            throw AppError.translationServiceUnavailable("ClawCloud service is unavailable")
        }
        
        let prompt = buildTranslationPrompt(text: text, context: context, type: type)
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": config.maxTokens,
            "temperature": 0.3
        ]
        
        let response = try await makeAPIRequest(config: config, body: requestBody)
        return try parseChatAPIResponse(response, originalText: text, provider: .gemini)
    }
    
    // MARK: - Gemini Direct API
    
    private func translateWithGeminiDirect(
        text: String,
        context: String,
        type: TranslationType,
        config: APIConfiguration
    ) async throws -> Translation {
        let prompt = buildTranslationPrompt(text: text, context: context, type: type)
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]
        
        // 首先尝试主API密钥
        do {
            return try await performGeminiDirectRequest(
                requestBody: requestBody,
                apiKey: config.apiKey,
                baseURL: config.baseURL,
                originalText: text
            )
        } catch {
            logger.warning("主API密钥失败，尝试备用密钥: \(error.localizedDescription)")
            
            // 如果主密钥失败且有备用密钥，尝试备用密钥
            if let backupKey = config.secretKey, !backupKey.isEmpty {
                do {
                    return try await performGeminiDirectRequest(
                        requestBody: requestBody,
                        apiKey: backupKey,
                        baseURL: config.baseURL,
                        originalText: text
                    )
                } catch {
                    logger.error("备用API密钥也失败: \(error.localizedDescription)")
                    throw error
                }
            } else {
                throw error
            }
        }
    }
    
    /// 执行Gemini Direct API请求的辅助方法
    private func performGeminiDirectRequest(
        requestBody: [String: Any],
        apiKey: String,
        baseURL: String,
        originalText: String
    ) async throws -> Translation {
        // 构建带API密钥的URL
        var urlComponents = URLComponents(string: baseURL)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            throw AppError.translationInvalidConfiguration("Invalid URL configuration")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AppError.translationInvalidRequest("Failed to serialize request body: \(error.localizedDescription)")
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError(NSError(domain: "OnlineTranslationProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]))
        }
        
        guard httpResponse.statusCode == 200 else {
            logger.error("Gemini Direct API error: \(httpResponse.statusCode)")
            throw AppError.translationApiError(httpResponse.statusCode, "Gemini Direct API error")
        }
        
        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.translationInvalidResponse("Failed to parse JSON response")
        }
        
        return try parseGeminiDirectResponse(jsonResponse, originalText: originalText)
    }
    
    // MARK: - Tencent Translate API
    
    private func translateWithTencentAPI(
        text: String,
        context: String,
        type: TranslationType,
        config: APIConfiguration
    ) async throws -> Translation {
        // 腾讯云API需要特殊的签名算法
        let requestBody: [String: Any] = [
            "Action": "TextTranslate",
            "Version": "2018-03-21",
            "Region": "ap-beijing",
            "SourceText": text,
            "Source": "en",
            "Target": "zh",
            "ProjectId": 0
        ]
        
        let response = try await makeAPIRequest(config: config, body: requestBody)
        return try parseTencentResponse(response, originalText: text)
    }
    
    private func parseTencentResponse(
        _ response: [String: Any],
        originalText: String
    ) throws -> Translation {
        guard let responseData = response["Response"] as? [String: Any],
              let translatedText = responseData["TargetText"] as? String else {
            throw AppError.translationInvalidResponse("Invalid Tencent API response format")
        }
        
        return Translation(
            originalText: originalText,
            translatedText: translatedText,
            confidence: 0.83,
            provider: .tencent,
            contextualMeaning: nil,
            grammarAnalysis: nil
        )
    }
    
    // MARK: - Network Request
    
    private func makeAPIRequest(
        config: APIConfiguration,
        body: [String: Any],
        method: String = "POST",
        contentType: String? = nil
    ) async throws -> [String: Any] {
        guard let url = URL(string: config.baseURL) else {
            throw AppError.translationInvalidConfiguration("Invalid base URL configuration")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // 设置请求头
        for (key, value) in config.headers {
            let headerValue = value.replacingOccurrences(of: "{API_KEY}", with: config.apiKey)
            request.setValue(headerValue, forHTTPHeaderField: key)
        }
        
        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        
        // 设置请求体
        if contentType == "application/x-www-form-urlencoded" {
            let formData = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            request.httpBody = formData.data(using: .utf8)
        } else {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        // 发送请求
        let (data, response) = try await urlSession.data(for: request)
        
        // 检查响应状态
        if let httpResponse = response as? HTTPURLResponse {
            logger.info("API Response - Status: \(httpResponse.statusCode), URL: \(config.baseURL)")
            guard 200...299 ~= httpResponse.statusCode else {
                var errorMessage = "❌ HTTP error: \(httpResponse.statusCode)"
                
                // 尝试解析错误响应体
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Response body: \(responseString)")
                    errorMessage += ", Response: \(responseString)"
                }
                
                // 尝试解析JSON错误信息
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorDict = errorData["error"] as? [String: Any],
                       let message = errorDict["message"] as? String {
                        errorMessage += ", API Message: \(message)"
                    } else if let message = errorData["message"] as? String {
                        errorMessage += ", Message: \(message)"
                    }
                }
                
                logger.error("\(errorMessage)")
                throw AppError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            }
        }
        
        // 解析响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.translationInvalidResponse("Failed to parse JSON response")
        }
        
        return json
    }
    
    // MARK: - Helper Methods
    
    private func getFallbackProvider(excluding: TranslationProvider) -> TranslationProvider? {
        let availableProviders = getAvailableProviders().filter { $0 != excluding }
        return availableProviders.first
    }
}

// MARK: - Supporting Types

struct APIConfiguration {
    var baseURL: String
    var apiKey: String
    var secretKey: String?
    let headers: [String: String]
    let maxTokens: Int
    var model: String
    
    var isConfigured: Bool {
        return !apiKey.isEmpty
    }
}

// MARK: - Rate Limiter

class RateLimiter: @unchecked Sendable {
    private var requestCounts: [TranslationProvider: (count: Int, resetTime: Date)] = [:]
    private let queue = DispatchQueue(label: "com.en01.translation.ratelimiter")
    
    // 每个提供者的速率限制（每分钟请求数）
    private let limits: [TranslationProvider: Int] = [
        // GPT系列模型
        .gpt35turbo: 60,
        .gpt4: 60,
        .gpt4turbo: 60,
        .gpt4o: 60,
        .gpt4omini: 60,
        
        // Claude系列模型
        .claude3haiku: 60,
        .claude3sonnet: 60,
        .claude3opus: 60,
        .claude35sonnet: 60,
        
        // Gemini系列模型
        .gemini25pro: 60,
        .gemini25flash: 60,
        .gemini20flash: 60,
        .gemini20flashSpark: 60,
        .gemini15pro: 60,
        .gemini15flash: 60,
        
        // DeepSeek系列模型
        .deepseekV3: 60,
        
        // Qwen系列模型
        .qwenMax: 60,
        
        // 豆包系列模型
        .doubaoLite: 60,
        .doubaoPro: 60,
        
        // 传统翻译服务
        .google: 100,
        .baidu: 100,
        .tencent: 100,
        
        // 本地模型
        .local: 0, // 本地模型无速率限制
        
        // 兼容性配置（旧的通用提供商）
        .gemini: 60,
        .geminiDirect: 60,
        .openai: 60,
        .doubao: 60,
        .deepseek: 60
    ]
    
    func checkLimit(for provider: TranslationProvider) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let now = Date()
                let limit = self.limits[provider] ?? 60
                
                if let record = self.requestCounts[provider] {
                    if now > record.resetTime {
                        // 重置计数
                        self.requestCounts[provider] = (count: 1, resetTime: now.addingTimeInterval(60))
                        continuation.resume()
                    } else if record.count >= limit {
                        // 超出限制
                        continuation.resume(throwing: AppError.translationRateLimitExceeded("Rate limit exceeded for provider \(provider)"))
                    } else {
                        // 增加计数
                        self.requestCounts[provider] = (count: record.count + 1, resetTime: record.resetTime)
                        continuation.resume()
                    }
                } else {
                    // 首次请求
                    self.requestCounts[provider] = (count: 1, resetTime: now.addingTimeInterval(60))
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - OnlineTranslationProvider API Key Management Extension

extension OnlineTranslationProvider {
    
    // MARK: - API Key Management
    
    /// 获取用户设置的Gemini API密钥
    private func getUserGeminiAPIKey() -> String {
        if let key = UserDefaults.standard.string(forKey: "geminiAPIKey"), !key.isEmpty {
            return key
        }
        // 默认使用用户提供的主API密钥
        return "AIzaSyCuGzUTUY_s_lB4NmKULmDqD2Z_gWsSN8w"
    }
    
    /// 获取用户设置的Gemini备用API密钥
    private func getUserGeminiBackupAPIKey() -> String {
        if let key = UserDefaults.standard.string(forKey: "geminiBackupAPIKey"), !key.isEmpty {
            return key
        }
        // 默认使用用户提供的备用API密钥
        return "AIzaSyDPnQ0nL6aqJ6mVHTa-BZGbPy2Gd_JqHo0"
    }
    
    /// 更新Gemini API密钥
    public func updateGeminiAPIKeys() {
        apiConfigurations[TranslationProvider.geminiDirect]?.apiKey = getUserGeminiAPIKey()
        apiConfigurations[TranslationProvider.geminiDirect]?.secretKey = getUserGeminiBackupAPIKey()
        logger.info("Gemini API keys updated from user settings")
    }
    
    // MARK: - Dynamic Model Selection
    
    /// 根据提供者获取当前选择的模型标识符
    private func getModelIdentifier(for provider: TranslationProvider) -> String {
        // 如果有选择的AI模型且提供者匹配，使用其模型标识符
        if let selectedModel = selectedAIModel,
           selectedModel.provider == provider {
            return selectedModel.modelIdentifier
        }
        
        // 直接使用提供者的模型标识符
        return provider.modelIdentifier
    }
    
    /// 根据选择的AI模型更新API配置
    private func updateAPIConfigurationsForModel(_ model: AIModel) {
        let provider = model.provider
        let modelIdentifier = model.modelIdentifier
        
        // 更新对应提供者的模型标识符
        if var config = apiConfigurations[provider] {
            config.model = modelIdentifier
            
            // 对于Gemini Direct，还需要更新baseURL中的模型名称
            if provider == .geminiDirect {
                config.baseURL = "https://gemini-api.apifox.cn/v1beta/models/\(modelIdentifier):generateContent"
            }
            
            apiConfigurations[provider] = config
            logger.info("Updated \(provider.displayName) configuration with model: \(modelIdentifier)")
        }
    }
}

