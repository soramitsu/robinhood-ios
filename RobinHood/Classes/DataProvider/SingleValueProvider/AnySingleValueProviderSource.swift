/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public final class AnySingleValueProviderSource<T>: SingleValueProviderSourceProtocol {
    public typealias Model = T

    private let _fetch: () -> BaseOperation<Model>

    public init<U: SingleValueProviderSourceProtocol>(_ source: U) where U.Model == Model {
        _fetch = source.fetchOperation
    }

    public init(fetch: @escaping () -> BaseOperation<Model>) {
        _fetch = fetch
    }

    public func fetchOperation() -> BaseOperation<T> {
        return _fetch()
    }
}
