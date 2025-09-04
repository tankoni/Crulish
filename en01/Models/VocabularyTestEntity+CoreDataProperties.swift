//
//  VocabularyTestEntity+CoreDataProperties.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import Foundation
import CoreData

extension VocabularyTestEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<VocabularyTestEntity> {
        return NSFetchRequest<VocabularyTestEntity>(entityName: "VocabularyTestEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var dictionaryName: String?
    @NSManaged public var dictionaryFileName: String?
    @NSManaged public var totalWords: Int32
    @NSManaged public var masteredCount: Int32
    @NSManaged public var familiarCount: Int32
    @NSManaged public var unfamiliarCount: Int32
    @NSManaged public var estimatedVocabularySize: Int32
    @NSManaged public var accuracyPercentage: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var completedAt: Date?
    @NSManaged public var isCompleted: Bool
}

extension VocabularyTestEntity: Identifiable {
    
}