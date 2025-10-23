// 修复Preview中Mock服务使用的脚本
// 这个文件用于记录需要修复的Preview文件列表

/*
需要修复的文件：
1. StatisticsExportView.swift - 行725-730
2. KaoyanDictionaryStatusView.swift - 行274-275
3. VocabularyTestView.swift - 行1094-1096
4. SettingsView.swift - 行738-756
5. TestResultView.swift - 行649-658
6. TestHistoryListView.swift - 行481-487
7. HybridReaderView.swift - 行650-653
8. VocabularyView.swift - 行1129-1131
9. StatisticsView.swift - 行718-723
10. DictionarySelectionView.swift - 行415-421
11. HomeView.swift - 行604-606
12. ContinuousTextView.swift - 行315

修复策略：
- 将直接实例化的Mock服务改为使用ServiceContainer.shared.getXXXService()
- 对于Preview特有的Mock服务，需要先在ServiceContainer中注入Mock实现
*/