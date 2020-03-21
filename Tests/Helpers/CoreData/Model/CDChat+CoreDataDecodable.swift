/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

import Foundation
import RobinHood
import CoreData

extension CDChat: CoreDataCodable {
    enum CodingKeys: String, CodingKey {
        case identifier
        case title
    }

    func populate(from chat: ChatData) {
        identifier = chat.identifier
        title = chat.title
    }

    public func populate(from decoder: Decoder,
                         using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decode(String.self, forKey: .identifier)
        title = try container.decode(String.self, forKey: .title)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(title, forKey: .title)
    }
}
