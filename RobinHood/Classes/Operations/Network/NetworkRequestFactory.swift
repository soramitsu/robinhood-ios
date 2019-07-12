/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol NetworkRequestFactoryProtocol: class {
    func createRequest() throws -> URLRequest
}

public typealias NetworkRequestCreationBlock = () throws -> URLRequest

public final class BlockNetworkRequestFactory: NetworkRequestFactoryProtocol {
    private var requestBlock: NetworkRequestCreationBlock

    public init(requestBlock: @escaping NetworkRequestCreationBlock) {
        self.requestBlock = requestBlock
    }

    public func createRequest() throws -> URLRequest {
        return try requestBlock()
    }
}
