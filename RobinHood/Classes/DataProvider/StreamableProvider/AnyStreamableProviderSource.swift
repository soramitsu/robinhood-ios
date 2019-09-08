/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public typealias AnyStreamableFetchHistoryBlock = (Int, Int, DispatchQueue?, ((Result<Int, Error>?) -> Void)?) -> Void

public final class AnyStreamableSource<T: Identifiable>: StreamableSourceProtocol {
    public typealias Model = T

    private let _fetchHistory: AnyStreamableFetchHistoryBlock

    public init<U: StreamableSourceProtocol>(_ source: U) where U.Model == Model {
        _fetchHistory = source.fetchHistory
    }

    public init(fetchHistory: @escaping AnyStreamableFetchHistoryBlock) {
        _fetchHistory = fetchHistory
    }

    public func fetchHistory(offset: Int, count: Int, runningIn queue: DispatchQueue?,
                             commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {
        _fetchHistory(offset, count, queue, commitNotificationBlock)
    }
}
