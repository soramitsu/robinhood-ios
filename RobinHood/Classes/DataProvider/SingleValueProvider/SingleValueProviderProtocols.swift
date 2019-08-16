/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol SingleValueProviderProtocol {
    associatedtype Model

    var executionQueue: OperationQueue { get }

    func fetch(with completionBlock: ((OperationResult<Model>?) -> Void)?) -> BaseOperation<Model>

    func addCacheObserver(_ observer: AnyObject,
                          deliverOn queue: DispatchQueue?,
                          executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                          failing failureBlock: @escaping (Error) -> Void,
                          options: DataProviderObserverOptions)

    func removeCacheObserver(_ observer: AnyObject)

    func refreshCache()
}

public extension SingleValueProviderProtocol {
    func addCacheObserver(_ observer: AnyObject,
                          deliverOn queue: DispatchQueue?,
                          executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                          failing failureBlock: @escaping (Error) -> Void) {
        addCacheObserver(observer,
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
