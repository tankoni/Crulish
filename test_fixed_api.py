#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试修复后的API配置
验证ClawCloud和Gemini Direct API的可用性
"""

import requests
import json
import time
from typing import Dict, Any

# 用户提供的配置信息
CLAW_CLOUD_BASE_URL = "https://xxobadygvwbx.ap-southeast-1.clawcloudrun.com"
CLAW_CLOUD_API_KEY = "tankoni"
GEMINI_API_KEYS = ["AIzaSyCuGzUTUY_s_lB4NmKULmDqD2Z_gWsSN8w", "AIzaSyDPnQ0nL6aqJ6mVHTa-BZGbPy2Gd_JqHo0"]
APPFOX_MIRROR_URL = "https://gemini-api.apifox.cn"

def test_claw_cloud_connectivity():
    """测试ClawCloud连通性检查端点"""
    print("\n=== 测试ClawCloud连通性检查 ===")
    
    connectivity_url = f"{CLAW_CLOUD_BASE_URL}/api/v1/models"
    
    try:
        response = requests.get(
            connectivity_url,
            timeout=10,
            headers={
                "Authorization": f"Bearer {CLAW_CLOUD_API_KEY}",
                "Content-Type": "application/json"
            }
        )
        
        print(f"连通性检查URL: {connectivity_url}")
        print(f"状态码: {response.status_code}")
        print(f"响应头: {dict(response.headers)}")
        
        if response.status_code == 200:
            print("✅ ClawCloud连通性检查成功")
            try:
                data = response.json()
                print(f"响应数据: {json.dumps(data, indent=2, ensure_ascii=False)}")
            except:
                print(f"响应文本: {response.text[:500]}")
            return True
        else:
            print(f"❌ ClawCloud连通性检查失败: {response.status_code}")
            print(f"错误响应: {response.text[:500]}")
            return False
            
    except requests.exceptions.Timeout:
        print("❌ ClawCloud连通性检查超时")
        return False
    except Exception as e:
        print(f"❌ ClawCloud连通性检查异常: {e}")
        return False

def test_claw_cloud_translation():
    """测试ClawCloud翻译API"""
    print("\n=== 测试ClawCloud翻译API ===")
    
    api_url = f"{CLAW_CLOUD_BASE_URL}/api/v1/chat/completions"
    
    payload = {
        "model": "gemini-2.0-flash",
        "messages": [
            {
                "role": "user",
                "content": "请将以下英文翻译成中文：Hello, how are you?"
            }
        ],
        "max_tokens": 1000,
        "temperature": 0.3
    }
    
    try:
        response = requests.post(
            api_url,
            json=payload,
            timeout=30,
            headers={
                "Authorization": f"Bearer {CLAW_CLOUD_API_KEY}",
                "Content-Type": "application/json"
            }
        )
        
        print(f"翻译API URL: {api_url}")
        print(f"状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ ClawCloud翻译API调用成功")
            try:
                data = response.json()
                if 'choices' in data and len(data['choices']) > 0:
                    translation = data['choices'][0]['message']['content']
                    print(f"翻译结果: {translation}")
                else:
                    print(f"响应数据: {json.dumps(data, indent=2, ensure_ascii=False)}")
            except:
                print(f"响应文本: {response.text[:500]}")
            return True
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
    
    for i, api_key in enumerate(GEMINI_API_KEYS, 1):
        print(f"\n--- 测试API密钥 {i} ---")
        
        api_url = f"{APPFOX_MIRROR_URL}/v1beta/models/gemini-2.0-flash:generateContent"
        
        payload = {
            "contents": [
                {
                    "parts": [
                        {
                            "text": "请将以下英文翻译成中文：Hello, how are you?"
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
                f"{api_url}?key={api_key}",
                json=payload,
                timeout=30,
                headers={
                    "Content-Type": "application/json"
                }
            )
            
            print(f"API URL: {api_url}")
            print(f"状态码: {response.status_code}")
            
            if response.status_code == 200:
                print(f"✅ Gemini Direct API密钥 {i} 调用成功")
                try:
                    data = response.json()
                    if 'candidates' in data and len(data['candidates']) > 0:
                        content = data['candidates'][0]['content']['parts'][0]['text']
                        print(f"翻译结果: {content}")
                    else:
                        print(f"响应数据: {json.dumps(data, indent=2, ensure_ascii=False)}")
                except:
                    print(f"响应文本: {response.text[:500]}")
                return True
            else:
                print(f"❌ Gemini Direct API密钥 {i} 调用失败: {response.status_code}")
                print(f"错误响应: {response.text[:500]}")
                
        except requests.exceptions.Timeout:
            print(f"❌ Gemini Direct API密钥 {i} 调用超时")
        except Exception as e:
            print(f"❌ Gemini Direct API密钥 {i} 调用异常: {e}")
    
    return False

def main():
    """主测试函数"""
    print("🔍 开始测试修复后的API配置...")
    print(f"测试时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    results = {
        "claw_cloud_connectivity": False,
        "claw_cloud_translation": False,
        "gemini_direct_api": False
    }
    
    # 测试ClawCloud连通性
    results["claw_cloud_connectivity"] = test_claw_cloud_connectivity()
    
    # 测试ClawCloud翻译API
    results["claw_cloud_translation"] = test_claw_cloud_translation()
    
    # 测试Gemini Direct API
    results["gemini_direct_api"] = test_gemini_direct_api()
    
    # 总结测试结果
    print("\n" + "="*50)
    print("📊 测试结果总结")
    print("="*50)
    
    for test_name, result in results.items():
        status = "✅ 通过" if result else "❌ 失败"
        test_display_name = {
            "claw_cloud_connectivity": "ClawCloud连通性检查",
            "claw_cloud_translation": "ClawCloud翻译API",
            "gemini_direct_api": "Gemini Direct API"
        }.get(test_name, test_name)
        
        print(f"{test_display_name}: {status}")
    
    # 给出修复建议
    print("\n🔧 修复建议:")
    
    if not results["claw_cloud_connectivity"]:
        print("- ClawCloud服务可能暂时不可用，建议检查服务状态")
    
    if not results["claw_cloud_translation"]:
        print("- ClawCloud翻译API调用失败，可能是认证或配置问题")
    
    if not results["gemini_direct_api"]:
        print("- Gemini Direct API不可用，建议检查API密钥有效性")
    
    if results["gemini_direct_api"]:
        print("- ✅ Gemini Direct API可用，建议优先使用此API")
    
    if any(results.values()):
        print("\n🎉 至少有一个API可用，翻译功能应该能够正常工作")
    else:
        print("\n⚠️ 所有API都不可用，需要进一步排查网络或配置问题")

if __name__ == "__main__":
    main()