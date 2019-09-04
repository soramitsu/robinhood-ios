/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import RobinHood
import CoreData

func clear(databaseService: CoreDataServiceProtocol) throws {
    try databaseService.close()
    try databaseService.drop()
}

final class CoreDataRepositoryFacade {
    static let shared = CoreDataRepositoryFacade()

    let databaseService: CoreDataServiceProtocol

    private init() {
        let configuration = CoreDataServiceConfiguration.createDefaultConfigutation()
        databaseService = CoreDataService(configuration: configuration)
    }

    func createCoreDataRepository<T, U>(domain: String = UUID().uuidString, sortDescriptor: NSSortDescriptor? = nil) -> CoreDataRepository<T, U>
        where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable  {

            let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
            return CoreDataRepository(databaseService: databaseService,
                                      mapper: mapper,
                                      domain: domain,
                                      sortDescriptor: sortDescriptor)
    }

    func clearDatabase() throws {
        try clear(databaseService: databaseService)
    }
}
