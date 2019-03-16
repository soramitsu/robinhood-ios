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
    public var alwaysNotifyOnRefresh: Bool = false
}

public protocol DataProviderProtocol {
    associatedtype Model: Identifiable

    var executionQueue: OperationQueue { get }

    func fetch(by modelId: String, completionBlock: ((OperationResult<Model?>?) -> Void)?) -> BaseOperation<Model?>

    func fetch(page index: UInt, completionBlock: ((OperationResult<[Model]>?) -> Void)?) -> BaseOperation<[Model]>

    func addCacheObserver(_ observer: AnyObject,
                          deliverOn queue: DispatchQueue,
                          executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                          failing failureBlock: @escaping (Error) -> Void,
                          options: DataProviderObserverOptions)

    func removeCacheObserver(_ observer: AnyObject)

    func refreshCache()
}

public extension DataProviderProtocol {
    public func addCacheObserver(_ observer: AnyObject,
                                 deliverOn queue: DispatchQueue,
                                 executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                                 failing failureBlock: @escaping (Error) -> Void) {
        addCacheObserver(observer,
                         deliverOn: queue,
                         executing: updateBlock,
                         failing: failureBlock,
                         options: DataProviderObserverOptions())
    }
}

public protocol SingleValueProviderProtocol {
    associatedtype Model

    var executionQueue: OperationQueue { get }

    func fetch(with completionBlock: ((OperationResult<Model>?) -> Void)?) -> BaseOperation<Model>

    func addCacheObserver(_ observer: AnyObject,
                          deliverOn queue: DispatchQueue,
                          executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                          failing failureBlock: @escaping (Error) -> Void,
                          options: DataProviderObserverOptions)

    func removeCacheObserver(_ observer: AnyObject)

    func refreshCache()
}

public extension SingleValueProviderProtocol {
    public func addCacheObserver(_ observer: AnyObject,
                                 deliverOn queue: DispatchQueue,
                                 executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                                 failing failureBlock: @escaping (Error) -> Void) {
        addCacheObserver(observer,
                         deliverOn: queue,
                         executing: updateBlock,
                         failing: failureBlock,
                         options: DataProviderObserverOptions())
    }
}

public protocol DataProviderCacheProtocol {
    associatedtype Model: Identifiable

    var domain: String { get }

    func fetchOperation(by modelId: String) -> BaseOperation<Model?>

    func fetchAllOperation() -> BaseOperation<[Model]>

    func saveOperation(_ updateModelsBlock: @escaping () throws -> [Model],
                       _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Bool>

    func deleteAllOperation() -> BaseOperation<Bool>
}

public protocol DataProviderSourceProtocol {
    associatedtype Model: Identifiable

    func fetchOperation(by modelId: String) -> BaseOperation<Model?>

    func fetchOperation(page index: UInt) -> BaseOperation<[Model]>
}

public protocol SingleValueProviderSourceProtocol {
    associatedtype Model

    func fetchOperation() -> BaseOperation<Model>
}

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

public final class AnySingleValueProviderSource<T>: SingleValueProviderSourceProtocol {
    public typealias Model = T

    public private(set) var base: Any

    private let _fetch: () -> BaseOperation<Model>

    public init<U: SingleValueProviderSourceProtocol>(_ source: U) where U.Model == Model {
        self.base = source
        _fetch = source.fetchOperation
    }

    public init(base: Any,
                fetch: @escaping () -> BaseOperation<Model>) {
        self.base = base
        _fetch = fetch
    }

    public func fetchOperation() -> BaseOperation<T> {
        return _fetch()
    }
}

public final class AnyDataProvider<T: Identifiable & Equatable>: DataProviderProtocol {
    public typealias Model = T

    private let _fetchById: (String, ((OperationResult<T?>?) -> Void)?) -> BaseOperation<T?>
    private let _fetchPage: (UInt, ((OperationResult<[T]>?) -> Void)?) -> BaseOperation<[T]>

    private let _addCacheObserver: (AnyObject, DispatchQueue,
    @escaping ([DataProviderChange<T>]) -> Void, @escaping (Error) -> Void, DataProviderObserverOptions) -> Void

    private let _removeObserver: (AnyObject) -> Void

    private let _refreshCache: () -> Void

    public private(set) var executionQueue: OperationQueue

    public init<U: DataProviderProtocol>(_ dataProvider: U) where U.Model == Model {
        _fetchById = dataProvider.fetch
        _fetchPage = dataProvider.fetch
        _addCacheObserver = dataProvider.addCacheObserver
        _removeObserver = dataProvider.removeCacheObserver
        _refreshCache = dataProvider.refreshCache
        self.executionQueue = dataProvider.executionQueue
    }

    public func fetch(by modelId: String, completionBlock: ((OperationResult<T?>?) -> Void)?) -> BaseOperation<T?> {
        return _fetchById(modelId, completionBlock)
    }

    public func fetch(page index: UInt, completionBlock: ((OperationResult<[T]>?) -> Void)?) -> BaseOperation<[T]> {
        return _fetchPage(index, completionBlock)
    }

    public func addCacheObserver(_ observer: AnyObject,
                                 deliverOn queue: DispatchQueue,
                                 executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                                 failing failureBlock: @escaping (Error) -> Void,
                                 options: DataProviderObserverOptions) {

        _addCacheObserver(observer, queue, updateBlock, failureBlock, options)
    }

    public func removeCacheObserver(_ observer: AnyObject) {
        _removeObserver(observer)
    }

    public func refreshCache() {
        _refreshCache()
    }
}
