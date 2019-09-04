/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol SingleValueProviderProtocol {
    associatedtype Model

    var executionQueue: OperationQueue { get }

    func fetch(with completionBlock: ((Result<Model, Error>?) -> Void)?) -> BaseOperation<Model>

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue?,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void,
                     options: DataProviderObserverOptions)

    func removeObserver(_ observer: AnyObject)

    func refresh()
}

public extension SingleValueProviderProtocol {
    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue?,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void) {
        addObserver(observer,
                    deliverOn: queue,
                    executing: updateBlock,
                    failing: failureBlock,
                    options: DataProviderObserverOptions())
    }
}

public protocol SingleValueProviderSourceProtocol {
    associatedtype Model

    func fetchOperation() -> BaseOperation<Model>
}
