import XCTest
@testable import RobinHood

class CoreDataCacheTests: XCTestCase {
    var cache: CoreDataCache<FeedData, CDFeed> = {
        let coreDataService = CoreDataService.shared
        coreDataService.configuration = CoreDataServiceConfiguration.createDefaultConfigutation()
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<FeedData, CDFeed>())

        return CoreDataCache(databaseService: coreDataService,
                             mapper: mapper)
    }()

    var operationQueue = OperationQueue()

    override func setUp() {
        try! clearDatabase(using: cache.databaseService)
    }

    override func tearDown() {
        try! clearDatabase(using: cache.databaseService)
    }

    func testSaveFetchAll() {
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

    func testSaveFetchById() {
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
}
