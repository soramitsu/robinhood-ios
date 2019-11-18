/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import RobinHood

class CoreDataRepositoryDomainTests: XCTestCase {
    var defaultDomainRepository: CoreDataRepository<FeedData, CDFeed> = {
        let filter = NSPredicate(format: "%K == %@", #keyPath(CDFeed.domain), Domain.default.rawValue)
        return CoreDataRepositoryFacade.shared.createCoreDataRepository(filter: filter)
    }()

    var favoriteDomainRepository: CoreDataRepository<FeedData, CDFeed> = {
        let filter = NSPredicate(format: "%K == %@", #keyPath(CDFeed.domain), Domain.favorites.rawValue)
        return CoreDataRepositoryFacade.shared.createCoreDataRepository(filter: filter)
    }()

    var operationQueue = OperationQueue()

    override func setUp() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    override func tearDown() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    func testSaveAndFetch() {
        let defaultObjects = (0..<10).map { _ in return createRandomFeed(in: .default) }
        XCTAssertTrue(save(objects: defaultObjects, in: defaultDomainRepository))

        let favoriteObjects = (0..<15).map { _ in return createRandomFeed(in: .favorites) }
        XCTAssertTrue(save(objects: favoriteObjects, in: favoriteDomainRepository))

        let optionalFetchedDefaultObjects = fetchAll(from: defaultDomainRepository)

        guard let fetchedDefaultObjects = optionalFetchedDefaultObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets(defaultObjects, fetchedDefaultObjects))

        let optionalFetchedFavoriteObjects = fetchAll(from: favoriteDomainRepository)

        guard let fetchedFavoriteObjects = optionalFetchedFavoriteObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets(favoriteObjects, fetchedFavoriteObjects))
    }

    func testSaveDeleteFetch() {
        let defaultObjects = (0..<10).map { _ in return createRandomFeed(in: .default) }
        XCTAssertTrue(save(objects: defaultObjects, in: defaultDomainRepository))

        let favoriteObjects = (0..<15).map { _ in return createRandomFeed(in: .favorites) }
        XCTAssertTrue(save(objects: favoriteObjects, in: favoriteDomainRepository))

        XCTAssertTrue(deleteAll(in: favoriteDomainRepository))

        let optionalFetchedDefaultObjects = fetchAll(from: defaultDomainRepository)

        guard let fetchedDefaultObjects = optionalFetchedDefaultObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets(defaultObjects, fetchedDefaultObjects))

        let optionalFetchedFavoriteObjects = fetchAll(from: favoriteDomainRepository)

        guard let fetchedFavoriteObjects = optionalFetchedFavoriteObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets([], fetchedFavoriteObjects))
    }

    func testFetchByIdInDomain() {
        let defaultObjects = (0..<10).map { _ in return createRandomFeed(in: .default) }
        XCTAssertTrue(save(objects: defaultObjects, in: defaultDomainRepository))

        let favoriteObjects = (0..<15).map { _ in return createRandomFeed(in: .favorites) }
        XCTAssertTrue(save(objects: favoriteObjects, in: favoriteDomainRepository))

        var object = fetchById(defaultObjects[0].identifier, repository: defaultDomainRepository)
        XCTAssertEqual(object, defaultObjects[0])

        object = fetchById(defaultObjects[0].identifier, repository: favoriteDomainRepository)
        XCTAssertNil(object)
    }

    func testDeleteByIdentifier() {
        let defaultObjects = (0..<10).map { _ in return createRandomFeed(in: .default) }
        XCTAssertTrue(save(objects: defaultObjects, in: defaultDomainRepository))

        let favoriteObjects = (0..<15).map { _ in return createRandomFeed(in: .favorites) }
        XCTAssertTrue(save(objects: favoriteObjects, in: favoriteDomainRepository))

        XCTAssertTrue(delete(objectIds: defaultObjects[0..<5].map { return $0.identifier }, in: defaultDomainRepository))

        let optionalFetchedDefaultObjects = fetchAll(from: defaultDomainRepository)

        guard let fetchedDefaultObjects = optionalFetchedDefaultObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets(Array<FeedData>(defaultObjects[5..<defaultObjects.count]), fetchedDefaultObjects))

        let optionalFetchedFavoriteObjects = fetchAll(from: favoriteDomainRepository)

        guard let fetchedFavoriteObjects = optionalFetchedFavoriteObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets(favoriteObjects, fetchedFavoriteObjects))
    }

    // MARK: Private

    private func save(objects: [FeedData], in repository: CoreDataRepository<FeedData, CDFeed>) -> Bool {
        let saveOperation = repository.saveOperation( { return objects }, { return [] })

        let expectation = XCTestExpectation()

        var operationResult: Bool = false

        saveOperation.completionBlock = {
            if let result = saveOperation.result, case .success = result {
                operationResult = true
            }

            expectation.fulfill()
        }

        operationQueue.addOperations([saveOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return operationResult
    }

    private func delete(objectIds: [String], in repository: CoreDataRepository<FeedData, CDFeed>) -> Bool {
        let saveOperation = repository.saveOperation( { return [] }, { return objectIds })

        let expectation = XCTestExpectation()

        var operationResult: Bool = false

        saveOperation.completionBlock = {
            if let result = saveOperation.result, case .success = result {
                operationResult = true
            }

            expectation.fulfill()
        }

        operationQueue.addOperations([saveOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return operationResult
    }

    private func deleteAll(in repository: CoreDataRepository<FeedData, CDFeed>) -> Bool {
        let deleteOperation = repository.deleteAllOperation()

        let expectation = XCTestExpectation()

        var operationResult: Bool = false

        deleteOperation.completionBlock = {
            if let result = deleteOperation.result, case .success = result {
                operationResult = true
            }

            expectation.fulfill()
        }

        operationQueue.addOperations([deleteOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return operationResult
    }

    private func fetchAll(from repository: CoreDataRepository<FeedData, CDFeed>) -> [FeedData]? {
        let fetchOperation = repository.fetchAllOperation()

        let expectation = XCTestExpectation()

        var objects: [FeedData]?

        fetchOperation.completionBlock = {
            if let result = fetchOperation.result, case .success(let fetchedObjects) = result {
                objects = fetchedObjects
            }

            expectation.fulfill()
        }

        operationQueue.addOperations([fetchOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return objects
    }

    private func fetchById(_ modelId: String, repository: CoreDataRepository<FeedData, CDFeed>) -> FeedData? {
        let fetchOperation = repository.fetchOperation(by: modelId)

        let expectation = XCTestExpectation()

        var project: FeedData?

        fetchOperation.completionBlock = {
            if let result = fetchOperation.result, case .success(let fetchedProject) = result {
                project = fetchedProject
            }

            expectation.fulfill()
        }

        operationQueue.addOperations([fetchOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return project
    }

    private func isSameObjectSets(_ objects1: [FeedData], _ objects2: [FeedData]) -> Bool {
        if objects1.count != objects2.count {
            return false
        }

        for object in objects1 {
            if !objects2.contains(object) {
                return false
            }
        }

        return true
    }
}
