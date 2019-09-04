/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol DataProviderRepositoryProtocol {
    associatedtype Model: Identifiable

    var domain: String { get }

    func fetchOperation(by modelId: String) -> BaseOperation<Model?>

    func fetchAllOperation() -> BaseOperation<[Model]>

    func fetch(offset: Int, count: Int, reversed: Bool) -> BaseOperation<[Model]>

    func saveOperation(_ updateModelsBlock: @escaping () throws -> [Model],
                       _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Bool>

    func deleteAllOperation() -> BaseOperation<Bool>
}

public protocol DataProviderRepositoryObservable {
    associatedtype Model

    func start(completionBlock: @escaping (Error?) -> Void)
    func stop(completionBlock: @escaping (Error?) -> Void)

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void)

    func removeObserver(_ observer: AnyObject)
}
