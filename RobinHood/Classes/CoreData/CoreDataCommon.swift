import Foundation
import CoreData

public enum IncompatibleModelHandlingStrategy {
    case ignore
    case removeStore
}

public struct CoreDataPersistentSettings {
    public var databaseDirectory: URL
    public var databaseName: String
    public var incompatibleModelStrategy: IncompatibleModelHandlingStrategy
    public var excludeFromiCloudBackup: Bool

    public init(databaseDirectory: URL,
                databaseName: String,
                incompatibleModelStrategy: IncompatibleModelHandlingStrategy = .ignore,
                excludeFromiCloudBackup: Bool = true) {
        self.databaseDirectory = databaseDirectory
        self.databaseName = databaseName
        self.incompatibleModelStrategy = incompatibleModelStrategy
        self.excludeFromiCloudBackup = excludeFromiCloudBackup
    }
}

public enum CoreDataServiceStorageType {
    case persistent(settings: CoreDataPersistentSettings)
    case inMemory
}

public protocol CoreDataServiceConfigurationProtocol {
    var modelURL: URL { get }
    var storageType: CoreDataServiceStorageType { get }
}

public typealias CoreDataContextInvocationBlock = (NSManagedObjectContext?, Error?) -> Void

public protocol CoreDataServiceProtocol {
    var configuration: CoreDataServiceConfigurationProtocol { get }

    func performAsync(block: @escaping CoreDataContextInvocationBlock)
    func close() throws
    func drop() throws
}

public enum CoreDataManagerBaseError: Error {
    case missingContext
    case unexpectedEntity
}
