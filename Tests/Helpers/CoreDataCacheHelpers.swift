import Foundation
import RobinHood
import CoreData

func clear(databaseService: CoreDataServiceProtocol) throws {
    try databaseService.close()
    try databaseService.drop()
}

final class CoreDataCacheFacade {
    static let shared = CoreDataCacheFacade()

    let databaseService: CoreDataServiceProtocol

    private init() {
        let configuration = CoreDataServiceConfiguration.createDefaultConfigutation()
        databaseService = CoreDataService(configuration: configuration)
    }

    func createCoreDataCache<T, U>(domain: String = UUID().uuidString) -> CoreDataCache<T, U>
        where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable  {

            let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
            return CoreDataCache(databaseService: databaseService,
                                 mapper: mapper,
                                 domain: domain)
    }

    func clearDatabase() throws {
        try clear(databaseService: databaseService)
    }
}
