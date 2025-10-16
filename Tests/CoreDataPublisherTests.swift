//
//  CoreDataPublisherTests.swift
//  CoreDataPublisher
//
//  Created by caselet on 2/26/25.
//

import CoreData
import XCTest

@testable import CoreDataPublisher

final class CoreDataPublisherTests: XCTestCase {
    func testCoreDataPublisher() throws {
        let name = UUID().uuidString
        let another = UUID().uuidString

        let allPublisher = CoreDataPublisher(
            request: Item.fetchRequest(),
            context: viewContext
        ).map { $0.map(ItemModel.init) }

        let allTestPublisher = TestPublisher(allPublisher.assertNoFailure())

        var allPublisherValues = try awaitPublisher(
            allTestPublisher.publisher,
            expectationCheck: {
                !$0.contains { $0.name?.contains(name) ?? false || $0.name?.contains(another) ?? false }
            }
        )

        XCTAssertFalse(allPublisherValues.contains {
            $0.name?.contains(name) ?? false || $0.name?.contains(another) ?? false
        })

        for index in 1...5 {
            let item = Item(context: viewContext)
            item.name = "\(name) \(index)"
        }

        for index in 1...5 {
            let item = Item(context: viewContext)
            item.name = "\(another) \(index)"
        }

        try saveContext()

        allPublisherValues = try awaitPublisher(
            allTestPublisher.publisher,
            expectationCheck: {
                $0.contains { $0.name?.contains(name) ?? false || $0.name?.contains(another) ?? false }
            }
        )

        XCTAssertEqual(allPublisherValues.filter { $0.name?.contains(name) ?? false }.count, 5)
        XCTAssertEqual(allPublisherValues.filter { $0.name?.contains(another) ?? false }.count, 5)
    }

    func testFilterAndSortCoreDataPublisher() throws {
        let name = UUID().uuidString
        let another = UUID().uuidString

        let filterAndSortPublisher = CoreDataPublisher(
            request: Item.fetchRequest(),
            predicate: NSPredicate(format: "%K CONTAINS %@", #keyPath(Item.name), name),
            sortDescriptors: [NSSortDescriptor(key: #keyPath(Item.name), ascending: false)],
            context: viewContext
        ).map { $0.map(ItemModel.init) }

        let filterAndSortTestPublisher = TestPublisher(filterAndSortPublisher.assertNoFailure())

        var filterAndSortPublisherValues = try awaitPublisher(
            filterAndSortTestPublisher.publisher,
            expectationCheck: { $0.isEmpty }
        )

        XCTAssert(filterAndSortPublisherValues.isEmpty)

        for index in 1...5 {
            let item = Item(context: viewContext)
            item.name = "\(name) \(index)"
        }

        for index in 1...5 {
            let item = Item(context: viewContext)
            item.name = "\(another) \(index)"
        }

        try saveContext()

        filterAndSortPublisherValues = try awaitPublisher(
            filterAndSortTestPublisher.publisher,
            expectationCheck: { $0.count > 4 }
        )

        XCTAssertEqual(filterAndSortPublisherValues.map(\.name), (1...5).map { "\(name) \($0)" }.reversed())
    }

    func testFilterAndLimitCoreDataPublisher() throws {
        let name = UUID().uuidString
        let another = UUID().uuidString

        let filterAndLimitPublisher = CoreDataPublisher(
            request: Item.fetchRequest(),
            predicate: NSPredicate(format: "%K CONTAINS %@", #keyPath(Item.name), another),
            sortDescriptors: [NSSortDescriptor(key: #keyPath(Item.name), ascending: true)],
            fetchLimit: 2,
            context: viewContext
        ).map { $0.map(ItemModel.init) }

        let filterAndLimitTestPublisher = TestPublisher(filterAndLimitPublisher.assertNoFailure())

        var filterAndLimitPublisherValues = try awaitPublisher(
            filterAndLimitTestPublisher.publisher,
            expectationCheck: { $0.isEmpty }
        )

        XCTAssert(filterAndLimitPublisherValues.isEmpty)

        for index in 1...5 {
            let item = Item(context: viewContext)
            item.name = "\(name) \(index)"
        }

        for index in 1...5 {
            let item = Item(context: viewContext)
            item.name = "\(another) \(index)"
        }

        try saveContext()

        filterAndLimitPublisherValues = try awaitPublisher(
            filterAndLimitTestPublisher.publisher,
            expectationCheck: { $0.count > 1 }
        )

        XCTAssertEqual(filterAndLimitPublisherValues.map(\.name), (1...2).map { "\(another) \($0)" })
    }

    func testCoreDataPublisherWithPath() throws {
        try testPublisher(useRelationshipKeyPaths: true)
    }

    func testCoreDataPublisherWithoutPath() throws {
        try testPublisher(useRelationshipKeyPaths: false)
    }

    func testReplacingError() throws {
        let cdPublisher = CoreDataPublisher(
            request: Item.fetchRequest(),
            context: viewContext
        ).replacingError()

        _ = try awaitPublisher(
            cdPublisher
        )
    }
}

// MARK: - Private

private extension CoreDataPublisherTests {
    var viewContext: NSManagedObjectContext {
        PersistenceController.controller.container.viewContext
    }

    func testPublisher(useRelationshipKeyPaths: Bool) throws {
        let cdPublisher = CoreDataPublisher(
            request: Item.fetchRequest(),
            relationshipKeyPathsForRefreshing: useRelationshipKeyPaths ? [#keyPath(Item.date.date)] : [],
            context: viewContext
        ).map { $0.map(ItemModel.init) }

        let testPublisher = TestPublisher(cdPublisher.assertNoFailure())

        let name = UUID().uuidString

        var publisherValues = try awaitPublisher(
            testPublisher.publisher,
            expectationCheck: { !$0.contains(where: { $0.name == name }) }
        )

        XCTAssertFalse(publisherValues.contains(where: { $0.name == name }))

        let item = Item(context: viewContext)
        item.name = name

        try saveContext()

        publisherValues = try awaitPublisher(
            testPublisher.publisher,
            expectationCheck: { $0.contains(where: { $0.name == name }) }
        )

        XCTAssert(publisherValues.contains(where: { $0.name == name }))

        let date = Date()

        let itemDate = ItemDate(context: viewContext)
        itemDate.date = date
        itemDate.item = item

        let itemDates = ItemDates(context: viewContext)
        itemDates.date = date

        item.addToDates(itemDates)

        try saveContext()

        publisherValues = try awaitPublisher(
            testPublisher.publisher,
            expectationCheck: { $0.contains(where: { $0.date == date && $0.dates.contains(date) }) }
        )

        XCTAssert(publisherValues.contains(where: { $0.date == date }))

        let date2 = Date(timeIntervalSinceNow: 30)
        itemDate.date = date2
        itemDates.date = date2

        try saveContext()

        try XCTExpectFailure(
            "Puslishers should not emit values here when path is not set",
            enabled: !useRelationshipKeyPaths
        ) {
            publisherValues = try awaitPublisher(
                testPublisher.publisher,
                expectationCheck: { $0.contains(where: { $0.dates.contains(date2) }) }
            )

            XCTAssert(publisherValues.contains(where: { $0.dates.contains(date2) }))
        }
    }

    func saveContext() throws {
        if viewContext.hasChanges {
            try viewContext.save()
        }
    }

    struct ItemModel: Equatable {
        let name: String?
        let date: Date?
        let dates: [Date]

        init(_ item: Item) {
            self.name = item.name
            self.date = item.date?.date
            self.dates = item.dates?.compactMap { ($0 as? ItemDates)?.date } ?? []
        }
    }
}
