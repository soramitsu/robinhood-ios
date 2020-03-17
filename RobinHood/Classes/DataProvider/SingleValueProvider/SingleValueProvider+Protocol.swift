/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

extension SingleValueProvider {
    func isAlreadyAdded(observer: AnyObject) -> Bool {
        pendingObservers.contains(where: { $0.observer === observer}) ||
        observers.contains(where: { $0.observer === observer })
    }

    private func completeAdd(observer: AnyObject,
                             deliverOn queue: DispatchQueue?,
                             executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                             failing failureBlock: @escaping (Error) -> Void,
                             options: DataProviderObserverOptions) {
        guard
            let pending = pendingObservers.first(where: { $0.observer === observer }),
            let result = pending.operation?.result else {
            dispatchInQueueWhenPossible(queue) {
                failureBlock(DataProviderError.dependencyCancelled)
            }

            return
        }

        pendingObservers = pendingObservers.filter { $0.observer != nil && $0.observer !== observer }

        switch result {
        case .success(let optionalEntity):
            let repositoryObserver = DataProviderObserver(observer: observer,
                                                          queue: queue,
                                                          updateBlock: updateBlock,
                                                          failureBlock: failureBlock,
                                                          options: options)
            self.observers.append(repositoryObserver)

            self.updateTrigger.receive(event: .addObserver(observer))

            var updates: [DataProviderChange<T>] = []

            if let entity = optionalEntity,
                let model = try? self.decoder.decode(T.self, from: entity.payload) {
                updates.append(DataProviderChange.insert(newItem: model))
            }

            dispatchInQueueWhenPossible(queue) {
                updateBlock(updates)
            }
        case .failure(let error):
            dispatchInQueueWhenPossible(queue) {
                failureBlock(error)
            }
        }
    }
}

extension SingleValueProvider: SingleValueProviderProtocol {
    public func fetch(with completionBlock: ((Result<T?, Error>?) -> Void)?) -> BaseOperation<T?> {
        let repositoryOperation = repository.fetchOperation(by: targetIdentifier)

        let sourceOperation = source.fetchOperation()
        sourceOperation.configurationBlock = {
            if sourceOperation.isCancelled {
                return
            }

            guard let result = repositoryOperation.result else {
                sourceOperation.cancel()
                return
            }

            switch result {
            case .success(let optionalEntity):
                if let entity = optionalEntity,
                    let model = try? self.decoder.decode(T.self, from: entity.payload) {
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

        updateTrigger.receive(event: .fetchById(targetIdentifier))

        return sourceOperation
    }

    public func addObserver(_ observer: AnyObject,
                            deliverOn queue: DispatchQueue?,
                            executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                            failing failureBlock: @escaping (Error) -> Void,
                            options: DataProviderObserverOptions) {
        syncQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            if self.isAlreadyAdded(observer: observer) {
                dispatchInQueueWhenPossible(queue) {
                    failureBlock(DataProviderError.observerAlreadyAdded)
                }
                return
            }

            let repositoryOperation = self.repository.fetchOperation(by: self.targetIdentifier)

            let pending = DataProviderPendingObserver(observer: observer,
                                                      operation: repositoryOperation)
            self.pendingObservers.append(pending)

            repositoryOperation.completionBlock = {
                self.syncQueue.async {
                    self.completeAdd(observer: observer,
                                     deliverOn: queue,
                                     executing: updateBlock,
                                     failing: failureBlock,
                                     options: options)
                }
            }

            if options.waitsInProgressSyncOnAdd {
                if let syncOperation = self.lastSyncOperation, !syncOperation.isFinished {
                    repositoryOperation.addDependency(syncOperation)
                }

                self.lastSyncOperation = repositoryOperation
            }

            self.executionQueue.addOperations([repositoryOperation], waitUntilFinished: false)
        }
    }

    public func removeObserver(_ observer: AnyObject) {
        syncQueue.async {
            if let pending = self.pendingObservers.first(where: { $0.observer === observer }) {
                pending.operation?.cancel()
            }

            self.pendingObservers = self.pendingObservers
                .filter { $0.observer != nil && $0.observer !== observer }

            self.observers = self.observers.filter { $0.observer !== observer && $0.observer != nil}

            self.updateTrigger.receive(event: .removeObserver(observer))
        }
    }

    public func refresh() {
        dispatchUpdateRepository()
    }
}
