import XCTest
@testable import RobinHood

class SingleValueProviderInterfaceTests: SingleValueProviderBaseTests {
    let cache: CoreDataCache<SingleValueProviderObject, CDSingleValue> = createDefaultCoreDataCache()

    override func setUp() {
        try! clearDatabase(using: cache.databaseService)
    }

    override func tearDown() {
        try! clearDatabase(using: cache.databaseService)
    }

    func testSynchronizationOnInit() {
        // given
        let project = createRandomProject()
        let trigger = DataProviderEventTrigger.onInitialization
        let source = createSingleValueSourceMock(base: self, returns: project)
        let dataProvider = SingleValueProvider<ProjectData, CDSingleValue>(targetIdentifier: "co.jp.sora.project1",
                                               source: source,
                                               cache: cache,
                                               updateTrigger: trigger)

        let expectation = XCTestExpectation()

        var optionalChanges: [DataProviderChange<ProjectData>]?

        let changesBlock: ([DataProviderChange<ProjectData>]) -> Void = { (changes) in
            optionalChanges = changes
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addCacheObserver(self,
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
            XCTAssertEqual(project, newItem)
        default:
            XCTFail()
        }
    }

    func testSynchronizationOnObserverAdd() {
        // given
        let project = createRandomProject()
        let trigger = DataProviderEventTrigger.onAddObserver
        let source = createSingleValueSourceMock(base: self, returns: project)
        let dataProvider = SingleValueProvider<ProjectData, CDSingleValue>(targetIdentifier: "co.jp.sora.project1",
                                                                           source: source,
                                                                           cache: cache,
                                                                           updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<ProjectData>]] = []

        let changesBlock: ([DataProviderChange<ProjectData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addCacheObserver(self,
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
            XCTAssertEqual(newItem, project)
        default:
            XCTFail()
        }
    }

    func testFetchFromCache() {
        // given
        let project = createRandomProject()
        let trigger = DataProviderEventTrigger.onInitialization
        let source = createSingleValueSourceMock(base: self, returns: project)
        let dataProvider = SingleValueProvider<ProjectData, CDSingleValue>(targetIdentifier: "co.jp.sora.project1",
                                                                           source: source,
                                                                           cache: cache,
                                                                           updateTrigger: trigger)

        let changeExpectation = XCTestExpectation()

        let changesBlock: ([DataProviderChange<ProjectData>]) -> Void = { (changes) in
            changeExpectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addCacheObserver(self,
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

        XCTAssertEqual(fetchedProject, project)
    }

    func testManualSynchronization() {
        let project = createRandomProject()
        let trigger = DataProviderEventTrigger.onNone
        let source = createSingleValueSourceMock(base: self, returns: project)
        let dataProvider = SingleValueProvider<ProjectData, CDSingleValue>(targetIdentifier: "co.jp.sora.project1",
                                                                           source: source,
                                                                           cache: cache,
                                                                           updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<ProjectData>]] = []

        let changesBlock: ([DataProviderChange<ProjectData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        // when
        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: errorBlock)

        dataProvider.refreshCache()

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
            XCTAssertEqual(newItem, project)
        default:
            XCTFail()
        }
    }

    func testDeleteOnSynchronization() {
        // given
        let project = createRandomProject()

        guard let payload = try? JSONEncoder().encode(project) else {
            XCTFail()
            return
        }

        let cacheValueObject = SingleValueProviderObject(identifier: project.identifier, payload: payload)

        let saveExpectation = XCTestExpectation()

        cache.save(updating: [cacheValueObject], deleting: [], runCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)

        let trigger = DataProviderEventTrigger.onNone
        let source: AnySingleValueProviderSource<ProjectData?> = createSingleValueSourceMock(base: self, returns: nil)
        let dataProvider = SingleValueProvider<ProjectData?, CDSingleValue>(targetIdentifier: project.identifier,
                                                                           source: source,
                                                                           cache: cache,
                                                                           updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<ProjectData?>]] = []

        let changesBlock: ([DataProviderChange<ProjectData?>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
        }

        let errorBlock: (Error) -> Void = { (error) in
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: errorBlock,
                                      options: options)

        // when

        dataProvider.refreshCache()

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        // then

        XCTAssertEqual(allChanges.count, 2)

        XCTAssertEqual(allChanges[0].count, 1)

        switch allChanges[0][0] {
        case .insert(let receivedProject):
            XCTAssertEqual(receivedProject, project)
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
        let project = createRandomProject()

        guard let payload = try? JSONEncoder().encode(project) else {
            XCTFail()
            return
        }

        let cacheValueObject = SingleValueProviderObject(identifier: project.identifier, payload: payload)

        let saveExpectation = XCTestExpectation()

        cache.save(updating: [cacheValueObject], deleting: [], runCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)

        let trigger = DataProviderEventTrigger.onNone
        let source = createSingleValueSourceMock(base: self, returns: project)
        let dataProvider = SingleValueProvider<ProjectData, CDSingleValue>(targetIdentifier: project.identifier,
                                                                           source: source,
                                                                           cache: cache,
                                                                           updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<ProjectData>]] = []

        let changesBlock: ([DataProviderChange<ProjectData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
            return
        }

        let errorBlock: (Error) -> Void = { (error) in
            XCTFail()
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: errorBlock,
                                      options: options)

        // when
        dataProvider.refreshCache()

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
            XCTAssertEqual(newItem, project)
        default:
            XCTFail()
        }

        XCTAssertEqual(allChanges[1].count, 0)
    }

    func testDataProviderFailWithAlwaysNotifyOption() {
        // given
        let project = createRandomProject()

        guard let payload = try? JSONEncoder().encode(project) else {
            XCTFail()
            return
        }

        let cacheValueObject = SingleValueProviderObject(identifier: project.identifier, payload: payload)

        let saveExpectation = XCTestExpectation()

        cache.save(updating: [cacheValueObject], deleting: [], runCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)

        let trigger = DataProviderEventTrigger.onNone
        let source: AnySingleValueProviderSource<ProjectData> = createSingleValueSourceMock(base: self, returns: NetworkBaseError.unexpectedResponseObject)
        let dataProvider = SingleValueProvider<ProjectData, CDSingleValue>(targetIdentifier: project.identifier,
                                                                           source: source,
                                                                           cache: cache,
                                                                           updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var allChanges: [[DataProviderChange<ProjectData>]] = []
        var receivedError: Error?

        let changesBlock: ([DataProviderChange<ProjectData>]) -> Void = { (changes) in
            allChanges.append(changes)
            expectation.fulfill()
        }

        let errorBlock: (Error) -> Void = { (error) in
            receivedError = error
            expectation.fulfill()
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        dataProvider.addCacheObserver(self,
                                      deliverOn: .main,
                                      executing: changesBlock,
                                      failing: errorBlock,
                                      options: options)

        // when
        dataProvider.refreshCache()

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
            XCTAssertEqual(newItem, project)
        default:
            XCTFail()
        }

    }
}
