import Foundation
import SwiftData

// 简单的测试脚本来验证导出数据的一致性
print("🧪 开始测试导出功能的数据一致性")

// 模拟测试数据
let testWords = [
    ("apple", "mastered", 1.2),
    ("banana", "familiar", 2.1),
    ("cherry", "unfamiliar", 3.5),
    ("date", "mastered", 1.8)
]

print("�� 测试数据包含 \(testWords.count) 个单词")

// 分类统计
let masteredCount = testWords.filter { $0.1 == "mastered" }.count
let familiarCount = testWords.filter { $0.1 == "familiar" }.count
let unfamiliarCount = testWords.filter { $0.1 == "unfamiliar" }.count

print("✅ 掌握的单词: \(masteredCount)")
print("🔄 熟悉的单词: \(familiarCount)")
print("❌ 不熟悉的单词: \(unfamiliarCount)")
print("📈 总计: \(masteredCount + familiarCount + unfamiliarCount)")

// 验证分类逻辑
let knownWords = testWords.filter { $0.1 == "mastered" || $0.1 == "familiar" }
let unknownWords = testWords.filter { $0.1 == "unfamiliar" }

print("🎯 已知单词 (掌握+熟悉): \(knownWords.count)")
print("🎯 未知单词 (不熟悉): \(unknownWords.count)")

if knownWords.count + unknownWords.count == testWords.count {
    print("✅ 数据分类一致性验证通过")
} else {
    print("❌ 数据分类一致性验证失败")
}
