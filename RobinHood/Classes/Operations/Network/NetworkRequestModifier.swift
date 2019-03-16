import Foundation

public protocol NetworkRequestModifierProtocol {
    func modify(request: URLRequest) throws -> URLRequest
}
