import XCTest
@testable import RobinHood

class ListDifferenceCalculatorTests: XCTestCase {
    let sortBlock: (FeedData, FeedData) -> Bool = { (object1, object2) -> Bool in
        return object1.name < object2.name
    }

    func testInitial() {
        let objects = (0..<10).map({ _ in createRandomFeed() }).sorted(by: sortBlock)

        let diffCalculator = ListDifferenceCalculator(initialItems: objects, sortBlock: sortBlock)

        XCTAssertEqual(diffCalculator.allItems, objects)
        XCTAssertTrue(diffCalculator.lastDifferences.isEmpty)
    }

    func testUpdateOnly() {
        // given
        var objects = (0..<10).map({ _ in createRandomFeed() }).sorted(by: sortBlock)
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
        let objects = (0..<10).map({ _ in createRandomFeed() }).sorted(by: sortBlock)
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

        for diff in diffCalculator.lastDifferences {
            switch diff {
            case .delete(let index, let old):
                XCTAssertTrue(deletedIndexes.contains(index))
                XCTAssertEqual(objects[index], old)
            default:
                XCTFail()
            }
        }
    }

    func testInsertOnly() {
        // given
        let objects = (0..<10).map({ _ in createRandomFeed() }).sorted(by: sortBlock)
        let diffCalculator = ListDifferenceCalculator(initialItems: objects, sortBlock: sortBlock)

        let insertedItems = (0..<5).map { _ in createRandomFeed() }
        let changes: [DataProviderChange<FeedData>] = insertedItems.map { return .insert(newItem: $0) }

        // when
        diffCalculator.apply(changes: changes)

        // then
        XCTAssertEqual(changes.count, diffCalculator.lastDifferences.count)
        XCTAssertEqual(objects.count + changes.count, diffCalculator.allItems.count)

        for diff in diffCalculator.lastDifferences {
            switch diff {
            case .insert(_, let new):
                XCTAssertTrue(insertedItems.contains(new))
            default:
                XCTFail()
            }
        }
    }
}
