/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
import RobinHood

class StreamableDataProviderTests: XCTestCase {
    let cache: CoreDataCache<FeedData, CDFeed> = {
        let sortDescriptor = NSSortDescriptor(key: FeedData.CodingKeys.name.rawValue, ascending: false)
        return CoreDataCacheFacade.shared.createCoreDataCache(sortDescriptor: sortDescriptor)
    }()

    let operationQueue = OperationQueue()

    override func setUp() {
        try! CoreDataCacheFacade.shared.clearDatabase()
    }

    override func tearDown() {
        try! CoreDataCacheFacade.shared.clearDatabase()
    }

    func testChangesWhenListEmpty() {
        let sourceObjects = (0..<10).map { _ in createRandomFeed() }

        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(base: self,
                                                                               cache: cache,
                                                                               operationQueue: operationQueue,
                                                                               returns: sourceObjects)

        let fetchValidator: ([FeedData]) -> Bool = { (items) in
            return items.isEmpty
        }

        let updateValidator: ([DataProviderChange<FeedData>]) -> Bool = { (changes) in
            for change in changes {
                switch change {
                case .insert(let newItem):
                    if !sourceObjects.contains(newItem) {
                        return false
                    }
                default:
                    return false
                }
            }

            return sourceObjects.count == changes.count
        }

        performSingleChangeTest(with: source,
                                fetchValidator: fetchValidator,
                                updateValidator: updateValidator)
    }

    func testChangesWhenListNotEmpty() {
        let initialObjects = (0..<10).map({ _ in createRandomFeed()}).sorted { $0.name > $1.name }
        performSaveOperation(with: initialObjects, deletedIds: [])

        let newObjects = (0..<20).map { _ in createRandomFeed() }

        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(base: self,
                                                                               cache: cache,
                                                                               operationQueue: operationQueue,
                                                                               returns: newObjects)

        let fetchValidator: ([FeedData]) -> Bool = { (items) in
            return initialObjects == items
        }

        let updateValidator: ([DataProviderChange<FeedData>]) -> Bool = { (changes) in
            for change in changes {
                switch change {
                case .insert(let newItem):
                    if !newObjects.contains(newItem) {
                        return false
                    }
                default:
                    return false
                }
            }

            return newObjects.count == changes.count
        }

        performSingleChangeTest(with: source,
                                fetchValidator: fetchValidator,
                                updateValidator: updateValidator,
                                fetchOffset: 0,
                                fetchCount: initialObjects.count + newObjects.count)
    }

    func testAlwaysNotifyWhenFetchEmpty() {
        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(base: self,
                                                                               cache: cache,
                                                                               operationQueue: operationQueue,
                                                                               returns: [])

        let fetchValidator: ([FeedData]) -> Bool = { (items) in
            return items.isEmpty
        }

        let updateValidator: ([DataProviderChange<FeedData>]) -> Bool = { (changes) in
            return changes.isEmpty
        }

        performSingleChangeTest(with: source,
                                fetchValidator: fetchValidator,
                                updateValidator: updateValidator,
                                options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true))
    }

    func testErrorDispatchWhenFetch() {
        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(base: self,
                                                                               returns: NetworkBaseError.unexpectedResponseObject)

        let observable = CoreDataContextObservable(service: cache.databaseService,
                                                   mapper: cache.dataMapper,
                                                   predicate: { _ in return true })

        observable.start { _ in }

        let dataProvider = StreamableProvider(source: source,
                                              cache: cache,
                                              observable: observable,
                                              operationQueue: operationQueue)

        let failExpectation = XCTestExpectation()

        let updateBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            XCTFail()
        }

        let failBlock: (Error) -> Void = { (error) in
            defer {
                failExpectation.fulfill()
            }

            guard let networkError = error as? NetworkBaseError, case .unexpectedResponseObject = networkError else {
                XCTFail()
                return
            }
        }

        let fetchExpectation = XCTestExpectation()

        dataProvider.addObserver(self,
                                 deliverOn: .main, executing: updateBlock,
                                 failing: failBlock,
                                 options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true))

        _ = dataProvider.fetch(offset: 0, count: 10) { (optionalResult) in
            defer {
                fetchExpectation.fulfill()
            }

            guard let result = optionalResult, case .success(let items) = result else {
                XCTFail()
                return
            }

            XCTAssertTrue(items.isEmpty)
        }

        wait(for: [failExpectation, fetchExpectation], timeout: Constants.expectationDuration)
    }

    // MARK: Private

    private func performSingleChangeTest(with source: AnyStreamableSource<FeedData>,
                                         fetchValidator: @escaping ([FeedData]) -> Bool,
                                         updateValidator: @escaping ([DataProviderChange<FeedData>]) -> Bool,
                                         fetchOffset: Int = 0,
                                         fetchCount: Int = 10,
                                         options: DataProviderObserverOptions? = nil) {
        let observable = CoreDataContextObservable(service: cache.databaseService,
                                                   mapper: cache.dataMapper,
                                                   predicate: { _ in return true })

        observable.start { _ in }

        let dataProvider = StreamableProvider(source: source,
                                              cache: cache,
                                              observable: observable,
                                              operationQueue: operationQueue)

        let updateExpectation = XCTestExpectation()

        let updateBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            defer {
                updateExpectation.fulfill()
            }

            if !updateValidator(changes) {
                XCTFail()
            }
        }

        let failBlock: (Error) -> Void = { _ in
            XCTFail()
        }

        let fetchExpectation = XCTestExpectation()

        let dataProviderOptions = options ?? DataProviderObserverOptions(alwaysNotifyOnRefresh: false)

        dataProvider.addObserver(self,
                                 deliverOn: .main, executing: updateBlock,
                                 failing: failBlock,
                                 options: dataProviderOptions)

        _ = dataProvider.fetch(offset: fetchOffset, count: fetchCount) { (optionalResult) in
            defer {
                fetchExpectation.fulfill()
            }

            guard let result = optionalResult, case .success(let items) = result else {
                XCTFail()
                return
            }

            XCTAssertTrue(fetchValidator(items))
        }

        wait(for: [updateExpectation, fetchExpectation], timeout: Constants.expectationDuration)
    }

    @discardableResult
    private func performSaveOperation(with updatedObjects: [FeedData], deletedIds: [String]) -> OperationResult<Bool>? {
        let expectation = XCTestExpectation()

        let operation = cache.saveOperation({ updatedObjects }, { deletedIds })

        var result: OperationResult<Bool>?

        operation.completionBlock = {
            result = operation.result

            expectation.fulfill()
        }

        operationQueue.addOperation(operation)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return result
    }
}
