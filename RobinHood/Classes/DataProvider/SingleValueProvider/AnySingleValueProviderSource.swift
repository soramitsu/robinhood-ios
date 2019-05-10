import Foundation

public final class AnySingleValueProviderSource<T>: SingleValueProviderSourceProtocol {
    public typealias Model = T

    public private(set) var base: Any

    private let _fetch: () -> BaseOperation<Model>

    public init<U: SingleValueProviderSourceProtocol>(_ source: U) where U.Model == Model {
        self.base = source
        _fetch = source.fetchOperation
    }

    public init(base: Any,
                fetch: @escaping () -> BaseOperation<Model>) {
        self.base = base
        _fetch = fetch
    }

    public func fetchOperation() -> BaseOperation<T> {
        return _fetch()
    }
}
