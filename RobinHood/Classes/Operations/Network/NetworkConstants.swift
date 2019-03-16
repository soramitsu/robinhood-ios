import Foundation

public enum HttpMethod: String {
    case get
    case post
    case put
    case delete
}

public enum HttpContentType: String {
    case json = "application/json"
}

public enum HttpHeaderKey: String {
    case contentType = "Content-Type"
}
