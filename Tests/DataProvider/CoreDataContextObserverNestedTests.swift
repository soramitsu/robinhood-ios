/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

import XCTest
@testable import RobinHood

class CoreDataContextObserverNestedTests: XCTestCase {
    func testNotificationDeliveredWhenSeveralItemsUpdated() {
        // given

        let repository: CoreDataRepository<MessageData, CDMessage> = CoreDataRepositoryFacade.shared.createCoreDataRepository()

        let observable: CoreDataContextObservable<MessageData, CDMessage> =
            CoreDataContextObservable(service: CoreDataRepositoryFacade.shared.databaseService,
                                      mapper: repository.dataMapper,
                                      predicate: { _ in
            return true
        })

        // when

        var savedMessages: [MessageData] = []

        let completionExpectation = XCTestExpectation()

        observable.addObserver(self, deliverOn: .main) { changes in
            for change in changes {
                switch change {
                case .insert(let newItem):
                    savedMessages.append(newItem)
                default:
                    break
                }
            }

            completionExpectation.fulfill()
        }

        observable.start { error in
            XCTAssertNil(error)
        }

        let chat = createRandomChat()
        let messages = (0..<10).map { _ in createRandomMessage(for: chat) }

        repository.save(updating: messages, deleting: [], runCompletionIn: nil) { error in
            XCTAssertNil(error)
        }

        // then

        wait(for: [completionExpectation], timeout: Constants.expectationDuration)

        XCTAssertEqual(savedMessages.count, messages.count)

        for message in messages {
            XCTAssertTrue(savedMessages.contains(message))
        }
    }
}
