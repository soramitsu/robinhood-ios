/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public final class ClosureOperation<ResultType>: BaseOperation<ResultType> {

    public let closure: () throws -> ResultType

    public init(closure: @escaping () throws -> ResultType) {
        self.closure = closure
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            let executionResult = try closure()
            result = .success(executionResult)
        } catch {
            result = .failure(error)
        }
    }
}
