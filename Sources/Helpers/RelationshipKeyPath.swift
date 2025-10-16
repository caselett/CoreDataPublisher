//
//  RelationshipKeyPath.swift
//  CoreDataPublisher
//
//  Created by caselet on 2/26/25.
//

import CoreData
import Foundation

/// Describes a relationship key path for a Core Data entity.
struct RelationshipKeyPath: Hashable {

    // MARK: - Init

    init?(
        keyPath: String,
        relationships: [String: NSRelationshipDescription]
    ) {
        let splittedKeyPath = keyPath.split(separator: ".")

        guard let first = splittedKeyPath.first, let last = splittedKeyPath.last else {
            return nil
        }

        sourcePropertyName = String(first)
        destinationPropertyName = String(last)

        guard let relationship = relationships[sourcePropertyName],
              let destination = relationship.destinationEntity?.name,
              let inverse = relationship.inverseRelationship?.name else {
            return nil
        }

        destinationEntityName = destination
        inverseRelationshipKeyPath = inverse

        [sourcePropertyName, destinationEntityName, destinationPropertyName].forEach { property in
            assert(!property.isEmpty, "Invalid key path is used")
        }
    }

    // MARK: - Properties

    /// The source property name of the relationship entity we're observing.
    let sourcePropertyName: String

    let destinationEntityName: String

    /// The destination property name we're observing
    let destinationPropertyName: String

    /// The inverse property name of this relationship. Can be used to get the affected object IDs.
    let inverseRelationshipKeyPath: String
}

// MARK: - Set + NSManagedObject

extension Set where Element: NSManagedObject {
    /// Iterates over the objects and returns the object IDs that matched our observing keyPaths.
    /// - Parameter keyPaths: The keyPaths to observe changes for.
    func updatedObjectIDs(for keyPaths: Set<RelationshipKeyPath>) -> Set<NSManagedObjectID>? {
        var objectIDs: Set<NSManagedObjectID> = []

        forEach { object in
            guard let changedRelationshipKeyPath = object.changedKeyPath(from: keyPaths) else {
                return
            }

            let value = object.value(forKey: changedRelationshipKeyPath.inverseRelationshipKeyPath)
            if let toManyObjects = value as? Set<NSManagedObject> {
                toManyObjects.forEach {
                    objectIDs.insert($0.objectID)
                }
            } else if let toOneObject = value as? NSManagedObject {
                objectIDs.insert(toOneObject.objectID)
            } else {
                assertionFailure("Invalid relationship observed for keyPath: \(changedRelationshipKeyPath)")
                return
            }
        }

        return objectIDs
    }
}

// MARK: - NSManagedObject + Extension

private extension NSManagedObject {

    /// Matches the given key paths to the current changes of this `NSManagedObject`.
    /// - Parameter keyPaths: The key paths to match the changes for.
    /// - Returns: The matching relationship key path if found. Otherwise, `nil`.
    func changedKeyPath(from keyPaths: Set<RelationshipKeyPath>) -> RelationshipKeyPath? {
        keyPaths.first { keyPath -> Bool in
            guard keyPath.destinationEntityName == entity.name! ||
                  keyPath.destinationEntityName == entity.superentity?.name else {
                return false
            }

            return changedValues().keys.contains(keyPath.destinationPropertyName)
        }
    }
}
