/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public enum OperationResult<T> {
    case success(T)
    case error(Error)
}

public typealias OperationConfigBlock = () -> Void

public enum BaseOperationError: Error {
    case parentOperationCancelled
    case unexpectedDependentResult
}

open class BaseOperation<ResultType>: Operation {
    open var result: OperationResult<ResultType>?

    open var configurationBlock: OperationConfigBlock?

    override open func main() {
        configurationBlock?()
        configurationBlock = nil
    }

    override open func cancel() {
        configurationBlock = nil
        super.cancel()
    }
}
