/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

import Foundation

func createRandomMessage() -> MessageData {
    let chat = createRandomChat()

    return createRandomMessage(for: chat)
}

func createRandomMessage(for chat: ChatData) -> MessageData {
    return MessageData(identifier: UUID().uuidString,
                       chat: chat,
                       text: UUID().uuidString)
}

func createRandomChat() -> ChatData {
    return ChatData(identifier: UUID().uuidString,
                    title: UUID().uuidString)
}
