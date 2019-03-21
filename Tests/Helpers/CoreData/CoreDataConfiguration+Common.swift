import Foundation
import RobinHood

extension CoreDataServiceConfiguration {
    public static func createDefaultConfigutation() -> CoreDataServiceConfiguration {
        return createDefaultConfigutation(with: Constants.defaultCoreDataModelName,
                                          databaseName: Constants.defaultCoreDataModelName,
                                          incompatibleModelStrategy: .ignore)
    }

    public static func createDefaultConfigutation(with modelName: String,
                                                  databaseName: String,
                                                  incompatibleModelStrategy: IncompatibleModelHandlingStrategy) -> CoreDataServiceConfiguration {
        let bundle = Bundle(for: LoadableBundleClass.self)
        let modelURL = bundle.url(forResource: modelName, withExtension: "momd")
        let databaseName = "\(databaseName).sqlite"

        let baseURL = FileManager.default.urls(for: .documentDirectory,
                                               in: .userDomainMask).first?.appendingPathComponent("CoreData")

        var configuration = CoreDataServiceConfiguration(modelURL: modelURL,
                                                         databaseDirectory: baseURL,
                                                         databaseName: databaseName)
        configuration.incompatibleModelStrategy = incompatibleModelStrategy

        return configuration
    }
}
