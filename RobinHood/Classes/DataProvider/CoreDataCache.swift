import Foundation
import CoreData

public final class CoreDataCache<T: Identifiable, U: NSManagedObject> {
    public typealias Model = T

    public let databaseService: CoreDataServiceProtocol
    public let dataMapper: AnyCoreDataMapper<T, U>
    public let domain: String

    public init(databaseService: CoreDataServiceProtocol, mapper: AnyCoreDataMapper<T, U>, domain: String = "default") {

        self.databaseService = databaseService
        self.dataMapper = mapper
        self.domain = domain
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

    public func fetch(by modelId: String,
                      runCompletionIn queue: DispatchQueue,
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

                        queue.async {
                            block(model, nil)
                        }
                    } else {
                        queue.async {
                            block(nil, nil)
                        }
                    }
                } catch {
                    queue.async {
                        block(nil, error)
                    }
                }
            } else {
                queue.async {
                    block(nil, optionalError)
                }
            }
        }
    }

    public func fetchAll(runCompletionIn queue: DispatchQueue,
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

                    let entities = try context.fetch(fetchRequest)
                    let models = try entities.map { try strongSelf.dataMapper.transform(entity: $0) }

                    queue.async {
                        block(models, nil)
                    }

                } catch {
                    queue.async {
                        block(nil, error)
                    }
                }
            } else {
                queue.async {
                    block(nil, optionalError)
                }
            }
        }
    }

    public func save(updating updatedModels: [Model], deleting deletedIds: [String],
                     runCompletionIn queue: DispatchQueue,
                     executing block: @escaping (Error?) -> Void) {

        databaseService.performAsync { (optionalContext, optionalError) in

            if let context = optionalContext {
                do {
                    try self.save(models: updatedModels, in: context)

                    try self.delete(modelIds: deletedIds, in: context)

                    try context.save()

                    queue.async {
                        block(nil)
                    }

                } catch {
                    context.rollback()

                    queue.async {
                        block(error)
                    }
                }
            } else {
                queue.async {
                    block(optionalError)
                }
            }
        }
    }

    public func deleteAll(runCompletionIn queue: DispatchQueue,
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

                    queue.async {
                        block(nil)
                    }

                } catch {
                    context.rollback()

                    queue.async {
                        block(error)
                    }
                }
            } else {
                queue.async {
                    block(optionalError)
                }
            }
        }
    }
}

public enum CoreDataCacheError: Error {
    case bothModelAndErrorNull
    case unexpectedSaveResult
}

extension CoreDataCache: DataProviderCacheProtocol {
    public func fetchOperation(by modelId: String) -> BaseOperation<Model?> {
        return ClosureOperation {
            var model: Model?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetch(by: modelId,
                       runCompletionIn: .main) { (optionalModel, optionalError) in
                        model = optionalModel
                        error = optionalError

                        semaphore.signal()
            }

            semaphore.wait()

            if let existingModel = model {
                return existingModel
            }

            if let existingError = error {
                throw existingError
            }

            return nil
        }
    }

    public func fetchAllOperation() -> BaseOperation<[Model]> {
        return ClosureOperation {
            var models: [Model]?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetchAll(runCompletionIn: .main) { (optionalModels, optionalError) in
                models = optionalModels
                error = optionalError

                semaphore.signal()
            }

            semaphore.wait()

            if let existingModels = models {
                return existingModels
            }

            if let existingError = error {
                throw existingError
            } else {
                throw CoreDataCacheError.bothModelAndErrorNull
            }
        }
    }

    public func saveOperation(_ updateModelsBlock: @escaping () throws -> [Model],
                              _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Bool> {
        return ClosureOperation {
            var error: Error?

            let updatedModels = try updateModelsBlock()
            let deletedIds = try deleteIdsBlock()

            if updatedModels.count == 0, deletedIds.count == 0 {
                return true
            }

            let semaphore = DispatchSemaphore(value: 0)

            self.save(updating: updatedModels,
                      deleting: deletedIds,
                      runCompletionIn: .main) { (optionalError) in
                        error = optionalError
                        semaphore.signal()
            }

            semaphore.wait()

            if let existingError = error {
                throw existingError
            } else {
                return true
            }
        }
    }

    public func deleteAllOperation() -> BaseOperation<Bool> {
        return ClosureOperation {
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.deleteAll(runCompletionIn: .main) { (optionalError) in
                            error = optionalError
                            semaphore.signal()
            }

            semaphore.wait()

            if let existingError = error {
                throw existingError
            } else {
                return true
            }
        }
    }
}
