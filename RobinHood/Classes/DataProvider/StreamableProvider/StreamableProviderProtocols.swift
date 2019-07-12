/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol StreamableProviderProtocol {
    associatedtype Model: Identifiable

    func fetch(offset: Int, count: Int,
               with completionBlock: @escaping (OperationResult<[Model]>?) -> Void) -> BaseOperation<[Model]>

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void,
                     options: DataProviderObserverOptions)

    func removeObserver(_ observer: AnyObject)
}

public extension StreamableProviderProtocol {
    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void) {
        addObserver(observer,
                    deliverOn: queue,
                    executing: updateBlock,
                    failing: failureBlock,
                    options: DataProviderObserverOptions(alwaysNotifyOnRefresh: false))
    }
}

public protocol StreamableSourceProtocol {
    associatedtype Model: Identifiable

    func fetchHistory(offset: Int, count: Int, runningIn queue: DispatchQueue?,
                      commitNotificationBlock: ((OperationResult<Int>?) -> Void)?)
}

public protocol StreamableSourceObservable {
    associatedtype Model

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void)

    func removeObserver(_ observer: AnyObject)
}
