import Foundation
import CoreData

public enum CoreDataServiceError: Error {
    case modelURLInvalid
    case databaseURLInvalid
    case modelInitializationFailed
    case unexpectedCloseDuringSetup
    case unexpectedDropWhenOpen
}

public class CoreDataService {
    public enum SetupState {
        case initial
        case inprogress
        case completed
    }

    public static let shared = CoreDataService()

    private init() {}

    public var configuration: CoreDataServiceConfigurationProtocol!

    public private(set) var context: NSManagedObjectContext!
    public private(set) var setupState = SetupState.initial
    public private(set) var pendingInvocations = [CoreDataContextInvocationBlock]()

    private func databaseURL(with fileManager: FileManager) -> URL? {
        guard let dabaseDirectory = configuration.databaseDirectory else {
            return nil
        }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: dabaseDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return dabaseDirectory.appendingPathComponent(configuration.databaseName)
        }

        do {
            try fileManager.createDirectory(at: dabaseDirectory, withIntermediateDirectories: true)
            return dabaseDirectory.appendingPathComponent(configuration.databaseName)
        } catch {
            return nil
        }
    }
}

extension CoreDataService {
    private func queueInvocation(block: @escaping CoreDataContextInvocationBlock) {
        pendingInvocations.append(block)
    }

    private func flushInvocations(with error: Error?) {
        let copiedInvocations = pendingInvocations
        pendingInvocations.removeAll()

        for block in copiedInvocations {
            if error == nil {
                invoke(block: block, in: context)
            } else {
                block(nil, error)
            }
        }
    }

    private func invoke(block: @escaping CoreDataContextInvocationBlock, in context: NSManagedObjectContext) {
        context.perform {
            block(context, nil)
        }
    }
}

extension CoreDataService {
    private func setup() {
        self.setupState = .inprogress

        setup { (error) in
            if error == nil {
                self.setupState = .completed
            } else {
                self.setupState = .initial
            }

            self.flushInvocations(with: error)
        }
    }

    private func setup(withCompletion block: @escaping (Error?) -> Void) {
        guard let modelURL = configuration.modelURL else {
            block(CoreDataServiceError.modelURLInvalid)
            return
        }

        guard let databaseURL = databaseURL(with: FileManager.default) else {
            block(CoreDataServiceError.databaseURLInvalid)
            return
        }

        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            block(CoreDataServiceError.modelInitializationFailed)
            return
        }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        let queue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
        queue.async {
            do {
                try coordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: databaseURL,
                    options: nil
                )

                DispatchQueue.main.async {
                    block(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    block(error)
                }
            }
        }

    }
}

extension CoreDataService: CoreDataServiceProtocol {
    public func performAsync(block: @escaping CoreDataContextInvocationBlock) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                self._performAsync(block: block)
            }
        } else {
            self._performAsync(block: block)
        }
    }

    private func _performAsync(block: @escaping CoreDataContextInvocationBlock) {
        switch self.setupState {
        case .completed:
            self.invoke(block: block, in: self.context)
        case .initial:
            self.queueInvocation(block: block)
            self.setup()
        case .inprogress:
            self.queueInvocation(block: block)
        }
    }

    public func close() throws {
        if !Thread.isMainThread {
            try DispatchQueue.main.sync {
                try self._close()
            }
        } else {
            try self._close()
        }
    }

    private func _close() throws {
        if case .inprogress = setupState {
            throw CoreDataServiceError.unexpectedCloseDuringSetup
        }

        context?.performAndWait {
            guard let coordinator = self.context?.persistentStoreCoordinator else {
                return
            }

            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }

            self.context = nil
            self.setupState = .initial
        }
    }

    public func drop() throws {
        if !Thread.isMainThread {
            try DispatchQueue.main.sync {
                try self._drop()
            }
        } else {
            try self._drop()
        }
    }

    private func _drop() throws {
        guard case .initial = setupState else {
            throw CoreDataServiceError.unexpectedDropWhenOpen
        }

        guard let databaseDirectory = configuration.databaseDirectory else {
            throw CoreDataServiceError.databaseURLInvalid
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: databaseDirectory.path,
                                          isDirectory: &isDirectory), isDirectory.boolValue {
            try FileManager.default.removeItem(at: databaseDirectory)
        }
    }
}
