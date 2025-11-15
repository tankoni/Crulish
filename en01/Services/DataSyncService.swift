import Foundation
import SwiftData
import Combine

/// 数据同步服务 - 负责词典专属记录与总记录间的智能同步
@MainActor
class DataSyncService: ObservableObject {
    
    // MARK: - Properties
    
    private var modelContext: ModelContext
    private let errorHandler: ErrorHandler
    private let cacheSyncManager: CacheSyncManager
    private var syncQueue = DispatchQueue(label: "com.crulish.datasync", qos: .utility)
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.3
    
    // 同步状态跟踪
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    
    // 同步统计
    private var syncStats = SyncStatistics()
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, errorHandler: ErrorHandler, cacheSyncManager: CacheSyncManager = CacheSyncManager.shared) {
        self.modelContext = modelContext
        self.errorHandler = errorHandler
        self.cacheSyncManager = cacheSyncManager
        
        // 设置缓存失效监听器
        setupCacheInvalidationListeners()
    }
    
    // MARK: - Public Sync Methods
    
    /// 立即同步单个测试记录
    func syncTestRecord(_ testRecord: TestedWord, dictionaryFileName: String) async {
        await performSync {
            try await self.syncSingleTestRecord(testRecord, dictionaryFileName: dictionaryFileName)
        }
    }
    
    /// 延迟同步（防抖处理）
    func debouncedSync(for dictionaryFileName: String) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { _ in
            Task { @MainActor in
                await self.syncDictionaryRecords(dictionaryFileName)
            }
        }
    }
    
    /// 同步整个词典的记录
    func syncDictionaryRecords(_ dictionaryFileName: String) async {
        await performSync {
            try await self.performDictionarySync(dictionaryFileName)
        }
    }
    
    /// 全量数据同步（应用启动时调用）
    func performFullSync() async {
        await performSync {
            try await self.performFullDataSync()
            let syncedUserWords = try await self.syncUserWordsToGeneralTestedRecords()
            print("✅ [DataSyncService] 用户学习记录同步到总测试记录: 更新 \(syncedUserWords) 条")
        }
    }

    /// 将用户学习记录同步到通用测试记录（轻量入口）
    func syncUserWordsToGeneral() async {
        await performSync {
            let _ = try await self.syncUserWordsToGeneralTestedRecords()
        }
    }

    func propagateMasteryAcrossAllDictionaries(word: String, newMastery: MasteryLevel) async {
        await performSync {
            try await self.updateMasteryForAllDictionaries(word: word, newMastery: newMastery)
        }
    }

    func forceSetMasteryForWordsAcrossAllDictionaries(words: [String], newMastery: MasteryLevel) async {
        await performSync {
            try await self.forceUpdateMasteryForWordsAcrossAllDictionaries(words: words, newMastery: newMastery)
        }
    }
    
    /// 检查并修复数据一致性
    func validateAndRepairDataConsistency() async -> DataConsistencyReport {
        return await performSafeOperation("数据一致性检查") {
            try await self.checkDataConsistency()
        } ?? DataConsistencyReport()
    }
    
    // MARK: - Private Sync Implementation
    
    private func performSync(_ operation: @escaping () async throws -> Void) async {
        do {
            isSyncing = true
            try await operation()
            lastSyncTime = Date()
            print("✅ [DataSyncService] 同步操作完成")
        } catch {
            print("❌ [DataSyncService] 同步失败: \(error.localizedDescription)")
            errorHandler.handle(error, context: "数据同步失败")
        }
        isSyncing = false
    }
    
    private func syncSingleTestRecord(_ testRecord: TestedWord, dictionaryFileName: String) async throws {
        let word = testRecord.word.lowercased()
        
        // 获取相关的测试记录
        let (dictionaryRecords, generalRecords) = try await getRelatedTestRecords(for: word, dictionaryFileName: dictionaryFileName)
        
        // 执行智能合并
        let mergedRecord = performIntelligentMerge(
            dictionaryRecords: dictionaryRecords,
            generalRecords: generalRecords,
            newRecord: testRecord
        )
        
        // 更新或创建总记录
        try await updateOrCreateGeneralRecord(mergedRecord, for: word)
        
        // 更新统计
        syncStats.recordSync(type: .singleRecord)
        
        // 触发相关缓存失效
        invalidateRelatedCaches(for: "单个记录同步", dictionaryFileName: dictionaryFileName)
        
        print("✅ [DataSyncService] 单词 '\(word)' 同步完成")
    }
    
    private func performDictionarySync(_ dictionaryFileName: String) async throws {
        print("🔄 [DataSyncService] 开始同步词典: \(dictionaryFileName)")
        
        // 获取词典专属记录
        let dictionaryRecords = try await getDictionarySpecificRecords(dictionaryFileName)
        
        var syncedCount = 0
        
        // 按单词分组处理
        let groupedRecords = Dictionary(grouping: dictionaryRecords) { $0.word.lowercased() }
        
        for (word, records) in groupedRecords {
            // 获取该单词的总记录
            let generalRecords = try await getGeneralRecords(for: word)
            
            // 执行智能合并
            let mergedRecord = performIntelligentMerge(
                dictionaryRecords: records,
                generalRecords: generalRecords
            )
            
            // 更新总记录
            try await updateOrCreateGeneralRecord(mergedRecord, for: word)
            syncedCount += 1
        }
        
        syncStats.recordSync(type: .dictionaryBatch, count: syncedCount)
        
        // 触发相关缓存失效
        invalidateRelatedCaches(for: "词典批量同步", dictionaryFileName: dictionaryFileName)
        
        print("✅ [DataSyncService] 词典 \(dictionaryFileName) 同步完成，处理 \(syncedCount) 个单词")
    }
    
    private func performFullDataSync() async throws {
        print("🔄 [DataSyncService] 开始全量数据同步")
        
        // 获取所有词典文件名
        let dictionaryNames = try await getAllDictionaryNames()
        
        var totalSynced = 0
        
        for dictionaryName in dictionaryNames {
            try await performDictionarySync(dictionaryName)
            totalSynced += 1
        }

        // 去重与规范化所有词典的测试记录
        let dedupChanges = try await deduplicateAllDictionaries()
        print("✅ [DataSyncService] 去重规范化完成，合并删除重复记录: \(dedupChanges) 条")
        
        // 执行数据一致性检查
        let consistencyReport = try await checkDataConsistency()
        
        syncStats.recordSync(type: .fullSync, count: totalSynced)
        
        // 触发全局缓存失效
        invalidateRelatedCaches(for: "全量同步")
        
        print("✅ [DataSyncService] 全量同步完成，处理 \(totalSynced) 个词典")
        print("📊 [DataSyncService] 一致性检查: \(consistencyReport.summary)")
    }

    // MARK: - Deduplication

    func deduplicateDictionaryRecords(_ dictionaryFileName: String) async {
        _ = await performSafeOperation("去重规范化词典记录") {
            let service = DictionarySpecificImportExportService(modelContext: self.modelContext)
            return try await service.deduplicateAndNormalizeDictionaryRecords(dictionaryFileName: dictionaryFileName)
        }
    }

    func deduplicateAllDictionaries() async throws -> Int {
        let namesFromTests = try await getAllDictionaryNames()
        let namesFromRecords = try getAllDictionaryNamesFromTestedWords()
        let allNames = Array(Set(namesFromTests + namesFromRecords)).filter { !$0.isEmpty }
        var changes = 0
        let service = DictionarySpecificImportExportService(modelContext: self.modelContext)
        for name in allNames {
            do {
                let c = try await service.deduplicateAndNormalizeDictionaryRecords(dictionaryFileName: name)
                changes += c
            } catch {
                print("⚠️ [DataSyncService] 去重失败: \(name) -> \(error.localizedDescription)")
            }
        }
        return changes
    }

    /// 将用户学习记录(UserWord)同步为通用(General)测试记录，供未测试过滤使用
    private func syncUserWordsToGeneralTestedRecords() async throws -> Int {
        let context = modelContext
        let userWords = try context.fetch(FetchDescriptor<UserWord>())
        guard !userWords.isEmpty else { return 0 }
        let generalTest = try await getOrCreateGeneralTest()
        var updated = 0
        for uw in userWords {
            let word = uw.word.lowercased()
            let existingRecords = try await getGeneralRecords(for: word)
            if let existing = existingRecords.first {
                let current = MasteryLevel(rawValue: existing.masteryLevel) ?? .unfamiliar
                if uw.masteryLevel > current {
                    existing.masteryLevel = uw.masteryLevel.rawValue
                    existing.lastTestedDate = Date()
                    existing.testCount = max(existing.testCount, 1)
                    updated += 1
                }
            } else {
                let newRecord = TestedWord(
                    word: word,
                    dictionaryName: "General",
                    dictionaryFileName: "general",
                    masteryLevel: uw.masteryLevel,
                    testSessionId: generalTest.id
                )
                newRecord.testCount = 1
                newRecord.correctCount = uw.masteryLevel == .mastered ? 1 : 0
                newRecord.lastTestedDate = Date()
                context.insert(newRecord)
                updated += 1
            }
        }
        try context.save()
        invalidateRelatedCaches(for: "用户学习记录同步到总测试")
        return updated
    }

    private func getAllDictionaryNamesFromTestedWords() throws -> [String] {
        let descriptor = FetchDescriptor<TestedWord>()
        let records = try modelContext.fetch(descriptor)
        return Array(Set(records.map { $0.dictionaryFileName }))
    }

    private func getSingleTestedWord(word: String, dictionaryFileName: String) throws -> TestedWord? {
        let lowercasedWord = word.lowercased()
        let descriptor = FetchDescriptor<TestedWord>(
            predicate: #Predicate<TestedWord> { r in
                r.word == lowercasedWord && r.dictionaryFileName == dictionaryFileName
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func updateMasteryForAllDictionaries(word: String, newMastery: MasteryLevel) async throws {
        var names: [String] = []
        let fromTests = try await getAllDictionaryNames()
        let fromRecords = try getAllDictionaryNamesFromTestedWords()
        names = Array(Set(fromTests + fromRecords + ["general"]))
        var updatedCount = 0
        for name in names {
            do {
                if let existing = try getSingleTestedWord(word: word, dictionaryFileName: name) {
                    let current = MasteryLevel(rawValue: existing.masteryLevel) ?? .unfamiliar
                    if newMastery > current {
                        existing.masteryLevel = newMastery.rawValue
                        existing.lastTestedDate = Date()
                        existing.testCount = max(existing.testCount, 1)
                        updatedCount += 1
                    }
                } else {
                    let record = TestedWord(
                        word: word.lowercased(),
                        dictionaryName: name == "general" ? "General" : name,
                        dictionaryFileName: name,
                        masteryLevel: newMastery
                    )
                    record.testCount = 1
                    record.lastTestedDate = Date()
                    modelContext.insert(record)
                    updatedCount += 1
                }
            } catch {
                continue
            }
        }
        try modelContext.save()
        invalidateRelatedCaches(for: "跨词典掌握同步")
        print("✅ [DataSyncService] 跨词典掌握同步: \(word) -> \(newMastery.rawValue), 更新 \(updatedCount) 条")
    }

    private func forceUpdateMasteryForWordsAcrossAllDictionaries(words: [String], newMastery: MasteryLevel) async throws {
        var names: [String] = []
        let fromTests = try await getAllDictionaryNames()
        let fromRecords = try getAllDictionaryNamesFromTestedWords()
        names = Array(Set(fromTests + fromRecords + ["general"]))
        var updatedCount = 0
        let lowercasedWords = words.map { $0.lowercased() }
        for word in lowercasedWords {
            for name in names {
                do {
                    if let existing = try getSingleTestedWord(word: word, dictionaryFileName: name) {
                        existing.masteryLevel = newMastery.rawValue
                        existing.lastTestedDate = Date()
                        existing.testCount = max(existing.testCount, 1)
                        updatedCount += 1
                    } else {
                        let record = TestedWord(
                            word: word,
                            dictionaryName: name == "general" ? "General" : name,
                            dictionaryFileName: name,
                            masteryLevel: newMastery
                        )
                        record.testCount = 1
                        record.lastTestedDate = Date()
                        modelContext.insert(record)
                        updatedCount += 1
                    }
                } catch {
                    continue
                }
            }
        }
        try modelContext.save()
        invalidateRelatedCaches(for: "跨词典批量掌握同步")
        print("✅ [DataSyncService] 跨词典批量掌握同步: 目标 \(newMastery.rawValue), 处理 \(lowercasedWords.count) 个单词，更新 \(updatedCount) 条")
    }
    
    // MARK: - Intelligent Merge Logic
    
    private func performIntelligentMerge(
        dictionaryRecords: [TestedWord],
        generalRecords: [TestedWord],
        newRecord: TestedWord? = nil
    ) -> MergedTestRecord {
        
        var mergedRecord = MergedTestRecord()
        
        // 合并所有记录
        let allRecords = dictionaryRecords + generalRecords + (newRecord.map { [$0] } ?? [])
        
        guard !allRecords.isEmpty else {
            return mergedRecord
        }
        
        // 基础信息从最新记录获取
        let latestRecord = allRecords.max(by: { $0.lastTestedDate ?? $0.testedAt < $1.lastTestedDate ?? $1.testedAt })!
        
        mergedRecord.word = latestRecord.word
        mergedRecord.dictionaryFileName = latestRecord.dictionaryFileName
        mergedRecord.dictionaryName = latestRecord.dictionaryName
        mergedRecord.lastTestedDate = latestRecord.lastTestedDate
        mergedRecord.testedAt = latestRecord.testedAt
        mergedRecord.testSessionId = latestRecord.testSessionId
        
        // 统计数据合并
        mergedRecord.totalTests = allRecords.reduce(into: 0) { result, record in
            result += record.testCount
        }
        mergedRecord.correctAnswers = allRecords.reduce(into: 0) { result, record in
            result += record.correctCount
        }
        mergedRecord.incorrectAnswers = allRecords.reduce(into: 0) { result, record in
            result += (record.testCount - record.correctCount)
        }
        
        // 掌握程度取最高级别
        let masteryLevels = allRecords.map { MasteryLevel(rawValue: $0.masteryLevel) ?? .unfamiliar }
        if masteryLevels.contains(.mastered) {
            mergedRecord.masteryLevel = MasteryLevel.mastered.rawValue
        } else if masteryLevels.contains(.familiar) {
            mergedRecord.masteryLevel = MasteryLevel.familiar.rawValue
        } else {
            mergedRecord.masteryLevel = MasteryLevel.unfamiliar.rawValue
        }
        
        return mergedRecord
    }
    
    private func getRecordPriority(_ record: TestedWord) -> Int {
        // 检查是否为词典专属记录
        if let testSessionId = record.testSessionId {
            // 通过testSessionId查找对应的VocabularyTest
            let testDescriptor = FetchDescriptor<VocabularyTest>(
                predicate: #Predicate<VocabularyTest> { test in
                    test.id == testSessionId
                }
            )
            
            if let test = try? modelContext.fetch(testDescriptor).first {
                return test.isDictionarySpecific ? 2 : 1
            }
        }
        
        return 0 // 默认优先级
    }
    
    // MARK: - Data Access Methods
    
    private func getRelatedTestRecords(for word: String, dictionaryFileName: String) async throws -> ([TestedWord], [TestedWord]) {
        let lowercaseWord = word.lowercased()
        
        // 获取该单词的所有测试记录
        let allRecordsDescriptor = FetchDescriptor<TestedWord>(
            predicate: #Predicate<TestedWord> { record in
                record.word == lowercaseWord
            }
        )
        let allRecords = try modelContext.fetch(allRecordsDescriptor)
        
        // 分离词典专属记录和总记录
        var dictionaryRecords: [TestedWord] = []
        var generalRecords: [TestedWord] = []
        
        for record in allRecords {
            if let testSessionId = record.testSessionId {
                let testDescriptor = FetchDescriptor<VocabularyTest>(
                    predicate: #Predicate<VocabularyTest> { test in
                        test.id == testSessionId
                    }
                )
                
                if let test = try? modelContext.fetch(testDescriptor).first {
                    if test.isDictionarySpecific && test.dictionaryFileName == dictionaryFileName {
                        dictionaryRecords.append(record)
                    } else if !test.isDictionarySpecific {
                        generalRecords.append(record)
                    }
                }
            }
        }
        
        return (dictionaryRecords, generalRecords)
    }
    
    private func getDictionarySpecificRecords(_ dictionaryFileName: String) async throws -> [TestedWord] {
        // 获取该词典的所有专属测试
        let testsDescriptor = FetchDescriptor<VocabularyTest>(
            predicate: #Predicate<VocabularyTest> { test in
                test.dictionaryFileName == dictionaryFileName && test.isDictionarySpecific == true
            }
        )
        let tests = try modelContext.fetch(testsDescriptor)
        let testIds = Set(tests.map { $0.id })
        
        // 获取对应的测试记录
        let recordsDescriptor = FetchDescriptor<TestedWord>(
            predicate: #Predicate<TestedWord> { record in
                record.testSessionId != nil
            }
        )
        let allRecords = try modelContext.fetch(recordsDescriptor)
        let linkedRecords = allRecords.filter { record in
            guard let testSessionId = record.testSessionId else { return false }
            return testIds.contains(testSessionId)
        }

        // 兼容导入生成的“孤立记录”：没有 testSessionId，但 dictionaryFileName 匹配
        let orphanDescriptor = FetchDescriptor<TestedWord>(
            predicate: #Predicate<TestedWord> { record in
                record.testSessionId == nil && record.dictionaryFileName == dictionaryFileName
            }
        )
        let orphanRecords = try modelContext.fetch(orphanDescriptor)

        return linkedRecords + orphanRecords
    }
    
    private func getGeneralRecords(for word: String) async throws -> [TestedWord] {
        let lowercaseWord = word.lowercased()
        // 直接通过“general”字典标识获取，不要求有 testSessionId，便于修复早期孤立总记录
        let recordsDescriptor = FetchDescriptor<TestedWord>(
            predicate: #Predicate<TestedWord> { record in
                record.word == lowercaseWord && record.dictionaryFileName == "general"
            }
        )
        return try modelContext.fetch(recordsDescriptor)
    }
    
    private func updateOrCreateGeneralRecord(_ mergedRecord: MergedTestRecord, for word: String) async throws {
        // 获取或创建通用测试会话
        let generalTest = try await getOrCreateGeneralTest()

        // 查找现有的总记录（允许早期无 testSessionId 的记录）
        let existingRecords = try await getGeneralRecords(for: word)

        if let existingRecord = existingRecords.first {
            // 更新现有记录
            let totalTests = mergedRecord.totalTests ?? existingRecord.testCount
            existingRecord.testCount = max(totalTests, 1)
            existingRecord.correctCount = mergedRecord.correctAnswers ?? existingRecord.correctCount
            existingRecord.masteryLevel = mergedRecord.masteryLevel
            existingRecord.lastTestedDate = mergedRecord.lastTestedDate ?? existingRecord.lastTestedDate
            // 确保绑定到通用测试会话
            if existingRecord.testSessionId == nil {
                existingRecord.testSessionId = generalTest.id
            }
            existingRecord.dictionaryName = "General"
            existingRecord.dictionaryFileName = "general"
        } else {
            // 创建新记录（绑定通用测试会话）
            let newRecord = TestedWord(
                word: word,
                dictionaryName: "General",
                dictionaryFileName: "general",
                masteryLevel: MasteryLevel(rawValue: mergedRecord.masteryLevel) ?? .unfamiliar,
                testSessionId: generalTest.id
            )

            // 设置统计数据，至少为1次
            newRecord.testCount = max(mergedRecord.totalTests ?? 1, 1)
            newRecord.correctCount = mergedRecord.correctAnswers ?? 0
            newRecord.lastTestedDate = mergedRecord.lastTestedDate
            newRecord.testedAt = mergedRecord.testedAt

            modelContext.insert(newRecord)
        }
        
        try modelContext.save()
    }
    
    private func getOrCreateGeneralTest() async throws -> VocabularyTest {
        // 查找现有的总测试记录
        let descriptor = FetchDescriptor<VocabularyTest>(
            predicate: #Predicate<VocabularyTest> { test in
                test.isDictionarySpecific == false
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        if let existingTest = try modelContext.fetch(descriptor).first {
            return existingTest
        }
        
        // 创建新的总测试记录
        let generalTest = VocabularyTest.createGeneralRecord(dictionaryName: "General")
        modelContext.insert(generalTest)
        try modelContext.save()
        
        return generalTest
    }
    
    private func getAllDictionaryNames() async throws -> [String] {
        let descriptor = FetchDescriptor<VocabularyTest>(
            predicate: #Predicate<VocabularyTest> { test in
                test.isDictionarySpecific == true && test.dictionaryFileName != ""
            }
        )
        
        let tests = try modelContext.fetch(descriptor)
        return Array(Set(tests.map { $0.dictionaryFileName }))
    }
    
    // MARK: - Data Consistency Check
    
    private func checkDataConsistency() async throws -> DataConsistencyReport {
        var report = DataConsistencyReport()
        
        // 检查孤立的测试记录
        let orphanedRecords = try await findOrphanedTestRecords()
        report.orphanedRecords = orphanedRecords.count
        
        // 检查重复记录
        let duplicateRecords = try await findDuplicateRecords()
        report.duplicateRecords = duplicateRecords.count
        
        // 检查数据不一致
        let inconsistentRecords = try await findInconsistentRecords()
        report.inconsistentRecords = inconsistentRecords.count
        
        report.isHealthy = report.orphanedRecords == 0 && report.duplicateRecords == 0 && report.inconsistentRecords == 0
        
        return report
    }
    
    private func findOrphanedTestRecords() async throws -> [TestedWord] {
        let allRecords = try modelContext.fetch(FetchDescriptor<TestedWord>())
        var orphaned: [TestedWord] = []
        
        for record in allRecords {
            if let testSessionId = record.testSessionId {
                let testDescriptor = FetchDescriptor<VocabularyTest>(
                    predicate: #Predicate<VocabularyTest> { test in
                        test.id == testSessionId
                    }
                )
                
                if try modelContext.fetch(testDescriptor).isEmpty {
                    orphaned.append(record)
                }
            }
        }
        
        return orphaned
    }
    
    private func findDuplicateRecords() async throws -> [TestedWord] {
        let allRecords = try modelContext.fetch(FetchDescriptor<TestedWord>())
        let grouped = Dictionary(grouping: allRecords) { record in
            "\(record.word.lowercased())_\(record.testSessionId?.uuidString ?? "nil")"
        }
        
        return grouped.values.filter { $0.count > 1 }.flatMap { $0 }
    }
    
    private func findInconsistentRecords() async throws -> [TestedWord] {
        // 这里可以添加更多的一致性检查逻辑
        return []
    }
    
    // MARK: - Utility Methods
    
    private func performSafeOperation<T>(_ operation: String, _ block: () async throws -> T) async -> T? {
        do {
            let result = try await block()
            print("✅ [DataSyncService] \(operation) 成功")
            return result
        } catch {
            print("❌ [DataSyncService] \(operation) 失败: \(error.localizedDescription)")
            errorHandler.handle(error, context: operation)
            return nil
        }
    }
    
    // MARK: - Public Statistics
    
    func getSyncStatistics() -> SyncStatistics {
        return syncStats
    }
    
    // MARK: - Cache Sync Integration
    
    /// 设置缓存失效监听器
    private func setupCacheInvalidationListeners() {
        // 设置缓存失效监听器
        cacheSyncManager.addInvalidationListener(for: "vocabulary_test_") { [weak self] cacheKey in
            Task { [weak self] in
                await self?.handleCacheInvalidation(for: cacheKey)
            }
        }
    }
    
    private func handleCacheInvalidation(for cacheKey: String) async {
        print("🔄 [DataSyncService] 处理缓存失效: \(cacheKey)")
        
        // 根据缓存键类型执行相应的同步操作
        if cacheKey.contains("vocabulary_test_") {
            await performFullSync()
        }
    }
    
    private func invalidateRelatedCaches(for operation: String, dictionaryFileName: String? = nil) {
        let cacheKeys = [
            "vocabulary_test_\(dictionaryFileName ?? "general")",
            "user_progress_",
            "statistics_",
            "tested_words_\(dictionaryFileName ?? "general")"
        ]
        
        cacheSyncManager.batchInvalidateCacheIntelligently(cacheKeys)
        print("🔄 [DataSyncService] 已失效相关缓存: \(operation)")
    }
    
    /// 执行数据一致性检查
    private func performConsistencyCheck() async {
        let report = await validateAndRepairDataConsistency()
        if !report.isHealthy {
            print("⚠️ [DataSyncService] 数据一致性检查发现问题: \(report.summary)")
        }
    }
}

// MARK: - Supporting Types

struct MergedTestRecord {
    var word: String = ""
    var dictionaryFileName: String?
    var dictionaryName: String?
    var masteryLevel: String = MasteryLevel.unfamiliar.rawValue
    var totalTests: Int?
    var correctAnswers: Int?
    var incorrectAnswers: Int?
    var lastTestedDate: Date?
    var testedAt: Date = Date()
    var testSessionId: UUID?
}

struct DataConsistencyReport {
    var isHealthy: Bool = true
    var orphanedRecords: Int = 0
    var duplicateRecords: Int = 0
    var inconsistentRecords: Int = 0
    
    var summary: String {
        if isHealthy {
            return "数据一致性良好"
        } else {
            return "发现问题: 孤立记录(\(orphanedRecords)), 重复记录(\(duplicateRecords)), 不一致记录(\(inconsistentRecords))"
        }
    }
}

struct SyncStatistics {
    private var syncCounts: [SyncType: Int] = [:]
    private var lastSyncTimes: [SyncType: Date] = [:]
    
    mutating func recordSync(type: SyncType, count: Int = 1) {
        syncCounts[type, default: 0] += count
        lastSyncTimes[type] = Date()
    }
    
    func getSyncCount(for type: SyncType) -> Int {
        return syncCounts[type, default: 0]
    }
    
    func getLastSyncTime(for type: SyncType) -> Date? {
        return lastSyncTimes[type]
    }
}

enum SyncType {
    case singleRecord
    case dictionaryBatch
    case fullSync
}
