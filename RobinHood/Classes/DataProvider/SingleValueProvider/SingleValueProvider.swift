/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct SingleValueProviderObject: Identifiable & Codable {
    public var identifier: String
    public var payload: Data
}

public final class SingleValueProvider<T: Codable & Equatable> {
    public typealias Model = T

    public private(set) var repository: AnyDataProviderRepository<SingleValueProviderObject>
    public private(set) var source: AnySingleValueProviderSource<T>
    public private(set) var updateTrigger: DataProviderTriggerProtocol
    public private(set) var executionQueue: OperationQueue
    public private(set) var syncQueue: DispatchQueue
    public private(set) var targetIdentifier: String

    var observers: [RepositoryObserver<T>] = []
    var lastSyncOperation: Operation?
    var repositoryUpdateOperation: Operation?

    lazy var encoder = JSONEncoder()
    lazy var decoder = JSONDecoder()

    public init(targetIdentifier: String,
                source: AnySingleValueProviderSource<T>,
                repository: AnyDataProviderRepository<SingleValueProviderObject>,
                updateTrigger: DataProviderTriggerProtocol = DataProviderEventTrigger.onAll,
                executionQueue: OperationQueue? = nil,
                serialSyncQueue: DispatchQueue? = nil) {

        self.targetIdentifier = targetIdentifier
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
                label: "co.jp.singlevalueprovider.repository.queue.\(UUID().uuidString)",
                qos: .utility)
        }

        self.updateTrigger = updateTrigger
        self.updateTrigger.delegate = self
        self.updateTrigger.receive(event: .initialization)
    }
}

// MARK: Internal Repository update logic implementation
extension SingleValueProvider {
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

        let sourceOperation = source.fetchOperation()

        let repositoryOperation = repository.fetchOperation(by: targetIdentifier)

        let differenceOperation = createDifferenceOperation(dependingOn: sourceOperation,
                                                            repositoryOperation: repositoryOperation)

        let saveOperation = createSaveRepositoryOperation(dependingOn: differenceOperation)

        saveOperation.completionBlock = {
            guard let saveResult = saveOperation.result else {
                return
            }

            if case .failure(let error) = saveResult {
                self.syncQueue.async {
                    self.notifyObservers(with: error)
                }

                return
            }

            guard let changesResult = differenceOperation.result,
                case .success(let optionalUpdate) = changesResult else {
                    return
            }

            self.syncQueue.async {
                self.notifyObservers(with: optionalUpdate)
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

    private func createDifferenceOperation(dependingOn sourceOperation: BaseOperation<T>,
                                           repositoryOperation: BaseOperation<SingleValueProviderObject?>)
        -> BaseOperation<DataProviderChange<T>?> {

            let operation = ClosureOperation<DataProviderChange<T>?> {
                guard let sourceResult = sourceOperation.result else {
                    throw DataProviderError.unexpectedSourceResult
                }

                if case .failure(let error) = sourceResult {
                    throw error
                }

                guard let repositoryResult = repositoryOperation.result else {
                    throw DataProviderError.unexpectedSourceResult
                }

                if case .failure(let error) = repositoryResult {
                    throw error
                }

                if case .success(let sourceModel) = sourceResult,
                    case .success(let repositoryModel) = repositoryResult {

                    return try self.findChanges(sourceResult: sourceModel,
                                                repositoryResult: repositoryModel)
                } else {
                    throw DataProviderError.unexpectedSourceResult
                }
            }

            operation.addDependency(sourceOperation)
            operation.addDependency(repositoryOperation)

            return operation
    }

    private func createSaveRepositoryOperation(dependingOn differenceOperation: BaseOperation<DataProviderChange<T>?>)
        -> BaseOperation<Void> {

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
                case .failure(let error):
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
                case .failure(let error):
                    throw error
                }
            }

            let operation = repository.saveOperation(updatedItemsBlock, deletedItemsBlock)

            operation.addDependency(differenceOperation)

            return operation
    }

    private func notifyObservers(with update: DataProviderChange<T>?) {
        observers.forEach { (repositoryObserver) in
            if repositoryObserver.observer != nil,
                (update != nil || repositoryObserver.options.alwaysNotifyOnRefresh) {

                dispatchInQueueWhenPossible(repositoryObserver.queue) {
                    if let update = update {
                        repositoryObserver.updateBlock([update])
                    } else {
                        repositoryObserver.updateBlock([])
                    }
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

    private func findChanges(sourceResult: T, repositoryResult: SingleValueProviderObject?) throws
        -> DataProviderChange<T>? {

            let sourceData = try? encoder.encode(sourceResult)

            guard let existingRepositoryResult = repositoryResult else {
                if sourceData != nil {
                    return DataProviderChange.insert(newItem: sourceResult)
                } else {
                    return nil
                }
            }

            guard let existingSourceData = sourceData else {
                return DataProviderChange.delete(deletedIdentifier: targetIdentifier)
            }

            if existingSourceData != existingRepositoryResult.payload {
                return DataProviderChange.update(newItem: sourceResult)
            } else {
                return nil
            }
    }
}
