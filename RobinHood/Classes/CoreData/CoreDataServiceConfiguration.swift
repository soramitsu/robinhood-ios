import Foundation

public struct CoreDataServiceConfiguration: CoreDataServiceConfigurationProtocol {
    public var modelURL: URL!
    public var databaseDirectory: URL!
    public var databaseName: String
}
