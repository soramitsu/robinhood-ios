/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
import RobinHood

class StreamableDataProviderInitTests: XCTestCase {
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

    func testInitWithoutRefreshWaitingWhenInitiallyEmpty() throws {
        // given
        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: 0)

        // when

        let result = try performInit(options: options)

        // then

        XCTAssertEqual([], result)
    }

    func testInitWithoutRefreshWaitingWhenInitiallyAllFetch() throws {
        // given

        let totalCount = 10
        let expectedItems = (0..<totalCount).map { _ in createRandomFeed(in: .default) }.sorted { $0.name > $1.name }
        try modifyRepository(AnyDataProviderRepository(repository),
                             handler: self,
                             saving: { expectedItems },
                             deleting: { [] })

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: 0)

        // when

        let result = try performInit(options: options)

        // then

        XCTAssertEqual(expectedItems, result)
    }

    func testInitWithoutRefreshWaitingWhenInitiallyFixedFetch() throws {
        // given

        let totalCount = 10
        let fetchingCount = 5

        let expectedItems = (0..<totalCount)
            .map { _ in createRandomFeed(in: .default) }
            .sorted { $0.name > $1.name }

        try modifyRepository(AnyDataProviderRepository(repository),
                             handler: self,
                             saving: { expectedItems },
                             deleting: { [] })

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: fetchingCount)

        // when

        let result = try performInit(options: options)

        // then

        XCTAssertEqual(Array(expectedItems[0..<fetchingCount]), result)
    }

    func testInitWaitingRefresh() throws {
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
                                                        waitsInProgressSyncOnAdd: true,
                                                        initialSize: 0)

        // when

        source.refresh(runningIn: nil, commitNotificationBlock: nil)

        let result = try performDataProviderInit(with: source,
                                                 operationManager: operationManager,
                                                 options: options)

        // then

        XCTAssertEqual(result, refreshItems)
    }

    // MARK: Private

    private func performInit(options: StreamableProviderObserverOptions) throws -> [FeedData] {
        let operationManager = OperationManager()

        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(repository: repository,
                                                                               returns: [])

        return try performDataProviderInit(with: source,
                                           operationManager: operationManager,
                                           options: options)
    }

    private func performDataProviderInit(with source: AnyStreamableSource<FeedData>,
                                         operationManager: OperationManagerProtocol,
                                         options: StreamableProviderObserverOptions) throws
        -> [FeedData] {

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

        let updateExpectation = XCTestExpectation()
        var result: [FeedData] = []

        let updateBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            result = changes.compactMap { change in
                switch change {
                case .insert(let newItem):
                    return newItem
                default:
                    return nil
                }
            }
            updateExpectation.fulfill()
        }

        let failBlock: (Error) -> Void = { error in
            optionalError = error

            updateExpectation.fulfill()
        }

        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: updateBlock,
                                 failing: failBlock,
                                 options: options)

        wait(for: [updateExpectation], timeout: Constants.expectationDuration)

        if let error = optionalError {
            throw error
        }

        return result
    }
}
