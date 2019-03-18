import Foundation

// MARK: SingleValueProviderProtocol implementation
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
