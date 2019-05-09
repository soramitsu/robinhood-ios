import Foundation

public protocol StreamableProviderProtocol {
    associatedtype Model: Identifiable

    func fetch(offset: Int, count: Int,
               with completionBlock: @escaping (OperationResult<[Model]>?) -> Void) -> BaseOperation<[Model]>

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void)

    func removeObserver(_ observer: AnyObject)
}

public protocol StreamableSourceProtocol {
    associatedtype Model: Identifiable

    func fetchHistory(offset: Int, count: Int, runningIn queue: DispatchQueue?,
                      commitNotificationBlock: ((OperationResult<Int>?) -> Void)?)
}

public protocol StreamableSourceObservable {
    associatedtype Model

    func addCacheObserver(_ observer: AnyObject,
                          deliverOn queue: DispatchQueue,
                          executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void)

    func removeCacheObserver(_ observer: AnyObject)
}
