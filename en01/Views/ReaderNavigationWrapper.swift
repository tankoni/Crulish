//
//  ReaderNavigationWrapper.swift
//  en01
//
//  Created by AI Assistant on 2024/12/19.
//

import SwiftUI

// MARK: - 导航栏按钮类型枚举
enum NavigationButtonType {
    case back
    case bookmark
    case share
    case settings
    case fullScreen
}

// MARK: - 统一导航栏包装器
struct ReaderNavigationWrapper<Content: View>: View {
    @State private var isFullScreen = false
    let content: Content
    let title: String
    let standardButtons: [NavigationButtonType]
    let customButtons: [AnyView]
    let onBack: () -> Void
    let onBookmark: (() -> Void)?
    let onShare: (() -> Void)?
    let onSettings: (() -> Void)?
    
    init(
        title: String,
        standardButtons: [NavigationButtonType] = [.back, .bookmark, .share, .settings],
        customButtons: [AnyView] = [],
        onBack: @escaping () -> Void,
        onBookmark: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil,
        onSettings: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.standardButtons = standardButtons
        self.customButtons = customButtons
        self.onBack = onBack
        self.onBookmark = onBookmark
        self.onShare = onShare
        self.onSettings = onSettings
        self.content = content()
    }
    
    var body: some View {
        NavigationStack {
            content
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            if value.startLocation.x < CGFloat(50) &&
                               value.translation.width > CGFloat(100) &&
                               abs(value.translation.height) < CGFloat(50) {
                                onBack()
                            }
                        }
                )
                .navigationBarHidden(isFullScreen)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // 左侧按钮组 - 始终显示返回按钮
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        backButton
                    }
                    
                    // 右侧按钮组 - 多行显示避免重叠
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        VStack(spacing: 2) {
                            // 第一行：主要操作按钮
                            HStack(spacing: 8) {
                                if standardButtons.contains(.bookmark) {
                                    bookmarkButton
                                }
                                
                                if standardButtons.contains(.share) {
                                    shareButton
                                }
                                
                                if standardButtons.contains(.settings) {
                                    settingsButton
                                }
                            }
                            
                            // 第二行：次要操作按钮和自定义按钮
                            if standardButtons.contains(.fullScreen) || !customButtons.isEmpty {
                                HStack(spacing: 8) {
                                    if standardButtons.contains(.fullScreen) {
                                        fullScreenButton
                                    }
                                    
                                    // 自定义按钮
                                    ForEach(0..<min(customButtons.count, 3), id: \.self) { index in
                                        customButtons[index]
                                    }
                                    
                                    // 如果自定义按钮超过3个，显示更多菜单
                                    if customButtons.count > 3 {
                                        Menu {
                                            ForEach(3..<customButtons.count, id: \.self) { index in
                                                customButtons[index]
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .font(.system(size: 14))
                                                .foregroundColor(.primary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
        }
    }
    
    // MARK: - 标准按钮组件
    
    private var backButton: some View {
        Button(action: onBack) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                Text("返回")
                    .font(.system(size: 16))
            }
            .foregroundColor(.primary)
        }
    }
    
    private var bookmarkButton: some View {
        Button(action: {
            onBookmark?()
        }) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
        .disabled(onBookmark == nil)
    }
    
    private var shareButton: some View {
        Button(action: {
            onShare?()
        }) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
        .disabled(onShare == nil)
    }
    
    private var settingsButton: some View {
        Button(action: {
            onSettings?()
        }) {
            Image(systemName: "textformat.size")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
        .disabled(onSettings == nil)
    }
    
    private var fullScreenButton: some View {
        Button(action: { isFullScreen.toggle() }) {
            Image(systemName: "square")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 预览
#Preview {
    ReaderNavigationWrapper(
        title: "示例标题",
        standardButtons: [.back, .bookmark, .share, .settings],
        customButtons: [
            AnyView(
                Menu {
                    Button("选项1") { }
                    Button("选项2") { }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
            )
        ],
        onBack: { print("返回") },
        onBookmark: { print("书签") },
        onShare: { print("分享") },
        onSettings: { print("设置") }
    ) {
        VStack {
            Text("内容区域")
                .font(.title)
            Spacer()
        }
        .padding()
    }
}