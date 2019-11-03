/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
import CoreData
@testable import RobinHood

class CoreDataContextObserverTests: XCTestCase {
    let repository: CoreDataRepository<FeedData, CDFeed> = {
        let sortDescriptor = NSSortDescriptor(key: FeedData.CodingKeys.name.rawValue, ascending: false)
        return CoreDataRepositoryFacade.shared.createCoreDataRepository(sortDescriptors: [sortDescriptor])
    }()

    let operationQueue: OperationQueue = OperationQueue()

    override func setUp() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    override func tearDown() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    func testInsertionWhenListEmpty() {
        let sourceObjects = (0..<10).map { _ in createRandomFeed(in: .default) }

        let validationBlock: ([DataProviderChange<FeedData>]) -> Bool = { (changes) in
            for change in changes {
                switch change {
                case .insert(let item):
                    if !sourceObjects.contains(item) {
                        return false
                    }
                default:
                    return false
                }
            }

            return sourceObjects.count == changes.count
        }

        performTest(updateObjects: sourceObjects, deletedIds: [], changesValidationBlock: validationBlock)
    }

    func testInsertionWhenListNotEmpty() {
        let initialObjects = (0..<15).map { _ in createRandomFeed(in: .default) }
        performSaveOperation(with: initialObjects, deletedIds: [])

        let sourceObjects = (0..<10).map { _ in createRandomFeed(in: .default) }

        let validationBlock: ([DataProviderChange<FeedData>]) -> Bool = { (changes) in
            for change in changes {
                switch change {
                case .insert(let item):
                    if !sourceObjects.contains(item) {
                        return false
                    }
                default:
                    return false
                }
            }

            return sourceObjects.count == changes.count
        }

        performTest(updateObjects: sourceObjects, deletedIds: [], changesValidationBlock: validationBlock)
    }

    func testUpdateObjects() {
        let initialObjects = (0..<15).map { _ in createRandomFeed(in: .default) }
        performSaveOperation(with: initialObjects, deletedIds: [])

        let updateObjects: [FeedData] = initialObjects.suffix(5).map { (object) in
            var updatedObject = object
            updatedObject.name = UUID().uuidString

            return updatedObject
        }

        let validationBlock: ([DataProviderChange<FeedData>]) -> Bool = { (changes) in
            for change in changes {
                switch change {
                case .update(let item):
                    if !updateObjects.contains(item) {
                        return false
                    }
                default:
                    return false
                }
            }

            return updateObjects.count == changes.count
        }

        performTest(updateObjects: updateObjects, deletedIds: [], changesValidationBlock: validationBlock)
    }

    func testDeleteObjects() {
        let initialObjects = (0..<15).map { _ in createRandomFeed(in: .default) }
        performSaveOperation(with: initialObjects, deletedIds: [])

        let deletingIds: [String] = initialObjects.suffix(5).map { $0.identifier }

        let validationBlock: ([DataProviderChange<FeedData>]) -> Bool = { (changes) in
            for change in changes {
                switch change {
                case .delete(let deletedIdentifier):
                    if !deletingIds.contains(deletedIdentifier) {
                        return false
                    }
                default:
                    return false
                }
            }

            return deletingIds.count == changes.count
        }

        performTest(updateObjects: [], deletedIds: deletingIds, changesValidationBlock: validationBlock)
    }

    func testInsertUpdateDeleteAtOnce() {
        let initialObjects = (0..<15).map { _ in createRandomFeed(in: .default) }
        performSaveOperation(with: initialObjects, deletedIds: [])

        let updatingObjects: [FeedData] = initialObjects.suffix(5).map { (object) in
            var updated = object
            updated.name = UUID().uuidString
            return updated
        }

        let deletingIds: [String] = initialObjects.prefix(5).map { $0.identifier }

        let insertingObjects = (0..<10).map { _ in createRandomFeed(in: .default) }

        let validationBlock: ([DataProviderChange<FeedData>]) -> Bool = { (changes) in
            var insertedCount = 0
            var updatedCount = 0
            var deletedCount = 0

            for change in changes {
                switch change {
                case .insert(let newItem):
                    if !insertingObjects.contains(newItem) {
                        return false
                    }

                    insertedCount += 1
                case .update(let item):
                    if !updatingObjects.contains(item) {
                        return false
                    }

                    updatedCount += 1
                case .delete(let deletedIdentifier):
                    if !deletingIds.contains(deletedIdentifier) {
                        return false
                    }

                    deletedCount += 1
                }
            }

            return insertingObjects.count == insertedCount &&
                updatingObjects.count == updatedCount &&
                deletingIds.count == deletedCount
        }

        performTest(updateObjects: insertingObjects + updatingObjects, deletedIds: deletingIds, changesValidationBlock: validationBlock)
    }

    // MARK: Private

    private func performTest(updateObjects: [FeedData],
                             deletedIds: [String],
                             changesValidationBlock: @escaping ([DataProviderChange<FeedData>]) -> Bool) {
        performTest(updateObjects: updateObjects,
                    deletedIds: deletedIds,
                    changesValidationBlock: changesValidationBlock) { $0 is CDFeed }
    }

    private func performTest(updateObjects: [FeedData],
                             deletedIds: [String],
                             changesValidationBlock: @escaping ([DataProviderChange<FeedData>]) -> Bool,
                             predicateBlock: @escaping (NSManagedObject) -> Bool) {
        let observable = CoreDataContextObservable(service: CoreDataRepositoryFacade.shared.databaseService,
                                                   mapper: repository.dataMapper,
                                                   predicate: predicateBlock)

        observable.start { (optionalError) in
            if let error = optionalError {
                XCTFail("Did receive error \(error)")
            }
        }

        let expectation = XCTestExpectation()

        observable.addObserver(self, deliverOn: .main) { (changes) in
            defer {
                expectation.fulfill()
            }

            if !changesValidationBlock(changes) {
                XCTFail()
            }
        }

        let operation = repository.saveOperation({ updateObjects }, { deletedIds })
        operationQueue.addOperation(operation)

        wait(for: [expectation], timeout: Constants.expectationDuration)
    }

    @discardableResult
    private func performSaveOperation(with updatedObjects: [FeedData], deletedIds: [String]) -> Result<Void, Error>? {
        let expectation = XCTestExpectation()

        let operation = repository.saveOperation({ updatedObjects }, { deletedIds })

        var result: Result<Void, Error>?

        operation.completionBlock = {
            result = operation.result

            expectation.fulfill()
        }

        operationQueue.addOperation(operation)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return result
    }
}
