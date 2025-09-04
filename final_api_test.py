#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
最终API测试脚本
验证修复后的所有API配置
"""

import requests
import json
import time
from typing import Dict, Any

# 修复后的配置
CLAW_CLOUD_CONFIG = {
    "base_url": "https://xxobadygvwbx.ap-southeast-1.clawcloudrun.com",
    "api_key": "tankoni",
    "model": "gemini-2.0-flash",
    "connectivity_endpoint": "/v1/models",
    "chat_endpoint": "/v1/chat/completions"
}

GEMINI_DIRECT_CONFIG = {
    "base_url": "https://gemini-api.apifox.cn",
    "api_keys": ["AIzaSyCuGzUTUY_s_lB4NmKULmDqD2Z_gWsSN8w", "AIzaSyDPnQ0nL6aqJ6mVHTa-BZGbPy2Gd_JqHo0"],
    "endpoint": "/v1beta/models/gemini-2.0-flash:generateContent"
}

def test_claw_cloud_connectivity():
    """测试ClawCloud连通性检查"""
    print("\n=== 测试ClawCloud连通性检查 ===")
    
    url = f"{CLAW_CLOUD_CONFIG['base_url']}{CLAW_CLOUD_CONFIG['connectivity_endpoint']}"
    
    try:
        response = requests.get(
            url,
            timeout=10,
            headers={
                "Authorization": f"Bearer {CLAW_CLOUD_CONFIG['api_key']}",
                "Content-Type": "application/json"
            }
        )
        
        print(f"连通性检查URL: {url}")
        print(f"状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ ClawCloud连通性检查成功")
            try:
                data = response.json()
                print(f"可用模型: {json.dumps(data, indent=2, ensure_ascii=False)[:300]}...")
            except:
                print(f"响应文本: {response.text[:300]}...")
            return True
        else:
            print(f"❌ ClawCloud连通性检查失败: {response.status_code}")
            print(f"错误响应: {response.text[:300]}")
            return False
            
    except Exception as e:
        print(f"❌ ClawCloud连通性检查异常: {e}")
        return False

def test_claw_cloud_translation():
    """测试ClawCloud翻译API"""
    print("\n=== 测试ClawCloud翻译API ===")
    
    url = f"{CLAW_CLOUD_CONFIG['base_url']}{CLAW_CLOUD_CONFIG['chat_endpoint']}"
    
    payload = {
        "model": CLAW_CLOUD_CONFIG['model'],
        "messages": [
            {
                "role": "user",
                "content": "请将以下英文翻译成中文：Hello, how are you today?"
            }
        ],
        "max_tokens": 1000,
        "temperature": 0.3
    }
    
    try:
        response = requests.post(
            url,
            json=payload,
            timeout=30,
            headers={
                "Authorization": f"Bearer {CLAW_CLOUD_CONFIG['api_key']}",
                "Content-Type": "application/json"
            }
        )
        
        print(f"翻译API URL: {url}")
        print(f"状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ ClawCloud翻译API调用成功")
            try:
                data = response.json()
                if 'choices' in data and len(data['choices']) > 0:
                    translation = data['choices'][0]['message']['content']
                    print(f"翻译结果: {translation}")
                    return True
                else:
                    print(f"响应数据格式异常: {json.dumps(data, indent=2, ensure_ascii=False)[:500]}")
                    return False
            except Exception as parse_error:
                print(f"响应解析失败: {parse_error}")
                print(f"原始响应: {response.text[:500]}")
                return False
        else:
            print(f"❌ ClawCloud翻译API调用失败: {response.status_code}")
            print(f"错误响应: {response.text[:500]}")
            return False
            
    except requests.exceptions.Timeout:
        print("❌ ClawCloud翻译API调用超时")
        return False
    except Exception as e:
        print(f"❌ ClawCloud翻译API调用异常: {e}")
        return False

def test_gemini_direct_api():
    """测试Gemini Direct API (通过Apifox镜像)"""
    print("\n=== 测试Gemini Direct API (Apifox镜像) ===")
    
    for i, api_key in enumerate(GEMINI_DIRECT_CONFIG['api_keys'], 1):
        print(f"\n--- 测试API密钥 {i} ---")
        
        url = f"{GEMINI_DIRECT_CONFIG['base_url']}{GEMINI_DIRECT_CONFIG['endpoint']}"
        
        payload = {
            "contents": [
                {
                    "parts": [
                        {
                            "text": "请将以下英文翻译成中文：Hello, how are you today?"
                        }
                    ]
                }
            ],
            "generationConfig": {
                "maxOutputTokens": 1000,
                "temperature": 0.3
            }
        }
        
        try:
            response = requests.post(
                f"{url}?key={api_key}",
                json=payload,
                timeout=30,
                headers={
                    "Content-Type": "application/json"
                }
            )
            
            print(f"API URL: {url}")
            print(f"状态码: {response.status_code}")
            
            if response.status_code == 200:
                print(f"✅ Gemini Direct API密钥 {i} 调用成功")
                try:
                    data = response.json()
                    if 'candidates' in data and len(data['candidates']) > 0:
                        content = data['candidates'][0]['content']['parts'][0]['text']
                        print(f"翻译结果: {content}")
                        return True
                    else:
                        print(f"响应数据格式异常: {json.dumps(data, indent=2, ensure_ascii=False)[:500]}")
                except Exception as parse_error:
                    print(f"响应解析失败: {parse_error}")
                    print(f"原始响应: {response.text[:500]}")
            else:
                print(f"❌ Gemini Direct API密钥 {i} 调用失败: {response.status_code}")
                print(f"错误响应: {response.text[:300]}")
                
        except requests.exceptions.Timeout:
            print(f"❌ Gemini Direct API密钥 {i} 调用超时")
        except Exception as e:
            print(f"❌ Gemini Direct API密钥 {i} 调用异常: {e}")
    
    return False

def test_translation_scenarios():
    """测试不同的翻译场景"""
    print("\n=== 测试翻译场景 ===")
    
    test_cases = [
        "Hello",
        "How are you?",
        "This is a beautiful day.",
        "The quick brown fox jumps over the lazy dog.",
        "Artificial intelligence is transforming the world."
    ]
    
    # 使用ClawCloud进行测试
    url = f"{CLAW_CLOUD_CONFIG['base_url']}{CLAW_CLOUD_CONFIG['chat_endpoint']}"
    
    success_count = 0
    total_count = len(test_cases)
    
    for i, text in enumerate(test_cases, 1):
        print(f"\n--- 测试用例 {i}: {text} ---")
        
        payload = {
            "model": CLAW_CLOUD_CONFIG['model'],
            "messages": [
                {
                    "role": "user",
                    "content": f"请将以下英文翻译成中文：{text}"
                }
            ],
            "max_tokens": 500,
            "temperature": 0.3
        }
        
        try:
            response = requests.post(
                url,
                json=payload,
                timeout=20,
                headers={
                    "Authorization": f"Bearer {CLAW_CLOUD_CONFIG['api_key']}",
                    "Content-Type": "application/json"
                }
            )
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    if 'choices' in data and len(data['choices']) > 0:
                        translation = data['choices'][0]['message']['content']
                        print(f"✅ 翻译成功: {translation}")
                        success_count += 1
                    else:
                        print(f"❌ 响应格式异常")
                except:
                    print(f"❌ 响应解析失败")
            else:
                print(f"❌ 请求失败: {response.status_code}")
                
        except Exception as e:
            print(f"❌ 请求异常: {e}")
    
    print(f"\n翻译场景测试结果: {success_count}/{total_count} 成功")
    return success_count > 0

def main():
    """主测试函数"""
    print("🔍 开始最终API测试...")
    print(f"测试时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"ClawCloud配置: {CLAW_CLOUD_CONFIG['base_url']}")
    print(f"Gemini Direct配置: {GEMINI_DIRECT_CONFIG['base_url']}")
    
    results = {
        "claw_cloud_connectivity": False,
        "claw_cloud_translation": False,
        "gemini_direct_api": False,
        "translation_scenarios": False
    }
    
    # 执行所有测试
    results["claw_cloud_connectivity"] = test_claw_cloud_connectivity()
    results["claw_cloud_translation"] = test_claw_cloud_translation()
    results["gemini_direct_api"] = test_gemini_direct_api()
    results["translation_scenarios"] = test_translation_scenarios()
    
    # 总结测试结果
    print("\n" + "="*60)
    print("📊 最终测试结果总结")
    print("="*60)
    
    test_names = {
        "claw_cloud_connectivity": "ClawCloud连通性检查",
        "claw_cloud_translation": "ClawCloud翻译API",
        "gemini_direct_api": "Gemini Direct API",
        "translation_scenarios": "翻译场景测试"
    }
    
    for test_name, result in results.items():
        status = "✅ 通过" if result else "❌ 失败"
        display_name = test_names.get(test_name, test_name)
        print(f"{display_name}: {status}")
    
    # 给出最终建议
    print("\n🎯 最终建议:")
    
    working_apis = sum(results.values())
    
    if working_apis >= 2:
        print("✅ 多个API可用，翻译功能应该能够正常工作")
        print("✅ 建议在应用中启用智能切换机制")
    elif working_apis == 1:
        print("⚠️ 只有一个API可用，建议修复其他API作为备用")
    else:
        print("❌ 所有API都不可用，需要进一步排查问题")
    
    if results["claw_cloud_translation"]:
        print("🚀 ClawCloud API可用，建议作为主要翻译服务")
    
    if results["gemini_direct_api"]:
        print("🚀 Gemini Direct API可用，建议作为备用翻译服务")
    
    print("\n📝 修复总结:")
    print("1. ✅ 更新了ClawCloud API端点从 /api/v1/chat/completions 到 /v1/chat/completions")
    print("2. ✅ 更新了连通性检查URL从 /api/v1/models 到 /v1/models")
    print("3. ✅ 配置了Gemini Direct API使用Apifox镜像")
    print("4. ✅ 保持了API密钥和认证配置")
    
    return working_apis > 0

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)