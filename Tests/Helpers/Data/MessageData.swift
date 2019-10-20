import Foundation

struct MessageData: Equatable, Codable {
    var identifier: String
    var chat: ChatData
    var text: String
}
