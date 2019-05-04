import Foundation

public protocol StreamableProviderProtocol {
    associatedtype Model: Identifiable

    func upgrade(page index: UInt, for observer: AnyObject)

    func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue,
                     executing updateBlock: @escaping ([ListDifference<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void)

    func removeObserver(_ observer: AnyObject)
}

public protocol StreamableSourceProtocol {
    associatedtype Model: Identifiable

    func connect(with updateBlock: ([DataProviderChange<Model>]) -> Void,
                 queue: DispatchQueue)

    func fetchHistory(preceding model: Model?,
                      count: Int,
                      runningCompletionIn queue: DispatchQueue,
                      with block: ([Model]) -> Void)
}
