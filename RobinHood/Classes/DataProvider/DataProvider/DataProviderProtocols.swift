/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol DataProviderProtocol {
    associatedtype Model: Identifiable

    var executionQueue: OperationQueue { get }

    func fetch(by modelId: String, completionBlock: ((OperationResult<Model?>?) -> Void)?) -> BaseOperation<Model?>

    func fetch(page index: UInt, completionBlock: ((OperationResult<[Model]>?) -> Void)?) -> BaseOperation<[Model]>

    func addCacheObserver(_ observer: AnyObject,
                          deliverOn queue: DispatchQueue,
                          executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                          failing failureBlock: @escaping (Error) -> Void,
                          options: DataProviderObserverOptions)

    func removeCacheObserver(_ observer: AnyObject)

    func refreshCache()
}

public extension DataProviderProtocol {
    func addCacheObserver(_ observer: AnyObject,
                          deliverOn queue: DispatchQueue,
                          executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                          failing failureBlock: @escaping (Error) -> Void) {
        addCacheObserver(observer,
                         deliverOn: queue,
                         executing: updateBlock,
                         failing: failureBlock,
                         options: DataProviderObserverOptions())
    }
}

public protocol DataProviderSourceProtocol {
    associatedtype Model: Identifiable

    func fetchOperation(by modelId: String) -> BaseOperation<Model?>

    func fetchOperation(page index: UInt) -> BaseOperation<[Model]>
}
