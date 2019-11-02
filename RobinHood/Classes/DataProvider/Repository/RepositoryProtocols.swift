/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

/**
 *  Protocol is designed to interface access to local persistent storage and provides
 *  necessary CRUD operations to manage single entity type (```Model```).
 *  All methods of the implementation must return an operation and a client is responsible
 *  for its execution to receive result.
 */

public protocol DataProviderRepositoryProtocol {
    associatedtype Model: Identifiable

    /**
     *  Creates operation which fetches object by identifier in current domain.
     *
     *  - parameters:
     *    - modelId: Identifier of the object to fetch.
     *  - returns: Operation that results in an object or nil if there is
     *  no object with specified identifier.
     */

    func fetchOperation(by modelId: String) -> BaseOperation<Model?>

    /**
     *  Creates operation which fetches all objects in current domain.
     *
     *  - returns: Operation that results in a list of objects.
     */

    func fetchAllOperation() -> BaseOperation<[Model]>

    /**
     *  Creates operation which fetches subset of objects in current domain.
     *
     *  - parameters:
     *      - offset: An offset to fetch objects from.
     *      - count: Maximum amount of objects to fetch.
     *      - reversed: Pass true if offset and count should be applied to the reversed list
     *      of objects.
     *  - returns: Operation that results in a list of objects.
     */

    func fetchOperation(by offset: Int, count: Int, reversed: Bool) -> BaseOperation<[Model]>

    /**
     *  Creates operation which persists changes to the list of objects in current domain.
     *
     *  - parameters:
     *    - updateModelsBlocks: Closure which returns list of objects to create or update.
     *    - deleteIdsBlock: Closure which returns identifiers of objects to delete.
     *  - returns: Operation that returns nothing.
     */

    func saveOperation(_ updateModelsBlock: @escaping () throws -> [Model],
                       _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Void>

    /**
     *  Creates operation which removes all objects in current domain.s
     *
     *  - returns: Operation which returns nothing.
     */

    func deleteAllOperation() -> BaseOperation<Void>
}

/**
 *  Protocol is designed to provide an interface to observe changes in repository.
 */

public protocol DataProviderRepositoryObservable {
    associatedtype Model

    /**
     *  Asks to start notifying observers if any changes arrive.
     *
     *  - parameters:
     *    - completionBlock: Closure to call when observable sucessfully activated or failed.
     *      In case of failure an error is passed as a parameter.
     */

    func start(completionBlock: @escaping (Error?) -> Void)

    /**
     *  Asks to stop notifying observers.
     *
     *  - parameters:
     *    - completionBlock: Closure to call when observable sucessfully deactivated or failed.
     *      In case of failure an error is passed as a parameter.
     */

    func stop(completionBlock: @escaping (Error?) -> Void)

    /**
     *  Adds an observer to receive repository changes.
     *
     *  - parameters:
     *    - observer: An observer which is responsible for handling changes. It is expected
     *      that implementation does nothing if the observer already exists.
     *    - queue: Dispatch queue to execute closure containing changes in.
     *    - updateBlock: Closure to deliver changes to observer.
     */

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void)

    /**
     *  Removes an observer from repository's observers list.
     *
     *  - parameters:
     *    - observer: An observer to remove from the list.
     */

    func removeObserver(_ observer: AnyObject)
}
