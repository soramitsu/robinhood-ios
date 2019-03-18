import Foundation
import RobinHood

extension CoreDataServiceConfiguration {
    public static func createDefaultConfigutation() -> CoreDataServiceConfiguration {
        let modelName = "Entities"

        let bundle = Bundle(for: LoadableBundleClass.self)
        let modelURL = bundle.url(forResource: modelName, withExtension: "momd")
        let databaseName = "\(modelName).sqlite"

        let baseURL = FileManager.default.urls(for: .documentDirectory,
                                               in: .userDomainMask).first?.appendingPathComponent("CoreData")

        return CoreDataServiceConfiguration(modelURL: modelURL,
                                            databaseDirectory: baseURL,
                                            databaseName: databaseName)
    }
}
