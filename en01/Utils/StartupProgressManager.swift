import Foundation
import SwiftUI
import Combine

/// 启动进度管理器
/// 负责跟踪应用启动过程中各个阶段的进度，提供用户友好的启动状态反馈
@MainActor
class StartupProgressManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentStage: StartupStage = .initializing
    @Published var progress: Double = 0.0
    @Published var isCompleted: Bool = false
    @Published var statusMessage: String = "正在初始化..."
    @Published var detailMessage: String = ""
    
    // MARK: - Private Properties
    private var stageProgress: [StartupStage: Double] = [:]
    private let totalStages = StartupStage.allCases.count
    
    // MARK: - Initialization
    init() {
        setupInitialProgress()
    }
    
    // MARK: - Public Methods
    
    /// 更新当前阶段
    func updateStage(_ stage: StartupStage, message: String = "", detail: String = "") {
        currentStage = stage
        statusMessage = message.isEmpty ? stage.defaultMessage : message
        detailMessage = detail
        
        // 更新总体进度
        updateOverallProgress()
        
        // 检查是否完成
        if stage == .completed {
            isCompleted = true
            progress = 1.0
        }
    }
    
    /// 更新当前阶段的进度
    func updateStageProgress(_ stage: StartupStage, progress: Double) {
        stageProgress[stage] = min(max(progress, 0.0), 1.0)
        updateOverallProgress()
    }
    
    /// 标记阶段完成
    func completeStage(_ stage: StartupStage) {
        stageProgress[stage] = 1.0
        updateOverallProgress()
        
        // 自动进入下一阶段
        if let nextStage = stage.nextStage {
            updateStage(nextStage)
        }
    }
    
    /// 重置进度
    func reset() {
        currentStage = .initializing
        progress = 0.0
        isCompleted = false
        statusMessage = "正在初始化..."
        detailMessage = ""
        stageProgress.removeAll()
        setupInitialProgress()
    }
    
    // MARK: - Private Methods
    
    private func setupInitialProgress() {
        for stage in StartupStage.allCases {
            stageProgress[stage] = 0.0
        }
    }
    
    private func updateOverallProgress() {
        let completedStages = stageProgress.values.reduce(0.0, +)
        progress = completedStages / Double(totalStages)
    }
}

// MARK: - StartupStage Enum

enum StartupStage: CaseIterable {
    case initializing           // 初始化基础组件
    case loadingCoreServices   // 加载核心服务
    case loadingBusinessServices // 加载业务服务
    case loadingDictionary     // 加载基础词典
    case loadingKaoyanDict     // 加载考研词典
    case loadingOptionalServices // 加载非核心服务
    case completed             // 完成
    
    var defaultMessage: String {
        switch self {
        case .initializing:
            return "正在初始化应用..."
        case .loadingCoreServices:
            return "正在加载核心服务..."
        case .loadingBusinessServices:
            return "正在加载业务服务..."
        case .loadingDictionary:
            return "正在加载词典数据..."
        case .loadingKaoyanDict:
            return "正在加载考研词典..."
        case .loadingOptionalServices:
            return "正在加载扩展功能..."
        case .completed:
            return "启动完成"
        }
    }
    
    var nextStage: StartupStage? {
        let allCases = StartupStage.allCases
        guard let currentIndex = allCases.firstIndex(of: self),
              currentIndex + 1 < allCases.count else {
            return nil
        }
        return allCases[currentIndex + 1]
    }
}

// MARK: - StartupProgressView

struct StartupProgressView: View {
    @ObservedObject var progressManager: StartupProgressManager
    
    var body: some View {
        VStack(spacing: 20) {
            // App Logo or Icon
            Image(systemName: "book.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Crulish")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                // Progress Bar
                ProgressView(value: progressManager.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                // Status Message
                Text(progressManager.statusMessage)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Detail Message
                if !progressManager.detailMessage.isEmpty {
                    Text(progressManager.detailMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Progress Percentage
                Text("\(Int(progressManager.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

#Preview {
    let progressManager = StartupProgressManager()
    progressManager.updateStage(.loadingCoreServices, message: "正在加载核心服务...", detail: "初始化文本处理器和PDF服务")
    progressManager.updateStageProgress(.loadingCoreServices, progress: 0.6)
    
    return StartupProgressView(progressManager: progressManager)
}