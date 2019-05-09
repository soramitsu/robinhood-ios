import Foundation
import CoreData

public final class StreamableProvider<T: Identifiable, U: NSManagedObject> {

    let source: AnyStreamableSource<T>
    let cache: CoreDataCache<T, U>
    let observable: CoreDataContextObservable<T, U>
    let operationQueue: OperationQueue
    let processingQueue: DispatchQueue

    var observers: [CacheObserver<T>] = []

    public init(source: AnyStreamableSource<T>,
                cache: CoreDataCache<T, U>,
                observable: CoreDataContextObservable<T, U>,
                operationQueue: OperationQueue? = nil,
                serialQueue: DispatchQueue? = nil) {
        self.source = source
        self.cache = cache
        self.observable = observable

        if let currentExecutionQueue = operationQueue {
            self.operationQueue = currentExecutionQueue
        } else {
            self.operationQueue = OperationQueue()
        }

        if let currentCacheQueue = serialQueue {
            self.processingQueue = currentCacheQueue
        } else {
            self.processingQueue = DispatchQueue(
                label: "co.jp.streamableprovider.cachequeue.\(UUID().uuidString)",
                qos: .utility)
        }
    }

    private func startObservingSource() {
        observable.addCacheObserver(self, deliverOn: processingQueue) { [weak self] (changes) in
            self?.observers.forEach { $0.updateBlock(changes) }
        }
    }

    private func stopObservingSource() {
        observable.removeCacheObserver(self)
    }
}

extension StreamableProvider: StreamableProviderProtocol {
    public typealias Model = T

    public func fetch(offset: Int, count: Int,
                      with completionBlock: @escaping (OperationResult<[Model]>?) -> Void) -> BaseOperation<[Model]> {
        let operation = cache.fetch(offset: offset, count: count, reversed: false)

        operation.completionBlock = { [weak self] in
            if
                let result = operation.result,
                case .success(let models) = result, models.count < count {
                self?.source.fetchHistory(offset: offset + models.count,
                                          count: count - models.count,
                                          runningIn: nil,
                                          commitNotificationBlock: nil)
            }

            completionBlock(operation.result)
        }

        operationQueue.addOperation(operation)

        return operation
    }

    public func addObserver(_ observer: AnyObject,
                     deliverOn queue: DispatchQueue,
                     executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                     failing failureBlock: @escaping (Error) -> Void) {
        processingQueue.async {
            let shouldObserveSource = self.observers.isEmpty

            self.observers = self.observers.filter { $0.observer != nil }

            if !self.observers.contains(where: { $0.observer === observer }) {
                let observerWrapper = CacheObserver(observer: observer,
                                                    queue: queue,
                                                    updateBlock: updateBlock,
                                                    failureBlock: failureBlock,
                                                    options: DataProviderObserverOptions(alwaysNotifyOnRefresh: false))
                self.observers.append(observerWrapper)

                if shouldObserveSource {
                    self.startObservingSource()
                }
            }
        }
    }

    public func removeObserver(_ observer: AnyObject) {
        processingQueue.async {
            let wasObservingSource = self.observers.count > 0
            self.observers = self.observers.filter { $0.observer != nil && $0.observer !== observer }

            if wasObservingSource, self.observers.isEmpty {
                self.stopObservingSource()
            }
        }
    }
}
