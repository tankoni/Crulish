import Foundation
import SwiftData

/// 一次性数据迁移服务：规范化历史 TestedWord.masteryLevel 存储值
final class DataMigrationService {
    /// 规范化 TestedWord 的掌握程度字符串为枚举原始值（中文：生疏/熟悉/掌握）
    /// - Returns: 更新的记录数量
    @MainActor
    func normalizeTestedWordMasteryLevels(context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<TestedWord>()
        let testedWords = try context.fetch(descriptor)
        var updated = 0

        for word in testedWords {
            let canonical = word.masteryLevelEnum.rawValue
            if word.masteryLevel != canonical {
                word.masteryLevel = canonical
                updated += 1
            }
        }

        if updated > 0 {
            try context.save()
            print("✅ [DataMigration] 规范化掌握程度完成，更新 \(updated) 条 TestedWord 记录")
        } else {
            print("✅ [DataMigration] 掌握程度已规范，无需更新")
        }

        return updated
    }
}