/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public enum DataProviderError: Error {
    case unexpectedSourceResult
    case unexpectedRepositoryResult
    case dependencyCancelled
}

public final class DataProvider<T: Identifiable & Equatable> {
    public typealias Model = T

    public private(set) var repository: AnyDataProviderRepository<T>
    public private(set) var source: AnyDataProviderSource<T>
    public private(set) var updateTrigger: DataProviderTriggerProtocol
    public private(set) var executionQueue: OperationQueue
    public private(set) var syncQueue: DispatchQueue

    var observers: [RepositoryObserver<T>] = []
    var lastSyncOperation: Operation?
    var repositoryUpdateOperation: Operation?

    public init(source: AnyDataProviderSource<T>,
                repository: AnyDataProviderRepository<T>,
                updateTrigger: DataProviderTriggerProtocol = DataProviderEventTrigger.onAll,
                executionQueue: OperationQueue? = nil,
                serialSyncQueue: DispatchQueue? = nil) {
        self.source = source
        self.repository = repository

        if let currentExecutionQueue = executionQueue {
            self.executionQueue = currentExecutionQueue
        } else {
            self.executionQueue = OperationQueue()
        }

        if let currentSyncQueue = serialSyncQueue {
            self.syncQueue = currentSyncQueue
        } else {
            self.syncQueue = DispatchQueue(
                label: "co.jp.dataprovider.repository.queue.\(UUID().uuidString)",
                qos: .utility)
        }

        self.updateTrigger = updateTrigger
        self.updateTrigger.delegate = self
        self.updateTrigger.receive(event: .initialization)
    }
}

// MARK: Internal Repository update logic
extension DataProvider {
    func dispatchUpdateRepository() {
        syncQueue.async {
            self.updateRepository()
        }
    }

    private func updateRepository() {
        if let currentUpdateRepositoryOperation = repositoryUpdateOperation,
            !currentUpdateRepositoryOperation.isFinished {
            return
        }

        let sourceOperation = source.fetchOperation(page: 0)

        let repositoryOperation = repository.fetchAllOperation()

        let differenceOperation = createDifferenceOperation(dependingOn: sourceOperation,
                                                            repositoryOperation: repositoryOperation)

        let saveOperation = createSaveRepositoryOperation(dependingOn: differenceOperation)

        saveOperation.completionBlock = {
            guard let saveResult = saveOperation.result else {
                return
            }

            if case .error(let error) = saveResult {
                self.syncQueue.async {
                    self.notifyObservers(with: error)
                }

                return
            }

            guard let changesResult = differenceOperation.result,
                case .success(let updates) = changesResult else {
                    return
            }

            self.syncQueue.async {
                self.notifyObservers(with: updates)
            }
        }

        repositoryUpdateOperation = saveOperation

        if let syncOperation = lastSyncOperation, !syncOperation.isFinished {
            sourceOperation.addDependency(syncOperation)
            repositoryOperation.addDependency(syncOperation)
        }

        lastSyncOperation = saveOperation

        let operations = [sourceOperation, repositoryOperation, differenceOperation, saveOperation]

        executionQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func createDifferenceOperation(dependingOn sourceOperation: BaseOperation<[T]>,
                                           repositoryOperation: BaseOperation<[T]>)
        -> BaseOperation<[DataProviderChange<T>]> {

            let operation = ClosureOperation<[DataProviderChange<T>]> {
                guard let sourceResult = sourceOperation.result else {
                    throw DataProviderError.unexpectedSourceResult
                }

                if case .error(let error) = sourceResult {
                    throw error
                }

                guard let repositoryResult = repositoryOperation.result else {
                    throw DataProviderError.unexpectedRepositoryResult
                }

                if case .error(let error) = repositoryResult {
                    throw error
                }

                if case .success(let sourceModels) = sourceResult,
                    case .success(let repositoryModels) = repositoryResult {

                    return try self.findChanges(sourceResult: sourceModels,
                                                repositoryResult: repositoryModels)
                } else {
                    throw DataProviderError.unexpectedSourceResult
                }
            }

            operation.addDependency(sourceOperation)
            operation.addDependency(repositoryOperation)

            return operation
    }

    private func createSaveRepositoryOperation(dependingOn differenceOperation: BaseOperation<[DataProviderChange<T>]>)
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

            let operation = repository.saveOperation(updatedItemsBlock, deletedItemsBlock)

            operation.addDependency(differenceOperation)

            return operation
    }

    private func notifyObservers(with updates: [DataProviderChange<T>]) {
        observers.forEach { (repositoryObserver) in
            if repositoryObserver.observer != nil,
                (updates.count > 0 || repositoryObserver.options.alwaysNotifyOnRefresh) {
                dispatchInQueueWhenPossible(repositoryObserver.queue) {
                    repositoryObserver.updateBlock(updates)
                }
            }
        }
    }

    private func notifyObservers(with error: Error) {
        observers.forEach { (repositoryObserver) in
            if repositoryObserver.observer != nil, repositoryObserver.options.alwaysNotifyOnRefresh {
                dispatchInQueueWhenPossible(repositoryObserver.queue) {
                    repositoryObserver.failureBlock(error)
                }
            }
        }
    }

    private func findChanges(sourceResult: [T], repositoryResult: [T]) throws -> [DataProviderChange<T>] {
        var sourceKeyValue = sourceResult.reduce(into: [String: T]()) { (result, item) in
            result[item.identifier] = item
        }

        var repositoryKeyValue = repositoryResult.reduce(into: [String: T]()) { (result, item) in
            result[item.identifier] = item
        }

        var updates: [DataProviderChange<T>] = []

        for sourceModel in sourceResult {
            if let repositoryModel = repositoryKeyValue[sourceModel.identifier] {
                if sourceModel != repositoryModel {
                    updates.append(DataProviderChange.update(newItem: sourceModel))
                }

            } else {
                updates.append(DataProviderChange.insert(newItem: sourceModel))
            }
        }

        for repositoryModel in repositoryResult where sourceKeyValue[repositoryModel.identifier] == nil {
            updates.append(DataProviderChange.delete(deletedIdentifier: repositoryModel.identifier))
        }

        return updates
    }
}
