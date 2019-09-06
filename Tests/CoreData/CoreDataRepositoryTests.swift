/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import RobinHood

class CoreDataRepositoryTests: XCTestCase {
    override func setUp() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    override func tearDown() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    func testSaveFetchAll() {
        let repository: CoreDataRepository<FeedData, CDFeed> = CoreDataRepositoryFacade.shared.createCoreDataRepository()
        let operationQueue = OperationQueue()

        let sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = repository.saveOperation({ sourceObjects }, { [] })

        let fetchOperation = repository.fetchAllOperation()

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
        let repository: CoreDataRepository<FeedData, CDFeed> = CoreDataRepositoryFacade.shared
            .createCoreDataRepository(sortDescriptor: sortDescriptor)
        let operationQueue = OperationQueue()

        let sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = repository.saveOperation({ sourceObjects }, { [] })

        let fetchOperation = repository.fetchAllOperation()

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
        let repository: CoreDataRepository<FeedData, CDFeed> = CoreDataRepositoryFacade.shared.createCoreDataRepository()
        let operationQueue = OperationQueue()

        let sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = repository.saveOperation({ sourceObjects }, { [] })

        guard let object = sourceObjects.last else {
            XCTFail()
            return
        }

        let fetchOperation = repository.fetchOperation(by: object.identifier)

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
        let repository: CoreDataRepository<FeedData, CDFeed> = CoreDataRepositoryFacade.shared.createCoreDataRepository()
        let operationQueue = OperationQueue()

        var sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = repository.saveOperation({ sourceObjects }, { [] })

        guard let firstObject = sourceObjects.first else {
            XCTFail()
            return
        }

        guard let lastObject = sourceObjects.last else {
            XCTFail()
            return
        }

        let deleteOperation = repository.saveOperation({ [] },
                                                  { [firstObject.identifier, lastObject.identifier] })

        deleteOperation.addDependency(saveOperation)

        let fetchAllOperation = repository.fetchAllOperation()

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
        let repository: CoreDataRepository<FeedData, CDFeed> = CoreDataRepositoryFacade.shared.createCoreDataRepository()
        let operationQueue = OperationQueue()

        var sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = repository.saveOperation({ sourceObjects }, { [] })

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

        let updateOperation = repository.saveOperation({ [firstObject] }, { [lastObject.identifier] })

        updateOperation.addDependency(saveOperation)

        operationQueue.addOperation(updateOperation)

        let fetchAllOperation = repository.fetchAllOperation()

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
        let repository: CoreDataRepository<FeedData, CDFeed> = CoreDataRepositoryFacade.shared.createCoreDataRepository()
        let operationQueue = OperationQueue()

        let sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let saveOperation = repository.saveOperation({ sourceObjects }, { [] })

        let deleteAllOperation = repository.deleteAllOperation()

        deleteAllOperation.addDependency(saveOperation)

        let fetchAllOperation = repository.fetchAllOperation()

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
        let repository: CoreDataRepository<FeedData, CDFeed> = CoreDataRepositoryFacade.shared
            .createCoreDataRepository(sortDescriptor: sortDescriptor)
        let operationQueue = OperationQueue()

        let sourceObjects = (0..<objectsCount).map { _ in createRandomFeed() }

        let saveOperation = repository.saveOperation({ sourceObjects }, { [] })

        let fetchOperation = repository.fetch(offset: offset, count: count, reversed: reversed)

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