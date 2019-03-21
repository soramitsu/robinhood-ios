import Foundation

public struct CoreDataServiceConfiguration: CoreDataServiceConfigurationProtocol {
    public var modelURL: URL!
    public var databaseDirectory: URL!
    public var databaseName: String
    public var incompatibleModelStrategy: IncompatibleModelHandlingStrategy = .ignore

    public init(modelURL: URL!, databaseDirectory: URL!, databaseName: String) {
        self.modelURL = modelURL
        self.databaseDirectory = databaseDirectory
        self.databaseName = databaseName
    }
}
