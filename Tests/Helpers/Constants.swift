/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

struct Constants {
    static let defaultCoreDataModelName = "Entities"
    static let incompatibleCoreDataModelName = "IEntities"
    static let repositoryDomain = "co.jp.sora.test.repository"
    static let expectationDuration: TimeInterval = 60.0
    static let dummyNetworkURL: URL = URL(string: "https://google.com")!
    static let networkRequestTimeout: TimeInterval = 60.0
}
