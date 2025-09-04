#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
API连通性测试脚本
用于测试ClawCloud和Google Gemini Direct API的连通性
"""

import requests
import json
import time
from typing import Dict, Any, Optional

# API配置
CLAW_CLOUD_CONFIG = {
    "base_url": "https://xxobadygvwbx.ap-southeast-1.clawcloudrun.com",
    "api_key": "tankoni",
    "model": "gemini-2.0-flash"
}

GEMINI_DIRECT_CONFIG = {
    "base_url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
    "api_keys": [
        "AIzaSyCuGzUTUY_s_lB4NmKULmDqD2Z_gWsSN8w",
        "AIzaSyDPnQ0nL6aqJ6mVHTa-BZGbPy2Gd_JqHo0"
    ]
}

# 备用API地址
GEMINI_APIFOX_CONFIG = {
    "base_url": "https://gemini-api.apifox.cn/v1beta/models/gemini-2.0-flash:generateContent",
    "api_keys": [
        "AIzaSyCuGzUTUY_s_lB4NmKULmDqD2Z_gWsSN8w",
        "AIzaSyDPnQ0nL6aqJ6mVHTa-BZGbPy2Gd_JqHo0"
    ]
}

def test_claw_cloud_connectivity() -> bool:
    """测试ClawCloud连通性"""
    print("\n=== 测试ClawCloud连通性 ===")
    
    # 1. 测试连通性检查端点
    connectivity_url = "https://api.claw.cloud/v1/models"
    print(f"测试连通性检查URL: {connectivity_url}")
    
    try:
        response = requests.get(connectivity_url, timeout=10)
        print(f"连通性检查状态码: {response.status_code}")
        print(f"响应内容: {response.text[:500]}..." if len(response.text) > 500 else f"响应内容: {response.text}")
        
        if response.status_code != 200:
            print("❌ ClawCloud连通性检查失败")
            return False
    except Exception as e:
        print(f"❌ ClawCloud连通性检查异常: {e}")
        return False
    
    # 2. 测试实际API端点
    api_url = f"{CLAW_CLOUD_CONFIG['base_url']}/api/v1/chat/completions"
    print(f"\n测试API端点: {api_url}")
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {CLAW_CLOUD_CONFIG['api_key']}"
    }
    
    payload = {
        "model": CLAW_CLOUD_CONFIG['model'],
        "messages": [
            {
                "role": "user",
                "content": "请翻译这个英文单词：hello"
            }
        ],
        "max_tokens": 100,
        "temperature": 0.3
    }
    
    try:
        response = requests.post(api_url, headers=headers, json=payload, timeout=30)
        print(f"API请求状态码: {response.status_code}")
        print(f"响应头: {dict(response.headers)}")
        print(f"响应内容: {response.text[:1000]}..." if len(response.text) > 1000 else f"响应内容: {response.text}")
        
        if response.status_code == 200:
            print("✅ ClawCloud API测试成功")
            return True
        else:
            print("❌ ClawCloud API测试失败")
            return False
            
    except Exception as e:
        print(f"❌ ClawCloud API请求异常: {e}")
        return False

def test_gemini_direct_api(config: Dict[str, Any], name: str) -> bool:
    """测试Google Gemini Direct API"""
    print(f"\n=== 测试{name} ===")
    
    for i, api_key in enumerate(config['api_keys']):
        print(f"\n测试API密钥 {i+1}: {api_key[:20]}...")
        
        url = f"{config['base_url']}?key={api_key}"
        print(f"请求URL: {url}")
        
        headers = {
            "Content-Type": "application/json"
        }
        
        payload = {
            "contents": [
                {
                    "parts": [
                        {
                            "text": "请翻译这个英文单词：hello"
                        }
                    ]
                }
            ]
        }
        
        try:
            response = requests.post(url, headers=headers, json=payload, timeout=30)
            print(f"状态码: {response.status_code}")
            print(f"响应头: {dict(response.headers)}")
            print(f"响应内容: {response.text[:1000]}..." if len(response.text) > 1000 else f"响应内容: {response.text}")
            
            if response.status_code == 200:
                print(f"✅ {name} API密钥 {i+1} 测试成功")
                return True
            else:
                print(f"❌ {name} API密钥 {i+1} 测试失败")
                
        except Exception as e:
            print(f"❌ {name} API密钥 {i+1} 请求异常: {e}")
    
    return False

def test_network_connectivity():
    """测试基础网络连通性"""
    print("\n=== 测试基础网络连通性 ===")
    
    test_urls = [
        "https://www.google.com",
        "https://api.claw.cloud",
        "https://generativelanguage.googleapis.com",
        "https://gemini-api.apifox.cn"
    ]
    
    for url in test_urls:
        try:
            response = requests.get(url, timeout=10)
            print(f"✅ {url} - 状态码: {response.status_code}")
        except Exception as e:
            print(f"❌ {url} - 错误: {e}")

def main():
    """主函数"""
    print("开始API连通性测试...")
    print(f"测试时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    # 测试基础网络连通性
    test_network_connectivity()
    
    # 测试ClawCloud
    claw_cloud_success = test_claw_cloud_connectivity()
    
    # 测试Google Gemini Direct API
    gemini_direct_success = test_gemini_direct_api(GEMINI_DIRECT_CONFIG, "Google Gemini Direct API")
    
    # 测试备用API地址
    gemini_apifox_success = test_gemini_direct_api(GEMINI_APIFOX_CONFIG, "Gemini API (Apifox镜像)")
    
    # 总结
    print("\n=== 测试结果总结 ===")
    print(f"ClawCloud API: {'✅ 可用' if claw_cloud_success else '❌ 不可用'}")
    print(f"Google Gemini Direct API: {'✅ 可用' if gemini_direct_success else '❌ 不可用'}")
    print(f"Gemini API (Apifox镜像): {'✅ 可用' if gemini_apifox_success else '❌ 不可用'}")
    
    if not any([claw_cloud_success, gemini_direct_success, gemini_apifox_success]):
        print("\n❌ 所有API都不可用，请检查:")
        print("1. 网络连接是否正常")
        print("2. API密钥是否正确")
        print("3. API服务是否正常运行")
        print("4. 防火墙或代理设置")
    else:
        print("\n✅ 至少有一个API可用")

if __name__ == "__main__":
    main()