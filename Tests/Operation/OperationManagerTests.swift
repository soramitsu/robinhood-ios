/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

import XCTest
@testable import RobinHood

class OperationManagerTests: XCTestCase {
    static let second: TimeInterval = 1e+6

    final class CheckPointResult<T: Equatable> {
        private(set) var operationIds: [T] = []

        private let lock: NSLock = NSLock()

        func checkpoint(operationId: T) {
            lock.lock()

            operationIds.append(operationId)

            lock.unlock()
        }
    }

    func testOperationsByIdentifier() {
        // given

        let firstIdentifier = UUID().uuidString
        let secondIdentifier = UUID().uuidString

        let result = CheckPointResult<UInt>()

        let operations: [Operation] = [
            ClosureOperation { result.checkpoint(operationId: 0) },
            ClosureOperation {
                usleep(UInt32(0.1 * Self.second))
                result.checkpoint(operationId: 1)
            },
            ClosureOperation {
                result.checkpoint(operationId: 2)
            }
        ]

        // when

        simulate(operations: operations) { manager in
            manager.enqueue(operations: [operations[1]], in: .byIdentifier(firstIdentifier))
            manager.enqueue(operations: [operations[0]], in: .byIdentifier(firstIdentifier))
            manager.enqueue(operations: [operations[2]], in: .byIdentifier(secondIdentifier))
        }

        // then

        XCTAssertEqual([2, 1, 0], result.operationIds)
    }

    func testOperationWaitsBefore() {
        // given

        let result = CheckPointResult<UInt>()

        let operations: [Operation] = [
            ClosureOperation {
                usleep(UInt32(0.1 * Self.second))
                result.checkpoint(operationId: 0)
            },
            ClosureOperation {
                result.checkpoint(operationId: 1)
            }
        ]

        // when

        simulate(operations: operations) { manager in
            manager.enqueue(operations: [operations[0]], in: .byIdentifier(UUID().uuidString))
            manager.enqueue(operations: [operations[1]], in: .waitBefore)
        }

        // then

        XCTAssertEqual([0, 1], result.operationIds)
    }

    func testOperationBlockAfter() {
        // given

        let result = CheckPointResult<UInt>()

        let operations: [Operation] = [
            ClosureOperation {
                usleep(UInt32(0.1 * Self.second))
                result.checkpoint(operationId: 0)
            },
            ClosureOperation {
                result.checkpoint(operationId: 1)
            }
        ]

        // when

        simulate(operations: operations) { manager in
            manager.enqueue(operations: [operations[0]], in: .blockAfter)
            manager.enqueue(operations: [operations[1]], in: .transient)
        }

        // then

        XCTAssertEqual([0, 1], result.operationIds)
    }

    func testSyncOperation() {
        // given

        let result = CheckPointResult<UInt>()

        let operations: [Operation] = [
            ClosureOperation {
                usleep(UInt32(0.25 * Self.second))
                result.checkpoint(operationId: 0)
            },
            ClosureOperation {
                usleep(UInt32(0.1 * Self.second))
                result.checkpoint(operationId: 1)
            },
            ClosureOperation {
                result.checkpoint(operationId: 2)
            }
        ]

        // when

        simulate(operations: operations) { manager in
            manager.enqueue(operations: [operations[0]], in: .byIdentifier(UUID().uuidString))
            manager.enqueue(operations: [operations[1]], in: .sync)
            manager.enqueue(operations: [operations[2]], in: .byIdentifier(UUID().uuidString))
        }

        // then

        XCTAssertEqual([0, 1, 2], result.operationIds)
    }

    func testSubmitOperationsFromDifferentQueues() {
        // given

        let operationsCount = 100

        let expectations = (0..<operationsCount).map { _ in XCTestExpectation() }

        let operations: [Operation] = (0..<operationsCount).map { index in
            let operation = ClosureOperation { usleep(UInt32(0.1 * Self.second)) }

            operation.completionBlock = {
                expectations[index].fulfill()
            }

            return operation
        }

        let queues: [DispatchQueue] = (0..<operationsCount).map { _ in
            DispatchQueue(label: UUID().uuidString,
                          qos: .default,
                          attributes: .concurrent,
                          autoreleaseFrequency: .inherit,
                          target: nil)
        }

        let operationManager = OperationManager()

        // when

        (0..<operationsCount / 2).forEach { index in
            queues[index].async {
                operationManager.enqueue(operations: [operations[index]],
                                         in: .byIdentifier(UUID().uuidString))
            }
        }

        usleep(UInt32(0.15 * Self.second))

        (operationsCount/2..<operationsCount).forEach { index in
            queues[index].async {
                operationManager.enqueue(operations: [operations[index]],
                                         in: .byIdentifier(UUID().uuidString))
            }
        }

        // then

        wait(for: expectations, timeout: 5.0 * TimeInterval(operationsCount))
    }

    // MARK: Private

    private func simulate(operations: [Operation], timeout: TimeInterval = 10.0, enqueueClosure: (OperationManager) -> Void) {
        var completedOperations: [Operation] = []

        let expectations = (0..<operations.count).map { _ in XCTestExpectation() }

        let lock = NSLock()

        for (index, operation) in operations.enumerated() {
            operation.completionBlock = {
                lock.lock()

                defer {
                    lock.unlock()
                }

                completedOperations.append(operation)

                expectations[index].fulfill()
            }
        }

        let manager = OperationManager()

        enqueueClosure(manager)

        wait(for: expectations, timeout: timeout)
    }
}
