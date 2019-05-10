import Foundation

public protocol DataProviderCacheProtocol {
    associatedtype Model: Identifiable

    var domain: String { get }

    func fetchOperation(by modelId: String) -> BaseOperation<Model?>

    func fetchAllOperation() -> BaseOperation<[Model]>

    func fetch(offset: Int, count: Int, reversed: Bool) -> BaseOperation<[Model]>

    func saveOperation(_ updateModelsBlock: @escaping () throws -> [Model],
                       _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Bool>

    func deleteAllOperation() -> BaseOperation<Bool>
}
