/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

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
