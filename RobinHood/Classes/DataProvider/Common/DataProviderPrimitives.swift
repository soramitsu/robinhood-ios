/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol Identifiable {
    var identifier: String { get }
}

public enum DataProviderChange<T> {
    case insert(newItem: T)
    case update(newItem: T)
    case delete(deletedIdentifier: String)

    var item: T? {
        switch self {
        case .insert(let newItem):
            return newItem
        case .update(let newItem):
            return newItem
        default:
            return nil
        }
    }
}

public struct DataProviderObserverOptions {
    public var alwaysNotifyOnRefresh: Bool

    public init(alwaysNotifyOnRefresh: Bool = false) {
        self.alwaysNotifyOnRefresh = alwaysNotifyOnRefresh
    }
}
