import Foundation

struct Constants {
    static let defaultCoreDataModelName = "Entities"
    static let incompatibleCoreDataModelName = "IEntities"
    static let cacheDomain = "co.jp.sora.test.cache"
    static let expectationDuration: TimeInterval = 60.0
    static let dummyNetworkURL: URL = URL(string: "https://google.com")!
    static let networkRequestTimeout: TimeInterval = 60.0
}
