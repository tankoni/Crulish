import SwiftUI
import Charts

struct ProgressDashboardView: View {
    @ObservedObject var viewModel: ProgressViewModel
    
    init(viewModel: ProgressViewModel) {
        self.viewModel = viewModel
    }
    @State private var selectedTimeRange: TimeRange = .week
    @State private var progressData: ProgressData?
    @State private var achievements: [Achievement] = []
    @State private var isLoading = false
    @State private var isDataLoaded = false // 防止重复加载
    @State private var isShowingAchievements = false
    
    var body: some View {
        // 内部所有ProgressView引用更新为ProgressDashboardView，如果有嵌套
    }
}