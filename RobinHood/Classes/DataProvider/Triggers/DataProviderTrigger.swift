/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public enum DataProviderEvent {
    case initialization
    case fetchById(_ identifier: String)
    case fetchPage(_ page: UInt)
    case addObserver(_ observer: AnyObject)
    case removeObserver(_ observer: AnyObject)
}

public protocol DataProviderTriggerProtocol {
    var delegate: DataProviderTriggerDelegate? { get set }

    func receive(event: DataProviderEvent)
}

public protocol DataProviderTriggerDelegate: class {
    func didTrigger()
}

public struct DataProviderEventTrigger: OptionSet {
    public typealias RawValue = UInt8

    public static var onNone: DataProviderEventTrigger { return DataProviderEventTrigger(rawValue: 0) }
    public static var onInitialization: DataProviderEventTrigger { return DataProviderEventTrigger(rawValue: 1 << 0) }
    public static var onFetchById: DataProviderEventTrigger { return DataProviderEventTrigger(rawValue: 1 << 1) }
    public static var onFetchPage: DataProviderEventTrigger { return DataProviderEventTrigger(rawValue: 1 << 2) }
    public static var onAddObserver: DataProviderEventTrigger { return DataProviderEventTrigger(rawValue: 1 << 3) }
    public static var onRemoveObserver: DataProviderEventTrigger { return DataProviderEventTrigger(rawValue: 1 << 4) }
    public static var onAll: DataProviderEventTrigger {
        let rawValue = DataProviderEventTrigger.onInitialization.rawValue |
            DataProviderEventTrigger.onFetchById.rawValue |
            DataProviderEventTrigger.onFetchPage.rawValue |
            DataProviderEventTrigger.onAddObserver.rawValue |
            DataProviderEventTrigger.onRemoveObserver.rawValue

        return DataProviderEventTrigger(rawValue: rawValue)
    }

    public private(set) var rawValue: UInt8

    public weak var delegate: DataProviderTriggerDelegate?

    public init(rawValue: DataProviderEventTrigger.RawValue) {
        self.rawValue = rawValue
    }

    public mutating func formIntersection(_ other: DataProviderEventTrigger) {
        rawValue &= other.rawValue
    }

    public mutating func formUnion(_ other: DataProviderEventTrigger) {
        rawValue |= other.rawValue
    }

    public mutating func formSymmetricDifference(_ other: DataProviderEventTrigger) {
        rawValue ^= other.rawValue
    }
}

extension DataProviderEventTrigger: DataProviderTriggerProtocol {
    public func receive(event: DataProviderEvent) {
        guard let delegate = delegate else {
            return
        }

        switch event {
        case .initialization where self.contains(.onInitialization):
            delegate.didTrigger()
        case .fetchById where self.contains(.onFetchById):
            delegate.didTrigger()
        case .fetchPage where self.contains(.onFetchPage):
            delegate.didTrigger()
        case .addObserver where self.contains(.onAddObserver):
            delegate.didTrigger()
        case .removeObserver where self.contains(.onRemoveObserver):
            delegate.didTrigger()
        default:
            break
        }
    }
}
