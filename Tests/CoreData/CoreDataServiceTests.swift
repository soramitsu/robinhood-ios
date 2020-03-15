/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

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
        try! databaseService.drop()

        super.tearDown()
    }

    func testWhenAccessedFirstTime() {
        // given
        let invocationsCount = 10

        // when
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = invocationsCount

        guard databaseService.context == nil else {
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

        // then

        wait(for: [expectation], timeout: Constants.expectationDuration)

        guard databaseService.context != nil else {
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

        guard databaseService.context != nil else {
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
    }

    func testCloseOnSetup() {
        let expectation = XCTestExpectation()

        databaseService.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        XCTAssertNoThrow(try databaseService.close())

        wait(for: [expectation], timeout: Constants.expectationDuration)

        XCTAssertNil(databaseService.context)
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
