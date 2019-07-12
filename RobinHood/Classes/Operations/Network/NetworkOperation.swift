/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public final class NetworkOperation<ResultType>: BaseOperation<ResultType> {
    public lazy var networkSession: URLSession = URLSession.shared

    public lazy var networkIndicatorManager: NetworkIndicatorManagerProtocol = NetworkIndicatorManager.shared

    public var requestModifier: NetworkRequestModifierProtocol?

    public var requestFactory: NetworkRequestFactoryProtocol
    public var resultFactory: AnyNetworkResultFactory<ResultType>

    private var networkTask: URLSessionDataTask?

    public init(requestFactory: NetworkRequestFactoryProtocol, resultFactory: AnyNetworkResultFactory<ResultType>) {
        self.requestFactory = requestFactory
        self.resultFactory = resultFactory

        super.init()
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            var request = try requestFactory.createRequest()

            if let modifier = requestModifier {
                request = try modifier.modify(request: request)
            }

            let semaphore = DispatchSemaphore(value: 0)

            var receivedData: Data?
            var receivedResponse: URLResponse?
            var receivedError: Error?

            if isCancelled {
                return
            }

            networkIndicatorManager.increment()

            defer {
                networkIndicatorManager.decrement()
            }

            let dataTask = networkSession.dataTask(with: request) { (data, response, error) in

                receivedData = data
                receivedResponse = response
                receivedError = error

                semaphore.signal()
            }

            networkTask = dataTask
            dataTask.resume()

            _ = semaphore.wait(timeout: .distantFuture)

            if let error = receivedError, NetworkOperationHelper.isCancellation(error: error) {
                return
            }

            result = resultFactory.createResult(data: receivedData,
                                                response: receivedResponse, error: receivedError)

        } catch {
            result = .error(error)
        }
    }

    override public func cancel() {
        networkTask?.cancel()

        super.cancel()
    }
}
