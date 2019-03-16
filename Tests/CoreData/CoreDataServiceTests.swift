import XCTest
@testable import RobinHood

class CoreDataServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()

        CoreDataService.shared.configuration = CoreDataServiceConfiguration.createDefaultConfigutation()
    }

    override func tearDown() {
        try! CoreDataService.shared.close()

        super.tearDown()
    }

    func testWhenAccessedFirstTime() {
        // given
        let invocationsCount = 10

        // when
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = invocationsCount

        guard case .initial = CoreDataService.shared.setupState else {
            XCTFail()
            return
        }

        (0..<invocationsCount).forEach { _ in
            CoreDataService.shared.performAsync { (context, error) in
                XCTAssertNotNil(context)
                XCTAssertNil(error)
                expectation.fulfill()
            }
        }

        guard case .inprogress = CoreDataService.shared.setupState else {
            XCTFail()
            return
        }

        // then
        XCTAssertEqual(CoreDataService.shared.pendingInvocations.count, invocationsCount)

        wait(for: [expectation], timeout: Constants.expectationDuration)

        guard case .completed = CoreDataService.shared.setupState else {
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
            CoreDataService.shared.performAsync { (context, error) in
                XCTAssertNotNil(context)
                XCTAssertNil(error)
                expectation.fulfill()
            }
        }

        CoreDataService.shared.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        // then
        wait(for: [expectation], timeout: Constants.expectationDuration)

        guard case .completed = CoreDataService.shared.setupState else {
            XCTFail()
            return
        }
    }

    func testWhenAccessedAfterSetup() {
        // given
        let invocationsCount = 10

        var expectation = XCTestExpectation()

        CoreDataService.shared.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // when

        expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = invocationsCount

        (0..<invocationsCount).forEach { _ in
            CoreDataService.shared.performAsync { (context, error) in
                XCTAssertNotNil(context)
                XCTAssertNil(error)
                expectation.fulfill()
            }
        }

        // then
        XCTAssertEqual(CoreDataService.shared.pendingInvocations.count, 0)

        wait(for: [expectation], timeout: Constants.expectationDuration)
    }

    func testSuccessfullClose() {
        // given
        let expectation = XCTestExpectation()

        CoreDataService.shared.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        XCTAssertNotNil(CoreDataService.shared.context)

        // when
        XCTAssertNoThrow(try CoreDataService.shared.close())

        // then
        XCTAssertNil(CoreDataService.shared.context)

        guard case .initial = CoreDataService.shared.setupState else {
            XCTFail()
            return
        }
    }

    func testCloseOnSetup() {
        let expectation = XCTestExpectation()

        CoreDataService.shared.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        guard case .inprogress = CoreDataService.shared.setupState else {
            XCTFail()
            return
        }

        XCTAssertThrowsError(try CoreDataService.shared.close())

        wait(for: [expectation], timeout: Constants.expectationDuration)
    }

    func testSuccessfullDrop() {
        // given
        let expectation = XCTestExpectation()

        CoreDataService.shared.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        let path = CoreDataService.shared.configuration.databaseDirectory.path

        // when
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        XCTAssertNoThrow(try CoreDataService.shared.close())
        XCTAssertNoThrow(try CoreDataService.shared.drop())

        // then
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testDropWhenNotClosed() {
        // given
        let expectation = XCTestExpectation()

        CoreDataService.shared.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        XCTAssertThrowsError(try CoreDataService.shared.drop())
    }
}
