/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import RobinHood

class StreamableDataProviderObserverTests: XCTestCase {
    func testAddObserverWaitInitAndRemove() {
        // given

        let dataProvider = prepareDataProvider()

        let operationQueue = OperationQueue()

        // when

        let addObserverWaitingOperation = ClosureOperation {
            while(dataProvider.observers.isEmpty) {
                usleep(10000)
            }
        }

        let addExpectation = XCTestExpectation()

        addObserverWaitingOperation.completionBlock = {
            addExpectation.fulfill()
        }

        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: { _ in },
                                 failing: { _ in })

        operationQueue.addOperation(addObserverWaitingOperation)

        wait(for: [addExpectation], timeout: Constants.expectationDuration)

        XCTAssertTrue(!dataProvider.observers.isEmpty)
        XCTAssertTrue(dataProvider.pendingObservers.isEmpty)

        // then

        let removeObseverOperation = ClosureOperation {
            while(!dataProvider.observers.isEmpty) {
                usleep(10000)
            }
        }

        let removeExpectation = XCTestExpectation()

        removeObseverOperation.completionBlock = {
            removeExpectation.fulfill()
        }

        dataProvider.removeObserver(self)

        operationQueue.addOperation(removeObseverOperation)

        wait(for: [removeExpectation], timeout: Constants.expectationDuration)

        XCTAssertTrue(dataProvider.observers.isEmpty)
        XCTAssertTrue(dataProvider.pendingObservers.isEmpty)
    }

    func testAddObserverAndImmedeatellyRemove() {
        // given

        let dataProvider = prepareDataProvider()

        // when

        var resultError: Error?

        let expectation = XCTestExpectation()

        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: { _ in },
                                 failing: { error in
                                    resultError = error
                                    expectation.fulfill()
        })

        dataProvider.removeObserver(self)

        // then

        wait(for: [expectation], timeout: Constants.expectationDuration)

        if let error = resultError as? DataProviderError {
            XCTAssertEqual(error, DataProviderError.dependencyCancelled)
        } else {
            XCTFail("Unexpected error \(String(describing: resultError))")
        }

        XCTAssertTrue(dataProvider.pendingObservers.isEmpty)
    }

    func testMultipleAddObserverAtOnce() {
        // given

        let dataProvider = prepareDataProvider()

        // when

        var resultError: Error?

        let expectation = XCTestExpectation()

        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: { _ in },
                                 failing: { _ in })

        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: { _ in },
                                 failing: { error in
                                    resultError = error
                                    expectation.fulfill()
        })

        // then

        wait(for: [expectation], timeout: Constants.expectationDuration)

        if let error = resultError as? DataProviderError {
            XCTAssertEqual(error, DataProviderError.observerAlreadyAdded)
        } else {
            XCTFail("Unexpected error \(String(describing: resultError))")
        }
    }

    func testRefreshCalledOnAddObserver() {
        // given

        let sourceList = (0..<10).map { _ in createRandomFeed(in: .default) }

        let dataProvider = prepareDataProvider(with: sourceList)

        // when

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var resultChanges: [[DataProviderChange<FeedData>]] = []

        let updateClosure: ([DataProviderChange<FeedData>]) -> Void = { changes in
            resultChanges.append(changes)

            expectation.fulfill()
        }

        let failureClosure: (Error) -> Void = { error in
            XCTFail("Unexpected error \(error)")

            expectation.fulfill()
        }

        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: updateClosure,
                                 failing: failureClosure)

        // then

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        guard resultChanges.count == 2 else {
            XCTFail("Unexpected number of changes")
            return
        }

        XCTAssertTrue(resultChanges[0].isEmpty)

        let resultItems = resultChanges[1].reduce(into: [FeedData]()) { (result, change) in
            if case .insert(let item) = change {
                result.append(item)
            }
        }.sorted { $0.name > $1.name }

        let expectedItems = sourceList.sorted { $0.name > $1.name }

        XCTAssertEqual(expectedItems, resultItems)
    }

    // MARK: Private

    private func prepareDataProvider(with sourceItems: [FeedData] = []) -> StreamableProvider<FeedData> {
        let repository: CoreDataRepository<FeedData, CDFeed> =
            CoreDataRepositoryFacade.shared.createCoreDataRepository()

        let source: AnyStreamableSource<FeedData> = createStreamableSourceMock(repository: repository,
                                                                               returns: sourceItems)

        let operationManager = OperationManager()

        let observable = CoreDataContextObservable(service: repository.databaseService,
                                                   mapper: repository.dataMapper,
                                                   predicate: { _ in return true })

        let dataProvider = StreamableProvider(source: source,
                                              repository: AnyDataProviderRepository(repository),
                                              observable: AnyDataProviderRepositoryObservable(observable),
                                              operationManager: operationManager)

        observable.start { _ in }

        return dataProvider
    }
}
