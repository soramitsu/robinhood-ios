import Foundation

public final class NetworkOperationHelper {
    public static func isCancellation(error: Error) -> Bool {
        if let nserror = error as NSError?, nserror.code == NSURLErrorCancelled {
            return true
        } else {
            return false
        }
    }

    public static func createError(from response: URLResponse?) -> Error? {
        guard let httpUrlResponse = response as? HTTPURLResponse else {
            return NetworkBaseError.unexpectedResponseObject
        }

        return NetworkResponseError.createFrom(statusCode: httpUrlResponse.statusCode)
    }
}
