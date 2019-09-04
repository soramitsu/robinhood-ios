/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public typealias AnyStreamableFetchHistoryBlock = (Int, Int, DispatchQueue?, ((Result<Int, Error>?) -> Void)?) -> Void

public final class AnyStreamableSource<T: Identifiable>: StreamableSourceProtocol {
    public typealias Model = T

    public private(set) var base: Any

    private let _fetchHistory: AnyStreamableFetchHistoryBlock

    public init<U: StreamableSourceProtocol>(_ source: U) where U.Model == Model {
        base = source
        _fetchHistory = source.fetchHistory
    }

    public init(source: Any, fetchHistory: @escaping AnyStreamableFetchHistoryBlock) {
        base = source
        _fetchHistory = fetchHistory
    }

    public func fetchHistory(offset: Int, count: Int, runningIn queue: DispatchQueue?,
                             commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {
        _fetchHistory(offset, count, queue, commitNotificationBlock)
    }
}
