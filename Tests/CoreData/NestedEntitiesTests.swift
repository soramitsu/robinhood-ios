import XCTest
@testable import RobinHood

class NestedEntitiesTests: XCTestCase {

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

        let repository: CoreDataRepository<MessageData, CDMessage> =
            CoreDataRepositoryFacade.shared.createCoreDataRepository()
        let operationQueue = OperationQueue()

        let saveOperation = repository.saveOperation({ messages }, { [] })

        let saveExpectation = XCTestExpectation()

        saveOperation.completionBlock = {
            saveExpectation.fulfill()
        }

        operationQueue.addOperation(saveOperation)

        wait(for: [saveExpectation], timeout: Constants.expectationDuration)

        // when

        let fetchOperation = repository.fetchAllOperation()

        let fetchExpectation = XCTestExpectation()

        fetchOperation.completionBlock = {
            fetchExpectation.fulfill()
        }

        operationQueue.addOperation(fetchOperation)

        wait(for: [fetchExpectation], timeout: Constants.expectationDuration)

        // then

        guard let fetchResult = fetchOperation.result else {
            XCTFail("Unexpected empty result")
            return
        }

        guard case .success(let fetchedMessages) = fetchResult else {
            XCTFail("Unexpected fetch error")
            return
        }

        for fetchedMessage in fetchedMessages {
            XCTAssert(messages.contains(fetchedMessage))
        }

        XCTAssertEqual(fetchedMessages.count, messages.count)
    }
}
