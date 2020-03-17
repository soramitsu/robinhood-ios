/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import RobinHood

class ListDifferenceCalculatorTests: XCTestCase {
    let sortBlock: (FeedData, FeedData) -> Bool = { (object1, object2) -> Bool in
        return object1.name < object2.name
    }

    func testInitial() {
        let objects = (0..<10).map({ _ in createRandomFeed(in: .default) }).sorted(by: sortBlock)

        let diffCalculator = ListDifferenceCalculator(initialItems: objects, sortBlock: sortBlock)

        XCTAssertEqual(diffCalculator.allItems, objects)
        XCTAssertTrue(diffCalculator.lastDifferences.isEmpty)
    }

    func testUpdateOnly() {
        // given
        var objects = (0..<10).map({ _ in createRandomFeed(in: .default) }).sorted(by: sortBlock)
        let diffCalculator = ListDifferenceCalculator(initialItems: objects, sortBlock: sortBlock)

        var updatedIndexes: [Int] = []
        var changes: [DataProviderChange<FeedData>] = []

        // when
        for (index, object) in objects.enumerated() {
            if [false, true].randomElement()! {
                var changedObject = object
                changedObject.favorite = !object.favorite
                objects[index] = changedObject

                updatedIndexes.append(index)
                changes.append(.update(newItem: changedObject))
            }
        }

        diffCalculator.apply(changes: changes)

        // then
        XCTAssertEqual(updatedIndexes.count, diffCalculator.lastDifferences.count)
        XCTAssertEqual(objects, diffCalculator.allItems)

        for diff in diffCalculator.lastDifferences {
            switch diff {
            case .update(let index, _, let new):
                XCTAssertTrue(updatedIndexes.contains(index))
                XCTAssertEqual(objects[index], new)
            default:
                XCTFail()
            }
        }
    }

    func testDeleteOnly() {
        // given
        let objects = (0..<10).map({ _ in createRandomFeed(in: .default) }).sorted(by: sortBlock)
        let diffCalculator = ListDifferenceCalculator(initialItems: objects, sortBlock: sortBlock)

        var deletedIndexes: [Int] = []
        var changes: [DataProviderChange<FeedData>] = []

        // when
        for (index, object) in objects.enumerated() {
            if [false, true].randomElement()! {
                deletedIndexes.append(index)

                changes.append(.delete(deletedIdentifier: object.identifier))
            }
        }

        diffCalculator.apply(changes: changes)

        // then
        XCTAssertEqual(changes.count, diffCalculator.lastDifferences.count)
        XCTAssertEqual(objects.count - deletedIndexes.count, diffCalculator.allItems.count)

        var prevIndex: Int?

        for diff in diffCalculator.lastDifferences {
            switch diff {
            case .delete(let index, let old):
                XCTAssertTrue(deletedIndexes.contains(index))
                XCTAssertEqual(objects[index], old)

                if let oldIndex = prevIndex {
                    // insure that delete updates are sorted desc
                    XCTAssertTrue(oldIndex > index)
                }

                prevIndex = index

            default:
                XCTFail()
            }
        }
    }

    func testInsertOnly() {
        // given
        let objects = (0..<10).map({ _ in createRandomFeed(in: .default) }).sorted(by: sortBlock)
        let diffCalculator = ListDifferenceCalculator(initialItems: objects, sortBlock: sortBlock)

        let insertedItems = (0..<5).map { _ in createRandomFeed(in: .default) }
        let changes: [DataProviderChange<FeedData>] = insertedItems.map { return .insert(newItem: $0) }

        // when
        diffCalculator.apply(changes: changes)

        // then
        XCTAssertEqual(changes.count, diffCalculator.lastDifferences.count)
        XCTAssertEqual(objects.count + changes.count, diffCalculator.allItems.count)

        var prevIndex: Int?

        for diff in diffCalculator.lastDifferences {
            switch diff {
            case .insert(let index, let new):
                XCTAssertTrue(insertedItems.contains(new))

                if let oldIndex = prevIndex {
                    // insure that delete updates are sorted asc
                    XCTAssertTrue(oldIndex < index)
                }

                prevIndex = index

            default:
                XCTFail()
            }
        }
    }

    func testOrderIsKeptAfterUpdate() {
        // given
        let count = 10
        var objects = (0..<count).map({ _ in createRandomFeed(in: .default) }).sorted(by: sortBlock)
        let diffCalculator = ListDifferenceCalculator(initialItems: objects, sortBlock: sortBlock)

        // when

        let firstName = objects[0].name
        objects[0].name = objects[count - 1].name
        objects[count - 1].name = firstName

        let changes: [DataProviderChange<FeedData>] = [
            .update(newItem: objects[0]),
            .update(newItem: objects[count - 1])]

        diffCalculator.apply(changes: changes)

        // then

        guard diffCalculator.lastDifferences.count == 4 else {
            XCTFail("Unexpected changes")
            return
        }

        for change in diffCalculator.lastDifferences {
            switch change {
            case .insert(let index, let newData):
                guard
                    (index == 0 && newData.identifier == objects[count - 1].identifier) ||
                    (index == count - 1 && newData.identifier == objects[0].identifier) else {
                        XCTFail("Unexpected insert at \(index)")
                        return
                }
            case .delete(let index, let oldData):
                guard
                    (index == 0 && oldData.identifier == objects[0].identifier) ||
                    (index == count - 1 && oldData.identifier == objects[count - 1].identifier) else {
                        XCTFail("Unexpected delete at \(index)")
                        return

                }
            case .update(let index, _, _):
                XCTFail("Unexpected update at \(index)")
                return
            }
        }

        objects = objects.sorted(by: sortBlock)
        XCTAssertEqual(diffCalculator.allItems, objects)
    }
}
