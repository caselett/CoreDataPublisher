//
//  PersistenceController.swift
//  CoreDataPublisher
//
//  Created by caselet on 2/26/25.
//

import CoreData
import Foundation

class PersistenceController {
    static let controller = PersistenceController(withName: PersistentContainerName.testModel, inMemory: true)

    private init(
        withName name: String,
        inMemory: Bool = false
    ) {
        guard let modelURL = Bundle.module.url(forResource: name, withExtension: "momd"),
              let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Unable to load persistent stores")
        }

        container = NSPersistentContainer(name: name, managedObjectModel: managedObjectModel)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { [weak container] _, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }

            container?.viewContext.automaticallyMergesChangesFromParent = true
            if !inMemory {
                try? container?.viewContext.setQueryGenerationFrom(.current)
            }
        }
    }

    let container: NSPersistentContainer

    enum PersistentContainerName {
        static let testModel = "TestModel"
    }
}
