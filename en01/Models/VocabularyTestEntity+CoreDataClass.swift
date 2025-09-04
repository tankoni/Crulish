//
//  VocabularyTestEntity+CoreDataClass.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import Foundation
import CoreData

@objc(VocabularyTestEntity)
public class VocabularyTestEntity: NSManagedObject {
    
    /// 转换为VocabularyTest模型
    func toVocabularyTest() -> VocabularyTest {
        let test = VocabularyTest(dictionaryName: self.dictionaryName ?? "Unknown")
        test.id = self.id ?? UUID()
        test.testDate = self.createdAt ?? Date()
        test.totalWords = Int(self.totalWords)
        test.knownWords = Int(self.masteredCount)
        test.unknownWords = Int(self.unfamiliarCount)
        test.estimatedVocabulary = Int(self.estimatedVocabularySize)
        test.accuracy = self.accuracyPercentage
        test.isCompleted = self.isCompleted
        return test
    }
    
    /// 从VocabularyTest模型创建实体
    static func fromVocabularyTest(_ test: VocabularyTest, context: NSManagedObjectContext) -> VocabularyTestEntity {
        let entity = VocabularyTestEntity(context: context)
        entity.id = test.id
        entity.dictionaryName = test.dictionaryName
        entity.dictionaryFileName = test.dictionaryName // 使用词典名作为文件名
        entity.totalWords = Int32(test.totalWords)
        entity.masteredCount = Int32(test.knownWords)
        entity.familiarCount = 0 // VocabularyTest 模型中没有这个概念
        entity.unfamiliarCount = Int32(test.unknownWords)
        entity.estimatedVocabularySize = Int32(test.estimatedVocabulary)
        entity.accuracyPercentage = test.accuracy
        entity.createdAt = test.testDate
        entity.completedAt = test.isCompleted ? test.testDate : nil
        entity.isCompleted = test.isCompleted
        return entity
    }
}