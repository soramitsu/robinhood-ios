/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

import XCTest
@testable import RobinHood

class NestedEntitiesTests: XCTestCase {

    let operationQueue = OperationQueue()

    override func setUp() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    override func tearDown() {
        try! CoreDataRepositoryFacade.shared.clearDatabase()
    }

    func testInsertNestedItems() {
        // given

        let chatsCount: Int = 2
        let chats = (0..<chatsCount).map { _ in createRandomChat() }

        let messagesCount: Int = 10
        let messages: [MessageData] = (0..<messagesCount).map { messageIndex in
            let chat = chats[messageIndex % chatsCount]

            return createRandomMessage(for: chat)
        }

        // when

        let repository: CoreDataRepository<MessageData, CDMessage> =
            CoreDataRepositoryFacade.shared.createCoreDataRepository()

        save(messages: messages, to: repository)

        // then

        let fetchedMessages = fetchAllMessages(from: repository)

        for fetchedMessage in fetchedMessages {
            XCTAssert(messages.contains(fetchedMessage))
        }

        XCTAssertEqual(fetchedMessages.count, messages.count)
    }

    func testUpdateNestedItem() {
        // given

        let oldChat = createRandomChat()
        var message = createRandomMessage(for: oldChat)

        let repository: CoreDataRepository<MessageData, CDMessage> =
        CoreDataRepositoryFacade.shared.createCoreDataRepository()

        save(messages: [message], to: repository)

        // when

        let newChat = createRandomChat()
        message.chat = newChat

        save(messages: [message], to: repository)

        // then

        let allMessages = fetchAllMessages(from: repository)

        XCTAssertEqual(allMessages.count, 1)
        XCTAssertEqual(allMessages.first, message)
    }

    // MARK: Private

    func save(messages: [MessageData], to repository: CoreDataRepository<MessageData, CDMessage>) {
        let saveOperation = repository.saveOperation({ messages }, { [] })

        let saveExpectation = XCTestExpectation()

        saveOperation.completionBlock = {
            saveExpectation.fulfill()
        }

        operationQueue.addOperation(saveOperation)

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)
    }

    func fetchAllMessages(from repository: CoreDataRepository<MessageData, CDMessage>) -> [MessageData] {
        let fetchOperation = repository.fetchAllOperation()

        let fetchExpectation = XCTestExpectation()

        fetchOperation.completionBlock = {
            fetchExpectation.fulfill()
        }

        operationQueue.addOperation(fetchOperation)

        wait(for: [fetchExpectation], timeout: Constants.expectationDuration)

        guard let fetchResult = fetchOperation.result else {
            XCTFail("Unexpected empty result")
            return []
        }

        guard case .success(let fetchedMessages) = fetchResult else {
            XCTFail("Unexpected fetch error")
            return []
        }

        return fetchedMessages
    }
}
