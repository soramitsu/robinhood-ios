/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
import RobinHood

class CompoundOperationWrapperTests: XCTestCase {

    func testInitAndExecutionFlow() throws {
        // given

        let operationManager = OperationManager()

        let arg1: Int = 10
        let arg2: Int = 20

        let firstArgOperation = ClosureOperation { arg1 }

        let secondArgOperation = ClosureOperation { arg2 }

        let sumArgOperation: BaseOperation<Int> = ClosureOperation {
            let firstArg = try firstArgOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let secondArg = try secondArgOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return firstArg + secondArg
        }

        sumArgOperation.addDependency(firstArgOperation)
        sumArgOperation.addDependency(secondArgOperation)

        let wrapper = CompoundOperationWrapper(targetOperation: sumArgOperation,
                                               dependencies: [firstArgOperation, secondArgOperation])

        var result: Int?

        let expectation = XCTestExpectation()

        wrapper.targetOperation.completionBlock = {
            result = try? sumArgOperation.extractResultData()

            expectation.fulfill()
        }

        // when

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        // then

        XCTAssertEqual(arg1 + arg2, result)
    }

}
