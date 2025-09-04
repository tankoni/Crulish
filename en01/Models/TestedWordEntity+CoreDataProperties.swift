//
//  TestedWordEntity+CoreDataProperties.swift
//  en01
//
//  Created by SOLO Coding on 2025/1/18.
//

import Foundation
import CoreData

extension TestedWordEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TestedWordEntity> {
        return NSFetchRequest<TestedWordEntity>(entityName: "TestedWordEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var word: String?
    @NSManaged public var dictionaryName: String?
    @NSManaged public var dictionaryFileName: String?
    @NSManaged public var masteryLevel: String?
    @NSManaged public var testedAt: Date?
    @NSManaged public var testSessionId: UUID?
    @NSManaged public var difficulty: String?
    @NSManaged public var responseTime: Double
}

// MARK: - Identifiable

extension TestedWordEntity: Identifiable {
    
}