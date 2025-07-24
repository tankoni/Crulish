//
//  TabItemView.swift
//  en01
//
//  Created by AI Assistant on 2024-12-19.
//

import SwiftUI

/// 统一的 Tab 项视图，优化图标加载性能
struct TabItemView<Content: View>: View {
    let tab: TabSelection
    let content: () -> Content
    @ObservedObject var iconCache: IconCache
    
    var body: some View {
        content()
            .tabItem {
                SafeIconView(iconName: tab.iconName, iconCache: iconCache)
                Text(tab.title)
            }
            .tag(tab)
    }
}

/// 加载状态的 Tab 内容
struct LoadingTabContent: View {
    var body: some View {
        VStack(spacing: 16) {
            // 使用简单的进度指示器，避免复杂动画
            ProgressView()
                .scaleEffect(1.2)
            
            Text("加载中...")
                .foregroundColor(.secondary)
                .font(.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    TabView {
        TabItemView(
            tab: .home,
            content: {
                LoadingTabContent()
            },
            iconCache: IconCache()
        )
    }
}