//
//  ColorExtensions.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import SwiftUI
import UIKit

extension Color {
    /// 从十六进制字符串创建颜色
    /// - Parameter hex: 十六进制颜色字符串，支持格式："#RRGGBB"、"RRGGBB"、"#RRGGBBAA"、"RRGGBBAA"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 255) // 默认为红色，便于调试
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// 安全地从字符串创建颜色，支持十六进制和系统颜色名称
    /// - Parameter string: 颜色字符串，可以是十六进制（如"#007AFF"）或系统颜色名称
    static func from(string: String) -> Color {
        // 如果是十六进制颜色
        if string.hasPrefix("#") || string.allSatisfy({ $0.isHexDigit }) {
            return Color(hex: string)
        }
        
        // 尝试系统预定义颜色
        switch string.lowercased() {
        case "blue":
            return .blue
        case "red":
            return .red
        case "green":
            return .green
        case "yellow":
            return .yellow
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "pink":
            return .pink
        case "primary":
            return .primary
        case "secondary":
            return .secondary
        case "black":
            return .black
        case "white":
            return .white
        case "gray", "grey":
            return .gray
        case "clear":
            return .clear
        default:
            // 如果都不匹配，返回默认蓝色
            return .blue
        }
    }
}

extension UIColor {
    /// 从十六进制字符串创建UIColor
    /// - Parameter hex: 十六进制颜色字符串
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 255) // 默认为红色
        }
        
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}