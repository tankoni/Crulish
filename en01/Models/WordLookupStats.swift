//
//  WordLookupStats.swift
//  en01
//
//  Created by tankoni TK on 2025/7/1.
//

import Foundation

// 单词查询统计
struct WordLookupStats: Codable {
    let totalLookups: Int // 总查询次数
    let uniqueWords: Int // 唯一单词数
    let averageLookupsPerDay: Double // 日均查询次数
    let mostLookedUpWords: [WordFrequency] // 最常查询的单词
    let lookupTrend: [DailyLookupCount] // 查询趋势
    
    init(totalLookups: Int = 0, uniqueWords: Int = 0, averageLookupsPerDay: Double = 0, mostLookedUpWords: [WordFrequency] = [], lookupTrend: [DailyLookupCount] = []) {
        self.totalLookups = totalLookups
        self.uniqueWords = uniqueWords
        self.averageLookupsPerDay = averageLookupsPerDay
        self.mostLookedUpWords = mostLookedUpWords
        self.lookupTrend = lookupTrend
    }
}

// 单词频率
struct WordFrequency: Codable, Identifiable {
    let id = UUID()
    let word: String
    let count: Int
}

// 每日查询统计
struct DailyLookupCount: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}