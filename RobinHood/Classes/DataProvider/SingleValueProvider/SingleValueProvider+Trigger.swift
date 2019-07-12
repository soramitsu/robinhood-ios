/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

// MARK: Trigger Protocol implementation
extension SingleValueProvider: DataProviderTriggerDelegate {
    public func didTrigger() {
        dispatchUpdateCache()
    }
}
