/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

extension DataProvider: DataProviderProtocol {
    public func fetch(by modelId: String, completionBlock: ((Result<T?, Error>?) -> Void)?) -> BaseOperation<T?> {
        let repositoryOperation = repository.fetchOperation(by: modelId)
        let sourceOperation = source.fetchOperation(by: modelId)

        sourceOperation.configurationBlock = {
            if sourceOperation.isCancelled {
                return
            }

            guard let repositoryResult = repositoryOperation.result else {
                sourceOperation.cancel()
                return
            }

            switch repositoryResult {
            case .success(let optionalModel):
                if let model = optionalModel {
                    sourceOperation.result = .success(model)
                }
            case .failure(let error):
                sourceOperation.result = .failure(error)
            }
        }

        sourceOperation.addDependency(repositoryOperation)

        sourceOperation.completionBlock = {
            completionBlock?(sourceOperation.result)
        }

        executionQueue.addOperations([repositoryOperation, sourceOperation], waitUntilFinished: false)

        updateTrigger.receive(event: .fetchById(modelId))

        return sourceOperation
    }

    public func fetch(page index: UInt,
                      completionBlock: ((Result<[Model], Error>?) -> Void)?)
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

            let repositoryOperation = repository.fetchAllOperation()

            let sourceOperation = source.fetchOperation(page: 0)
            sourceOperation.configurationBlock = {
                if sourceOperation.isCancelled {
                    return
                }

                guard let result = repositoryOperation.result else {
                    sourceOperation.cancel()
                    return
                }

                switch result {
                case .success(let models):
                    if models.count > 0 {
                        sourceOperation.result = .success(models)
                    }
                case .failure(let error):
                    sourceOperation.result = .failure(error)
                }
            }

            sourceOperation.addDependency(repositoryOperation)

            sourceOperation.completionBlock = {
                completionBlock?(sourceOperation.result)
            }

            executionQueue.addOperations([repositoryOperation, sourceOperation], waitUntilFinished: false)

            updateTrigger.receive(event: .fetchPage(index))

            return sourceOperation
    }

    public func addObserver(_ observer: AnyObject,
                            deliverOn queue: DispatchQueue?,
                            executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                            failing failureBlock: @escaping (Error) -> Void,
                            options: DataProviderObserverOptions) {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            let repositoryOperation = self.repository.fetchAllOperation()

            repositoryOperation.completionBlock = {
                guard let result = repositoryOperation.result else {
                    dispatchInQueueWhenPossible(queue) {
                        failureBlock(DataProviderError.dependencyCancelled)
                    }

                    return
                }

                switch result {
                case .success(let items):
                    self.syncQueue.async {
                        let repositoryObserver = RepositoryObserver(observer: observer,
                                                                    queue: queue,
                                                                    updateBlock: updateBlock,
                                                                    failureBlock: failureBlock,
                                                                    options: options)
                        self.observers.append(repositoryObserver)

                        self.updateTrigger.receive(event: .addObserver(observer))

                        let updates = items.map { DataProviderChange<T>.insert(newItem: $0) }

                        dispatchInQueueWhenPossible(queue) {
                            updateBlock(updates)
                        }
                    }
                case .failure(let error):
                    dispatchInQueueWhenPossible(queue) {
                        failureBlock(error)
                    }
                }
            }

            if let syncOperation = self.lastSyncOperation, !syncOperation.isFinished {
                repositoryOperation.addDependency(syncOperation)
            }

            self.lastSyncOperation = repositoryOperation

            self.executionQueue.addOperations([repositoryOperation], waitUntilFinished: false)
        }
    }

    public func removeObserver(_ observer: AnyObject) {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer !== observer && $0.observer != nil}

            self.updateTrigger.receive(event: .removeObserver(observer))
        }
    }

    public func refresh() {
        dispatchUpdateRepository()
    }
}
