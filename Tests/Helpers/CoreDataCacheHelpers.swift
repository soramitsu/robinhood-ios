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

    func createCoreDataRepository<T, U>(filter: NSPredicate? = nil,
                                        sortDescriptors: [NSSortDescriptor] = []) -> CoreDataRepository<T, U>
        where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable  {

            let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
            return CoreDataRepository(databaseService: databaseService,
                                      mapper: mapper,
                                      filter: filter,
                                      sortDescriptors: sortDescriptors)
    }

    func clearDatabase() throws {
        try clear(databaseService: databaseService)
    }
}
