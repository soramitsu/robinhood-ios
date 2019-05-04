import Foundation
import CoreData

public enum CoreDataCacheError: Error {
    case bothModelAndErrorNull
    case unexpectedSaveResult
}

public final class CoreDataCache<T: Identifiable, U: NSManagedObject> {
    public typealias Model = T

    public let databaseService: CoreDataServiceProtocol
    public let dataMapper: AnyCoreDataMapper<T, U>
    public let domain: String
    public let sortDescriptor: NSSortDescriptor?

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
                throw CoreDataCacheError.unexpectedSaveResult
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
