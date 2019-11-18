/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import XCTest
import RobinHood
import CoreData

class CoreDataCompatibilityTests: XCTestCase {
    let defaultCoreDataService: CoreDataServiceProtocol = {
        let configuration = CoreDataServiceConfiguration.createDefaultConfigutation()
        return CoreDataService(configuration: configuration)
    }()

    override func setUp() {
        try! clear(databaseService: defaultCoreDataService)
    }

    override func tearDown() {
        try! clear(databaseService: defaultCoreDataService)
    }

    func testWhenCompatibleAndIgnored() {
        guard case .persistent = defaultCoreDataService.configuration.storageType else {
            return
        }

        // given
        initializePersistent(coreDataService: defaultCoreDataService)

        let databaseReopenExpectation = XCTestExpectation()

        // when

        defaultCoreDataService.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)

            databaseReopenExpectation.fulfill()
        }

        // then

        wait(for: [databaseReopenExpectation], timeout: Constants.expectationDuration)
    }

    func testWhenIncompatibleAndIgnored() {
        guard case .persistent = defaultCoreDataService.configuration.storageType else {
            return
        }

        // given

        initializePersistent(coreDataService: defaultCoreDataService)

        let incompatibleConfiguration = CoreDataServiceConfiguration.createDefaultConfigutation(with: Constants.incompatibleCoreDataModelName,
                                                                                                databaseName: Constants.defaultCoreDataModelName,
                                                                                                incompatibleModelStrategy: .ignore)
        let incompatibleDataService = CoreDataService(configuration: incompatibleConfiguration)

        let databaseReopenExpectation = XCTestExpectation()

        // when

        incompatibleDataService.performAsync { (context, error) in
            XCTAssertNil(context)
            XCTAssertNotNil(error)

            databaseReopenExpectation.fulfill()
        }

        // then

        wait(for: [databaseReopenExpectation], timeout: Constants.expectationDuration)
    }

    func testWhenIncompatibleAndRemove() {
        guard case .persistent = defaultCoreDataService.configuration.storageType else {
            return
        }

        // given

        initializePersistent(coreDataService: defaultCoreDataService)

        let incompatibleConfiguration = CoreDataServiceConfiguration.createDefaultConfigutation(with: Constants.incompatibleCoreDataModelName,
                                                                                                databaseName: Constants.defaultCoreDataModelName,
                                                                                                incompatibleModelStrategy: .removeStore)
        let incompatibleCoreDataService = CoreDataService(configuration: incompatibleConfiguration)

        let databaseReopenExpectation = XCTestExpectation()

        // when

        incompatibleCoreDataService.performAsync { (context, error) in
            XCTAssertNotNil(context)
            XCTAssertNil(error)

            databaseReopenExpectation.fulfill()
        }

        // then

        wait(for: [databaseReopenExpectation], timeout: Constants.expectationDuration)
    }

    // MARK: Private
    private func initializePersistent(coreDataService: CoreDataServiceProtocol) {
        // given

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
