/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
import RobinHood

class StreamableDataProviderTests: XCTestCase {
    let repository: CoreDataRepository<FeedData, CDFeed> = {
        let sortDescriptor = NSSortDescriptor(key: FeedData.CodingKeys.name.rawValue, ascending: false)
        return CoreDataRepositoryFacade.shared.createCoreDataRepository(sortDescriptors: [sortDescriptor])
    }()

    let operationQueue = OperationQueue()

    override func setUp() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    override func tearDown() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    func testChangesWhenListEmpty() {
        let sourceObjects = (0..<10).map { _ in createRandomFeed(in: .default) }

        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(repository: repository,
                                                                               operationQueue: operationQueue,
                                                                               returns: sourceObjects)

        let fetchValidator: ([FeedData]) -> Bool = { (items) in
            return items.isEmpty
        }

        let updateValidator: ([DataProviderChange<FeedData>], Int) -> Bool = { (changes, index) in
            if index == 0 {
                return changes.count == 0
            } else {
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
        }

        performSingleChangeTest(with: source,
                                fetchValidator: fetchValidator,
                                updateValidator: updateValidator)
    }

    func testChangesWhenListNotEmpty() {
        let initialObjects = (0..<10).map({ _ in createRandomFeed(in: .default)}).sorted { $0.name > $1.name }
        performSaveOperation(with: initialObjects, deletedIds: [])

        let newObjects = (0..<20).map { _ in createRandomFeed(in: .default) }

        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(repository: repository,
                                                                               operationQueue: operationQueue,
                                                                               returns: newObjects)

        let fetchValidator: ([FeedData]) -> Bool = { (items) in
            return initialObjects == items
        }

        let updateValidator: ([DataProviderChange<FeedData>], Int) -> Bool = { (changes, index) in
            let targetObjects = index == 0 ? initialObjects : newObjects
            for change in changes {
                switch change {
                case .insert(let newItem):
                    if !targetObjects.contains(newItem) {
                        return false
                    }
                default:
                    return false
                }
            }

            return targetObjects.count == changes.count
        }

        performSingleChangeTest(with: source,
                                fetchValidator: fetchValidator,
                                updateValidator: updateValidator,
                                fetchOffset: 0,
                                fetchCount: initialObjects.count + newObjects.count)
    }

    func testAlwaysNotifyWhenFetchEmpty() {
        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(repository: repository,
                                                                               operationQueue: operationQueue,
                                                                               returns: [])

        let fetchValidator: ([FeedData]) -> Bool = { (items) in
            return items.isEmpty
        }

        let updateValidator: ([DataProviderChange<FeedData>], Int) -> Bool = { (changes, index) in
            return changes.isEmpty
        }

        performSingleChangeTest(with: source,
                                fetchValidator: fetchValidator,
                                updateValidator: updateValidator,
                                options: StreamableProviderObserverOptions(alwaysNotifyOnRefresh: true))
    }

    func testErrorDispatchWhenFetch() {
        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(returns: NetworkBaseError.unexpectedResponseObject)

        let observable = CoreDataContextObservable(service: repository.databaseService,
                                                   mapper: repository.dataMapper,
                                                   predicate: { _ in return true })

        let dataProvider = StreamableProvider(source: source,
                                              repository: AnyDataProviderRepository(repository),
                                              observable: AnyDataProviderRepositoryObservable(observable))

        observable.start { _ in }

        let failExpectation = XCTestExpectation()

        let initialExpectation = XCTestExpectation()
        initialExpectation.assertForOverFulfill = true

        let updateBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            initialExpectation.fulfill()
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
                                 options: StreamableProviderObserverOptions(alwaysNotifyOnRefresh: true))

        wait(for: [initialExpectation], timeout: Constants.expectationDuration)

        _ = dataProvider.fetch(offset: 0, count: 10, synchronized: true) { (optionalResult) in
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
                                         updateValidator: @escaping ([DataProviderChange<FeedData>], Int) -> Bool,
                                         fetchOffset: Int = 0,
                                         fetchCount: Int = 10,
                                         options: StreamableProviderObserverOptions? = nil) {
        let observable = CoreDataContextObservable(service: repository.databaseService,
                                                   mapper: repository.dataMapper,
                                                   predicate: { _ in return true })

        let dataProvider = StreamableProvider(source: source,
                                              repository: AnyDataProviderRepository(repository),
                                              observable: AnyDataProviderRepositoryObservable(observable))

        observable.start { _ in }

        let initialExpectation = XCTestExpectation()

        let updateExpectation = XCTestExpectation()
        updateExpectation.assertForOverFulfill = true

        var updateCallIndex = 0

        let updateBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            defer {
                if updateCallIndex == 1 {
                    initialExpectation.fulfill()
                } else {
                    updateExpectation.fulfill()
                }
            }

            if !updateValidator(changes, updateCallIndex) {
                XCTFail()
            }

            updateCallIndex += 1
        }

        let failBlock: (Error) -> Void = { _ in
            XCTFail()
        }

        let fetchExpectation = XCTestExpectation()

        let dataProviderOptions = options ?? StreamableProviderObserverOptions(alwaysNotifyOnRefresh: false)

        dataProvider.addObserver(self,
                                 deliverOn: .main, executing: updateBlock,
                                 failing: failBlock,
                                 options: dataProviderOptions)

        wait(for: [initialExpectation], timeout: Constants.expectationDuration)

        _ = dataProvider.fetch(offset: fetchOffset, count: fetchCount, synchronized: true) { (optionalResult) in
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
