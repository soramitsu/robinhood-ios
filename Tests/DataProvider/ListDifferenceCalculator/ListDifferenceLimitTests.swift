/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
import RobinHood

class ListDifferenceLimitTests: XCTestCase {
    let sortBlock: (FeedData, FeedData) -> Bool = { (object1, object2) -> Bool in
        return object1.name < object2.name
    }

    func testWhenObjectsInsertedInTheMiddle() {
        // given

        let totalCount = 10
        let objects = (0..<totalCount).map({ _ in createRandomFeed(in: .default) }).sorted(by: sortBlock)
        let diffCalculator = ListDifferenceCalculator(initialItems: objects,
                                                      limit: totalCount, sortBlock: sortBlock)

        // when

        var newItems: [FeedData] = []

        let targetIndex = totalCount/2 - 1

        for index in (0..<totalCount/2) {
            let newIdentifier = UUID().uuidString
            let newName = (0..<index+2)
                .map { _ in objects[targetIndex].name }
                .joined()

            let newItem = FeedData(identifier: newIdentifier,
                                   domain: .default,
                                   favorite: false,
                                   favoriteCount: 0,
                                   name: newName,
                                   description: nil,
                                   imageLink: nil,
                                   status: .open,
                                   likesCount: 0)

            newItems.append(newItem)
        }

        let changes = newItems.map { DataProviderChange.insert(newItem: $0) }

        let expectedDeletedIdentifiers  = diffCalculator.allItems[(targetIndex+1)...]
            .map { $0.identifier }
        let expectedInsertedIdentifiers = newItems.map { $0.identifier }

        diffCalculator.apply(changes: changes)

        // then

        let expectedItems = (diffCalculator.allItems[0..<targetIndex+1] + newItems)
            .sorted(by: sortBlock)

        XCTAssertEqual(expectedItems, diffCalculator.allItems)

        var deletedIdentifiers = Set<String>()
        var insertedIdentifiers = Set<String>()

        for diff in diffCalculator.lastDifferences {
            switch diff {
            case .insert(_, let newItem):
                insertedIdentifiers.insert(newItem.identifier)
            case .delete(_, let oldItem):
                deletedIdentifiers.insert(oldItem.identifier)
            case .update:
                XCTFail("Unexpected update")
            }
        }

        XCTAssertEqual(Set(expectedDeletedIdentifiers), deletedIdentifiers)
        XCTAssertEqual(Set(expectedInsertedIdentifiers), insertedIdentifiers)
    }

    func testWhenBottomObjectsInserted() {
        // given

        let totalCount = 10
        let objects = (0..<totalCount).map({ _ in createRandomFeed(in: .default) }).sorted(by: sortBlock)
        let diffCalculator = ListDifferenceCalculator(initialItems: objects,
                                                      limit: totalCount, sortBlock: sortBlock)

        // when

        var newItems: [FeedData] = []

        let newItemsCount = 10

        for index in (0..<newItemsCount) {
            let newIdentifier = UUID().uuidString
            let newName = (0..<index+2)
                .map { _ in objects[totalCount-1].name }
                .joined()

            let newItem = FeedData(identifier: newIdentifier,
                                   domain: .default,
                                   favorite: false,
                                   favoriteCount: 0,
                                   name: newName,
                                   description: nil,
                                   imageLink: nil,
                                   status: .open,
                                   likesCount: 0)

            newItems.append(newItem)
        }

        let changes = newItems.map { DataProviderChange.insert(newItem: $0) }

        let expectedItems = diffCalculator.allItems

        diffCalculator.apply(changes: changes)

        // then

        XCTAssertEqual(expectedItems, diffCalculator.allItems)
        XCTAssertTrue(diffCalculator.lastDifferences.isEmpty)
    }

    func testWhenPropertyChanges() {
        // given

        let totalCount = 10
        let objects = (0..<totalCount).map({ _ in createRandomFeed(in: .default) }).sorted(by: sortBlock)
        let diffCalculator = ListDifferenceCalculator(initialItems: objects,
                                                      limit: totalCount, sortBlock: sortBlock)

        // when

        let expectedDeletedIdentifiers  = diffCalculator.allItems[(totalCount/2)...]
        .map { $0.identifier }

        diffCalculator.limit = totalCount / 2

        // then

        XCTAssertEqual(diffCalculator.allItems.count, totalCount/2)

        var deletedIdentifiers = Set<String>()

        for diff in diffCalculator.lastDifferences {
            switch diff {
            case .delete(_, let oldItem):
                deletedIdentifiers.insert(oldItem.identifier)
            default:
                XCTFail("Unexpected update")
            }
        }

        XCTAssertEqual(Set(expectedDeletedIdentifiers), deletedIdentifiers)
    }

    func testWhenLimitedChangesToUnlimited() {
        // given

        let totalCount = 10
        let objects = (0..<totalCount).map({ _ in createRandomFeed(in: .default) }).sorted(by: sortBlock)
        let diffCalculator = ListDifferenceCalculator(initialItems: objects,
                                                      limit: totalCount, sortBlock: sortBlock)

        // when

        diffCalculator.limit = 0

        // then

        XCTAssertEqual(diffCalculator.allItems, objects)
    }

    func testWhenOldItemOutOfBoundsButUpdatedOneNot() {
        // given

        let totalCount = 10
        let objects = (0..<totalCount+1).map({ _ in createRandomFeed(in: .default) }).sorted(by: sortBlock)

        let initialItems = Array(objects[0..<totalCount])
        let diffCalculator = ListDifferenceCalculator(initialItems: initialItems,
                                                      limit: totalCount, sortBlock: sortBlock)

        // when

        var expectedNewObject = objects.last!
        expectedNewObject.name = initialItems[0].name

        diffCalculator.apply(changes: [.update(newItem: expectedNewObject)])

        // then

        guard diffCalculator.lastDifferences.count == 2 else {
            XCTFail()
            return
        }

        guard
            case .delete(_, let firstDiffItem) = diffCalculator.lastDifferences[0],
            firstDiffItem.identifier == initialItems.last?.identifier else {
                XCTFail()
                return
        }

        guard
            case .insert(_, let secondDiffItem) = diffCalculator.lastDifferences[1],
            secondDiffItem.identifier == expectedNewObject.identifier else {
                XCTFail()
                return
        }
    }
}
