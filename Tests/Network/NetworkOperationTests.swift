/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
import RobinHood
import FireMock

class NetworkOperationTests: NetworkBaseTests {

    func testSingleDummyOperationSuccess() {
        // given
        FireMock.register(mock: DummyNetworkMock(),
                          forURL: Constants.dummyNetworkURL,
                          httpMethod: .get)

        let operationQueue = OperationQueue()

        let expectedValue = 10

        let operation = createTestOperation(url: Constants.dummyNetworkURL,
                                            resultValue: expectedValue)

        let expectation = XCTestExpectation()

        operation.completionBlock = {
            expectation.fulfill()
        }

        // when
        operationQueue.addOperation(operation)

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        if let operationResult = operation.result, case .success(let value) = operationResult {
            XCTAssertEqual(value, expectedValue)
        } else {
            XCTFail()
        }
    }

    func testSingleDummyOperationCancel() {
        // given
        FireMock.register(mock: DummyNetworkMock(delay: 60.0),
                          forURL: Constants.dummyNetworkURL,
                          httpMethod: .get)

        let operationQueue = OperationQueue()

        let expectedValue = 10

        let operation = createTestOperation(url: Constants.dummyNetworkURL,
                                            resultValue: expectedValue)

        let expectation = XCTestExpectation()

        operation.completionBlock = {
            expectation.fulfill()
        }

        // when
        operationQueue.addOperation(operation)

        operation.cancel()

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        XCTAssertNil(operation.result)
    }

    func testRandomOperations() {
        // given
        let operationQueue = OperationQueue()

        let operationCount = 20

        let expectedValue = "Hello World!"

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = operationCount

        // when
        for index in 0..<operationCount {
            let url = Constants.dummyNetworkURL.appendingPathComponent(String(index))
            FireMock.register(mock: DummyNetworkMock(delay: 0.05 * TimeInterval(index) + 1.0),
                              forURL: url,
                              httpMethod: .get)

            let operation = createTestOperation(url: url, resultValue: expectedValue)

            operation.completionBlock = {
                if let operationResult = operation.result, case .success(let value) = operationResult {
                    XCTAssertEqual(value, expectedValue)
                } else {
                    XCTFail()
                }

                expectation.fulfill()
            }

            operationQueue.addOperation(operation)
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout * TimeInterval(operationCount))
    }
}
