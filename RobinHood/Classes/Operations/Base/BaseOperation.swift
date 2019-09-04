/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public typealias OperationConfigBlock = () -> Void

public enum BaseOperationError: Error {
    case parentOperationCancelled
    case unexpectedDependentResult
}

open class BaseOperation<ResultType>: Operation {
    open var result: Result<ResultType, Error>?

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
