import Foundation

public protocol NetworkResultFactoryProtocol: class {
    associatedtype ResultType
    func createResult(data: Data?, response: URLResponse?, error: Error?) -> OperationResult<ResultType>
}

public typealias NetworkResultFactoryBlock<ResultType> = (Data?, URLResponse?, Error?) -> OperationResult<ResultType>
public typealias NetworkResultFactorySuccessResponseBlock<ResultType> = () -> ResultType
public typealias NetworkResultFactoryProcessingBlock<ResultType> = (Data) throws -> ResultType

public final class AnyNetworkResultFactory<T>: NetworkResultFactoryProtocol {
    public typealias ResultType = T

    private var _createResult: NetworkResultFactoryBlock<ResultType>

    public init<U: NetworkResultFactoryProtocol>(factory: U) where U.ResultType == ResultType {
        _createResult = factory.createResult
    }

    public init(block: @escaping NetworkResultFactoryBlock<ResultType>) {
        _createResult = block
    }

    public convenience init(successResponseBlock: @escaping NetworkResultFactorySuccessResponseBlock<ResultType>) {
        self.init { (_, response, error) -> OperationResult<ResultType> in
            if let connectionError = error {
                return .error(connectionError)
            }

            if let error = NetworkOperationHelper.createError(from: response) {
                return .error(error)
            }

            let result = successResponseBlock()
            return .success(result)
        }
    }

    public convenience init(processingBlock: @escaping NetworkResultFactoryProcessingBlock<ResultType>) {
        self.init { (data, response, error) -> OperationResult<ResultType> in
            if let connectionError = error {
                return .error(connectionError)
            }

            if let error = NetworkOperationHelper.createError(from: response) {
                return .error(error)
            }

            guard let documentData = data else {
                return .error(NetworkBaseError.unexpectedEmptyData)
            }

            do {
                let value = try processingBlock(documentData)
                return .success(value)
            } catch {
                return .error(error)
            }
        }
    }

    public func createResult(data: Data?, response: URLResponse?, error: Error?) -> OperationResult<ResultType> {
        return _createResult(data, response, error)
    }
}
