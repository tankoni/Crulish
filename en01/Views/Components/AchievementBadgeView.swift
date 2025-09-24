//
//  AchievementBadgeView.swift
//  en01
//
//  Created by AI Assistant on 2024/12/30.
//

import SwiftUI

/// 成就徽章视图组件
struct AchievementBadgeView: View {
    let badge: AchievementBadgeUI
    let size: BadgeSize
    
    enum BadgeSize {
        case small, medium, large
        
        var iconSize: Font {
            switch self {
            case .small: return .caption
            case .medium: return .title2
            case .large: return .title
            }
        }
        
        var textSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .footnote
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 12
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 12
            }
        }
    }
    
    init(badge: AchievementBadgeUI, size: BadgeSize = .medium) {
        self.badge = badge
        self.size = size
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // 徽章图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [badge.color.opacity(0.8), badge.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: badge.color.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: badge.iconName)
                    .font(size.iconSize)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
            }
            .frame(
                width: iconFrameSize,
                height: iconFrameSize
            )
            
            // 徽章名称
            if size != .small {
                Text(badge.name)
                    .font(size.textSize)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }
        }
        .padding(size.padding)
        .background(
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .stroke(badge.color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var iconFrameSize: CGFloat {
        switch size {
        case .small: return 24
        case .medium: return 32
        case .large: return 48
        }
    }
}

/// 成就徽章网格视图
struct AchievementBadgeGrid: View {
    let badges: [AchievementBadgeUI]
    let columns: Int
    let size: AchievementBadgeView.BadgeSize
    
    init(badges: [AchievementBadgeUI], columns: Int = 4, size: AchievementBadgeView.BadgeSize = .medium) {
        self.badges = badges
        self.columns = columns
        self.size = size
    }
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: columns),
            spacing: 12
        ) {
            ForEach(badges) { badge in
                AchievementBadgeView(badge: badge, size: size)
            }
        }
    }
}

#Preview {
    let sampleBadges = [
        AchievementBadgeUI(
            name: "首次阅读",
            iconName: "book.fill",
            color: .blue
        ),
        AchievementBadgeUI(
            name: "词汇达人",
            iconName: "textbook.fill",
            color: .green
        ),
        AchievementBadgeUI(
            name: "学习专家",
            iconName: "graduationcap.fill",
            color: .purple
        ),
        AchievementBadgeUI(
            name: "连续学习",
            iconName: "flame.fill",
            color: .orange
        )
    ]
    
    VStack(spacing: 20) {
        Text("成就徽章")
            .font(.title2)
            .fontWeight(.bold)
        
        AchievementBadgeGrid(badges: sampleBadges)
        
        HStack {
            AchievementBadgeView(badge: sampleBadges[0], size: .small)
            AchievementBadgeView(badge: sampleBadges[1], size: .medium)
            AchievementBadgeView(badge: sampleBadges[2], size: .large)
        }
    }
    .padding()
}