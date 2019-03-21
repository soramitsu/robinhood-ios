import XCTest
import RobinHood
import CoreData

class CoreDataCompatibilityTests: XCTestCase {

    override func setUp() {
        CoreDataService.shared.configuration = CoreDataServiceConfiguration.createDefaultConfigutation()
        try! clearDatabase(using: CoreDataService.shared)
    }

    override func tearDown() {
        CoreDataService.shared.configuration = CoreDataServiceConfiguration.createDefaultConfigutation()
        try! clearDatabase(using: CoreDataService.shared)
    }

    func testWhenCompatibleAndIgnored() {
        // given
        initializePersistentDatabase()

        let coreDataService = CoreDataService.shared

        let databaseReopenExpectation = XCTestExpectation()

        // when

        coreDataService.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)

            databaseReopenExpectation.fulfill()
        }

        // then

        wait(for: [databaseReopenExpectation], timeout: Constants.expectationDuration)
    }

    func testWhenIncompatibleAndIgnored() {
        // given

        initializePersistentDatabase()

        let coreDataService = CoreDataService.shared
        coreDataService.configuration = CoreDataServiceConfiguration.createDefaultConfigutation(with: Constants.incompatibleCoreDataModelName,
                                                                                                databaseName: Constants.defaultCoreDataModelName,
                                                                                                incompatibleModelStrategy: .ignore)

        let databaseReopenExpectation = XCTestExpectation()

        // when

        coreDataService.performAsync { (context, error) in
            XCTAssertNil(context)
            XCTAssertNotNil(error)

            databaseReopenExpectation.fulfill()
        }

        // then

        wait(for: [databaseReopenExpectation], timeout: Constants.expectationDuration)
    }

    func testWhenIncompatibleAndRemove() {
        // given

        initializePersistentDatabase()

        let coreDataService = CoreDataService.shared
        coreDataService.configuration = CoreDataServiceConfiguration.createDefaultConfigutation(with: Constants.incompatibleCoreDataModelName,
                                                                                                databaseName: Constants.defaultCoreDataModelName,
                                                                                                incompatibleModelStrategy: .removeStore)

        let databaseReopenExpectation = XCTestExpectation()

        // when

        coreDataService.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)

            databaseReopenExpectation.fulfill()
        }

        // then

        wait(for: [databaseReopenExpectation], timeout: Constants.expectationDuration)
    }

    // MARK: Private
    private func initializePersistentDatabase() {
        // given
        let coreDataService = CoreDataService.shared

        let compatibleConfiguration = CoreDataServiceConfiguration.createDefaultConfigutation()
        coreDataService.configuration = compatibleConfiguration

        let databaseCreationExpectation = XCTestExpectation()

        // when

        coreDataService.performAsync { (context, error) in
            XCTAssertNil(error)

            guard let context = context else {
                XCTFail()
                return
            }

            do {
                let entityName = String(describing: CDSingleValue.self)
                let optionalEntity = NSEntityDescription.insertNewObject(forEntityName: entityName,
                                                                         into: context) as? CDSingleValue
                XCTAssertNotNil(optionalEntity)

                optionalEntity?.domain = Constants.cacheDomain
                optionalEntity?.identifier = UUID().uuidString
                optionalEntity?.payload = Data()

                try context.save()
            } catch {
                XCTFail(error.localizedDescription)
            }

            databaseCreationExpectation.fulfill()
        }

        // then

        wait(for: [databaseCreationExpectation], timeout: Constants.expectationDuration)
        XCTAssertNoThrow(try coreDataService.close())
    }
}
