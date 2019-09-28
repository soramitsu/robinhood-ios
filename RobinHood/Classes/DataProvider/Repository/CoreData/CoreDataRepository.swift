/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import CoreData

/**
 *  Enum is designed to define internal errors which can occur
 *  in ```CoreDataRepository```.
 */

public enum CoreDataRepositoryError: Error {
    /// Returned where there is no information about error.
    case undefined

    /// Returned when new entity can't be created.
    case creationFailed
}

/**
 *  Implementation of ```DataProviderRepositoryProtocol``` based on Core Data which manages list of
 *  objects of a particular type.
 *
 *  Repository requires an implementation of ```CoreDataServiceProtocol``` to request a context to save/fetch
 *  Core Data entities to/from persistent store. More precisely, repository operates two
 *  kind of models: swift model and NSManagedObject provided by the client as generic parameters.
 *  Repository converts swift model to NSManagedObject using mapper passed as a parameter during
 *  initialization and saves Core Data entity through context. And vice versa, repository converts
 *  NSManagedObject, fetched from the context, to swift model and returns to the client.
 *  Additionally, repository allows sorting fetched entities using ```NSSortDescriptor``` provided
 *  during initialization.
 */

public final class CoreDataRepository<T: Identifiable, U: NSManagedObject> {
    public typealias Model = T

    /// Service which manages Core Data contexts and persistent storage.
    public let databaseService: CoreDataServiceProtocol

    /// Mapper to convert from swift model to Core Data NSManagedObject and back.
    public let dataMapper: AnyCoreDataMapper<T, U>

    /// Domain to access only subset of objects.
    public let domain: String

    /// Descriptor that sorts fetched NSManagedObject list.
    public let sortDescriptor: NSSortDescriptor?

    /**
     *  Creates new Core Data repository object.
     *
     *  - parameters:
     *    - databaseService: Core Data persistent store and contexts manager.
     *    - mapper: Mapper converts from swift model to NSManagedObject and back.
     *    - domain: Domain of the subset of objects to access. Each NSManagedObject
     *    inside repository should have a field to store domain.
     *    See ```CoreDataMapperProtocol``` for more details.
     *    - sortDescriptor: Descriptor to sort fetched objects.
     */

    public init(databaseService: CoreDataServiceProtocol,
                mapper: AnyCoreDataMapper<T, U>,
                domain: String = "default",
                sortDescriptor: NSSortDescriptor? = nil) {

        self.databaseService = databaseService
        self.dataMapper = mapper
        self.domain = domain
        self.sortDescriptor = sortDescriptor
    }

    private func save(models: [Model], in context: NSManagedObjectContext) throws {
        try models.forEach { (model) in
            let entityName = String(describing: U.self)
            let fetchRequest = NSFetchRequest<U>(entityName: entityName)
            let predicate = NSPredicate(format: "(%K == %@) AND (%K == %@)",
                                        dataMapper.entityIdentifierFieldName,
                                        model.identifier,
                                        dataMapper.entityDomainFieldName,
                                        domain)
            fetchRequest.predicate = predicate

            var optionalEntitity = try context.fetch(fetchRequest).first

            if optionalEntitity == nil {
                optionalEntitity = NSEntityDescription.insertNewObject(forEntityName: entityName,
                                                                       into: context) as? U
                optionalEntitity?.setValue(domain, forKey: dataMapper.entityDomainFieldName)
            }

            guard let entity = optionalEntitity else {
                throw CoreDataRepositoryError.creationFailed
            }

            try dataMapper.populate(entity: entity, from: model)
        }
    }

    private func delete(modelIds: [String], in context: NSManagedObjectContext) throws {
        try modelIds.forEach { (modelId) in
            let entityName = String(describing: U.self)
            let fetchRequest = NSFetchRequest<U>(entityName: entityName)
            let predicate = NSPredicate(format: "(%K == %@) AND (%K == %@)",
                                        dataMapper.entityIdentifierFieldName,
                                        modelId,
                                        dataMapper.entityDomainFieldName,
                                        domain)

            fetchRequest.predicate = predicate

            if let entity = try context.fetch(fetchRequest).first {
                context.delete(entity)
            }
        }
    }

    private func call<T>(block: @escaping (T, Error?) -> Void, model: T, error: Error?, queue: DispatchQueue?) {
        if let queue = queue {
            queue.async {
                block(model, error)
            }
        } else {
            block(model, error)
        }
    }

    private func call(block: @escaping (Error?) -> Void, error: Error?, queue: DispatchQueue?) {
        if let queue = queue {
            queue.async {
                block(error)
            }
        } else {
            block(error)
        }
    }

    public func fetch(by modelId: String,
                      runCompletionIn queue: DispatchQueue?,
                      executing block: @escaping (Model?, Error?) -> Void) {

        databaseService.performAsync { [weak self] (optionalContext, optionalError) in
            guard let strongSelf = self else {
                return
            }

            if let context = optionalContext {
                do {
                    let entityName = String(describing: U.self)
                    let fetchRequest = NSFetchRequest<U>(entityName: entityName)
                    let predicate = NSPredicate(format: "(%K == %@) AND (%K == %@)",
                                                strongSelf.dataMapper.entityIdentifierFieldName,
                                                modelId,
                                                strongSelf.dataMapper.entityDomainFieldName,
                                                strongSelf.domain)

                    fetchRequest.predicate = predicate

                    let entities = try context.fetch(fetchRequest)

                    if let entity = entities.first {
                        let model = try strongSelf.dataMapper.transform(entity: entity)

                        strongSelf.call(block: block, model: model, error: nil, queue: queue)
                    } else {
                        strongSelf.call(block: block, model: nil, error: nil, queue: queue)
                    }
                } catch {
                    strongSelf.call(block: block, model: nil, error: error, queue: queue)
                }
            } else {
                strongSelf.call(block: block, model: nil, error: optionalError, queue: queue)
            }
        }
    }

    public func fetchAll(runCompletionIn queue: DispatchQueue?,
                         executing block: @escaping ([Model]?, Error?) -> Void) {

        databaseService.performAsync { [weak self] (optionalContext, optionalError) in
            guard let strongSelf = self else {
                return
            }

            if let context = optionalContext {
                do {
                    let entityName = String(describing: U.self)
                    let fetchRequest = NSFetchRequest<U>(entityName: entityName)
                    let predicate = NSPredicate(format: "%K == %@",
                                                strongSelf.dataMapper.entityDomainFieldName,
                                                strongSelf.domain)
                    fetchRequest.predicate = predicate

                    if let sortDescriptor = strongSelf.sortDescriptor {
                        fetchRequest.sortDescriptors = [sortDescriptor]
                    }

                    let entities = try context.fetch(fetchRequest)
                    let models = try entities.map { try strongSelf.dataMapper.transform(entity: $0) }

                    strongSelf.call(block: block, model: models, error: nil, queue: queue)

                } catch {
                    strongSelf.call(block: block, model: nil, error: error, queue: queue)
                }
            } else {
                strongSelf.call(block: block, model: nil, error: optionalError, queue: queue)
            }
        }
    }

    public func fetch(offset: Int, count: Int, reversed: Bool,
                      runCompletionIn queue: DispatchQueue?, executing block: @escaping ([Model]?, Error?) -> Void) {
        databaseService.performAsync { [weak self] (optionalContext, optionalError) in
            guard let strongSelf = self else {
                return
            }

            if let context = optionalContext {
                do {
                    let entityName = String(describing: U.self)
                    let fetchRequest = NSFetchRequest<U>(entityName: entityName)
                    let predicate = NSPredicate(format: "%K == %@",
                                                strongSelf.dataMapper.entityDomainFieldName,
                                                strongSelf.domain)
                    fetchRequest.predicate = predicate
                    fetchRequest.fetchOffset = offset
                    fetchRequest.fetchLimit = count

                    var sortDescriptor = strongSelf.sortDescriptor

                    if reversed {
                        sortDescriptor = sortDescriptor?.reversedSortDescriptor as? NSSortDescriptor
                    }

                    if let currentSortDescriptor = sortDescriptor {
                        fetchRequest.sortDescriptors = [currentSortDescriptor]
                    }

                    let entities = try context.fetch(fetchRequest)
                    let models = try entities.map { try strongSelf.dataMapper.transform(entity: $0) }

                    strongSelf.call(block: block, model: models, error: nil, queue: queue)

                } catch {
                    strongSelf.call(block: block, model: nil, error: error, queue: queue)
                }
            } else {
                strongSelf.call(block: block, model: nil, error: optionalError, queue: queue)
            }
        }
    }

    public func save(updating updatedModels: [Model], deleting deletedIds: [String],
                     runCompletionIn queue: DispatchQueue?,
                     executing block: @escaping (Error?) -> Void) {

        databaseService.performAsync { (optionalContext, optionalError) in

            if let context = optionalContext {
                do {
                    try self.save(models: updatedModels, in: context)

                    try self.delete(modelIds: deletedIds, in: context)

                    try context.save()

                    self.call(block: block, error: nil, queue: queue)

                } catch {
                    context.rollback()

                    self.call(block: block, error: error, queue: queue)
                }
            } else {
                self.call(block: block, error: optionalError, queue: queue)
            }
        }
    }

    public func deleteAll(runCompletionIn queue: DispatchQueue?,
                          executing block: @escaping (Error?) -> Void) {
        databaseService.performAsync { (optionalContext, optionalError) in
            if let context = optionalContext {
                do {
                    let entityName = String(describing: U.self)
                    let fetchRequest = NSFetchRequest<U>(entityName: entityName)
                    let predicate = NSPredicate(format: "%K == %@",
                                                self.dataMapper.entityDomainFieldName,
                                                self.domain)
                    fetchRequest.predicate = predicate

                    let entities = try context.fetch(fetchRequest)

                    for entity in entities {
                        context.delete(entity)
                    }

                    try context.save()

                    self.call(block: block, error: nil, queue: queue)

                } catch {
                    context.rollback()

                    self.call(block: block, error: error, queue: queue)
                }
            } else {
                self.call(block: block, error: optionalError, queue: queue)
            }
        }
    }
}
