//
//  ExportProgressManager.swift
//  en01
//
//  Created by AI Assistant on 2024/12/31.
//

import Foundation
import SwiftUI
import Combine

/// 导出进度状态
/// 导出进度状态枚举
enum ExportProgressState: Equatable {
    case idle                    // 空闲状态
    case preparing              // 准备阶段
    case waitingForDictionary   // 等待词典加载
    case processing             // 处理数据
    case generating             // 生成导出文件
    case completed              // 完成
    case failed(Error)          // 失败
    
    static func == (lhs: ExportProgressState, rhs: ExportProgressState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.preparing, .preparing),
             (.waitingForDictionary, .waitingForDictionary),
             (.processing, .processing),
             (.generating, .generating),
             (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// 导出类型
enum ExportType {
    case testResults           // 测试结果导出
    case vocabularyStatistics  // 词汇统计导出
    case fullReport           // 完整报告导出
}

/// 导出进度管理器
@MainActor
class ExportProgressManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentState: ExportProgressState = .idle
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var isExporting: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private weak var dictionaryService: DictionaryService?
    
    // MARK: - Initialization
    
    init(dictionaryService: DictionaryService) {
        self.dictionaryService = dictionaryService
        setupDictionaryObservers()
    }
    
    // MARK: - Public Methods
    
    /// 开始导出流程
    func startExport(type: ExportType) async -> Bool {
        guard !isExporting else {
            updateStatus(.failed(ProgressExportError.alreadyExporting), message: "导出正在进行中，请稍候")
            return false
        }
        
        updateStatus(.preparing, message: "准备导出...")
        
        // 检查基础词典状态
        if !(await ensureBaseDictionaryReady()) {
            updateStatus(.failed(ProgressExportError.baseDictionaryNotReady), message: "基础词典未准备就绪")
            return false
        }
        
        // 检查是否需要等待考研词典
        if await shouldWaitForKaoyanDictionary(for: type) {
            if !(await ensureKaoyanDictionaryReady()) {
                updateStatus(.failed(ProgressExportError.kaoyanDictionaryTimeout), message: "考研词典加载超时")
                return false
            }
        }
        
        updateStatus(.processing, message: "开始处理数据...")
        return true
    }
    
    /// 完成导出
    func completeExport() {
        updateStatus(.completed, message: "导出完成")
        isExporting = false
        
        // 3秒后重置状态
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            resetState()
        }
    }
    
    /// 导出失败
    func failExport(with error: Error, message: String? = nil) {
        let errorMessage = message ?? error.localizedDescription
        updateStatus(.failed(error), message: errorMessage)
        isExporting = false
        
        // 5秒后重置状态
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            resetState()
        }
    }
    
    /// 更新进度
    func updateProgress(_ progress: Double, message: String? = nil) {
        self.progress = min(max(progress, 0.0), 1.0)
        if let message = message {
            self.statusMessage = message
        }
    }
    
    /// 重置状态
    func resetState() {
        currentState = .idle
        progress = 0.0
        statusMessage = ""
        isExporting = false
    }
    
    // MARK: - Private Methods
    
    /// 设置词典状态观察者
    private func setupDictionaryObservers() {
        guard let dictionaryService = dictionaryService else { return }
        
        // 观察考研词典加载进度
        dictionaryService.$kaoyanDictionaryLoadingProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                if self?.currentState == .waitingForDictionary {
                    self?.updateProgress(progress * 0.5, message: "正在加载考研词典... \(Int(progress * 100))%")
                }
            }
            .store(in: &cancellables)
        
        // 观察考研词典加载完成
        dictionaryService.$isKaoyanDictionaryLoaded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoaded in
                if isLoaded && self?.currentState == .waitingForDictionary {
                    self?.updateProgress(0.5, message: "考研词典加载完成")
                }
            }
            .store(in: &cancellables)
    }
    
    /// 更新状态
    private func updateStatus(_ state: ExportProgressState, message: String) {
        currentState = state
        statusMessage = message
        
        // 根据状态更新进度
        switch state {
        case .idle:
            progress = 0.0
        case .preparing:
            progress = 0.1
        case .waitingForDictionary:
            progress = 0.2
        case .processing:
            progress = 0.6
        case .generating:
            progress = 0.8
        case .completed:
            progress = 1.0
        case .failed:
            progress = 0.0
        }
    }
    
    /// 确保基础词典准备就绪
    private func ensureBaseDictionaryReady() async -> Bool {
        guard let dictionaryService = dictionaryService else { return false }
        
        if dictionaryService.isBaseDictionaryReady() {
            return true
        }
        
        updateStatus(.waitingForDictionary, message: "等待基础词典加载...")
        
        // 等待最多5秒
        let startTime = Date()
        while !dictionaryService.isBaseDictionaryReady() {
            if Date().timeIntervalSince(startTime) > 5.0 {
                return false
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        return true
    }
    
    /// 确保考研词典准备就绪
    private func ensureKaoyanDictionaryReady() async -> Bool {
        guard let dictionaryService = dictionaryService else {
            print("❌ [ExportProgressManager] DictionaryService 未设置")
            return false
        }
        
        updateStatus(.waitingForDictionary, message: "等待考研词典加载...")
        
        // 使用DictionaryService的等待方法
        do {
            return try await dictionaryService.waitForKaoyanDictionary(timeout: 15.0)
        } catch {
            print("❌ [ExportProgressManager] 等待考研词典加载失败: \(error)")
            return false
        }
    }
    
    /// 判断是否需要等待考研词典
    private func shouldWaitForKaoyanDictionary(for type: ExportType) async -> Bool {
        // 对于测试结果导出，如果有考研词典的测试数据，则需要等待
        // 对于词汇统计导出，总是尝试包含考研词典数据
        // 对于完整报告，总是需要考研词典
        
        switch type {
        case .testResults:
            // 检查是否有考研词典的测试记录
            return await hasKaoyanTestData()
        case .vocabularyStatistics, .fullReport:
            return true
        }
    }
    
    /// 检查是否有考研词典的测试数据
    private func hasKaoyanTestData() async -> Bool {
        // 这里可以添加检查逻辑，暂时返回true以确保数据完整性
        return true
    }
}

// MARK: - Export Errors

/// 导出进度管理器错误枚举
enum ProgressExportError: LocalizedError {
    case alreadyExporting
    case baseDictionaryNotReady
    case kaoyanDictionaryTimeout
    case dataProcessingFailed
    case fileGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .alreadyExporting:
            return "导出正在进行中"
        case .baseDictionaryNotReady:
            return "基础词典未准备就绪"
        case .kaoyanDictionaryTimeout:
            return "考研词典加载超时"
        case .dataProcessingFailed:
            return "数据处理失败"
        case .fileGenerationFailed:
            return "文件生成失败"
        }
    }
}

// MARK: - Progress View Extension

extension ExportProgressManager {
    
    /// 获取进度条颜色
    var progressColor: Color {
        switch currentState {
        case .idle:
            return .gray
        case .preparing, .waitingForDictionary, .processing, .generating:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    /// 获取状态图标
    var statusIcon: String {
        switch currentState {
        case .idle:
            return "doc.text"
        case .preparing:
            return "gear"
        case .waitingForDictionary:
            return "book.closed"
        case .processing:
            return "cpu"
        case .generating:
            return "doc.badge.gearshape"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    /// 是否显示进度条
    var shouldShowProgress: Bool {
        switch currentState {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }
}