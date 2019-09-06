/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

/**
 *  Type erasure implementation of `DataProviderSourceProtocol` protocol. It should be used
 *  to wrap concrete implementation of `DataProviderSourceProtocol` before passing as dependecy,
 *  for example, to data provider.
 */

public final class AnyDataProviderSource<T: Identifiable>: DataProviderSourceProtocol {
    public typealias Model = T

    /// Object responsible for handling communication with remote source
    public private(set) var base: Any

    private let _fetchById: (String) -> BaseOperation<Model?>
    private let _fetchByPage: (UInt) -> BaseOperation<[Model]>

    /**
     *  Initializes type erasure object with implementation of source protocol.
     *
     *  - parameters:
     *    - source: Implementation of `DataProviderSourceProtocol`.
     */

    public init<U: DataProviderSourceProtocol>(_ source: U) where U.Model == Model {
        self.base = source
        _fetchById = source.fetchOperation
        _fetchByPage = source.fetchOperation
    }

    /**
     *  Initializes type erasure object with closures to satisfy `DataProviderSourceProtocol`.
     *  Consider this initialization method to be used to mock data source in tests.
     *
     *  - parameters:
     *    - base: Object responsible for communication with remote source.
     *    - fetchByPage: Closure to return concrete page of remote objects.
     *    - fetchById: Closure to return object by id.
     */

    public init(base: Any,
                fetchByPage: @escaping (UInt) -> BaseOperation<[Model]>,
                fetchById: @escaping (String) -> BaseOperation<Model?>) {
        self.base = base
        _fetchByPage = fetchByPage
        _fetchById = fetchById
    }

    public func fetchOperation(by modelId: String) -> BaseOperation<T?> {
        return _fetchById(modelId)
    }

    public func fetchOperation(page index: UInt) -> BaseOperation<[T]> {
        return _fetchByPage(index)
    }
}
