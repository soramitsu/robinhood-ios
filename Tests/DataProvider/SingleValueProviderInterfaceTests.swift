/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import RobinHood

class SingleValueProviderInterfaceTests: SingleValueProviderBaseTests {
    let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = CoreDataRepositoryFacade.shared.createCoreDataRepository()

    override func setUp() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    override func tearDown() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    func testSynchronizationOnInit() {
        // given
        let object = createRandomFeed(in: .default)
        let trigger = DataProviderEventTrigger.onInitialization
        let source = createSingleValueSourceMock(returns: object)
        let dataProvider = SingleValueProvider<FeedData>(targetIdentifier: "co.jp.sora.project1",
                                               source: source,
                                               repository: AnyDataProviderRepository(repository),
                                               updateTrigger: trigger)

        let expectation = XCTestExpectation()

        var optionalChanges: [DataProviderChange<FeedData>]?

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            optionalChanges = changes
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: changesBlock,
                                 failing: errorBlock)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        guard let change = optionalChanges?.first else {
            XCTFail()
            return
        }

        switch change {
        case .insert(let newItem):
            XCTAssertEqual(object, newItem)
        default:
            XCTFail()
        }
    }

    func testSynchronizationOnObserverAdd() {
        // given
        let object = createRandomFeed(in: .default)
        let trigger = DataProviderEventTrigger.onAddObserver
        let source = createSingleValueSourceMock(returns: object)
        let dataProvider = SingleValueProvider<FeedData>(targetIdentifier: "co.jp.sora.project1",
                                                         source: source,
                                                         repository: AnyDataProviderRepository(repository),
                                                         updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<FeedData>]] = []

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: changesBlock,
                                 failing: errorBlock)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        guard allChanges.count == 2 else {
            XCTFail()
            return
        }

        XCTAssertTrue(allChanges[0].isEmpty)

        XCTAssertEqual(allChanges[1].count, 1)

        guard let change = allChanges[1].first else {
            XCTFail()
            return
        }

        switch change {
        case .insert(let newItem):
            XCTAssertEqual(newItem, object)
        default:
            XCTFail()
        }
    }

    func testFetchFromRepository() {
        // given
        let object = createRandomFeed(in: .default)
        let trigger = DataProviderEventTrigger.onInitialization
        let source = createSingleValueSourceMock(returns: object)
        let dataProvider = SingleValueProvider<FeedData>(targetIdentifier: "co.jp.sora.project1",
                                                         source: source,
                                                         repository: AnyDataProviderRepository(repository),
                                                         updateTrigger: trigger)

        let changeExpectation = XCTestExpectation()

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            changeExpectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: changesBlock,
                                 failing: errorBlock)

        wait(for: [changeExpectation], timeout: Constants.expectationDuration)

        // then
        let optionalResult = fetch(from: dataProvider)

        guard let result = optionalResult, case .success(let fetchedProject) = result else {
            XCTFail()
            return
        }

        XCTAssertEqual(fetchedProject, object)
    }

    func testManualSynchronization() {
        let object = createRandomFeed(in: .default)
        let trigger = DataProviderEventTrigger.onNone
        let source = createSingleValueSourceMock(returns: object)
        let dataProvider = SingleValueProvider<FeedData>(targetIdentifier: "co.jp.sora.project1",
                                                         source: source,
                                                         repository: AnyDataProviderRepository(repository),
                                                         updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<FeedData>]] = []

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: changesBlock,
                                 failing: errorBlock)

        dataProvider.refresh()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        guard allChanges.count == 2 else {
            XCTFail()
            return
        }

        XCTAssertTrue(allChanges[0].isEmpty)

        XCTAssertEqual(allChanges[1].count, 1)

        guard let change = allChanges[1].first else {
            XCTFail()
            return
        }

        switch change {
        case .insert(let newItem):
            XCTAssertEqual(newItem, object)
        default:
            XCTFail()
        }
    }

    func testDeleteOnSynchronization() {
        // given
        let object = createRandomFeed(in: .default)

        guard let payload = try? JSONEncoder().encode(object) else {
            XCTFail()
            return
        }

        let repositoryValueObject = SingleValueProviderObject(identifier: object.identifier, payload: payload)

        let saveExpectation = XCTestExpectation()

        repository.save(updating: [repositoryValueObject], deleting: [], runCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)

        let trigger = DataProviderEventTrigger.onNone
        let source: AnySingleValueProviderSource<FeedData> = createSingleValueSourceMock(returns: nil)
        let dataProvider = SingleValueProvider<FeedData>(targetIdentifier: object.identifier,
                                                         source: source,
                                                         repository: AnyDataProviderRepository(repository),
                                                         updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<FeedData>]] = []

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
        }

        let errorBlock: (Error) -> Void = { (error) in }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: changesBlock,
                                 failing: errorBlock,
                                 options: options)

        // when

        dataProvider.refresh()

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        // then

        XCTAssertEqual(allChanges.count, 2)

        XCTAssertEqual(allChanges[0].count, 1)

        switch allChanges[0][0] {
        case .insert(let receivedProject):
            XCTAssertEqual(receivedProject, object)
        default:
            XCTFail()
        }

        XCTAssertEqual(allChanges[1].count, 1)

        switch allChanges[1][0] {
        case .delete(let identifier):
            XCTAssertEqual(dataProvider.targetIdentifier, identifier)
        default:
            XCTFail()
        }
    }

    func testDataProviderSuccessWithAlwaysNotifyOption() {
        // given
        let object = createRandomFeed(in: .default)

        guard let payload = try? JSONEncoder().encode(object) else {
            XCTFail()
            return
        }

        let repositoryValueObject = SingleValueProviderObject(identifier: object.identifier, payload: payload)

        let saveExpectation = XCTestExpectation()

        repository.save(updating: [repositoryValueObject], deleting: [], runCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)

        let trigger = DataProviderEventTrigger.onNone
        let source = createSingleValueSourceMock(returns: object)
        let dataProvider = SingleValueProvider<FeedData>(targetIdentifier: object.identifier,
                                                         source: source,
                                                         repository: AnyDataProviderRepository(repository),
                                                         updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<FeedData>]] = []

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: changesBlock,
                                 failing: errorBlock,
                                 options: options)

        // when
        dataProvider.refresh()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard allChanges[0].count == 1 else {
            XCTFail()
            return
        }

        guard let change = allChanges[0].first else {
            XCTFail()
            return
        }

        switch change {
        case .insert(let newItem):
            XCTAssertEqual(newItem, object)
        default:
            XCTFail()
        }

        XCTAssertEqual(allChanges[1].count, 0)
    }

    func testDataProviderFailWithAlwaysNotifyOption() {
        // given
        let object = createRandomFeed(in: .default)

        guard let payload = try? JSONEncoder().encode(object) else {
            XCTFail()
            return
        }

        let repositoryValueObject = SingleValueProviderObject(identifier: object.identifier, payload: payload)

        let saveExpectation = XCTestExpectation()

        repository.save(updating: [repositoryValueObject], deleting: [], runCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)

        let trigger = DataProviderEventTrigger.onNone
        let source: AnySingleValueProviderSource<FeedData> = createSingleValueSourceMock(returns: NetworkBaseError.unexpectedResponseObject)
        let dataProvider = SingleValueProvider<FeedData>(targetIdentifier: object.identifier,
                                                         source: source,
                                                         repository: AnyDataProviderRepository(repository),
                                                         updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<FeedData>]] = []
        var receivedError: Error?

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
        }

        let errorBlock: (Error) -> Void = { (error) in
            receivedError = error
            expectation.fulfill()
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: changesBlock,
                                 failing: errorBlock,
                                 options: options)

        // when
        dataProvider.refresh()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        XCTAssertNotNil(receivedError)

        guard allChanges.count == 1 else {
            XCTFail()
            return
        }

        guard let change = allChanges[0].first else {
            XCTFail()
            return
        }

        switch change {
        case .insert(let newItem):
            XCTAssertEqual(newItem, object)
        default:
            XCTFail()
        }

    }

    func testAddObserverWithoutWaitingSynchronization() {
        // given
        let object = createRandomFeed(in: .default)

        let trigger = DataProviderEventTrigger.onNone
        let source = createSingleValueSourceMock(returns: object)
        let dataProvider = SingleValueProvider<FeedData>(targetIdentifier: object.identifier,
                                                         source: source,
                                                         repository: AnyDataProviderRepository(repository),
                                                         updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<FeedData>]] = []

        let changesBlock: ([DataProviderChange<FeedData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when

        dataProvider.refresh()

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                  waitsInProgressSyncOnAdd: false)
        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: changesBlock,
                                 failing: errorBlock,
                                 options: options)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then

        guard allChanges[1].count == 1 else {
            XCTFail()
            return
        }

        guard let change = allChanges[1].first else {
            XCTFail()
            return
        }

        switch change {
        case .insert(let newItem):
            XCTAssertEqual(newItem, object)
        default:
            XCTFail()
        }

        XCTAssertTrue(allChanges[0].isEmpty)
    }
}
