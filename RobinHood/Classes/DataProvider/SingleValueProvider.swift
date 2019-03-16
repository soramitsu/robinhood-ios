import Foundation
import CoreData

public struct SingleValueProviderObject: Identifiable & Codable {
    public var identifier: String
    public var payload: Data
}

public final class SingleValueProvider<T: Codable & Equatable, U: NSManagedObject> {
    public typealias Model = T

    public private(set) var cache: CoreDataCache<SingleValueProviderObject, U>
    public private(set) var source: AnySingleValueProviderSource<T>
    public private(set) var updateTrigger: DataProviderTriggerProtocol
    public private(set) var executionQueue: OperationQueue
    public private(set) var cacheQueue: DispatchQueue
    public private(set) var targetIdentifier: String

    private var cacheObservers: [CacheObserver<T>] = []

    private var lastSyncOperation: Operation?
    private var cacheUpdateOperation: Operation?

    lazy private var encoder = JSONEncoder()
    lazy private var decoder = JSONDecoder()

    public init(targetIdentifier: String,
                source: AnySingleValueProviderSource<T>,
                cache: CoreDataCache<SingleValueProviderObject, U>,
                updateTrigger: DataProviderTriggerProtocol = DataProviderEventTrigger.onAll,
                executionQueue: OperationQueue? = nil,
                serialCacheQueue: DispatchQueue? = nil) {

        self.targetIdentifier = targetIdentifier
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
                label: "co.jp.singlevalueprovider.cachequeue.\(UUID().uuidString)",
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

        let sourceOperation = source.fetchOperation()

        let cacheOperation = cache.fetchOperation(by: targetIdentifier)

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
                case .success(let optionalUpdate) = changesResult else {
                    return
            }

            self.cacheQueue.async {
                self.notifyObservers(with: optionalUpdate)
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

    private func createDifferenceOperation(dependingOn sourceOperation: BaseOperation<T>,
                                           cacheOperation: BaseOperation<SingleValueProviderObject?>)
        -> BaseOperation<DataProviderChange<T>?> {

            let operation = ClosureOperation<DataProviderChange<T>?> {
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

                if case .success(let sourceModel) = sourceResult,
                    case .success(let cacheModel) = cacheResult {

                    return try self.findChanges(sourceResult: sourceModel,
                                                cacheResult: cacheModel)
                } else {
                    throw DataProviderError.unexpectedSourceResult
                }
            }

            operation.addDependency(sourceOperation)
            operation.addDependency(cacheOperation)

            return operation
    }

    private func createSaveCacheOperation(dependingOn differenceOperation: BaseOperation<DataProviderChange<T>?>)
        -> BaseOperation<Bool> {

            let itemIdentifier = targetIdentifier

            let updatedItemsBlock = { () throws -> [SingleValueProviderObject] in
                guard let result = differenceOperation.result else {
                    throw DataProviderError.dependencyCancelled
                }

                switch result {
                case .success(let optionalUpdate):
                    if let update = optionalUpdate, let item = update.item {
                        let payload = try self.encoder.encode(item)
                        let singleValueObject = SingleValueProviderObject(identifier: itemIdentifier,
                                                                          payload: payload)
                        return [singleValueObject]
                    } else {
                        return []
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
                case .success(let optionalUpdate):
                    if let update = optionalUpdate, case .delete = update {
                        return [itemIdentifier]
                    } else {
                        return []
                    }
                case .error(let error):
                    throw error
                }
            }

            let operation = cache.saveOperation(updatedItemsBlock, deletedItemsBlock)

            operation.addDependency(differenceOperation)

            return operation
    }

    private func notifyObservers(with update: DataProviderChange<T>?) {
        cacheObservers.forEach { (cacheObserver) in
            if cacheObserver.observer != nil,
                (update != nil || cacheObserver.options.alwaysNotifyOnRefresh) {
                cacheObserver.queue.async {
                    if let update = update {
                        cacheObserver.updateBlock([update])
                    } else {
                        cacheObserver.updateBlock([])
                    }
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

    private func findChanges(sourceResult: T, cacheResult: SingleValueProviderObject?) throws
        -> DataProviderChange<T>? {

        let sourceData = try? encoder.encode(sourceResult)

        guard let existingCacheResult = cacheResult else {
            if sourceData != nil {
                return DataProviderChange.insert(newItem: sourceResult)
            } else {
                return nil
            }
        }

        guard let existingSourceData = sourceData else {
            return DataProviderChange.delete(deletedIdentifier: targetIdentifier)
        }

        if existingSourceData != existingCacheResult.payload {
            return DataProviderChange.update(newItem: sourceResult)
        } else {
            return nil
        }
    }
}

extension SingleValueProvider: SingleValueProviderProtocol {
    public func fetch(with completionBlock: ((OperationResult<T>?) -> Void)?) -> BaseOperation<T> {
        let cacheOperation = cache.fetchOperation(by: targetIdentifier)

        let sourceOperation = source.fetchOperation()
        sourceOperation.configurationBlock = {
            if sourceOperation.isCancelled {
                return
            }

            guard let result = cacheOperation.result else {
                sourceOperation.cancel()
                return
            }

            switch result {
            case .success(let optionalEntity):
                if let entity = optionalEntity,
                    let model = try? self.decoder.decode(T.self, from: entity.payload) {
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

        updateTrigger.receive(event: .fetchById(targetIdentifier))

        return sourceOperation
    }

    public func addCacheObserver(_ observer: AnyObject,
                                 deliverOn queue: DispatchQueue,
                                 executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                                 failing failureBlock: @escaping (Error) -> Void,
                                 options: DataProviderObserverOptions) {
        cacheQueue.async {
            self.cacheObservers = self.cacheObservers.filter { $0.observer != nil }

            let cacheOperation = self.cache.fetchOperation(by: self.targetIdentifier)

            cacheOperation.completionBlock = {
                guard let result = cacheOperation.result else {
                    queue.async {
                        failureBlock(DataProviderError.dependencyCancelled)
                    }
                    return
                }

                switch result {
                case .success(let optionalEntity):
                    self.cacheQueue.async {
                        let cacheObserver = CacheObserver(observer: observer,
                                                          queue: queue,
                                                          updateBlock: updateBlock,
                                                          failureBlock: failureBlock,
                                                          options: options)
                        self.cacheObservers.append(cacheObserver)

                        self.updateTrigger.receive(event: .addObserver(observer))

                        var updates: [DataProviderChange<T>] = []

                        if let entity = optionalEntity,
                            let model = try? self.decoder.decode(T.self, from: entity.payload) {
                            updates.append(DataProviderChange.insert(newItem: model))
                        }

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

extension SingleValueProvider: DataProviderTriggerDelegate {
    public func didTrigger() {
        dispatchUpdateCache()
    }
}
