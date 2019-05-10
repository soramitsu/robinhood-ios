import Foundation
import CoreData

final public class CoreDataContextObservable<T: Identifiable, U: NSManagedObject> {
    private(set) var service: CoreDataServiceProtocol
    private(set) var mapper: AnyCoreDataMapper<T, U>
    private(set) var processingQueue: DispatchQueue
    private(set) var predicate: (U) -> Bool

    private var observers: [StreamableSourceObserver<T>] = []

    init(service: CoreDataServiceProtocol,
         mapper: AnyCoreDataMapper<T, U>,
         predicate: @escaping (U) -> Bool,
         processingQueue: DispatchQueue?) {
        self.service = service
        self.mapper = mapper
        self.predicate = predicate

        if let processingQueue = processingQueue {
            self.processingQueue = processingQueue
        } else {
            self.processingQueue = DispatchQueue(
                label: "co.jp.streamableobservable.queue.\(UUID().uuidString)",
                qos: .utility)
        }
    }

    public func start() {
        service.performAsync { (optionalContext, optionalError) in
            if let context = optionalContext {
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(self.didReceive(notification:)),
                                                       name: Notification.Name.NSManagedObjectContextDidSave,
                                                       object: context)
            }
        }
    }

    public func stop() {
        service.performAsync { (optionalContext, optionalError) in
            if let context = optionalContext {
                NotificationCenter.default.removeObserver(self,
                                                          name: Notification.Name.NSManagedObjectContextDidSave,
                                                          object: context)
            }
        }
    }

    @objc private func didReceive(notification: Notification) {
        var changes: [DataProviderChange<T>] = []

        if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? [U] {
            let matchingChanges: [DataProviderChange<T>] = updatedObjects
                .filter(predicate)
                .compactMap({ try? mapper.transform(entity: $0) })
                .map({ DataProviderChange.update(newItem: $0) })

            changes.append(contentsOf: matchingChanges)
        }

        if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? [U] {
            let matchingChanges: [DataProviderChange<T>] = deletedObjects
                .filter(predicate)
                .compactMap({ try? mapper.transform(entity: $0) })
                .map({ DataProviderChange.delete(deletedIdentifier: $0.identifier) })

            changes.append(contentsOf: matchingChanges)
        }

        if let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? [U] {
            let matchingChanges: [DataProviderChange<T>] = insertedObjects
                .filter(predicate)
                .compactMap({ try? mapper.transform(entity: $0) })
                .map({ DataProviderChange.insert(newItem: $0) })

            changes.append(contentsOf: matchingChanges)
        }

        guard changes.count > 0 else {
            return
        }

        processingQueue.async {
            self.observers.forEach { (observerWrapper) in
                if observerWrapper.observer != nil {
                    observerWrapper.queue.async {
                        observerWrapper.updateBlock(changes)
                    }
                }
            }
        }
    }
}

extension CoreDataContextObservable: StreamableSourceObservable {
    public typealias Model = T

    public func addObserver(_ observer: AnyObject,
                            deliverOn queue: DispatchQueue,
                            executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void) {
        processingQueue.async {
            self.observers = self.observers.filter { $0.observer != nil }

            if !self.observers.contains(where: { $0.observer === observer }) {
                let newObserver = StreamableSourceObserver(observer: observer, queue: queue, updateBlock: updateBlock)
                self.observers.append(newObserver)
            }
        }
    }

    public func removeObserver(_ observer: AnyObject) {
        processingQueue.async {
            self.observers = self.observers.filter { $0.observer != nil && $0.observer !== observer }
        }
    }
}
