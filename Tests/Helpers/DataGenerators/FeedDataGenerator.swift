/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

func createRandomFeed(in domain: Domain) -> FeedData {
    let likesCount = Int32.random(in: 0..<100)
    let favorite = [false, true].randomElement()!
    let favoriteCount = UInt((0...100).randomElement()!)
    let status: FeedDataStatus = [.open, .hidden].randomElement()!

    return FeedData(identifier: UUID().uuidString,
                    domain: domain,
                    favorite: favorite,
                    favoriteCount: favoriteCount,
                    name: UUID().uuidString,
                    description: UUID().uuidString,
                    imageLink: URL(string: "https://google.com"),
                    status: status,
                    likesCount: likesCount)
}
