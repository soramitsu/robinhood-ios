import Foundation

public enum OperationResult<T> {
    case success(T)
    case error(Error)
}

public typealias OperationConfigBlock = () -> Void

public enum BaseOperationError: Error {
    case parentOperationCancelled
    case unexpectedDependentResult
}

public class BaseOperation<ResultType>: Operation {
    public var result: OperationResult<ResultType>?

    public var configurationBlock: OperationConfigBlock?

    override public func main() {
        configurationBlock?()
        configurationBlock = nil
    }

    override public func cancel() {
        configurationBlock = nil
        super.cancel()
    }
}
