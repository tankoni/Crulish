#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ClawCloud认证修复验证脚本
用于测试修复后的ClawCloud连通性检查是否能够正常工作
"""

import requests
import json
from datetime import datetime

def test_claw_cloud_connectivity():
    """
    测试ClawCloud连通性检查（修复后的版本）
    """
    print("=" * 60)
    print("ClawCloud连通性检查测试（修复后）")
    print("=" * 60)
    
    # ClawCloud配置
    base_url = "https://xxobadygvwbx.ap-southeast-1.clawcloudrun.com"
    api_key = "tankoni"
    
    # 测试连通性检查端点
    connectivity_url = f"{base_url}/v1/models"
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
    
    try:
        print(f"🔍 测试连通性检查端点: {connectivity_url}")
        print(f"📋 请求头: {headers}")
        
        response = requests.get(
            connectivity_url,
            headers=headers,
            timeout=10
        )
        
        print(f"📊 响应状态码: {response.status_code}")
        print(f"📄 响应头: {dict(response.headers)}")
        
        if response.status_code == 200:
            print("✅ ClawCloud连通性检查成功！")
            try:
                response_data = response.json()
                print(f"📦 响应数据: {json.dumps(response_data, indent=2, ensure_ascii=False)}")
            except:
                print(f"📦 响应文本: {response.text[:500]}")
            return True
        else:
            print(f"❌ ClawCloud连通性检查失败 - 状态码: {response.status_code}")
            print(f"📦 错误响应: {response.text}")
            return False
            
    except requests.exceptions.Timeout:
        print("❌ 连通性检查超时")
        return False
    except requests.exceptions.RequestException as e:
        print(f"❌ 连通性检查请求异常: {e}")
        return False
    except Exception as e:
        print(f"❌ 连通性检查未知错误: {e}")
        return False

def test_claw_cloud_translation():
    """
    测试ClawCloud翻译API
    """
    print("\n" + "=" * 60)
    print("ClawCloud翻译API测试")
    print("=" * 60)
    
    # ClawCloud配置
    base_url = "https://xxobadygvwbx.ap-southeast-1.clawcloudrun.com"
    api_key = "tankoni"
    translation_url = f"{base_url}/v1/chat/completions"
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
    
    # 测试翻译请求
    test_data = {
        "model": "gemini-2.0-flash",
        "messages": [
            {
                "role": "user",
                "content": "请将以下英文翻译成中文：Hello, how are you today?"
            }
        ],
        "max_tokens": 2000,
        "temperature": 0.3
    }
    
    try:
        print(f"🔍 测试翻译API端点: {translation_url}")
        print(f"📋 请求数据: {json.dumps(test_data, indent=2, ensure_ascii=False)}")
        
        response = requests.post(
            translation_url,
            headers=headers,
            json=test_data,
            timeout=30
        )
        
        print(f"📊 响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ ClawCloud翻译API调用成功！")
            try:
                response_data = response.json()
                print(f"📦 翻译响应: {json.dumps(response_data, indent=2, ensure_ascii=False)}")
                
                # 提取翻译结果
                if 'choices' in response_data and len(response_data['choices']) > 0:
                    content = response_data['choices'][0].get('message', {}).get('content', '')
                    print(f"🎯 翻译结果: {content}")
                    
            except Exception as e:
                print(f"📦 响应解析失败: {e}")
                print(f"📦 原始响应: {response.text[:1000]}")
            return True
        else:
            print(f"❌ ClawCloud翻译API调用失败 - 状态码: {response.status_code}")
            print(f"📦 错误响应: {response.text}")
            return False
            
    except requests.exceptions.Timeout:
        print("❌ 翻译API请求超时")
        return False
    except requests.exceptions.RequestException as e:
        print(f"❌ 翻译API请求异常: {e}")
        return False
    except Exception as e:
        print(f"❌ 翻译API未知错误: {e}")
        return False

def main():
    """
    主测试函数
    """
    print(f"🚀 开始ClawCloud认证修复验证测试 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # 测试连通性检查
    connectivity_success = test_claw_cloud_connectivity()
    
    # 测试翻译API
    translation_success = test_claw_cloud_translation()
    
    # 总结测试结果
    print("\n" + "=" * 60)
    print("测试结果总结")
    print("=" * 60)
    print(f"📊 连通性检查: {'✅ 成功' if connectivity_success else '❌ 失败'}")
    print(f"📊 翻译API: {'✅ 成功' if translation_success else '❌ 失败'}")
    
    if connectivity_success and translation_success:
        print("\n🎉 所有测试通过！ClawCloud认证修复成功！")
        print("💡 建议：")
        print("   - ClawCloud服务现在应该可以正常使用")
        print("   - 连通性检查已修复，不再返回401错误")
        print("   - Gemini翻译服务应该恢复可用状态")
    elif connectivity_success:
        print("\n⚠️  连通性检查修复成功，但翻译API仍有问题")
        print("💡 建议：检查翻译API的具体配置")
    else:
        print("\n❌ 连通性检查仍然失败")
        print("💡 建议：")
        print("   - 检查API密钥是否正确")
        print("   - 检查网络连接")
        print("   - 检查ClawCloud服务状态")
    
    print(f"\n🏁 测试完成 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    main()