/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

/**
 *  Enum is designed to define type of changes in the list of objects.
 */

public enum ListDifference<Model> {
    /// An object at given index was replaced with new one.
    /// An index, old and new objects are passed as associated values.
    case update(index: Int, old: Model, new: Model)

    /// An object at given index was deleted.
    /// An index and old object are passed as associated values.
    case delete(index: Int, old: Model)

    /// New object at given index was inserted
    /// An index and new object are passed as associated value.
    case insert(index: Int, new: Model)
}

/**
 *  Protocol is designed to provide an interface for difference calculation between
 *  two lists.
 *
 *  Implementation of the protocol should find how current list will change
 *  when changes described as a list of ```DataProviderChange``` items are applied and
 *  return list of ```ListDifference``` items as a result. List of last difference can be
 *  accessed via ```lastDifferences``` property. Also the client doesn't need
 *  to store list of objects separately as it should be available via ```allItems``` property.
 */

public protocol ListDifferenceCalculatorProtocol {
    associatedtype Model: Identifiable

    /// Defines sortition closure of difference calculator. See ```sortBlock``` property.
    typealias ListDifferenceSortBlock = (Model, Model) -> Bool

    /**
     *  Current objects list.
     *
     *  The property should always be modified after ```apply(changes:)``` call.
     */

    var allItems: [Model] { get }

    /**
     *  Last calculated changes.
     *
     *  The property should always be modified after ```apply(changes:)``` call.
     */
    var lastDifferences: [ListDifference<Model>] { get }

    /**
     *  Closure to order objects in the list.
     */

    var sortBlock: ListDifferenceSortBlock { get }

    /**
     *  Applies changes to the list resulting in list of ```ListDifference``` items.
     *
     *  Call to this method should always modify ```allItems``` and ```lastDifferences```
     *  properties.
     *
     *  - parameter:
     *    - changes: List of changes to apply to current ordered list.
     */

    func apply(changes: [DataProviderChange<Model>])
}

/**
 *  Class is designed to provide an implementation of ```ListDifferenceCalculatorProtocol```.
 *  Calculator accepts initial sorted list of objects and sortition closure to calculates changes
 *  in the list on request.
 *
 *  This implementation is aimed to connect data provider with user interface providing all
 *  necessary information to animate changes in ```UITableView``` or ```UICollectionView```.
 */

public final class ListDifferenceCalculator<T: Identifiable>: ListDifferenceCalculatorProtocol {
    public typealias Model = T

    public private(set) var allItems: [T]
    public private(set) var lastDifferences: [ListDifference<T>] = []
    public private(set) var sortBlock: ListDifferenceSortBlock

    /**
     *  Creates difference calculator object.
     *
     *  - parameters:
     *    - initialItems: List of items to start with. It is assumed that the list is
     *    already sorted according to sortition closure.
     *    - sortBlock: Sortition closure that define order in the list.
     */

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
