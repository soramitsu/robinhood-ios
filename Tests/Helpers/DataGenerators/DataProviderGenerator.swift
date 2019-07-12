/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import RobinHood
import CoreData

func createDataSourceMock<T>(base: Any, returns items: [T]) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> BaseOperation<[T]> = { _ in
        let pageOperation = BaseOperation<[T]>()
        pageOperation.result = .success(items)

        return pageOperation
    }

    let fetchByIdBlock: (String) -> BaseOperation<T?> = { _ in
        let identifierOperation = BaseOperation<T?>()
        identifierOperation.result = .success(nil)

        return identifierOperation
    }

    return AnyDataProviderSource(base: base,
                                 fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createDataSourceMock<T>(base: Any, returns error: Error) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> BaseOperation<[T]> = { _ in
        let pageOperation = BaseOperation<[T]>()
        pageOperation.result = .error(error)

        return pageOperation
    }

    let fetchByIdBlock: (String) -> BaseOperation<T?> = { _ in
        let identifierOperation = BaseOperation<T?>()
        identifierOperation.result = .error(error)

        return identifierOperation
    }

    return AnyDataProviderSource(base: base,
                                 fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createSingleValueSourceMock<T>(base: Any, returns item: T) -> AnySingleValueProviderSource<T> {
    let fetch: () -> BaseOperation<T> = {
        let operation = BaseOperation<T>()
        operation.result = .success(item)

        return operation
    }

    return AnySingleValueProviderSource(base: base,
                                        fetch: fetch)
}

func createSingleValueSourceMock<T>(base: Any, returns error: Error) -> AnySingleValueProviderSource<T> {
    let fetch: () -> BaseOperation<T> = {
        let operation = BaseOperation<T>()
        operation.result = .error(error)

        return operation
    }

    return AnySingleValueProviderSource(base: base,
                                        fetch: fetch)
}

func createStreamableSourceMock<T: Identifiable, U: NSManagedObject>(base: Any, cache: CoreDataCache<T, U>, operationQueue: OperationQueue,
                                                                     returns items: [T]) -> AnyStreamableSource<T> {
    let source: AnyStreamableSource<T> = AnyStreamableSource(source: base) { (offset, count, queue, completionBlock) in
        let dispatchQueue = queue ?? .main

        let saveOperation = cache.saveOperation( { items }, { [] })

        operationQueue.addOperation(saveOperation)

        dispatchQueue.async {
            completionBlock?(OperationResult.success(items.count))
        }
    }

    return source
}

func createStreamableSourceMock<T: Identifiable>(base: Any, returns error: Error) -> AnyStreamableSource<T> {
    let source: AnyStreamableSource<T> = AnyStreamableSource(source: base) { (offset, count, queue, completionBlock) in
        let dispatchQueue = queue ?? .main

        dispatchQueue.async {
            completionBlock?(OperationResult.error(error))
        }
    }

    return source
}
