/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
@testable import RobinHood

class DataProviderBaseTests: XCTestCase {

    func fetchById<T>(_ identifier: String, from dataProvider: DataProvider<T>) -> Result<T?, Error>? {
        let expectation = XCTestExpectation()

        let fetchByIdOperation = dataProvider.fetch(by: identifier) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return fetchByIdOperation.result
    }

    func fetch<T>(page: UInt, from dataProvider: DataProvider<T>) -> Result<[T], Error>? {
        let expectation = XCTestExpectation()

        let fetchByPageOperation = dataProvider.fetch(page: page) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return fetchByPageOperation.result
    }
}
