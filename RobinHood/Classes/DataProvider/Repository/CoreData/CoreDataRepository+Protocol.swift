/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

extension CoreDataRepository: DataProviderRepositoryProtocol {
    public func fetchOperation(by modelId: String) -> BaseOperation<Model?> {
        ClosureOperation {
            var model: Model?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetch(by: modelId,
                       runCompletionIn: nil) { (optionalModel, optionalError) in
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
        ClosureOperation {
            var models: [Model]?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetchAll(runCompletionIn: nil) { (optionalModels, optionalError) in
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
                throw CoreDataRepositoryError.undefined
            }
        }
    }

    public func fetchOperation(by offset: Int, count: Int, reversed: Bool) -> BaseOperation<[Model]> {
        ClosureOperation {
            var models: [Model]?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetch(offset: offset, count: count,
                       reversed: reversed, runCompletionIn: nil) { (optionalModels, optionalError) in
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
                throw CoreDataRepositoryError.undefined
            }
        }
    }

    public func saveOperation(_ updateModelsBlock: @escaping () throws -> [Model],
                              _ deleteIdsBlock: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {
            var error: Error?

            let updatedModels = try updateModelsBlock()
            let deletedIds = try deleteIdsBlock()

            if updatedModels.count == 0, deletedIds.count == 0 {
                return
            }

            let semaphore = DispatchSemaphore(value: 0)

            self.save(updating: updatedModels,
                      deleting: deletedIds,
                      runCompletionIn: nil) { (optionalError) in
                        error = optionalError
                        semaphore.signal()
            }

            semaphore.wait()

            if let existingError = error {
                throw existingError
            }
        }
    }

    public func replaceOperation(_ newModelsBlock: @escaping () throws -> [Model])
        -> BaseOperation<Void> {
        ClosureOperation {
            var error: Error?

            let models = try newModelsBlock()

            let semaphore = DispatchSemaphore(value: 0)

            self.replace(with: models, runCompletionIn: nil) { optionalError in
                error = optionalError

                semaphore.signal()
            }

            semaphore.wait()

            if let existingError = error {
                throw existingError
            }
        }
    }

    public func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation {
            var count: Int?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetchCount(runCompletionIn: nil) { (optionalCount, optionalError) in
                count = optionalCount
                error = optionalError

                semaphore.signal()
            }

            semaphore.wait()

            if let count = count {
                return count
            }

            if let existingError = error {
                throw existingError
            } else {
                throw CoreDataRepositoryError.undefined
            }
        }
    }

    public func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation {
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)

            self.deleteAll(runCompletionIn: nil) { (optionalError) in
                error = optionalError
                semaphore.signal()
            }

            semaphore.wait()

            if let existingError = error {
                throw existingError
            }
        }
    }
}
