import Foundation

public final class CacheObserver<T> {
    public private(set) weak var observer: AnyObject?
    public private(set) var queue: DispatchQueue
    public private(set) var updateBlock: ([DataProviderChange<T>]) -> Void
    public private(set) var failureBlock: (Error) -> Void
    public private(set) var options: DataProviderObserverOptions

    init(observer: AnyObject,
         queue: DispatchQueue,
         updateBlock: @escaping ([DataProviderChange<T>]) -> Void,
         failureBlock: @escaping (Error) -> Void,
         options: DataProviderObserverOptions) {

        self.observer = observer
        self.options = options
        self.queue = queue
        self.updateBlock = updateBlock
        self.failureBlock = failureBlock
    }
}
