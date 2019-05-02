import Foundation

public struct CoreDataServiceConfiguration: CoreDataServiceConfigurationProtocol {
    public var modelURL: URL
    public var storageType: CoreDataServiceStorageType

    public init(modelURL: URL, storageType: CoreDataServiceStorageType) {
        self.modelURL = modelURL
        self.storageType = storageType
    }
}
