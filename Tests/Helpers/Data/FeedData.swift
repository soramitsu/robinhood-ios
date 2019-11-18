/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

enum FeedDataStatus: String, Codable {
    case open = "OPEN"
    case hidden = "HIDDEN"
}

enum Domain: String, Codable {
    case `default` = "default"
    case favorites = "favorites"
}

struct FeedData: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case domain
        case favorite
        case favoriteCount
        case name
        case description
        case imageLink
        case status
        case likesCount
    }

    var identifier: String
    var domain: Domain
    var favorite: Bool
    var favoriteCount: UInt
    var name: String
    var description: String?
    var imageLink: URL?
    var status: FeedDataStatus
    var likesCount: Int32
}
