import Foundation
import SwiftUI

/// 成就进度数据结构
struct AchievementProgress: Identifiable, Codable {
    let id = UUID()
    let type: AchievementType
    let current: Int
    let required: Int
    let progress: Double
    let title: String
    let description: String
    let iconName: String
    let color: Color
    
    init(type: AchievementType, current: Int, required: Int, title: String, description: String, iconName: String = "star.fill", color: Color = .blue) {
        self.type = type
        self.current = current
        self.required = required
        self.progress = required > 0 ? Double(current) / Double(required) : 0
        self.title = title
        self.description = description
        self.iconName = iconName
        self.color = color
    }
    
    enum CodingKeys: String, CodingKey {
        case type, current, required, progress, title, description, iconName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(AchievementType.self, forKey: .type)
        current = try container.decode(Int.self, forKey: .current)
        required = try container.decode(Int.self, forKey: .required)
        progress = try container.decode(Double.self, forKey: .progress)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        iconName = try container.decode(String.self, forKey: .iconName)
        color = .blue // 默认颜色，实际应该根据成就类型设置
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(current, forKey: .current)
        try container.encode(required, forKey: .required)
        try container.encode(progress, forKey: .progress)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(iconName, forKey: .iconName)
    }
}