//
//  ModernWordDefinitionCard.swift
//  en01
//
//  Created by AI Assistant on 2025/01/18.
//

import SwiftUI
import AVFoundation

// MARK: - 现代化单词定义卡片
struct ModernWordDefinitionCard: View {
    let word: String
    let phonetic: String
    let definitions: [String]
    let examples: [String]
    let onClose: () -> Void
    let onAddToVocabulary: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isVisible = false
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        VStack(spacing: 0) {
            // 拖拽指示器
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // 卡片内容
            VStack(alignment: .leading, spacing: 16) {
                // 标题区域
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word)
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundColor(.primary)
                        
                        if !phonetic.isEmpty {
                            HStack(spacing: 8) {
                                Text(phonetic)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    // 播放发音
                                    playPronunciation()
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 关闭按钮
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // 定义列表
                if !definitions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("释义")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(Array(definitions.enumerated()), id: \.offset) { index, definition in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                
                                Text(definition)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                        }
                    }
                }
                
                // 例句
                if !examples.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("例句")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(example)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .italic()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
                
                // 操作按钮
                HStack(spacing: 12) {
                    Button(action: onAddToVocabulary) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("加入生词本")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.blue)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        // 分享单词
                        shareWord()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                            .padding(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
        )
        .offset(y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        onClose()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
    
    // MARK: - 私有方法
    private func playPronunciation() {
        // 停止当前播放
        speechSynthesizer.stopSpeaking(at: .immediate)
        
        // 创建语音合成请求
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // 播放发音
        speechSynthesizer.speak(utterance)
    }
    
    private func shareWord() {
        // 准备分享内容
        let shareText = """
        单词: \(word)
        音标: \(phonetic)
        
        释义:
        \(definitions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        
        例句:
        \(examples.joined(separator: "\n"))
        """
        
        // 获取当前窗口场景
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        // 创建分享控制器
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // 在iPad上设置弹出框位置
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // 呈现分享界面
        rootViewController.present(activityViewController, animated: true)
    }
}

// MARK: - 预览
#Preview {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            ModernWordDefinitionCard(
                word: "longest",
                phonetic: "/ˈlɔːŋɡɪst/",
                definitions: [
                    "adj. 最长的",
                    "This has been the longest week of my life. 这是我一生中最漫长的一周。"
                ],
                examples: [
                    "The longest chapter in almost any book on baby care is devoted to feeding.",
                    "This was the longest bull run in a century of art-market history."
                ],
                onClose: { print("关闭") },
                onAddToVocabulary: { print("加入生词本") }
            )
            .padding(.horizontal, 16)
        }
    }
}