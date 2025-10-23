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
    @State private var showingMenu = false
    
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
        VStack(spacing: 0) {
            // 现代化导航栏
            HStack {
                // 返回按钮 - 只显示箭头
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // 标题 - 居中显示
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                // 三点菜单按钮
                Button(action: { showingMenu = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .confirmationDialog("选项", isPresented: $showingMenu, titleVisibility: .hidden) {
                    if standardButtons.contains(.bookmark) {
                        Button(action: { onBookmark?() }) {
                            Label("书签", systemImage: "bookmark")
                        }
                        .disabled(onBookmark == nil)
                    }
                    
                    if standardButtons.contains(.share) {
                        Button(action: { onShare?() }) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        .disabled(onShare == nil)
                    }
                    
                    if standardButtons.contains(.settings) {
                        Button(action: { onSettings?() }) {
                            Label("设置", systemImage: "textformat.size")
                        }
                        .disabled(onSettings == nil)
                    }
                    
                    if standardButtons.contains(.fullScreen) {
                        Button(action: { isFullScreen.toggle() }) {
                            Label("全屏", systemImage: "square")
                        }
                    }
                    
                    Button("取消", role: .cancel) { }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator).opacity(0.3)),
                alignment: .bottom
            )
            
            // 内容区域
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