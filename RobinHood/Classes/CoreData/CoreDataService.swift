import Foundation
import CoreData

public enum CoreDataServiceError: Error {
    case databaseURLInvalid
    case modelInitializationFailed
    case unexpectedCloseDuringSetup
    case unexpectedDropWhenOpen
    case incompatibleModelRemoveFailed
}

public class CoreDataService {
    public enum SetupState {
        case initial
        case inprogress
        case completed
    }

    public let configuration: CoreDataServiceConfigurationProtocol

    public init(configuration: CoreDataServiceConfigurationProtocol) {
        self.configuration = configuration
    }

    var context: NSManagedObjectContext!
    var setupState: SetupState = .initial
    var pendingInvocations = [CoreDataContextInvocationBlock]()

    func databaseURL(with fileManager: FileManager) -> URL? {
        guard case .persistent(let settings) = configuration.storageType else {
            return nil
        }

        var dabaseDirectory = settings.databaseDirectory

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: dabaseDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return dabaseDirectory.appendingPathComponent(settings.databaseName)
        }

        do {
            try fileManager.createDirectory(at: dabaseDirectory, withIntermediateDirectories: true)

            var resources = URLResourceValues()
            resources.isExcludedFromBackup = settings.excludeFromiCloudBackup
            try dabaseDirectory.setResourceValues(resources)

            return dabaseDirectory.appendingPathComponent(settings.databaseName)
        } catch {
            return nil
        }
    }
}

// MARK: Internal Invocations logic
extension CoreDataService {
    func queueInvocation(block: @escaping CoreDataContextInvocationBlock) {
        pendingInvocations.append(block)
    }

    func flushInvocations(with error: Error?) {
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

    func invoke(block: @escaping CoreDataContextInvocationBlock, in context: NSManagedObjectContext) {
        context.perform {
            block(context, nil)
        }
    }
}

// MARK: Internal Setup Logic
extension CoreDataService {
    func setup() {
        setupState = .inprogress

        setup { (error) in
            if error == nil {
                self.setupState = .completed
            } else {
                self.setupState = .initial
            }

            self.flushInvocations(with: error)
        }
    }

    func setup(withCompletion block: @escaping (Error?) -> Void) {
        let fileManager = FileManager.default
        let optionalDatabaseURL = self.databaseURL(with: fileManager)
        let storageType: String

        guard let model = NSManagedObjectModel(contentsOf: configuration.modelURL) else {
            block(CoreDataServiceError.modelInitializationFailed)
            return
        }

        switch configuration.storageType {
        case .persistent(let settings):
            guard let databaseURL = optionalDatabaseURL  else {
                block(CoreDataServiceError.databaseURLInvalid)
                return
            }

            if settings.incompatibleModelStrategy != .ignore &&
                !checkCompatibility(of: model, with: databaseURL, using: fileManager) {

                do {
                    try fileManager.removeItem(at: databaseURL)
                } catch {
                    block(CoreDataServiceError.incompatibleModelRemoveFailed)
                    return
                }
            }

            storageType = NSSQLiteStoreType
        case .inMemory:
            storageType = NSInMemoryStoreType
        }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        let queue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
        queue.async {
            do {
                try coordinator.addPersistentStore(
                    ofType: storageType,
                    configurationName: nil,
                    at: optionalDatabaseURL,
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

// MARK: Model Compatability
extension CoreDataService {
    func checkCompatibility(of model: NSManagedObjectModel,
                            with databaseURL: URL,
                            using fileManager: FileManager) -> Bool {
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            return true
        }

        do {
            let storeMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType,
                                                                                            at: databaseURL,
                                                                                            options: nil)
            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: storeMetadata)
        } catch {
            return false
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

        guard case .persistent(let settings) = configuration.storageType else {
            return
        }

        try removeDatabaseFile(using: FileManager.default, settings: settings)
    }

    private func removeDatabaseFile(using fileManager: FileManager, settings: CoreDataPersistentSettings) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: settings.databaseDirectory.path,
                                  isDirectory: &isDirectory), isDirectory.boolValue {
            try fileManager.removeItem(at: settings.databaseDirectory)
        }
    }
}
