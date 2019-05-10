import Foundation

public typealias AnyStreamableFetchHistoryBlock = (Int, Int, DispatchQueue?, ((OperationResult<Int>?) -> Void)?) -> Void

public final class AnyStreamableSource<T: Identifiable>: StreamableSourceProtocol {
    public typealias Model = T

    public private(set) var base: Any

    private let _fetchHistory: AnyStreamableFetchHistoryBlock

    public init<U: StreamableSourceProtocol>(_ source: U) where U.Model == Model {
        base = source
        _fetchHistory = source.fetchHistory
    }

    public init(source: Any, fetchHistory: @escaping AnyStreamableFetchHistoryBlock) {
        base = source
        _fetchHistory = fetchHistory
    }

    public func fetchHistory(offset: Int, count: Int, runningIn queue: DispatchQueue?,
                             commitNotificationBlock: ((OperationResult<Int>?) -> Void)?) {
        _fetchHistory(offset, count, queue, commitNotificationBlock)
    }
}
