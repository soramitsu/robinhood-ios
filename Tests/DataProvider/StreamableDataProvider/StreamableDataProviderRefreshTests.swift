/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
import RobinHood

class StreamableDataProviderRefreshTests: XCTestCase {
    struct TestResult<T> {
        let initialItems: [T]
        let refreshedItems: [T]
    }

    let repository: CoreDataRepository<FeedData, CDFeed> = {
        let sortDescriptor = NSSortDescriptor(key: FeedData.CodingKeys.name.rawValue, ascending: false)
        return CoreDataRepositoryFacade.shared.createCoreDataRepository(sortDescriptors: [sortDescriptor])
    }()

    override func setUp() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    override func tearDown() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    func testRefreshWhenNonEmpty() throws {
        // given

        let totalCount = 10

        let initialItems = (0..<totalCount)
            .map { _ in createRandomFeed(in: .default) }
            .sorted { $0.name > $1.name }

        let refreshItems = (0..<totalCount)
            .map { _ in createRandomFeed(in: .default) }
            .sorted { $0.name > $1.name }

        try modifyRepository(AnyDataProviderRepository(repository),
                             handler: self,
                             saving: { initialItems },
                             deleting: { [] })

        let operationManager = OperationManager()
        let syncId = UUID().uuidString

        let enqueueClosure: OperationEnqueuClosure = { operations in
            operationManager.enqueue(operations: operations, in: .byIdentifier(syncId))
        }

        let source = createStreamableSourceMock(repository: repository,
                                                returns: refreshItems,
                                                enqueueClosure: enqueueClosure)

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: 0)

        // when

        let result = try performRefresh(with: source,
                                        operationManager: operationManager,
                                        options: options)

        // then

        XCTAssertEqual(result.initialItems, initialItems)
        XCTAssertEqual(result.refreshedItems, refreshItems)
    }

    func testRefreshWhenEmpty() throws {
        // given

        let operationManager = OperationManager()
        let syncId = UUID().uuidString

        let enqueueClosure: OperationEnqueuClosure = { operations in
            operationManager.enqueue(operations: operations, in: .byIdentifier(syncId))
        }

        let source = createStreamableSourceMock(repository: repository,
                                                returns: [],
                                                enqueueClosure: enqueueClosure)

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: 0)

        // when

        let result = try performRefresh(with: source,
                                        operationManager: operationManager,
                                        options: options)

        // then

        XCTAssertEqual(result.initialItems, [])
        XCTAssertEqual(result.refreshedItems, [])
    }

    func testRefreshFailure() {
        let operationManager = OperationManager()

        let expectedError = NetworkResponseError.resourceNotFound

        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(returns: expectedError)

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: 0)

        do {
            _ = try performRefresh(with: source,
                                   operationManager: operationManager,
                                   options: options)
            XCTFail("Error expected")
        } catch {
            if let error = error as? NetworkResponseError {
                XCTAssertEqual(error, expectedError)
            } else {
                XCTFail("Unexpected error")
            }
        }
    }

    // MARK: Private

    private func performRefresh(with source: AnyStreamableSource<FeedData>,
                                operationManager: OperationManagerProtocol,
                                options: StreamableProviderObserverOptions) throws
        -> TestResult<FeedData> {

        let observable = CoreDataContextObservable(service: repository.databaseService,
                                                   mapper: repository.dataMapper,
                                                   predicate: { _ in return true })

        let dataProvider = StreamableProvider(source: source,
                                              repository: AnyDataProviderRepository(repository),
                                              observable: AnyDataProviderRepositoryObservable(observable),
                                              operationManager: operationManager)

        let observableExpectation = XCTestExpectation()
        var optionalError: Error?

        observable.start { error in
            optionalError = error
            observableExpectation.fulfill()
        }

        if let error = optionalError {
            throw error
        }

        let initialExpectation = XCTestExpectation()
        let updateExpectation = XCTestExpectation()

        var initialItems: [FeedData]?
        var refreshedItems: [FeedData]?

        let updateBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            let items: [FeedData] = changes.compactMap { change in
                switch change {
                case .insert(let item):
                    return item
                default:
                    return nil
                }
            }.sorted { $0.name > $1.name }

            if initialItems == nil {
                initialItems = items

                initialExpectation.fulfill()
            } else {
                refreshedItems = items

                updateExpectation.fulfill()
            }
        }

        let failBlock: (Error) -> Void = { error in
            optionalError = error

            if initialItems == nil {
                initialExpectation.fulfill()
            } else {
                updateExpectation.fulfill()
            }
        }

        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: updateBlock,
                                 failing: failBlock,
                                 options: options)

        wait(for: [initialExpectation], timeout: Constants.expectationDuration)

        if let error = optionalError {
            throw error
        }

        dataProvider.refresh()

        wait(for: [updateExpectation], timeout: Constants.expectationDuration)

        if let error = optionalError {
            throw error
        }

        return TestResult(initialItems: initialItems ?? [],
                          refreshedItems: refreshedItems ?? [])
    }
}
