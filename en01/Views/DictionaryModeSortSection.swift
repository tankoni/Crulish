import SwiftUI

struct DictionaryModeSortSection: View {
    let selectedDictionary: DictionaryInfo?
    @Binding var selectedBasicSortOption: BasicSortOption
    @Binding var selectedKeywordSortOption: KeywordSortOption
    
    var body: some View {
        Group {
            // 词典排序模式状态显示
            Section(header: Text("当前排序状态")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "book.closed")
                            .foregroundColor(.blue)
                        Text("词典排序模式")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    Text("三层排序系统：词典匹配 → 关键词筛选 → 基础排序")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    // 排序条件逻辑介绍
                    VStack(alignment: .leading, spacing: 4) {
                        Text("排序条件逻辑：")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("• 匹配度：词典匹配词数多的文章优先")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• 难度：'掌握词/陌生词'比例高的文章优先（容易理解的优先）")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• 推荐度：综合权重评分（匹配度40% + 难度30% + 生词占比20% + 文章长度10%）")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• 生词数量：陌生词多的文章优先")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• 文章长度：文章总词数/词典匹配词数比例小的优先")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    
                    if let dictionary = selectedDictionary {
                        HStack {
                            Text("选中词典:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(dictionary.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // 基础排序选项
            Section("基础排序") {
                ForEach(BasicSortOption.allCases, id: \.self) { option in
                    SortOptionRow(
                        option: option.rawValue,
                        isSelected: selectedBasicSortOption == option
                    ) {
                        selectedBasicSortOption = option
                    }
                }
            }
            
            // 关键词排序选项
            Section(header: Text("关键词筛选（可选）"), footer: Text("词典模式下的三层排序：\n1. 文章按词典匹配词数排序\n2. 根据关键词筛选文章\n3. 在筛选结果中按基础条件排序")
                .font(.caption)
                .foregroundColor(.secondary)) {
                ForEach(KeywordSortOption.allCases, id: \.self) { option in
                    SortOptionRow(
                        option: option.rawValue,
                        isSelected: selectedKeywordSortOption == option
                    ) {
                        selectedKeywordSortOption = option
                    }
                }
            }
        }
    }
}

// 排序选项行组件
struct SortOptionRow: View {
    let option: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Text(option)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}