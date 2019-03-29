import XCTest
@testable import RobinHood

class CoreDataCacheDomainTests: XCTestCase {
    var defaultDomainCache: CoreDataCache<FeedData, CDFeed> = CoreDataCacheFacade.shared
        .createCoreDataCache(domain: "defaults")

    var favoriteDomainCache: CoreDataCache<FeedData, CDFeed> = CoreDataCacheFacade.shared
        .createCoreDataCache(domain: "favorite")

    var operationQueue = OperationQueue()

    override func setUp() {
        try! CoreDataCacheFacade.shared.clearDatabase()
    }

    override func tearDown() {
        try! CoreDataCacheFacade.shared.clearDatabase()
    }

    func testSaveAndFetch() {
        let defaultObjects = (0..<10).map { _ in return createRandomFeed() }
        XCTAssertTrue(save(objects: defaultObjects, in: defaultDomainCache))

        let favoriteObjects = (0..<15).map { _ in return createRandomFeed() }
        XCTAssertTrue(save(objects: favoriteObjects, in: favoriteDomainCache))

        let optionalFetchedDefaultObjects = fetchAll(from: defaultDomainCache)

        guard let fetchedDefaultObjects = optionalFetchedDefaultObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets(defaultObjects, fetchedDefaultObjects))

        let optionalFetchedFavoriteObjects = fetchAll(from: favoriteDomainCache)

        guard let fetchedFavoriteObjects = optionalFetchedFavoriteObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets(favoriteObjects, fetchedFavoriteObjects))
    }

    func testSaveDeleteFetch() {
        let defaultObjects = (0..<10).map { _ in return createRandomFeed() }
        XCTAssertTrue(save(objects: defaultObjects, in: defaultDomainCache))

        let favoriteObjects = (0..<15).map { _ in return createRandomFeed() }
        XCTAssertTrue(save(objects: favoriteObjects, in: favoriteDomainCache))

        XCTAssertTrue(deleteAll(in: favoriteDomainCache))

        let optionalFetchedDefaultObjects = fetchAll(from: defaultDomainCache)

        guard let fetchedDefaultObjects = optionalFetchedDefaultObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets(defaultObjects, fetchedDefaultObjects))

        let optionalFetchedFavoriteObjects = fetchAll(from: favoriteDomainCache)

        guard let fetchedFavoriteObjects = optionalFetchedFavoriteObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets([], fetchedFavoriteObjects))
    }

    func testFetchByIdInDomain() {
        let defaultObjects = (0..<10).map { _ in return createRandomFeed() }
        XCTAssertTrue(save(objects: defaultObjects, in: defaultDomainCache))

        let favoriteObjects = (0..<15).map { _ in return createRandomFeed() }
        XCTAssertTrue(save(objects: favoriteObjects, in: favoriteDomainCache))

        var object = fetchById(defaultObjects[0].identifier, cache: defaultDomainCache)
        XCTAssertEqual(object, defaultObjects[0])

        object = fetchById(defaultObjects[0].identifier, cache: favoriteDomainCache)
        XCTAssertNil(object)
    }

    func testDeleteByIdentifier() {
        let defaultObjects = (0..<10).map { _ in return createRandomFeed() }
        XCTAssertTrue(save(objects: defaultObjects, in: defaultDomainCache))

        let favoriteObjects = (0..<15).map { _ in return createRandomFeed() }
        XCTAssertTrue(save(objects: favoriteObjects, in: favoriteDomainCache))

        XCTAssertTrue(delete(objectIds: defaultObjects[0..<5].map { return $0.identifier }, in: defaultDomainCache))

        let optionalFetchedDefaultObjects = fetchAll(from: defaultDomainCache)

        guard let fetchedDefaultObjects = optionalFetchedDefaultObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets(Array<FeedData>(defaultObjects[5..<defaultObjects.count]), fetchedDefaultObjects))

        let optionalFetchedFavoriteObjects = fetchAll(from: favoriteDomainCache)

        guard let fetchedFavoriteObjects = optionalFetchedFavoriteObjects else {
            XCTFail()
            return
        }

        XCTAssertTrue(isSameObjectSets(favoriteObjects, fetchedFavoriteObjects))
    }

    // MARK: Private

    private func save(objects: [FeedData], in cache: CoreDataCache<FeedData, CDFeed>) -> Bool {
        let saveOperation = cache.saveOperation( { return objects }, { return [] })

        let expectation = XCTestExpectation()

        var operationResult: Bool = false

        saveOperation.completionBlock = {
            if let result = saveOperation.result, case .success(let isSuccess) = result {
                operationResult = isSuccess
            }

            expectation.fulfill()
        }

        operationQueue.addOperations([saveOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return operationResult
    }

    private func delete(objectIds: [String], in cache: CoreDataCache<FeedData, CDFeed>) -> Bool {
        let saveOperation = cache.saveOperation( { return [] }, { return objectIds })

        let expectation = XCTestExpectation()

        var operationResult: Bool = false

        saveOperation.completionBlock = {
            if let result = saveOperation.result, case .success(let isSuccess) = result {
                operationResult = isSuccess
            }

            expectation.fulfill()
        }

        operationQueue.addOperations([saveOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return operationResult
    }

    private func deleteAll(in cache: CoreDataCache<FeedData, CDFeed>) -> Bool {
        let deleteOperation = cache.deleteAllOperation()

        let expectation = XCTestExpectation()

        var operationResult: Bool = false

        deleteOperation.completionBlock = {
            if let result = deleteOperation.result, case .success(let isSuccess) = result {
                operationResult = isSuccess
            }

            expectation.fulfill()
        }

        operationQueue.addOperations([deleteOperation], waitUntilFinished: false)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return operationResult
    }

    private func fetchAll(from cache: CoreDataCache<FeedData, CDFeed>) -> [FeedData]? {
        let fetchOperation = cache.fetchAllOperation()

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

    private func fetchById(_ modelId: String, cache: CoreDataCache<FeedData, CDFeed>) -> FeedData? {
        let fetchOperation = cache.fetchOperation(by: modelId)

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
