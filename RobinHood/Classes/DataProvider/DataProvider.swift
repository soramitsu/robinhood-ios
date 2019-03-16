import Foundation
import CoreData

public enum DataProviderError: Error {
    case unexpectedSourceResult
    case unexpectedCacheResult
    case dependencyCancelled
}

public final class DataProvider<T: Identifiable & Equatable, U: NSManagedObject> {
    public typealias Model = T

    public private(set) var cache: CoreDataCache<T, U>
    public private(set) var source: AnyDataProviderSource<T>
    public private(set) var updateTrigger: DataProviderTriggerProtocol
    public private(set) var executionQueue: OperationQueue
    public private(set) var cacheQueue: DispatchQueue

    private var cacheObservers: [CacheObserver<T>] = []

    private var lastSyncOperation: Operation?
    private var cacheUpdateOperation: Operation?

    init(source: AnyDataProviderSource<T>,
         cache: CoreDataCache<T, U>,
         updateTrigger: DataProviderTriggerProtocol = DataProviderEventTrigger.onAll,
         executionQueue: OperationQueue? = nil,
         serialCacheQueue: DispatchQueue? = nil) {
        self.source = source
        self.cache = cache

        if let currentExecutionQueue = executionQueue {
            self.executionQueue = currentExecutionQueue
        } else {
            self.executionQueue = OperationQueue()
        }

        if let currentCacheQueue = serialCacheQueue {
            self.cacheQueue = currentCacheQueue
        } else {
            self.cacheQueue = DispatchQueue(
                label: "co.jp.dataprovider.cachequeue.\(UUID().uuidString)",
                qos: .utility)
        }

        self.updateTrigger = updateTrigger
        self.updateTrigger.delegate = self
        self.updateTrigger.receive(event: .initialization)
    }

    // MARK: Cache

    private func dispatchUpdateCache() {
        cacheQueue.async {
            self.updateCache()
        }
    }

    private func updateCache() {
        if let currentUpdateCacheOperation = cacheUpdateOperation, !currentUpdateCacheOperation.isFinished {
            return
        }

        let sourceOperation = source.fetchOperation(page: 0)

        let cacheOperation = cache.fetchAllOperation()

        let differenceOperation = createDifferenceOperation(dependingOn: sourceOperation,
                                                            cacheOperation: cacheOperation)

        let saveOperation = createSaveCacheOperation(dependingOn: differenceOperation)

        saveOperation.completionBlock = {
            guard let saveResult = saveOperation.result else {
                return
            }

            if case .error(let error) = saveResult {
                self.cacheQueue.async {
                    self.notifyObservers(with: error)
                }

                return
            }

            guard let changesResult = differenceOperation.result,
                case .success(let updates) = changesResult else {
                    return
            }

            self.cacheQueue.async {
                self.notifyObservers(with: updates)
            }
        }

        cacheUpdateOperation = saveOperation

        if let syncOperation = lastSyncOperation, !syncOperation.isFinished {
            sourceOperation.addDependency(syncOperation)
            cacheOperation.addDependency(syncOperation)
        }

        lastSyncOperation = saveOperation

        let operations = [sourceOperation, cacheOperation, differenceOperation, saveOperation]

        executionQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func createDifferenceOperation(dependingOn sourceOperation: BaseOperation<[T]>,
                                           cacheOperation: BaseOperation<[T]>)
        -> BaseOperation<[DataProviderChange<T>]> {

            let operation = ClosureOperation<[DataProviderChange<T>]> {
                guard let sourceResult = sourceOperation.result else {
                    throw DataProviderError.unexpectedSourceResult
                }

                if case .error(let error) = sourceResult {
                    throw error
                }

                guard let cacheResult = cacheOperation.result else {
                    throw DataProviderError.unexpectedSourceResult
                }

                if case .error(let error) = cacheResult {
                    throw error
                }

                if case .success(let sourceModels) = sourceResult,
                    case .success(let cacheModels) = cacheResult {

                    return try self.findChanges(sourceResult: sourceModels,
                                                cacheResult: cacheModels)
                } else {
                    throw DataProviderError.unexpectedSourceResult
                }
            }

            operation.addDependency(sourceOperation)
            operation.addDependency(cacheOperation)

            return operation
    }

    private func createSaveCacheOperation(dependingOn differenceOperation: BaseOperation<[DataProviderChange<T>]>)
        -> BaseOperation<Bool> {

            let updatedItemsBlock = { () throws -> [T] in
                guard let result = differenceOperation.result else {
                    throw DataProviderError.dependencyCancelled
                }

                switch result {
                case .success(let updates):
                    return updates.compactMap { (update) in
                        return update.item
                    }
                case .error(let error):
                    throw error
                }
            }

            let deletedItemsBlock = { () throws -> [String] in
                guard let result = differenceOperation.result else {
                    throw DataProviderError.dependencyCancelled
                }

                switch result {
                case .success(let updates):
                    return updates.compactMap { (item) in
                        if case .delete(let identifier) = item {
                            return identifier
                        } else {
                            return nil
                        }
                    }
                case .error(let error):
                    throw error
                }
            }

            let operation = cache.saveOperation(updatedItemsBlock, deletedItemsBlock)

            operation.addDependency(differenceOperation)

            return operation
    }

    private func notifyObservers(with updates: [DataProviderChange<T>]) {
        cacheObservers.forEach { (cacheObserver) in
            if cacheObserver.observer != nil,
                (updates.count > 0 || cacheObserver.options.alwaysNotifyOnRefresh) {
                    cacheObserver.queue.async {
                        cacheObserver.updateBlock(updates)
                    }
            }
        }
    }

    private func notifyObservers(with error: Error) {
        cacheObservers.forEach { (cacheObserver) in
            if cacheObserver.observer != nil, cacheObserver.options.alwaysNotifyOnRefresh {
                cacheObserver.queue.async {
                    cacheObserver.failureBlock(error)
                }
            }
        }
    }

    private func findChanges(sourceResult: [T], cacheResult: [T]) throws -> [DataProviderChange<T>] {
        var sourceKeyValue = sourceResult.reduce(into: [String: T]()) { (result, item) in
            result[item.identifier] = item
        }

        var cacheKeyValue = cacheResult.reduce(into: [String: T]()) { (result, item) in
            result[item.identifier] = item
        }

        var updates: [DataProviderChange<T>] = []

        for sourceModel in sourceResult {
            if let cacheModel = cacheKeyValue[sourceModel.identifier] {
                if sourceModel != cacheModel {
                    updates.append(DataProviderChange.update(newItem: sourceModel))
                }

            } else {
                updates.append(DataProviderChange.insert(newItem: sourceModel))
            }
        }

        for cacheModel in cacheResult where sourceKeyValue[cacheModel.identifier] == nil {
            updates.append(DataProviderChange.delete(deletedIdentifier: cacheModel.identifier))
        }

        return updates
    }
}

extension DataProvider: DataProviderProtocol {
    public func fetch(by modelId: String, completionBlock: ((OperationResult<T?>?) -> Void)?) -> BaseOperation<T?> {
        let cacheOperation = cache.fetchOperation(by: modelId)
        let sourceOperation = source.fetchOperation(by: modelId)

        sourceOperation.configurationBlock = {
            if sourceOperation.isCancelled {
                return
            }

            guard let cacheResult = cacheOperation.result else {
                sourceOperation.cancel()
                return
            }

            switch cacheResult {
            case .success(let optionalModel):
                if let model = optionalModel {
                    sourceOperation.result = .success(model)
                }
            case .error(let error):
                sourceOperation.result = .error(error)
            }
        }

        sourceOperation.addDependency(cacheOperation)

        sourceOperation.completionBlock = {
            completionBlock?(sourceOperation.result)
        }

        executionQueue.addOperations([cacheOperation, sourceOperation], waitUntilFinished: false)

        updateTrigger.receive(event: .fetchById(modelId))

        return sourceOperation
    }

    public func fetch(page index: UInt,
                      completionBlock: ((OperationResult<[Model]>?) -> Void)?)
        -> BaseOperation<[Model]> {

        if index > 0 {
            let sourceOperation = source.fetchOperation(page: index)

            sourceOperation.completionBlock = {
                completionBlock?(sourceOperation.result)
            }

            executionQueue.addOperation(sourceOperation)

            updateTrigger.receive(event: .fetchPage(index))

            return sourceOperation
        }

        let cacheOperation = cache.fetchAllOperation()

        let sourceOperation = source.fetchOperation(page: 0)
        sourceOperation.configurationBlock = {
            if sourceOperation.isCancelled {
                return
            }

            guard let result = cacheOperation.result else {
                sourceOperation.cancel()
                return
            }

            switch result {
            case .success(let models):
                if models.count > 0 {
                    sourceOperation.result = .success(models)
                }
            case .error(let error):
                sourceOperation.result = .error(error)
            }
        }

        sourceOperation.addDependency(cacheOperation)

        sourceOperation.completionBlock = {
            completionBlock?(sourceOperation.result)
        }

        executionQueue.addOperations([cacheOperation, sourceOperation], waitUntilFinished: false)

        updateTrigger.receive(event: .fetchPage(index))

        return sourceOperation
    }

    public func addCacheObserver(_ observer: AnyObject,
                                 deliverOn queue: DispatchQueue,
                                 executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                                 failing failureBlock: @escaping (Error) -> Void,
                                 options: DataProviderObserverOptions) {
        cacheQueue.async {
            self.cacheObservers = self.cacheObservers.filter { $0.observer != nil }

            let cacheOperation = self.cache.fetchAllOperation()

            cacheOperation.completionBlock = {
                guard let result = cacheOperation.result else {
                    queue.async {
                        failureBlock(DataProviderError.dependencyCancelled)
                    }
                    return
                }

                switch result {
                case .success(let items):
                    self.cacheQueue.async {
                        let cacheObserver = CacheObserver(observer: observer,
                                                          queue: queue,
                                                          updateBlock: updateBlock,
                                                          failureBlock: failureBlock,
                                                          options: options)
                        self.cacheObservers.append(cacheObserver)

                        self.updateTrigger.receive(event: .addObserver(observer))

                        let updates = items.map { DataProviderChange<T>.insert(newItem: $0) }

                        queue.async {
                            updateBlock(updates)
                        }
                    }
                case .error(let error):
                    queue.async {
                        failureBlock(error)
                    }
                }
            }

            if let syncOperation = self.lastSyncOperation, !syncOperation.isFinished {
                cacheOperation.addDependency(syncOperation)
            }

            self.lastSyncOperation = cacheOperation

            self.executionQueue.addOperations([cacheOperation], waitUntilFinished: false)
        }
    }

    public func removeCacheObserver(_ observer: AnyObject) {
        cacheQueue.async {
            self.cacheObservers = self.cacheObservers.filter { $0.observer !== observer && $0.observer != nil}

            self.updateTrigger.receive(event: .removeObserver(observer))
        }
    }

    public func refreshCache() {
        dispatchUpdateCache()
    }
}

extension DataProvider: DataProviderTriggerDelegate {
    public func didTrigger() {
        dispatchUpdateCache()
    }
}
