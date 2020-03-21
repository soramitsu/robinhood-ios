/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import RobinHood

class SingleValueProviderObserverTests: XCTestCase {
    func testAddObserverWaitInitAndRemove() {
        // given

        let dataProvider = prepareDataProvider()

        let operationQueue = OperationQueue()

        // when

        let addExpectation = XCTestExpectation()

        let addObserverWaitingOperation = ClosureOperation {
            while(dataProvider.observers.isEmpty) {
                usleep(10000)
            }
        }

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

    // MARK: Private

    private func prepareDataProvider() -> SingleValueProvider<FeedData> {
        let trigger = DataProviderEventTrigger.onNone
        let source: AnySingleValueProviderSource<FeedData> = createSingleValueSourceMock(returns: nil)
        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = CoreDataRepositoryFacade.shared.createCoreDataRepository()

        let dataProvider = SingleValueProvider<FeedData>(targetIdentifier: UUID().uuidString,
            source: source,
                                                         repository: AnyDataProviderRepository(repository),
                                                         updateTrigger: trigger)

        return dataProvider
    }
}
