import XCTest
@testable import RobinHood

class CoreDataServiceTests: XCTestCase {
    let databaseService: CoreDataService = {
        let configuration = CoreDataServiceConfiguration.createDefaultConfigutation()
        return CoreDataService(configuration: configuration)
    }()

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        try! databaseService.close()

        super.tearDown()
    }

    func testWhenAccessedFirstTime() {
        // given
        let invocationsCount = 10

        // when
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = invocationsCount

        guard case .initial = databaseService.setupState else {
            XCTFail()
            return
        }

        (0..<invocationsCount).forEach { _ in
            databaseService.performAsync { (context, error) in
                XCTAssertNotNil(context)
                XCTAssertNil(error)
                expectation.fulfill()
            }
        }

        guard case .inprogress = databaseService.setupState else {
            XCTFail()
            return
        }

        // then
        XCTAssertEqual(databaseService.pendingInvocations.count, invocationsCount)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        guard case .completed = databaseService.setupState else {
            XCTFail()
            return
        }
    }

    func testWhenAccessOnInBackgroundAndMain() {
        // given
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        // when
        DispatchQueue.global(qos: .background).async {
            self.databaseService.performAsync { (context, error) in
                XCTAssertNotNil(context)
                XCTAssertNil(error)
                expectation.fulfill()
            }
        }

        databaseService.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        // then
        wait(for: [expectation], timeout: Constants.expectationDuration)

        guard case .completed = databaseService.setupState else {
            XCTFail()
            return
        }
    }

    func testWhenAccessedAfterSetup() {
        // given
        let invocationsCount = 10

        var expectation = XCTestExpectation()

        databaseService.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // when

        expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = invocationsCount

        (0..<invocationsCount).forEach { _ in
            databaseService.performAsync { (context, error) in
                XCTAssertNotNil(context)
                XCTAssertNil(error)
                expectation.fulfill()
            }
        }

        // then
        XCTAssertEqual(databaseService.pendingInvocations.count, 0)

        wait(for: [expectation], timeout: Constants.expectationDuration)
    }

    func testSuccessfullClose() {
        // given
        let expectation = XCTestExpectation()

        databaseService.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        XCTAssertNotNil(databaseService.context)

        // when
        XCTAssertNoThrow(try databaseService.close())

        // then
        XCTAssertNil(databaseService.context)

        guard case .initial = databaseService.setupState else {
            XCTFail()
            return
        }
    }

    func testCloseOnSetup() {
        let expectation = XCTestExpectation()

        databaseService.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        guard case .inprogress = databaseService.setupState else {
            XCTFail()
            return
        }

        XCTAssertThrowsError(try databaseService.close())

        wait(for: [expectation], timeout: Constants.expectationDuration)
    }

    func testSuccessfullDrop() {
        guard case .persistent(let settings) = databaseService.configuration.storageType else {
            return
        }

        // given
        let expectation = XCTestExpectation()

        databaseService.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        let path = settings.databaseDirectory.path

        // when
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        XCTAssertNoThrow(try databaseService.close())
        XCTAssertNoThrow(try databaseService.drop())

        // then
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testDropWhenNotClosed() {
        // given
        let expectation = XCTestExpectation()

        databaseService.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        XCTAssertThrowsError(try databaseService.drop())
    }
}
