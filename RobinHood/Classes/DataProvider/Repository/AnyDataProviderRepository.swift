import Foundation

public final class AnyDataProviderRepository<T: Identifiable>: DataProviderRepositoryProtocol {
    public typealias Model = T

    public private(set) var base: Any

    public let domain: String

    private let _fetchByModelId: (String) -> BaseOperation<Model?>
    private let _fetchAll: () -> BaseOperation<[Model]>
    private let _fetchByOffsetCount: (Int, Int, Bool) -> BaseOperation<[Model]>
    private let _save: (@escaping () throws -> [Model], @escaping () throws -> [String]) -> BaseOperation<Bool>
    private let _deleteAll: () -> BaseOperation<Bool>

    public init<U: DataProviderRepositoryProtocol>(_ repository: U) where U.Model == Model {
        base = repository
        domain = repository.domain
        _fetchByModelId = repository.fetchOperation
        _fetchAll = repository.fetchAllOperation
        _fetchByOffsetCount = repository.fetch
        _save = repository.saveOperation
        _deleteAll = repository.deleteAllOperation
    }

    public func fetchOperation(by modelId: String) -> BaseOperation<T?> {
        return _fetchByModelId(modelId)
    }

    public func fetch(offset: Int, count: Int, reversed: Bool) -> BaseOperation<[T]> {
        return _fetchByOffsetCount(offset, count, reversed)
    }

    public func fetchAllOperation() -> BaseOperation<[T]> {
        return _fetchAll()
    }

    public func saveOperation(_ updateModelsBlock: @escaping () throws -> [T],
                              _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Bool> {
        return _save(updateModelsBlock, deleteIdsBlock)
    }

    public func deleteAllOperation() -> BaseOperation<Bool> {
        return _deleteAll()
    }
}
