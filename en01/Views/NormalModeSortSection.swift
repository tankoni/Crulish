import SwiftUI

struct NormalModeSortSection: View {
    @Binding var selectedBasicSortOption: BasicSortOption
    @Binding var selectedKeywordSortOption: KeywordSortOption
    
    var body: some View {
        Group {
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
            Section("关键词排序（可选）") {
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