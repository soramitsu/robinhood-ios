/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

import Foundation

struct MessageData: Equatable, Codable {
    var identifier: String
    var chat: ChatData
    var text: String
}
