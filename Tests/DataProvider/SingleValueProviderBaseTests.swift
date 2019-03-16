import XCTest
@testable import RobinHood

class SingleValueProviderBaseTests: XCTestCase {
    func fetch<T, U>(from dataProvider: SingleValueProvider<T, U>) -> OperationResult<T>? {
        let expectation = XCTestExpectation()

        let fetchOperation = dataProvider.fetch { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationDuration)

        return fetchOperation.result
    }
}
