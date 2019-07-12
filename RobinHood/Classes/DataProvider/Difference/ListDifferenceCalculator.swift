/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public enum ListDifference<Model> {
    case update(index: Int, old: Model, new: Model)
    case delete(index: Int, old: Model)
    case insert(index: Int, new: Model)
}

public protocol ListDifferenceCalculatorProtocol {
    associatedtype Model: Identifiable

    typealias ListDifferenceSortBlock = (Model, Model) -> Bool

    var allItems: [Model] { get }
    var lastDifferences: [ListDifference<Model>] { get }

    var sortBlock: ListDifferenceSortBlock { get }

    func apply(changes: [DataProviderChange<Model>])
}

public final class ListDifferenceCalculator<T: Identifiable>: ListDifferenceCalculatorProtocol {
    public typealias Model = T

    public private(set) var allItems: [T]
    public private(set) var lastDifferences: [ListDifference<T>] = []
    public private(set) var sortBlock: ListDifferenceSortBlock

    public init(initialItems: [T], sortBlock: @escaping ListDifferenceSortBlock) {
        self.allItems = initialItems
        self.sortBlock = sortBlock
    }

    public func apply(changes: [DataProviderChange<T>]) {
        lastDifferences.removeAll()

        let updateItems: [Model] = changes.compactMap { (change) in
            if case .update(let item) = change {
                return item
            } else {
                return nil
            }
        }

        let deleteIdentifiers: [String] = changes.compactMap { (change) in
            if case .delete(let identifier) = change {
                return identifier
            } else {
                return nil
            }
        }

        let insertItems: [Model] = changes.compactMap { (change) in
            if case .insert(let item) = change {
                return item
            } else {
                return nil
            }
        }

        if updateItems.count > 0 {
            update(items: updateItems)
        }

        if deleteIdentifiers.count > 0 {
            delete(identifiers: deleteIdentifiers)
        }

        if insertItems.count > 0 {
            insert(items: insertItems)
        }
    }

    private func update(items: [T]) {
        for (index, oldItem) in allItems.enumerated() {
            if let newItem = items.first(where: { $0.identifier == oldItem.identifier }) {
                lastDifferences.append(.update(index: index, old: oldItem, new: newItem))
                allItems[index] = newItem
            }
        }
    }

    private func delete(identifiers: [String]) {
        for (index, oldItem) in allItems.enumerated() {
            if identifiers.contains(oldItem.identifier) {
                lastDifferences.append(.delete(index: index, old: oldItem))
            }
        }

        allItems.removeAll { (item) in
            return identifiers.contains(item.identifier)
        }
    }

    private func insert(items: [T]) {
        allItems.append(contentsOf: items)
        allItems.sort(by: sortBlock)

        for (index, item) in allItems.enumerated() {
            if items.contains(where: { $0.identifier == item.identifier }) {
                lastDifferences.append(.insert(index: index, new: item))
            }
        }
    }
}
