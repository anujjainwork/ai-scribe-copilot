//
//  CoreDataManager.swift
//  Runner
import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    let persistentContainer: NSPersistentContainer
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "DrLoggerModel")
        persistentContainer.loadPersistentStores { storeDescription, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error)")
            }
        }
    }
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // Save context helper
    func saveContext() {
        if context.hasChanges {
            do {
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                try context.save()
            } catch {
                print("Core Data save error: \(error)")
            }
        }
    }
}

