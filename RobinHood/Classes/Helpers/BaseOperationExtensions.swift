import Foundation

extension BaseOperation {
    public func extractResultData(throwing noResultError: Error) throws -> ResultType {
        if let result = try extractResultData() {
            return result
        } else {
            throw noResultError
        }
    }

    public func extractResultData() throws -> ResultType? {
        guard let result = self.result else {
            return nil
        }

        switch result {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}
