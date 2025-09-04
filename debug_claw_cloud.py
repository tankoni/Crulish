#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
调试ClawCloud API的具体问题
尝试不同的请求方式和端点
"""

import requests
import json
import time

# ClawCloud配置
CLAW_CLOUD_BASE_URL = "https://xxobadygvwbx.ap-southeast-1.clawcloudrun.com"
CLAW_CLOUD_API_KEY = "tankoni"

def test_different_endpoints():
    """测试不同的API端点"""
    print("=== 测试不同的ClawCloud端点 ===")
    
    endpoints = [
        "/api/v1/chat/completions",
        "/v1/chat/completions", 
        "/api/chat/completions",
        "/chat/completions",
        "/api/v1/completions",
        "/v1/completions"
    ]
    
    payload = {
        "model": "gemini-2.0-flash",
        "messages": [
            {
                "role": "user",
                "content": "Hello"
            }
        ],
        "max_tokens": 100,
        "temperature": 0.3
    }
    
    for endpoint in endpoints:
        url = f"{CLAW_CLOUD_BASE_URL}{endpoint}"
        print(f"\n测试端点: {url}")
        
        try:
            response = requests.post(
                url,
                json=payload,
                timeout=10,
                headers={
                    "Authorization": f"Bearer {CLAW_CLOUD_API_KEY}",
                    "Content-Type": "application/json"
                }
            )
            
            print(f"状态码: {response.status_code}")
            print(f"响应头: {dict(response.headers)}")
            print(f"响应内容: {response.text[:500]}")
            
            if response.status_code == 200:
                print(f"✅ 端点 {endpoint} 工作正常")
                return endpoint
            elif response.status_code == 405:
                print(f"❌ 端点 {endpoint} 方法不允许")
            else:
                print(f"❌ 端点 {endpoint} 返回错误: {response.status_code}")
                
        except Exception as e:
            print(f"❌ 端点 {endpoint} 请求异常: {e}")
    
    return None

def test_different_methods():
    """测试不同的HTTP方法"""
    print("\n=== 测试不同的HTTP方法 ===")
    
    url = f"{CLAW_CLOUD_BASE_URL}/api/v1/chat/completions"
    
    payload = {
        "model": "gemini-2.0-flash",
        "messages": [
            {
                "role": "user",
                "content": "Hello"
            }
        ],
        "max_tokens": 100,
        "temperature": 0.3
    }
    
    methods = ["POST", "GET", "PUT", "PATCH"]
    
    for method in methods:
        print(f"\n测试方法: {method}")
        
        try:
            if method == "GET":
                response = requests.get(
                    url,
                    params=payload,
                    timeout=10,
                    headers={
                        "Authorization": f"Bearer {CLAW_CLOUD_API_KEY}"
                    }
                )
            else:
                response = requests.request(
                    method,
                    url,
                    json=payload,
                    timeout=10,
                    headers={
                        "Authorization": f"Bearer {CLAW_CLOUD_API_KEY}",
                        "Content-Type": "application/json"
                    }
                )
            
            print(f"状态码: {response.status_code}")
            print(f"响应内容: {response.text[:300]}")
            
            if response.status_code == 200:
                print(f"✅ 方法 {method} 工作正常")
                return method
            
        except Exception as e:
            print(f"❌ 方法 {method} 请求异常: {e}")
    
    return None

def test_authentication_methods():
    """测试不同的认证方式"""
    print("\n=== 测试不同的认证方式 ===")
    
    url = f"{CLAW_CLOUD_BASE_URL}/api/v1/chat/completions"
    
    payload = {
        "model": "gemini-2.0-flash",
        "messages": [
            {
                "role": "user",
                "content": "Hello"
            }
        ],
        "max_tokens": 100,
        "temperature": 0.3
    }
    
    auth_methods = [
        {"name": "Bearer Token", "headers": {"Authorization": f"Bearer {CLAW_CLOUD_API_KEY}"}},
        {"name": "API Key Header", "headers": {"X-API-Key": CLAW_CLOUD_API_KEY}},
        {"name": "API Key in URL", "headers": {}, "url_param": f"?api_key={CLAW_CLOUD_API_KEY}"},
        {"name": "Basic Auth", "headers": {"Authorization": f"Basic {CLAW_CLOUD_API_KEY}"}},
        {"name": "No Auth", "headers": {}}
    ]
    
    for auth in auth_methods:
        print(f"\n测试认证方式: {auth['name']}")
        
        request_url = url
        if "url_param" in auth:
            request_url += auth["url_param"]
        
        headers = {"Content-Type": "application/json"}
        headers.update(auth["headers"])
        
        try:
            response = requests.post(
                request_url,
                json=payload,
                timeout=10,
                headers=headers
            )
            
            print(f"状态码: {response.status_code}")
            print(f"响应内容: {response.text[:300]}")
            
            if response.status_code == 200:
                print(f"✅ 认证方式 {auth['name']} 工作正常")
                return auth
            
        except Exception as e:
            print(f"❌ 认证方式 {auth['name']} 请求异常: {e}")
    
    return None

def test_service_info():
    """获取服务信息"""
    print("\n=== 获取ClawCloud服务信息 ===")
    
    info_endpoints = [
        "/",
        "/api",
        "/api/v1",
        "/api/v1/models",
        "/v1/models",
        "/models",
        "/health",
        "/status",
        "/info"
    ]
    
    for endpoint in info_endpoints:
        url = f"{CLAW_CLOUD_BASE_URL}{endpoint}"
        print(f"\n测试信息端点: {url}")
        
        try:
            response = requests.get(
                url,
                timeout=10,
                headers={
                    "Authorization": f"Bearer {CLAW_CLOUD_API_KEY}",
                    "Content-Type": "application/json"
                }
            )
            
            print(f"状态码: {response.status_code}")
            if response.status_code == 200:
                print(f"响应内容: {response.text[:500]}")
                try:
                    data = response.json()
                    print(f"JSON数据: {json.dumps(data, indent=2, ensure_ascii=False)[:500]}")
                except:
                    pass
            else:
                print(f"错误响应: {response.text[:200]}")
                
        except Exception as e:
            print(f"请求异常: {e}")

def main():
    """主调试函数"""
    print("🔍 开始调试ClawCloud API...")
    print(f"基础URL: {CLAW_CLOUD_BASE_URL}")
    print(f"API密钥: {CLAW_CLOUD_API_KEY}")
    print(f"调试时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    # 1. 获取服务信息
    test_service_info()
    
    # 2. 测试不同端点
    working_endpoint = test_different_endpoints()
    
    # 3. 测试不同HTTP方法
    working_method = test_different_methods()
    
    # 4. 测试不同认证方式
    working_auth = test_authentication_methods()
    
    # 总结
    print("\n" + "="*50)
    print("🔧 调试结果总结")
    print("="*50)
    
    if working_endpoint:
        print(f"✅ 工作的端点: {working_endpoint}")
    else:
        print("❌ 没有找到工作的端点")
    
    if working_method:
        print(f"✅ 工作的HTTP方法: {working_method}")
    else:
        print("❌ 没有找到工作的HTTP方法")
    
    if working_auth:
        print(f"✅ 工作的认证方式: {working_auth['name']}")
    else:
        print("❌ 没有找到工作的认证方式")
    
    print("\n💡 建议:")
    print("1. 检查ClawCloud服务的API文档")
    print("2. 确认API密钥是否有效")
    print("3. 联系ClawCloud服务提供商确认正确的API使用方式")

if __name__ == "__main__":
    main()