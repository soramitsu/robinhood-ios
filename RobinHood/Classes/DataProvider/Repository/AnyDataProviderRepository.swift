/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public final class AnyDataProviderRepository<T: Identifiable>: DataProviderRepositoryProtocol {
    public typealias Model = T

    public private(set) var base: Any

    public let domain: String

    private let _fetchByModelId: (String) -> BaseOperation<Model?>
    private let _fetchAll: () -> BaseOperation<[Model]>
    private let _fetchByOffsetCount: (Int, Int, Bool) -> BaseOperation<[Model]>
    private let _save: (@escaping () throws -> [Model], @escaping () throws -> [String]) -> BaseOperation<Void>
    private let _deleteAll: () -> BaseOperation<Void>

    public init<U: DataProviderRepositoryProtocol>(_ repository: U) where U.Model == Model {
        base = repository
        domain = repository.domain
        _fetchByModelId = repository.fetchOperation
        _fetchAll = repository.fetchAllOperation
        _fetchByOffsetCount = repository.fetchOperation
        _save = repository.saveOperation
        _deleteAll = repository.deleteAllOperation
    }

    public func fetchOperation(by modelId: String) -> BaseOperation<T?> {
        return _fetchByModelId(modelId)
    }

    public func fetchOperation(by offset: Int, count: Int, reversed: Bool) -> BaseOperation<[T]> {
        return _fetchByOffsetCount(offset, count, reversed)
    }

    public func fetchAllOperation() -> BaseOperation<[T]> {
        return _fetchAll()
    }

    public func saveOperation(_ updateModelsBlock: @escaping () throws -> [T],
                              _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Void> {
        return _save(updateModelsBlock, deleteIdsBlock)
    }

    public func deleteAllOperation() -> BaseOperation<Void> {
        return _deleteAll()
    }
}
