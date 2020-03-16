/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
import RobinHood

class StreamableDataProviderFetchTests: XCTestCase {
    struct TestResult<T> {
        let initialItems: [T]
        let fetchedItems: [T]
        let fetchedChanges: [DataProviderChange<T>]
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

    func testFetchingItemWithoutSync() throws {
        // given

        let initialItemsCount = 15
        let fetchOffset = 10
        let fetchRemoteCount = 5

        let initialItems = (0..<initialItemsCount)
            .map { _ in createRandomFeed(in: .default) }
            .sorted { $0.name > $1.name }

        let remoteItems = (0..<fetchRemoteCount)
            .map { _ in createRandomFeed(in: .default) }
            .sorted { $0.name > $1.name }

        try modifyRepository(AnyDataProviderRepository(repository),
                             handler: self,
                             saving: { initialItems },
                             deleting: { [] })

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: fetchOffset)

        // when

        let result = try performFetchTest(with: options,
                                          remoteItems: remoteItems,
                                          fetchOffset: fetchOffset,
                                          fetchCount: initialItemsCount - fetchOffset + fetchOffset,
                                          isFetchSync: false,
                                          shouldTriggerRefreshAfterSetup: false)
        // then

        XCTAssertEqual(Array(initialItems[0..<fetchOffset]), result.initialItems)
        XCTAssertEqual(Array(initialItems[fetchOffset...]), result.fetchedItems)

        let remoteFetchedItems: [FeedData] = result.fetchedChanges.compactMap { change in
            switch change {
            case .insert(let newItem):
                return newItem
            default:
                return nil
            }
        }.sorted { $0.name > $1.name }

        XCTAssertEqual(remoteItems, remoteFetchedItems)
    }

    func testFetchingItemWithSync() throws {
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

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: 0)

        // when

        let result = try performFetch(with: source,
                                      operationManager: operationManager,
                                      options: options,
                                      fetchOffset: 0,
                                      fetchCount: totalCount,
                                      isFetchSync: true,
                                      shouldTriggerRefreshAfterSetup: true)

        // then

        XCTAssertEqual(result.initialItems, initialItems)
        XCTAssertEqual(result.fetchedItems, refreshItems)
    }

    func testFetchFailure() throws {
        // given

        let totalCount = 10

        let initialItems = (0..<totalCount)
            .map { _ in createRandomFeed(in: .default) }
            .sorted { $0.name > $1.name }

        try modifyRepository(AnyDataProviderRepository(repository),
                             handler: self,
                             saving: { initialItems },
                             deleting: { [] })

        let operationManager = OperationManager()

        let expectedError = NetworkResponseError.resourceNotFound

        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(returns: expectedError)

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: 0)

        // when

        do {
            _ = try performFetch(with: source,
                                 operationManager: operationManager,
                                 options: options,
                                 fetchOffset: 0,
                                 fetchCount: 2 * totalCount,
                                 isFetchSync: false,
                                 shouldTriggerRefreshAfterSetup: false)

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

    func performFetchTest(with options: StreamableProviderObserverOptions,
                          remoteItems: [FeedData],
                          fetchOffset: Int,
                          fetchCount: Int,
                          isFetchSync: Bool,
                          shouldTriggerRefreshAfterSetup: Bool) throws -> TestResult<FeedData> {
        let operationManager = OperationManager()
        let syncId = UUID().uuidString

        let enqueueClosure: OperationEnqueuClosure = { operations in
            operationManager.enqueue(operations: operations, in: .byIdentifier(syncId))
        }

        let source = createStreamableSourceMock(repository: repository,
                                                returns: remoteItems,
                                                enqueueClosure: enqueueClosure)

        return try performFetch(with: source,
                                operationManager: operationManager,
                                options: options,
                                fetchOffset: fetchOffset,
                                fetchCount: fetchCount,
                                isFetchSync: isFetchSync,
                                shouldTriggerRefreshAfterSetup: shouldTriggerRefreshAfterSetup)
    }

    private func performFetch(with source: AnyStreamableSource<FeedData>,
                              operationManager: OperationManagerProtocol,
                              options: StreamableProviderObserverOptions,
                              fetchOffset: Int,
                              fetchCount: Int,
                              isFetchSync: Bool,
                              shouldTriggerRefreshAfterSetup: Bool) throws -> TestResult<FeedData> {

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
        var fetchedChanges: [DataProviderChange<FeedData>]?

        let updateBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            if initialItems == nil {
                initialItems = changes.compactMap { change in
                    switch change {
                    case .insert(let newItem):
                        return newItem
                    default:
                        return nil
                    }
                }

                initialExpectation.fulfill()
            } else {
                fetchedChanges = changes

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

        if shouldTriggerRefreshAfterSetup {
            dataProvider.refresh()
        }

        var fetchedItems: [FeedData]?

        let fetchExpectation = XCTestExpectation()

        _ = dataProvider.fetch(offset: fetchOffset,
                               count: fetchCount,
                               synchronized: isFetchSync) { result in
                                defer {
                                    fetchExpectation.fulfill()
                                }

                                guard let result = result else {
                                    return
                                }

                                switch result {
                                case .success(let items):
                                    fetchedItems = items
                                case .failure:
                                    break
                                }
            }

        wait(for: [updateExpectation, fetchExpectation], timeout: Constants.expectationDuration)

        if let error = optionalError {
            throw error
        }

        return TestResult(initialItems: initialItems ?? [],
                          fetchedItems: fetchedItems ?? [],
                          fetchedChanges: fetchedChanges ?? [])
    }
}
