import Foundation
import RobinHood
import CoreData

func createCoreDataCache<T, U>(from databaseService: CoreDataServiceProtocol = CoreDataService.shared,
                               domain: String = UUID().uuidString) -> CoreDataCache<T, U>
    where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable  {

    let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
    return CoreDataCache(databaseService: databaseService,
                              mapper: mapper,
                              domain: domain)
}
