import Foundation

public final class AnyDataProviderSource<T: Identifiable>: DataProviderSourceProtocol {
    public typealias Model = T

    public private(set) var base: Any

    private let _fetchById: (String) -> BaseOperation<Model?>
    private let _fetchByPage: (UInt) -> BaseOperation<[Model]>

    init<U: DataProviderSourceProtocol>(_ source: U) where U.Model == Model {
        self.base = source
        _fetchById = source.fetchOperation
        _fetchByPage = source.fetchOperation
    }

    public init(base: Any,
                fetchByPage: @escaping (UInt) -> BaseOperation<[Model]>,
                fetchById: @escaping (String) -> BaseOperation<Model?>) {
        self.base = base
        _fetchByPage = fetchByPage
        _fetchById = fetchById
    }

    public func fetchOperation(by modelId: String) -> BaseOperation<T?> {
        return _fetchById(modelId)
    }

    public func fetchOperation(page index: UInt) -> BaseOperation<[T]> {
        return _fetchByPage(index)
    }
}
