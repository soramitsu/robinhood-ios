/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public protocol NetworkIndicatorManagerProtocol {
    func increment()
    func decrement()
}

public final class NetworkIndicatorManager {
    static let shared = NetworkIndicatorManager()

    let managerQueue = DispatchQueue(label: UUID().uuidString)

    var numberOfOperations = 0

    private init() {}
}

extension NetworkIndicatorManager: NetworkIndicatorManagerProtocol {
    public func increment() {
        managerQueue.async {
            self.numberOfOperations += 1

            if self.numberOfOperations == 1 {
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
                }
            }
        }
    }

    public func decrement() {
        managerQueue.async {
            guard self.numberOfOperations > 0 else {
                return
            }

            self.numberOfOperations -= 1

            if self.numberOfOperations == 0 {
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
            }
        }
    }
}
