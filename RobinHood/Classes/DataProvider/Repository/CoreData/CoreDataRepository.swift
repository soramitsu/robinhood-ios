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
 *  Additionally, repository allows filtering and sorting fetched entities using ```NSPredicate``` and
 *  list of ```NSSortDescriptor``` provided during initialization.
 */

public final class CoreDataRepository<T: Identifiable, U: NSManagedObject> {
    public typealias Model = T

    /// Service which manages Core Data contexts and persistent storage.
    public let databaseService: CoreDataServiceProtocol

    /// Mapper to convert from swift model to Core Data NSManagedObject and back.
    public let dataMapper: AnyCoreDataMapper<T, U>

    /// Predicate to access only subset of objects.
    public let filter: NSPredicate?

    /// Descriptors to sort fetched NSManagedObject list.
    public let sortDescriptors: [NSSortDescriptor]

    /**
     *  Creates new Core Data repository object.
     *
     *  - parameters:
     *    - databaseService: Core Data persistent store and contexts manager.
     *    - mapper: Mapper converts from swift model to NSManagedObject and back.
     *    - filter: NSPredicate of the subset of objects to access. By default `nil` (all objects).
     *    - sortDescriptor: Descriptor to sort fetched objects. By default `nil`.
     */

    public init(databaseService: CoreDataServiceProtocol,
                mapper: AnyCoreDataMapper<T, U>,
                filter: NSPredicate? = nil,
                sortDescriptors: [NSSortDescriptor] = []) {

        self.databaseService = databaseService
        self.dataMapper = mapper
        self.filter = filter
        self.sortDescriptors = sortDescriptors
    }

    private func save(models: [Model], in context: NSManagedObjectContext) throws {
        try models.forEach { (model) in
            let entityName = String(describing: U.self)
            let fetchRequest = NSFetchRequest<U>(entityName: entityName)
            var predicate = NSPredicate(format: "%K == %@",
                                        dataMapper.entityIdentifierFieldName,
                                        model.identifier)

            if let filter = filter {
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [filter, predicate])
            }

            fetchRequest.predicate = predicate

            var optionalEntitity = try context.fetch(fetchRequest).first

            if optionalEntitity == nil {
                optionalEntitity = NSEntityDescription.insertNewObject(forEntityName: entityName,
                                                                       into: context) as? U
            }

            guard let entity = optionalEntitity else {
                throw CoreDataRepositoryError.creationFailed
            }

            try dataMapper.populate(entity: entity, from: model, using: context)
        }
    }

    private func delete(modelIds: [String], in context: NSManagedObjectContext) throws {
        try modelIds.forEach { (modelId) in
            let entityName = String(describing: U.self)
            let fetchRequest = NSFetchRequest<U>(entityName: entityName)
            var predicate = NSPredicate(format: "%K == %@",
                                        dataMapper.entityIdentifierFieldName,
                                        modelId)

            if let filter = filter {
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [filter, predicate])
            }

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
                    var predicate = NSPredicate(format: "%K == %@",
                                                strongSelf.dataMapper.entityIdentifierFieldName,
                                                modelId)

                    if let filter = strongSelf.filter {
                        predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [filter, predicate])
                    }

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
                    fetchRequest.predicate = strongSelf.filter

                    if !strongSelf.sortDescriptors.isEmpty {
                        fetchRequest.sortDescriptors = strongSelf.sortDescriptors
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
                    fetchRequest.predicate = strongSelf.filter
                    fetchRequest.fetchOffset = offset
                    fetchRequest.fetchLimit = count

                    var sortDescriptors = strongSelf.sortDescriptors

                    if reversed {
                        sortDescriptors = sortDescriptors.compactMap {
                            $0.reversedSortDescriptor as? NSSortDescriptor
                        }
                    }

                    if !sortDescriptors.isEmpty {
                        fetchRequest.sortDescriptors = sortDescriptors
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
        databaseService.performAsync { [weak self] (optionalContext, optionalError) in
            guard let strongSelf = self else {
                return
            }

            if let context = optionalContext {
                do {
                    let entityName = String(describing: U.self)
                    let fetchRequest = NSFetchRequest<U>(entityName: entityName)
                    fetchRequest.predicate = strongSelf.filter

                    let entities = try context.fetch(fetchRequest)

                    for entity in entities {
                        context.delete(entity)
                    }

                    try context.save()

                    strongSelf.call(block: block, error: nil, queue: queue)

                } catch {
                    context.rollback()

                    strongSelf.call(block: block, error: error, queue: queue)
                }
            } else {
                strongSelf.call(block: block, error: optionalError, queue: queue)
            }
        }
    }
}
