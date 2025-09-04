//
//  CryptoExtensions.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation
import CryptoKit

// MARK: - String Crypto Extensions

extension String {
    /// 计算字符串的MD5哈希值
    var md5: String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// 计算字符串的SHA256哈希值
    var sha256: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Data Crypto Extensions

extension Data {
    /// 计算Data的MD5哈希值
    var md5: String {
        let hash = Insecure.MD5.hash(data: self)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// 计算Data的SHA256哈希值
    var sha256: String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}