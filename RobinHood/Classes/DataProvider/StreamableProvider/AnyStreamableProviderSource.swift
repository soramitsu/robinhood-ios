/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

/// Closure to receive history request callback from streamable data source.
public typealias AnyStreamableFetchHistoryBlock = (Int, Int, DispatchQueue?, ((Result<Int, Error>?) -> Void)?) -> Void

/**
 *  Type erasure implementation of `StreamableSourceProtocol` protocol. It should be used
 *  to wrap concrete implementation of `StreamableSourceProtocol` before passing as dependency
 *  to streamable data provider.
 */

public final class AnyStreamableSource<T: Identifiable>: StreamableSourceProtocol {
    public typealias Model = T

    private let _fetchHistory: AnyStreamableFetchHistoryBlock

    /**
     *  Initializes type erasure wrapper for streamable source implementation.
     *
     *  - parameters:
     *    - source: Streamable source implementation to erase type of.
     */

    public init<U: StreamableSourceProtocol>(_ source: U) where U.Model == Model {
        _fetchHistory = source.fetchHistory
    }

    /**
     *  Initializes type erasure wrapper with history request closure.
     *
     *  - parameters:
     *    - fetchHistory: Closure to request history from streamable remote source.
     */

    public init(fetchHistory: @escaping AnyStreamableFetchHistoryBlock) {
        _fetchHistory = fetchHistory
    }

    public func fetchHistory(offset: Int, count: Int, runningIn queue: DispatchQueue?,
                             commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {
        _fetchHistory(offset, count, queue, commitNotificationBlock)
    }
}
