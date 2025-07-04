import Foundation
import SwiftData
import SwiftUI

@Observable
class HomeViewModel {
    private var modelContext: ModelContext?
    
    init() {
        // 初始化
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // 获取今日摘要
    func getTodaySummary() -> TodaySummary {
        // 这里应该从AppViewModel或UserProgressService获取数据
        return TodaySummary(
            readingTime: 0,
            articlesRead: 0,
            wordsLookedUp: 0,
            reviewsCompleted: 0,
            dailyReadingGoalProgress: 0.0,
            consecutiveDays: 0
        )
    }
    
    // 获取连续学习状态
    func getStreakStatus() -> StreakStatus {
        return StreakStatus(
            consecutiveDays: 0,
            hasStudiedToday: false,
            isAtRisk: false
        )
    }
}