/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import CoreData

/**
 *  Protocol is designed to provide an interface for mapping swift identifiable model
 *  to Core Data NSManageObjectContext and back. It is expected that NSManagedObject
 *  contains at least two fields: one to store identifier and another for domain.
 */

public protocol CoreDataMapperProtocol: class {
    associatedtype DataProviderModel: Identifiable
    associatedtype CoreDataEntity: NSManagedObject

    /**
     *  Transforms Core Data entity to swift model.
     *
     *  - parameters:
     *    - entity: Subclass of NSManagedObject to convert to swift model.
     *  - returns: Identifiable swift model.
     */

    func transform(entity: CoreDataEntity) throws -> DataProviderModel

    /**
     *  Converts swift model to NSManagedObject.
     *
     *  - note: Because NSManagedObject can be created manually the method expects to
     *  receive a reference to it as a parameter.
     *
     *  - parameters:
     *    - entity: Subclass of NSManagedObject to populate from swift model.
     *    - model: Swift model to populate NSManagedObject from.
     */

    func populate(entity: CoreDataEntity, from model: DataProviderModel) throws

    /// Name of idetifier field to access NSManagedObject by.
    var entityIdentifierFieldName: String { get }

    /// Name of domain field to access NSManagedObject by.
    var entityDomainFieldName: String { get }
}

/**
 *  Class is designed to apply type erasure technique to ```CoreDataMapperProtocol```.
 */

public final class AnyCoreDataMapper<T: Identifiable, U: NSManagedObject>: CoreDataMapperProtocol {
    public typealias DataProviderModel = T
    public typealias CoreDataEntity = U

    private let _transform: (CoreDataEntity) throws -> DataProviderModel
    private let _populate: (CoreDataEntity, DataProviderModel) throws -> Void
    private let _entityIdentifierFieldName: String
    private let _entityDomainFieldName: String

    /**
     *  Initializes type erasure wrapper for mapper implementation.
     *
     *  - parameters:
     *    - mapper: Core Data mapper implementation to erase type of.
     */

    public init<M: CoreDataMapperProtocol>(_ mapper: M) where M.DataProviderModel == T, M.CoreDataEntity == U {
        _transform = mapper.transform
        _populate = mapper.populate
        _entityIdentifierFieldName = mapper.entityIdentifierFieldName
        _entityDomainFieldName = mapper.entityDomainFieldName
    }

    public func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        return try _transform(entity)
    }

    public func populate(entity: CoreDataEntity, from model: DataProviderModel) throws {
        try _populate(entity, model)
    }

    public var entityIdentifierFieldName: String {
        return _entityIdentifierFieldName
    }

    public var entityDomainFieldName: String {
        return _entityDomainFieldName
    }
}

/**
 *  Protocol is designed to serialize/deserialize subclass of NSManagedObject.
 */

public protocol CoreDataCodable: Encodable {
    /**
     *  Populates subclass of NSManagedObject from decoder.
     *
     *  Due to the fact that NSManagedObject can't be created manually from
     *  raw data it is assumed that the object is already allocated and only
     *  needs to be populated with field values.
     *
     *  - parameters:
     *    - decoder: Object to extract decoded data from.
     */

    func populate(from decoder: Decoder) throws
}

private class CoreDataDecodingContainer: Decodable {
    var decoder: Decoder

    required init(from decoder: Decoder) throws {
        self.decoder = decoder
    }

    func populate(entity: CoreDataCodable) throws {
        try entity.populate(from: decoder)
    }
}

/**
 *  Class is designed to provide implementation of ```CoreDataMapperProtocol```.
 *  Implementation assumes that swift model conforms to ```Codable``` protocol.
 */

public final class CodableCoreDataMapper<T: Identifiable & Codable,
U: NSManagedObject & CoreDataCodable>: CoreDataMapperProtocol {
    public typealias DataProviderModel = T
    public typealias CoreDataEntity = U

    public var entityIdentifierFieldName: String
    public var entityDomainFieldName: String

    /**
     *  Creates Core Data mapper object.
     *
     *  - parameters:
     *    - entityIdentifierFieldName: Field name to extract identifier by. By default ```identifier```.
     *    - entityDomainFieldName: Field name to extract domain by. By default ```domain```.
     */

    public init(entityIdentifierFieldName: String = "identifier", entityDomainFieldName: String = "domain") {
        self.entityIdentifierFieldName = entityIdentifierFieldName
        self.entityDomainFieldName = entityDomainFieldName
    }

    public func transform(entity: U) throws -> T {
        let data = try JSONEncoder().encode(entity)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func populate(entity: U, from model: T) throws {
        let data = try JSONEncoder().encode(model)
        let container = try JSONDecoder().decode(CoreDataDecodingContainer.self,
                                                 from: data)
        try container.populate(entity: entity)
    }
}
