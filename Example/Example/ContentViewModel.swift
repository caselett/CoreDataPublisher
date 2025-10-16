//
//  ContentViewModel.swift
//  Example
//
//  Created by caselet on 2/27/25.
//

import Combine
import CoreData
import CoreDataPublisher
import Foundation

class ContentViewModel: ObservableObject {

    // MARK: - Published

    @Published
    private(set) var items = [Item]()

    // MARK: - Init

    init(useKeyPath: Bool) {
        self.useKeyPath = useKeyPath

        setupBindings()
    }

    // MARK: - Properties

    private let useKeyPath: Bool

    private var viewContext: NSManagedObjectContext {
        PersistenceController.controller.container.viewContext
    }

    private var cancellable = [AnyCancellable]()
}

// MARK: - Public

extension ContentViewModel {
    func addItem() {
        let date = Date()

        let newRow = Row(context: viewContext)
        newRow.timestamp = date

        let newItem = Item(context: viewContext)
        newItem.timestamp = date
        newItem.row = newRow

        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    func editRow(for item: Item) {
        guard let row = item.row else {
            return
        }

        row.timestamp = Date(timeIntervalSinceNow: 30)

        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    func deleteItems(offsets: IndexSet) {
        offsets.map { items[$0] }.forEach(viewContext.delete)

        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

// MARK: - Bindings

private extension ContentViewModel {
    func setupBindings() {
        CoreDataPublisher(
            request: Item.fetchRequest(),
            relationshipKeyPathsForRefreshing: useKeyPath ? [#keyPath(Item.row.timestamp)] : [],
            context: viewContext
        )
        .receive(on: DispatchQueue.main)
        .replaceError(with: [])
        .sink { [weak self] in
            self?.items = $0
        }
        .store(in: &cancellable)
    }
}
