/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public final class AnyDataProvider<T: Identifiable & Equatable>: DataProviderProtocol {
    public typealias Model = T

    private let _fetchById: (String, ((OperationResult<T?>?) -> Void)?) -> BaseOperation<T?>
    private let _fetchPage: (UInt, ((OperationResult<[T]>?) -> Void)?) -> BaseOperation<[T]>

    private let _addObserver: (AnyObject, DispatchQueue?,
    @escaping ([DataProviderChange<T>]) -> Void, @escaping (Error) -> Void, DataProviderObserverOptions) -> Void

    private let _removeObserver: (AnyObject) -> Void

    private let _refresh: () -> Void

    public private(set) var executionQueue: OperationQueue

    public init<U: DataProviderProtocol>(_ dataProvider: U) where U.Model == Model {
        _fetchById = dataProvider.fetch
        _fetchPage = dataProvider.fetch
        _addObserver = dataProvider.addObserver
        _removeObserver = dataProvider.removeObserver
        _refresh = dataProvider.refresh
        self.executionQueue = dataProvider.executionQueue
    }

    public func fetch(by modelId: String, completionBlock: ((OperationResult<T?>?) -> Void)?) -> BaseOperation<T?> {
        return _fetchById(modelId, completionBlock)
    }

    public func fetch(page index: UInt, completionBlock: ((OperationResult<[T]>?) -> Void)?) -> BaseOperation<[T]> {
        return _fetchPage(index, completionBlock)
    }

    public func addObserver(_ observer: AnyObject,
                            deliverOn queue: DispatchQueue?,
                            executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                            failing failureBlock: @escaping (Error) -> Void,
                            options: DataProviderObserverOptions) {

        _addObserver(observer, queue, updateBlock, failureBlock, options)
    }

    public func removeObserver(_ observer: AnyObject) {
        _removeObserver(observer)
    }

    public func refresh() {
        _refresh()
    }
}
