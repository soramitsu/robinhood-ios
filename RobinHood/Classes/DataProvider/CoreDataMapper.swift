import Foundation
import CoreData

public enum CoreDataMapperError: Error {
    case missingField(name: String)
    case invalidField(name: String)
}

public protocol CoreDataMapperProtocol: class {
    associatedtype DataProviderModel: Identifiable
    associatedtype CoreDataEntity: NSManagedObject

    func transform(entity: CoreDataEntity) throws -> DataProviderModel
    func populate(entity: CoreDataEntity, from model: DataProviderModel) throws

    var entityIdentifierFieldName: String { get }
    var entityDomainFieldName: String { get }
}

public final class AnyCoreDataMapper<T: Identifiable, U: NSManagedObject>: CoreDataMapperProtocol {
    public typealias DataProviderModel = T
    public typealias CoreDataEntity = U

    private let _transform: (CoreDataEntity) throws -> DataProviderModel
    private let _populate: (CoreDataEntity, DataProviderModel) throws -> Void
    private let _entityIdentifierFieldName: String
    private let _entityDomainFieldName: String

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

public protocol CoreDataCodable: Encodable {
    func populate(from decoder: Decoder) throws
}

public enum CoreDataDecodingContainerError: Error {
    case decoderMissing
}

private class CoreDataDecodingContainer: Decodable {
    var decoder: Decoder?

    required public init(from decoder: Decoder) throws {
        self.decoder = decoder
    }

    func populate(entity: CoreDataCodable) throws {
        guard let decoder = decoder else {
            throw CoreDataDecodingContainerError.decoderMissing
        }

        try entity.populate(from: decoder)
    }
}

public final class CodableCoreDataMapper<T: Identifiable & Codable,
U: NSManagedObject & CoreDataCodable>: CoreDataMapperProtocol {
    public typealias DataProviderModel = T
    public typealias CoreDataEntity = U

    public var entityIdentifierFieldName: String
    public var entityDomainFieldName: String

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
