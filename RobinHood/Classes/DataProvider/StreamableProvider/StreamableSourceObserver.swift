import Foundation

public final class StreamableSourceObserver<T> {
    public private(set) weak var observer: AnyObject?
    public private(set) var queue: DispatchQueue
    public private(set) var updateBlock: ([DataProviderChange<T>]) -> Void

    public init(observer: AnyObject,
                queue: DispatchQueue,
                updateBlock: @escaping ([DataProviderChange<T>]) -> Void) {
        self.observer = observer
        self.queue = queue
        self.updateBlock = updateBlock
    }
}
