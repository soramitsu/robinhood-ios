/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import RobinHood

class SingleValueProviderBaseTests: XCTestCase {
    func fetch<T>(from dataProvider: SingleValueProvider<T>) -> Result<T?, Error>? {
        let expectation = XCTestExpectation()

        let fetchWrapper = dataProvider.fetch { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return fetchWrapper.targetOperation.result
    }
}
