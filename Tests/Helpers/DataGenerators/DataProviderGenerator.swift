/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
@testable import RobinHood
import CoreData

func createDataSourceMock<T>(returns items: [T], after delay: TimeInterval = 0.0) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> BaseOperation<[T]> = { _ in
        return ClosureOperation {
            usleep(useconds_t(delay * 1e+6))
            return items
        }
    }

    let fetchByIdBlock: (String) -> BaseOperation<T?> = { _ in
        return ClosureOperation {
            usleep(useconds_t(delay * 1e+6))
            return nil
        }
    }

    return AnyDataProviderSource(fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createDataSourceMock<T>(returns error: Error) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> BaseOperation<[T]> = { _ in
        let pageOperation = BaseOperation<[T]>()
        pageOperation.result = .failure(error)

        return pageOperation
    }

    let fetchByIdBlock: (String) -> BaseOperation<T?> = { _ in
        let identifierOperation = BaseOperation<T?>()
        identifierOperation.result = .failure(error)

        return identifierOperation
    }

    return AnyDataProviderSource(fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createSingleValueSourceMock<T>(returns item: T?, after delay: TimeInterval = 0.0) -> AnySingleValueProviderSource<T> {
    let fetch: () -> BaseOperation<T?> = {
        return ClosureOperation {
            usleep(useconds_t(delay * 1e+6))
            return item
        }
    }

    return AnySingleValueProviderSource(fetch: fetch)
}

func createSingleValueSourceMock<T>(returns error: Error) -> AnySingleValueProviderSource<T> {
    let fetch: () -> BaseOperation<T?> = {
        let operation = BaseOperation<T?>()
        operation.result = .failure(error)

        return operation
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
        let totalCountOperation = repository.fetchAllOperation()
        let deleteAllOperation = repository.deleteAllOperation()
        let saveOperation = repository.saveOperation( { items }, { [] })

        deleteAllOperation.addDependency(totalCountOperation)
        saveOperation.addDependency(deleteAllOperation)

        saveOperation.completionBlock = {
            do {
                let count = try totalCountOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled).count +
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

        let operations = [totalCountOperation, deleteAllOperation, saveOperation]

        if let enqueueClosure = enqueueClosure {
            enqueueClosure(operations)
        } else {
            OperationQueue().addOperations([totalCountOperation, deleteAllOperation, saveOperation],
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
