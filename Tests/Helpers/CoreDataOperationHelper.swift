/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import RobinHood
import XCTest

typealias OperationEnqueuClosure = ([Operation]) -> Void

func modifyRepository<T: Identifiable>(_ repository: AnyDataProviderRepository<T>,
                                       handler: XCTestCase,
                                       saving: @escaping () throws -> [T],
                                       deleting: @escaping () throws -> [String],
                                       enqueueClosure: OperationEnqueuClosure? = nil) throws {
    let operation = repository.saveOperation(saving, deleting)
    try handleOperation(operation, handler: handler, enqueueClosure: enqueueClosure)
}

func deleteAllFromRepository<T: Identifiable>(_ repository: AnyDataProviderRepository<T>,
                                              handler: XCTestCase,
                                              enqueueClosure: OperationEnqueuClosure? = nil) throws {
    let operation = repository.deleteAllOperation()
    try handleOperation(operation, handler: handler, enqueueClosure: enqueueClosure)
}

// MARK: Private

private func handleOperation<T>(_ operation: BaseOperation<T>,
                                handler: XCTestCase,
                                enqueueClosure: OperationEnqueuClosure?) throws {
    let expectation = XCTestExpectation()

    operation.completionBlock = {
        expectation.fulfill()
    }

    if let enqueueClosure = enqueueClosure {
        enqueueClosure([operation])
    } else {
        OperationQueue().addOperation(operation)
    }

    handler.wait(for: [expectation], timeout: Constants.expectationDuration)

    _ = try operation.extractResultData(throwing: BaseOperationError.unexpectedDependentResult)
}
