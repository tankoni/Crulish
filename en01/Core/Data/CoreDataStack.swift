//
//  CoreDataStack.swift
//  en01
//
//  Created by Assistant on 2025-01-18.
//

import Foundation
import CoreData

/// CoreData堆栈管理器
class CoreDataStack {
    
    // MARK: - Properties
    
    /// 持久化容器
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "VocabularyTest")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("CoreData加载失败: \(error)")
            }
        }
        return container
    }()
    
    /// 主上下文
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    /// 后台上下文
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Initialization
    
    static let shared = CoreDataStack()
    
    private init() {}
    
    // MARK: - Core Data Saving support
    
    func saveContext() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("保存失败: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func saveBackgroundContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("后台保存失败: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}