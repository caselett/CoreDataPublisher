//
//  CoreDataPublisher.swift
//  CoreDataPublisher
//
//  Created by caselet on 2/26/25.
//

import Combine
import CoreData
import Foundation

public class CoreDataPublisher<Entity>: NSObject,
                                        NSFetchedResultsControllerDelegate,
                                        Publisher where Entity: NSManagedObject {
    public typealias Output = [Entity]
    public typealias Failure = Error

    // MARK: - Init

    public init(
        request: NSFetchRequest<Entity>,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        fetchLimit: Int? = nil,
        relationshipKeyPathsForRefreshing keyPaths: Set<String> = [],
        context: NSManagedObjectContext
    ) {
        if let predicate {
            request.predicate = predicate
        }
        if let sortDescriptors {
            request.sortDescriptors = sortDescriptors
        }
        if let fetchLimit {
            request.fetchLimit = fetchLimit
        }
        if request.sortDescriptors == nil {
            request.sortDescriptors = []
        }

        self.request = request
        self.context = context
        self.subject = CurrentValueSubject(nil)

        super.init()

        configureRelationshipKeyPathsForRefreshing(keyPaths)
    }

    // MARK: - Properties

    private let request: NSFetchRequest<Entity>
    private let context: NSManagedObjectContext
    private let subject: CurrentValueSubject<[Entity]?, Failure>
    private var resultController: NSFetchedResultsController<NSManagedObject>?
    private var subscriptions = 0
    private var keyPaths: Set<RelationshipKeyPath> = []
    private var updatedObjectIDs: Set<NSManagedObjectID> = []
    private var cancellable = [AnyCancellable]()

    // MARK: - Public

    public func receive<S>(subscriber: S) where S: Subscriber,
                                                CoreDataPublisher.Failure == S.Failure,
                                                CoreDataPublisher.Output == S.Input {
        var start = false

        objc_sync_enter(self)
        subscriptions += 1
        start = subscriptions == 1
        objc_sync_exit(self)

        if start {
            let controller = NSFetchedResultsController(
                fetchRequest: request,
                managedObjectContext: context,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            controller.delegate = self
            context.perform {
                do {
                    try controller.performFetch()
                    let result = controller.fetchedObjects ?? []
                    self.subject.send(result)
                } catch {
                    self.subject.send(completion: .failure(error))
                }
            }
            resultController = controller as? NSFetchedResultsController<NSManagedObject>
        }

        CoreDataSubscription(fetchPublisher: self, subscriber: AnySubscriber(subscriber))
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let result = controller.fetchedObjects as? [Entity] {
            // NSFetchedResultsController ignores fetchLimit
            if request.fetchLimit > 0,
               result.count > request.fetchLimit {
                subject.send(Array(result.prefix(request.fetchLimit)))
            } else {
                subject.send(result)
            }
        }
    }
}

// MARK: - Private

private extension CoreDataPublisher {
    func dropSubscription() {
        objc_sync_enter(self)
        subscriptions -= 1
        let stop = subscriptions == 0
        objc_sync_exit(self)

        if stop {
            resultController?.delegate = nil
            resultController = nil
        }
    }

    class CoreDataSubscription: Subscription {
        @discardableResult
        init(fetchPublisher: CoreDataPublisher, subscriber: AnySubscriber<Output, Failure>) {
            self.fetchPublisher = fetchPublisher

            subscriber.receive(subscription: self)

            cancellable = fetchPublisher.subject
                .compactMap { $0 }
                .sink { completion in
                    subscriber.receive(completion: completion)
                } receiveValue: { value in
                    _ = subscriber.receive(value)
                }
        }

        private var fetchPublisher: CoreDataPublisher?
        private var cancellable: AnyCancellable?

        func request(_ demand: Subscribers.Demand) { }

        func cancel() {
            cancellable?.cancel()
            cancellable = nil
            fetchPublisher?.dropSubscription()
            fetchPublisher = nil
        }
    }
}

// MARK: - RelationshipKeyPathsForRefreshing

private extension CoreDataPublisher {
    func configureRelationshipKeyPathsForRefreshing(_ keyPaths: Set<String> = []) {
        guard !keyPaths.isEmpty else {
            return
        }

        let relationships = Entity.entity().relationshipsByName

        self.keyPaths = Set(keyPaths.compactMap { RelationshipKeyPath(keyPath: $0, relationships: relationships) })

        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)
            .sink { [weak self] notification in
                self?.contextDidChangeNotification(notification: notification)
            }
            .store(in: &cancellable)

        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                self?.contextDidSaveNotification(notification: notification)
            }
            .store(in: &cancellable)
    }

    func contextDidChangeNotification(notification: Notification) {
        guard let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>,
              let updatedObjectIDs = updatedObjects.updatedObjectIDs(for: keyPaths),
              !updatedObjectIDs.isEmpty else {
            return
        }

        self.updatedObjectIDs = self.updatedObjectIDs.union(updatedObjectIDs)
    }

    func contextDidSaveNotification(notification: Notification) {
        guard !updatedObjectIDs.isEmpty,
              let fetchedObjects = resultController?.fetchedObjects as? [NSManagedObject],
              !fetchedObjects.isEmpty else {
            return
        }

        for object in fetchedObjects where updatedObjectIDs.contains(object.objectID) {
            resultController?.managedObjectContext.refresh(object, mergeChanges: true)
        }

        updatedObjectIDs.removeAll()
    }
}
