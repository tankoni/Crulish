//
//  TestedWordEntity+CoreDataClass.swift
//  en01
//
//  Created by SOLO Coding on 2025/1/18.
//

import Foundation
import CoreData

@objc(TestedWordEntity)
public class TestedWordEntity: NSManagedObject {
    
    /// 转换为 TestedWord 模型
    func toTestedWord() -> TestedWord? {
        guard let word = self.word,
              let dictionaryName = self.dictionaryName,
              let dictionaryFileName = self.dictionaryFileName,
              let masteryLevelRaw = self.masteryLevel,
              let masteryLevel = MasteryLevel(rawValue: masteryLevelRaw),
              let testedAt = self.testedAt else {
            return nil
        }
        
        let difficultyLevel: DifficultyLevel
        if let difficultyRaw = self.difficulty {
            difficultyLevel = DifficultyLevel(rawValue: difficultyRaw) ?? .intermediate
        } else {
            difficultyLevel = .intermediate
        }
        
        let testedWord = TestedWord(
            word: word,
            dictionaryName: dictionaryName,
            dictionaryFileName: dictionaryFileName,
            masteryLevel: masteryLevel,
            testSessionId: self.testSessionId,
            difficulty: difficultyLevel.rawValue
        )
        testedWord.testedAt = testedAt
        testedWord.responseTime = self.responseTime
        return testedWord
    }
    
    /// 从 TestedWord 模型更新实体
    func update(from testedWord: TestedWord) {
        self.word = testedWord.word
        self.dictionaryName = testedWord.dictionaryName
        self.dictionaryFileName = testedWord.dictionaryFileName
        self.masteryLevel = testedWord.masteryLevel
        self.testSessionId = testedWord.testSessionId
        self.difficulty = testedWord.difficulty
        self.testedAt = testedWord.testedAt
        self.responseTime = testedWord.responseTime
    }
}