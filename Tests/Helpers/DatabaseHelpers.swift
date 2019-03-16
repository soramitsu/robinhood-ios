import Foundation
import RobinHood

func setupDatabaseIfNeeded(using service: CoreDataService) {
    if service.configuration == nil {
        service.configuration = CoreDataServiceConfiguration.createDefaultConfigutation()
    }
}

func clearDatabase(using service: CoreDataServiceProtocol) throws {
    try service.close()
    try service.drop()
}
