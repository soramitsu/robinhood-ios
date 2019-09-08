/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import CoreData

public final class StreamableProvider<T: Identifiable> {

    let source: AnyStreamableSource<T>
    let repository: AnyDataProviderRepository<T>
    let observable: AnyDataProviderRepositoryObservable<T>
    let operationQueue: OperationQueue
    let processingQueue: DispatchQueue

    var observers: [DataProviderObserver<T>] = []

    public init(source: AnyStreamableSource<T>,
                repository: AnyDataProviderRepository<T>,
                observable: AnyDataProviderRepositoryObservable<T>,
                operationQueue: OperationQueue? = nil,
                serialQueue: DispatchQueue? = nil) {
        self.source = source
        self.repository = repository
        self.observable = observable

        if let currentExecutionQueue = operationQueue {
            self.operationQueue = currentExecutionQueue
        } else {
            self.operationQueue = OperationQueue()
        }

        if let currentProcessingQueue = serialQueue {
            self.processingQueue = currentProcessingQueue
        } else {
            self.processingQueue = DispatchQueue(
                label: "co.jp.streamableprovider.repository.queue.\(UUID().uuidString)",
                qos: .utility)
        }
    }

    private func startObservingSource() {
        observable.addObserver(self, deliverOn: processingQueue) { [weak self] (changes) in
            self?.notifyObservers(with: changes)
        }
    }

    private func stopObservingSource() {
        observable.removeObserver(self)
    }

    private func fetchHistory(offset: Int, count: Int, completionBlock: ((Result<Int, Error>?) -> Void)?) {
        source.fetchHistory(offset: offset,
                            count: count,
                            runningIn: processingQueue,
                            commitNotificationBlock: completionBlock)
    }

    private func notifyObservers(with changes: [DataProviderChange<Model>]) {
        observers.forEach { (observerWrapper) in
            if observerWrapper.observer != nil {
                dispatchInQueueWhenPossible(observerWrapper.queue) {
                    observerWrapper.updateBlock(changes)
                }
            }
        }
    }

    private func notifyObservers(with error: Error) {
        observers.forEach { (observerWrapper) in
            if observerWrapper.observer != nil, observerWrapper.options.alwaysNotifyOnRefresh {
                dispatchInQueueWhenPossible(observerWrapper.queue) {
                    observerWrapper.failureBlock(error)
                }
            }
        }
    }

    private func notifyObservers(with fetchResult: Result<Int, Error>) {
        observers.forEach { (observerWrapper) in
            if observerWrapper.observer != nil, observerWrapper.options.alwaysNotifyOnRefresh {
                switch fetchResult {
                case .success(let count):
                    if count == 0 {
                        dispatchInQueueWhenPossible(observerWrapper.queue) {
                            observerWrapper.updateBlock([])
                        }
                    }
                case .failure(let error):
                    dispatchInQueueWhenPossible(observerWrapper.queue) {
                        observerWrapper.failureBlock(error)
                    }
                }
            }
        }
    }
}

extension StreamableProvider: StreamableProviderProtocol {
    public typealias Model = T

    public func fetch(offset: Int, count: Int,
                      with completionBlock: @escaping (Result<[Model], Error>?) -> Void) -> BaseOperation<[Model]> {
        let operation = repository.fetchOperation(by: offset, count: count, reversed: false)

        operation.completionBlock = { [weak self] in
            if let result = operation.result,
                case .success(let models) = result,
                models.count < count {

                let completionBlock: (Result<Int, Error>?) -> Void = { (optionalResult) in
                    if let result = optionalResult {
                        self?.notifyObservers(with: result)
                    }
                }

                self?.fetchHistory(offset: offset + models.count,
                                   count: count - models.count,
                                   completionBlock: completionBlock)
            }

            completionBlock(operation.result)
        }

        operationQueue.addOperation(operation)

        return operation
    }

    public func addObserver(_ observer: AnyObject,
                            deliverOn queue: DispatchQueue,
                            executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
                            failing failureBlock: @escaping (Error) -> Void,
                            options: DataProviderObserverOptions) {
        processingQueue.async {
            let shouldObserveSource = self.observers.isEmpty

            self.observers = self.observers.filter { $0.observer != nil }

            if !self.observers.contains(where: { $0.observer === observer }) {
                let observerWrapper = DataProviderObserver(observer: observer,
                                                           queue: queue,
                                                           updateBlock: updateBlock,
                                                           failureBlock: failureBlock,
                                                           options: options)
                self.observers.append(observerWrapper)
            }

            if shouldObserveSource {
                self.startObservingSource()
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
