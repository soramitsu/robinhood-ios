/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
@testable import RobinHood
import CoreData

func createDataSourceMock<T>(returns items: [T], after delay: TimeInterval = 0.0) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> CompoundOperationWrapper<[T]> = { _ in
        let operation = ClosureOperation<[T]> {
            usleep(useconds_t(delay * 1e+6))
            return items
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    let fetchByIdBlock: (String) -> CompoundOperationWrapper<T?> = { _ in
        let operation = ClosureOperation<T?> {
            usleep(useconds_t(delay * 1e+6))
            return nil
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    return AnyDataProviderSource(fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createDataSourceMock<T>(returns error: Error) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> CompoundOperationWrapper<[T]> = { _ in
        let pageOperation = BaseOperation<[T]>()
        pageOperation.result = .failure(error)

        return CompoundOperationWrapper(targetOperation: pageOperation)
    }

    let fetchByIdBlock: (String) -> CompoundOperationWrapper<T?> = { _ in
        let identifierOperation = BaseOperation<T?>()
        identifierOperation.result = .failure(error)

        return CompoundOperationWrapper(targetOperation: identifierOperation)
    }

    return AnyDataProviderSource(fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createSingleValueSourceMock<T>(returns item: T?, after delay: TimeInterval = 0.0) -> AnySingleValueProviderSource<T> {
    let fetch: () -> CompoundOperationWrapper<T?> = {
        let operation = ClosureOperation<T?> {
            usleep(useconds_t(delay * 1e+6))
            return item
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    return AnySingleValueProviderSource(fetch: fetch)
}

func createSingleValueSourceMock<T>(returns error: Error) -> AnySingleValueProviderSource<T> {
    let fetch: () -> CompoundOperationWrapper<T?> = {
        let operation = BaseOperation<T?>()
        operation.result = .failure(error)

        return CompoundOperationWrapper(targetOperation: operation)
    }

    return AnySingleValueProviderSource(fetch: fetch)
}

func createStreamableSourceMock<T: Identifiable, U: NSManagedObject>(repository: CoreDataRepository<T, U>,
                                                                     returns items: [T],
                                                                     enqueueClosure: OperationEnqueuClosure? = nil)
    -> AnyStreamableSource<T> {

    let historyClosure: AnyStreamableSourceFetchBlock = { (queue, completionBlock) in
        let saveOperation = repository.saveOperation( { items }, { [] })

        if let enqueueClosure = enqueueClosure {
            enqueueClosure([saveOperation])
        } else {
            OperationQueue().addOperation(saveOperation)
        }

        dispatchInQueueWhenPossible(queue) {
            completionBlock?(.success(items.count))
        }
    }

    let refreshClosure: AnyStreamableSourceFetchBlock = { (queue, completionBlock) in
        let totalCountOperation = repository.fetchCountOperation()
        let replaceOperation = repository.replaceOperation( { items })

        replaceOperation.addDependency(totalCountOperation)

        replaceOperation.completionBlock = {
            do {
                let count = try totalCountOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) +
                items.count

                dispatchInQueueWhenPossible(queue) {
                    completionBlock?(.success(count))
                }
            } catch {
                dispatchInQueueWhenPossible(queue) {
                    completionBlock?(.failure(error))
                }
            }
        }

        let operations = [totalCountOperation, replaceOperation]

        if let enqueueClosure = enqueueClosure {
            enqueueClosure(operations)
        } else {
            OperationQueue().addOperations([totalCountOperation, replaceOperation],
                                           waitUntilFinished: false)
        }
    }

    let source: AnyStreamableSource<T> = AnyStreamableSource(fetchHistory: historyClosure,
                                                             refresh: refreshClosure)

    return source
}

func createStreamableSourceMock<T: Identifiable>(returns error: Error) -> AnyStreamableSource<T> {
    let closure: AnyStreamableSourceFetchBlock = { (queue, completionBlock) in
        dispatchInQueueWhenPossible(queue) {
            completionBlock?(.failure(error))
        }
    }

    let source: AnyStreamableSource<T> = AnyStreamableSource(fetchHistory: closure,
                                                             refresh: closure)

    return source
}
