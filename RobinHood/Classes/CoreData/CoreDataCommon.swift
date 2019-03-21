import Foundation
import CoreData

public enum IncompatibleModelHandlingStrategy {
    case ignore
    case removeStore
}

public protocol CoreDataServiceConfigurationProtocol {
    var modelURL: URL! { get }
    var databaseDirectory: URL! { get }
    var databaseName: String { get }
    var incompatibleModelStrategy: IncompatibleModelHandlingStrategy { get }
    var excludeFromiCloudBackup: Bool { get }
}

public typealias CoreDataContextInvocationBlock = (NSManagedObjectContext?, Error?) -> Void

public protocol CoreDataServiceProtocol {
    var configuration: CoreDataServiceConfigurationProtocol! { get set }

    func performAsync(block: @escaping CoreDataContextInvocationBlock)
    func close() throws
    func drop() throws
}

public enum CoreDataManagerBaseError: Error {
    case missingContext
    case unexpectedEntity
}
