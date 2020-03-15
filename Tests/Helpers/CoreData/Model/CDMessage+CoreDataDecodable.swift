/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

import Foundation
import RobinHood
import CoreData

extension CDMessage: CoreDataCodable {
    enum CodingKeys: String, CodingKey {
        case identifier
        case chat
        case text
    }

    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        text = try container.decode(String.self, forKey: .text)

        let chat = try container.decode(ChatData.self, forKey: .chat)

        if chat.identifier != self.chat?.identifier {
            let entityName = String(describing: CDChat.self)

            let fetchRequest = NSFetchRequest<CDChat>(entityName: entityName)
            fetchRequest.predicate = NSPredicate(format: "%K = %@", #keyPath(CDChat.identifier), chat.identifier)
            fetchRequest.includesSubentities = false

            if let cdChat = try context.fetch(fetchRequest).first {
                self.chat = cdChat
            } else {
                self.chat = NSEntityDescription.insertNewObject(forEntityName: entityName,
                                                                into: context) as? CDChat
            }
        }

        self.chat?.populate(from: chat)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(chat, forKey: .chat)
    }
}
