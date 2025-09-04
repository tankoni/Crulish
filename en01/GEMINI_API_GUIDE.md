# Google Gemini API 配置与使用指南

本文档详细说明如何在应用中配置和使用Google Gemini API进行翻译服务。

## 📋 目录

- [API获取指南](#api获取指南)
- [配置方式](#配置方式)
- [使用策略](#使用策略)
- [安全指南](#安全指南)
- [错误处理](#错误处理)
- [测试验证](#测试验证)

## 🔑 API获取指南

### 1. 获取API密钥

1. **访问Google AI Studio**
   - 打开 [Google AI Studio](https://aistudio.google.com/)
   - 使用您的Google账户登录

2. **创建API密钥**
   - 点击页面上的 "Get API Key" 按钮
   - 选择或创建一个Google Cloud项目
   - 生成新的API密钥

3. **复制API密钥**
   - 复制生成的API密钥（格式：`AIzaSy...`）
   - 妥善保存，稍后配置时需要使用

### 2. API密钥验证

使用以下curl命令验证您的API密钥是否有效：

```bash
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
    ]
  }'
```

**注意**: 将 `YOUR_API_KEY` 替换为您的实际API密钥。

## ⚙️ 配置方式

### 双重配置策略

应用支持两种Gemini翻译方式：

#### 1. ClawCloud代理服务（推荐）
- **优势**: 更稳定，有连通性检测
- **配置**: 使用ClawCloud提供的代理地址
- **自动检测**: 应用会自动检测ClawCloud服务可用性

#### 2. Google Gemini Direct API
- **优势**: 直接调用Google服务，无中间代理
- **配置**: 直接使用Google官方API端点
- **备用方案**: 当ClawCloud不可用时自动切换

### 当前配置的API密钥

```swift
// 主API密钥
apiKey: "AIzaSyCuGzUTUY_s_lB4NmKULmDqD2Z_gWsSN8w"

// 备用API密钥
secretKey: "AIzaSyDPnQ0nL6aqJ6mVHTa-BZGbPy2Gd_JqHo0"
```

## 🎯 使用策略

### 智能切换机制

1. **优先级顺序**:
   ```
   ClawCloud代理 → Gemini Direct主密钥 → Gemini Direct备用密钥
   ```

2. **自动故障转移**:
   - ClawCloud连通性检测失败 → 切换到Direct API
   - 主API密钥失败 → 自动尝试备用密钥
   - 所有方式失败 → 返回错误信息

3. **速率限制**:
   - 每分钟最多60次请求
   - 内置请求频率控制
   - 超限时自动等待

### API密钥轮换

```swift
// 主密钥失败时的处理逻辑
do {
    // 尝试主API密钥
    return try await performGeminiDirectRequest(apiKey: config.apiKey)
} catch {
    // 主密钥失败，尝试备用密钥
    if let backupKey = config.secretKey {
        return try await performGeminiDirectRequest(apiKey: backupKey)
    }
}
```

## 🔒 安全指南

### ⚠️ 重要安全提醒

1. **API密钥保护**
   - 不要将API密钥提交到版本控制系统
   - 不要在客户端代码中硬编码API密钥
   - 定期轮换API密钥

2. **访问限制**
   - 为API密钥添加IP地址限制
   - 设置API使用配额限制
   - 启用API密钥的应用限制

3. **监控使用**
   - 定期检查API使用情况
   - 监控异常请求模式
   - 设置使用量告警

### 最佳实践

```swift
// 推荐的配置方式
struct SecureAPIConfig {
    private let keychain = Keychain(service: "com.yourapp.api")
    
    var geminiAPIKey: String? {
        get { keychain["gemini_api_key"] }
        set { keychain["gemini_api_key"] = newValue }
    }
}
```

## 🚨 错误处理

### 常见错误码

| 错误码 | 含义 | 解决方案 |
|--------|------|----------|
| 401 | API密钥无效或过期 | 检查密钥是否正确，或重新生成 |
| 403 | API密钥权限不足 | 检查API密钥的权限设置 |
| 429 | 请求频率超限 | 等待一段时间后重试 |
| 500 | 服务器内部错误 | 稍后重试或联系技术支持 |

### 错误处理策略

```swift
switch error {
case .apiError(401):
    // API密钥无效，尝试备用密钥
    logger.warning("主API密钥无效，切换到备用密钥")
    
case .apiError(429):
    // 请求频率超限，等待后重试
    logger.info("请求频率超限，等待60秒后重试")
    
case .networkError:
    // 网络错误，切换到备用服务
    logger.error("网络连接失败，切换到ClawCloud代理")
}
```

## 🧪 测试验证

### 连通性测试

```bash
# 测试ClawCloud代理
curl -X GET "https://clawcloud.com/api/health" \
  -H "Authorization: Bearer tankoni" \
  --max-time 5

# 测试Google Direct API
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=YOUR_API_KEY" \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"contents":[{"parts":[{"text":"Hello"}]}]}'
```

### 功能测试

1. **翻译测试**
   - 测试短文本翻译
   - 测试长文本翻译
   - 测试特殊字符处理

2. **故障转移测试**
   - 模拟ClawCloud不可用
   - 模拟主API密钥失效
   - 验证自动切换机制

3. **性能测试**
   - 测试并发请求处理
   - 测试速率限制机制
   - 测试响应时间

## 📞 技术支持

如果在配置或使用过程中遇到问题：

1. **检查日志**: 查看应用日志中的详细错误信息
2. **验证配置**: 确认API密钥和配置参数正确
3. **网络检查**: 确认网络连接正常
4. **联系支持**: 如问题持续存在，请联系技术支持团队

---

**更新时间**: 2024年12月
**版本**: 1.0
**维护者**: 开发团队