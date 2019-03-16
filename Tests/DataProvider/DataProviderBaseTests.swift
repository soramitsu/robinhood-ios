import XCTest
@testable import RobinHood

class DataProviderBaseTests: XCTestCase {

    func fetchById<T, U>(_ identifier: String, from dataProvider: DataProvider<T, U>) -> OperationResult<T?>? {
        let expectation = XCTestExpectation()

        let fetchByIdOperation = dataProvider.fetch(by: identifier) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return fetchByIdOperation.result
    }

    func fetch<T, U>(page: UInt, from dataProvider: DataProvider<T, U>) -> OperationResult<[T]>? {
        let expectation = XCTestExpectation()

        let fetchByPageOperation = dataProvider.fetch(page: page) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return fetchByPageOperation.result
    }
}
