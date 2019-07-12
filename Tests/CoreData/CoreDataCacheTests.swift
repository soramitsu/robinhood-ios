/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import RobinHood

class CoreDataCacheTests: XCTestCase {
    override func setUp() {
        try! CoreDataCacheFacade.shared.clearDatabase()
    }

    override func tearDown() {
        try! CoreDataCacheFacade.shared.clearDatabase()
    }

    func testSaveFetchAll() {
        let cache: CoreDataCache<FeedData, CDFeed> = CoreDataCacheFacade.shared.createCoreDataCache()
        let operationQueue = OperationQueue()

        let sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = cache.saveOperation({ sourceObjects }, { [] })

        let fetchOperation = cache.fetchAllOperation()

        fetchOperation.addDependency(saveOperation)

        let expectation = XCTestExpectation()

        fetchOperation.completionBlock = {
            expectation.fulfill()
        }

        operationQueue.addOperations([saveOperation, fetchOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        guard let result = fetchOperation.result,
            case .success(let fetchedObjects) = result else {
                XCTFail()
                return
        }

        XCTAssertEqual(fetchedObjects.count, sourceObjects.count)

        fetchedObjects.forEach { object in
            XCTAssertTrue(sourceObjects.contains(object))
        }
    }

    func testSaveFetchSorted() {
        let sortDescriptor = NSSortDescriptor(key: FeedData.CodingKeys.name.rawValue, ascending: false)
        let cache: CoreDataCache<FeedData, CDFeed> = CoreDataCacheFacade.shared.createCoreDataCache(sortDescriptor: sortDescriptor)
        let operationQueue = OperationQueue()

        let sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = cache.saveOperation({ sourceObjects }, { [] })

        let fetchOperation = cache.fetchAllOperation()

        fetchOperation.addDependency(saveOperation)

        let expectation = XCTestExpectation()

        fetchOperation.completionBlock = {
            expectation.fulfill()
        }

        operationQueue.addOperations([saveOperation, fetchOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        guard let result = fetchOperation.result,
            case .success(let fetchedObjects) = result else {
                XCTFail()
                return
        }

        let sortedSourceObjects = sourceObjects.sorted { return $0.name > $1.name }

        XCTAssertEqual(sortedSourceObjects, fetchedObjects)
    }

    func testSaveFetchSlice() {
        performTestSaveFetch(offset: 0, count: 10, reversed: false, objectsCount: 10)
        performTestSaveFetch(offset: 0, count: 10, reversed: true, objectsCount: 10)
        performTestSaveFetch(offset: 0, count: 5, reversed: false, objectsCount: 10)
        performTestSaveFetch(offset: 5, count: 5, reversed: false, objectsCount: 10)
        performTestSaveFetch(offset: 5, count: 5, reversed: true, objectsCount: 10)
        performTestSaveFetch(offset: 5, count: 10, reversed: true, objectsCount: 10)
        performTestSaveFetch(offset: 0, count: 1, reversed: false, objectsCount: 0)
    }

    func testSaveFetchById() {
        let cache: CoreDataCache<FeedData, CDFeed> = CoreDataCacheFacade.shared.createCoreDataCache()
        let operationQueue = OperationQueue()

        let sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = cache.saveOperation({ sourceObjects }, { [] })

        guard let object = sourceObjects.last else {
            XCTFail()
            return
        }

        let fetchOperation = cache.fetchOperation(by: object.identifier)

        fetchOperation.addDependency(saveOperation)

        let expectation = XCTestExpectation()

        fetchOperation.completionBlock = {
            expectation.fulfill()
        }

        operationQueue.addOperations([saveOperation, fetchOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        guard let result = fetchOperation.result, case .success(let fetchedObject) = result else {
            XCTFail()
            return
        }

        XCTAssertEqual(object, fetchedObject)
    }

    func testDeleteById() {
        let cache: CoreDataCache<FeedData, CDFeed> = CoreDataCacheFacade.shared.createCoreDataCache()
        let operationQueue = OperationQueue()

        var sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = cache.saveOperation({ sourceObjects }, { [] })

        guard let firstObject = sourceObjects.first else {
            XCTFail()
            return
        }

        guard let lastObject = sourceObjects.last else {
            XCTFail()
            return
        }

        let deleteOperation = cache.saveOperation({ [] },
                                                  { [firstObject.identifier, lastObject.identifier] })

        deleteOperation.addDependency(saveOperation)

        let fetchAllOperation = cache.fetchAllOperation()

        fetchAllOperation.addDependency(deleteOperation)

        let expectation = XCTestExpectation()

        fetchAllOperation.completionBlock = {
            expectation.fulfill()
        }

        operationQueue.addOperations([saveOperation, deleteOperation, fetchAllOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        guard let result = fetchAllOperation.result,
            case .success(let fetchedObjects) = result else {
                XCTFail()
                return
        }

        sourceObjects = sourceObjects.filter { $0 != firstObject && $0 != lastObject }

        XCTAssertEqual(fetchedObjects.count, sourceObjects.count)

        fetchedObjects.forEach { object in
            XCTAssertTrue(sourceObjects.contains(object))
        }
    }

    func testUpdateAndDeleteAtOnce() {
        let cache: CoreDataCache<FeedData, CDFeed> = CoreDataCacheFacade.shared.createCoreDataCache()
        let operationQueue = OperationQueue()

        var sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = cache.saveOperation({ sourceObjects }, { [] })

        operationQueue.addOperation(saveOperation)

        guard var firstObject = sourceObjects.first else {
            XCTFail()
            return
        }

        firstObject.name = UUID().uuidString
        sourceObjects[0] = firstObject

        guard let lastObject = sourceObjects.last else {
            XCTFail()
            return
        }

        let updateOperation = cache.saveOperation({ [firstObject] }, { [lastObject.identifier] })

        updateOperation.addDependency(saveOperation)

        operationQueue.addOperation(updateOperation)

        let fetchAllOperation = cache.fetchAllOperation()

        fetchAllOperation.addDependency(updateOperation)

        operationQueue.addOperation(fetchAllOperation)

        let expectation = XCTestExpectation()

        fetchAllOperation.completionBlock = {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        sourceObjects.removeLast()

        guard let result = fetchAllOperation.result,
            case .success(let fetchedObjects) = result else {
                XCTFail()
                return
        }

        XCTAssertEqual(fetchedObjects.count, sourceObjects.count)

        fetchedObjects.forEach { object in
            XCTAssertTrue(sourceObjects.contains(object))
        }
    }

    func testDeleteAll() {
        let cache: CoreDataCache<FeedData, CDFeed> = CoreDataCacheFacade.shared.createCoreDataCache()
        let operationQueue = OperationQueue()

        let sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = cache.saveOperation({ sourceObjects }, { [] })

        let deleteAllOperation = cache.deleteAllOperation()

        deleteAllOperation.addDependency(saveOperation)

        let fetchAllOperation = cache.fetchAllOperation()

        fetchAllOperation.addDependency(deleteAllOperation)

        let expectation = XCTestExpectation()

        fetchAllOperation.completionBlock = {
            expectation.fulfill()
        }

        operationQueue.addOperations([saveOperation, deleteAllOperation, fetchAllOperation],
                                     waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        guard let result = fetchAllOperation.result,
            case .success(let fetchedObjects) = result else {
                XCTFail()
                return
        }

        XCTAssertTrue(fetchedObjects.isEmpty)
    }

    // MARK: Private

    private func performTestSaveFetch(offset: Int, count: Int, reversed: Bool, objectsCount: Int = 10) {
        let sortDescriptor = NSSortDescriptor(key: FeedData.CodingKeys.name.rawValue, ascending: false)
        let cache: CoreDataCache<FeedData, CDFeed> = CoreDataCacheFacade.shared.createCoreDataCache(sortDescriptor: sortDescriptor)
        let operationQueue = OperationQueue()

        let sourceObjects = (0..<objectsCount).map { _ in createRandomFeed() }

        let saveOperation = cache.saveOperation({ sourceObjects }, { [] })

        let fetchOperation = cache.fetch(offset: offset, count: count, reversed: reversed)

        fetchOperation.addDependency(saveOperation)

        let expectation = XCTestExpectation()

        fetchOperation.completionBlock = {
            expectation.fulfill()
        }

        operationQueue.addOperations([saveOperation, fetchOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        guard let result = fetchOperation.result,
            case .success(let fetchedObjects) = result else {
                XCTFail()
                return
        }

        let sortedSourceObjects = sourceObjects.sorted { return reversed ? $0.name < $1.name : $0.name > $1.name}

        let reducedSourceObjects: [FeedData]

        if offset + count <= sourceObjects.count {
            reducedSourceObjects = Array(sortedSourceObjects[offset..<(offset+count)])
        } else {
            reducedSourceObjects = Array(sortedSourceObjects[offset..<sourceObjects.count])
        }

        XCTAssertEqual(reducedSourceObjects, fetchedObjects)
    }
}
