/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

/**
 *  Protocol is designed to provide an access to locally persistent list of objects that get updated by
 *  streaming changes from the remote. Clients can fetch object and suscribe for changes using methods described below.
 *
 *  Due to the nature of streaming it is convienent that source implementation will directly save changes to
 *  repository. Provider in this case is expected to trigger history fetch from data source and deliver
 *  changes received by listening repository to observers.
 */

public protocol StreamableProviderProtocol {
    associatedtype Model: Identifiable

    /**
     *  Returns list of objects from local store or fetches from remote store if it is not enough.
     *
     *  - parameters:
     *    - offset: `Int` offset to fetch objects from.
     *    - count: `Int` number of objects to fetch.
     *    - completionBlock: Block to call on completion. `Result` value is passed as a parameter.
     *    Note that remote objects may not be delivered in the completion closure and the client needs to add
     *    an observer to receive remained part of the list.
     *  - returns: Operation object to cancel if there is a need or to chain with other operations.
     *  **Don't try** to override operation's completion block but provide completion block to the function instead.
     */

    func fetch(offset: Int, count: Int,
               with completionBlock: @escaping (Result<[Model], Error>?) -> Void) -> BaseOperation<[Model]>

    /**
     *  Adds observer to notify when there are changes in local storage.
     *
     *  The closure is called after each received set
     *  of changes or if `alwaysNotifyOnRefresh` flag set in provided `options`. Failure block
     *  is called in case data provider is failed to add an observer or after each failed synchronization
     *  attempt in case `alwaysNotifyOnRefresh` flag is set. Consider also `options` parameter to
     *  properly setup a way of how and when observer is notified.
     *
     *  - parameters:
     *    - observer: An object which is responsible for handling changes. The object is not retained
     *      so it will be automatically removed from observation when deallocated. If the object
     *      is already in the observers list then failure block is called with `observerAlreadyAdded` error.
     *    - queue: Queue to dispatch update and failure blocks in. If `nil` is provided for this parameter
     *      then closures are dispatched in internal queue.
     *    - updateBlock: Closure to call when there are changes in local store.
     *      If there is a need to be notified even if there are no objects recevied
     *      after ```fetch(offset:count:with:)``` call from remote source then consider to set
     *      `alwaysNotifyOnRefresh` in options.
     *    - failureBlock: Closure to call in case data provider failed to add the observer. It is also called
     *      after failed synchronization but only if `alwaysNotifyOnRefresh` flag is set in options.
     *    - options: Controls a way of how and when observer is notified.
     */

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void,
                     options: DataProviderObserverOptions)

    /**
     *  Removes an observer from the list of observers.
     *
     *  - parameters:
     *    - observer: An object to remove from the list of observers.
     */

    func removeObserver(_ observer: AnyObject)
}

public extension StreamableProviderProtocol {

    /**
     *  Adds observer to notify when there are changes in local storage.
     *
     *  The closure is also called after each received set
     *  of changes or if `alwaysNotifyOnRefresh` flag set in provided `options`. Failure block
     *  is called in case data provider is failed to add an observer or after each failed synchronization
     *  attempt in case `alwaysNotifyOnRefresh` flag is set. Consider also `options` parameter to
     *  properly setup a way of how and when observer is notified.
     *
     *  - note: This method just calls original `addObserver(_:deliverOn:executing:failing:options)`
     *      with default options.
     *
     *  - parameters:
     *    - observer: An object which is responsible for handling changes. The object is not retained
     *      so it will be automatically removed from observation when deallocated. If the object
     *      is already in the observers list then failure block is called with `observerAlreadyAdded` error.
     *    - queue: Queue to dispatch update and failure blocks in. If `nil` is provided for this parameter
     *      then closures are dispatched in internal queue.
     *    - updateBlock: Closure to call when there are changes in local store.
     *      If there is a need to be notified even if there are no objects recevied after
     *      ```fetch(offset:count:with:)``` call from remote source then consider to set
     *      `alwaysNotifyOnRefresh` in options.
     *    - failureBlock: Closure to call in case data provider failed to add the observer. It is also called
     *      after failed synchronization but only if `alwaysNotifyOnRefresh` flag is set in options.
     *    - options: Controls a way of how and when observer is notified.
     */

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void) {
        addObserver(observer,
                    deliverOn: queue,
                    executing: updateBlock,
                    failing: failureBlock,
                    options: DataProviderObserverOptions())
    }
}

/**
 *  Protocol is designed to provide an inteface of fetching history from the remote stream.
 *
 *  Concrete implementation must be responsible for saving changes directly to repository.
 *  It can be objects received through stream or fetched as part of the history.
 */

public protocol StreamableSourceProtocol {
    associatedtype Model: Identifiable

    /**
     *  Fetches history based on offset and count and saves objects to the repository.
     *
     *  - parameters:
     *    - offset: Offset in the history list.
     *    - count: Number of objects to fetch.
     *    - queue: Dispatch queue to execute completion closure in. By default is ```nil```
     *    meaning that completion closure will be executed in the internal queueu.
     *    - commitNotificationBlock: Optional closure to execute on completion. Swift result
     *    passed as closure parameter contains either number of saved objects or an error
     *    in case of failure.
     */

    func fetchHistory(offset: Int, count: Int, runningIn queue: DispatchQueue?,
                      commitNotificationBlock: ((Result<Int, Error>?) -> Void)?)
}
