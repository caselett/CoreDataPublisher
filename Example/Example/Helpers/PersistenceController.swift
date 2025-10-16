//
//  PersistenceController.swift
//  Example
//
//  Created by caselet on 2/24/25.
//

import CoreData

struct PersistenceController {
    static let controller = PersistenceController(withName: PersistentContainerName.example, inMemory: true)

    private init(
        withName name: String,
        inMemory: Bool = false
    ) {
        container = NSPersistentContainer(name: name)

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
        static let example = "Example"
    }
}
