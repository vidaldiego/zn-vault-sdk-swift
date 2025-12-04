// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/Secret.swift

import Foundation

/// Types of secrets supported by ZN-Vault.
public enum SecretType: String, Codable, Sendable {
    case opaque
    case credential
    case setting
}

/// Represents a secret stored in ZN-Vault.
public struct Secret: Codable, Sendable, Identifiable {
    public let id: String
    public let alias: String
    public let tenant: String
    public let type: SecretType
    public let version: Int
    public let tags: [String]?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let ttlUntil: Date?
    public let contentType: String?
    public let createdBy: String?
    public let checksum: String?

    enum CodingKeys: String, CodingKey {
        case id, alias, tenant, type, version, tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case ttlUntil = "ttl_until"
        case contentType = "content_type"
        case createdBy = "created_by"
        case checksum
    }
}

/// Decrypted secret data.
public struct SecretData: Codable, Sendable {
    public let data: [String: AnyCodable]
    public let decryptedAt: Date

    enum CodingKeys: String, CodingKey {
        case data
        case decryptedAt = "decrypted_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode([String: AnyCodable].self, forKey: .data)
        decryptedAt = try container.decodeIfPresent(Date.self, forKey: .decryptedAt) ?? Date()
    }
}

/// Request to create a new secret.
public struct CreateSecretRequest: Codable, Sendable {
    public let alias: String
    public let type: SecretType
    public let data: [String: AnyCodable]
    public let tags: [String]?
    public let ttlUntil: Date?

    enum CodingKeys: String, CodingKey {
        case alias, type, data, tags
        case ttlUntil = "ttl_until"
    }

    public init(
        alias: String,
        type: SecretType,
        data: [String: AnyCodable],
        tags: [String]? = nil,
        ttlUntil: Date? = nil
    ) {
        self.alias = alias
        self.type = type
        self.data = data
        self.tags = tags
        self.ttlUntil = ttlUntil
    }
}

/// Request to update an existing secret.
public struct UpdateSecretRequest: Codable, Sendable {
    public let data: [String: AnyCodable]
    public let tags: [String]?

    public init(data: [String: AnyCodable], tags: [String]? = nil) {
        self.data = data
        self.tags = tags
    }
}

/// Request to update secret metadata (tags only).
public struct UpdateSecretMetadataRequest: Codable, Sendable {
    public let tags: [String]

    public init(tags: [String]) {
        self.tags = tags
    }
}

/// Filter for listing secrets.
public struct SecretFilter: Sendable {
    public let type: SecretType?
    public let tags: [String]?
    public let limit: Int
    public let offset: Int
    public let marker: String?

    public init(
        type: SecretType? = nil,
        tags: [String]? = nil,
        limit: Int = 50,
        offset: Int = 0,
        marker: String? = nil
    ) {
        self.type = type
        self.tags = tags
        self.limit = limit
        self.offset = offset
        self.marker = marker
    }
}

/// Historical version of a secret.
public struct SecretVersion: Codable, Sendable, Identifiable {
    public let id: Int
    public let tenant: String?
    public let alias: String?
    public let type: String?
    public let version: Int
    public let tags: [String]?
    public let createdAt: Date?
    public let createdBy: String?
    public let checksum: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tenant
        case alias
        case type
        case version
        case tags
        case createdAt = "created_at"
        case createdBy = "created_by"
        case checksum
    }
}

/// Response from secret history endpoint.
public struct SecretHistoryResponse: Codable, Sendable {
    public let history: [SecretVersion]
    public let count: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        history = try container.decodeIfPresent([SecretVersion].self, forKey: .history) ?? []
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

/// File metadata for opaque secrets containing files.
public struct FileMetadata: Codable, Sendable {
    public let filename: String
    public let contentType: String
    public let checksum: String?
    public let size: Int64?
    public let certificateExpiry: Date?

    enum CodingKeys: String, CodingKey {
        case filename
        case contentType = "content_type"
        case checksum, size
        case certificateExpiry = "certificate_expiry"
    }
}
