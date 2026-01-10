// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/Secret.swift

import Foundation

/// Types of secrets supported by ZnVault.
public enum SecretType: String, Codable, Sendable {
    case opaque
    case credential
    case setting
}

/// Semantic sub-types for secrets.
/// These provide more granular classification beyond the base type.
public enum SecretSubType: String, Codable, Sendable {
    // Credential sub-types
    case password
    case apiKey = "api_key"

    // Opaque sub-types
    case file
    case certificate
    case privateKey = "private_key"
    case keypair
    case sshKey = "ssh_key"
    case token
    case generic

    // Public key sub-types
    case rsaPublicKey = "rsa_public_key"
    case ed25519PublicKey = "ed25519_public_key"
    case ecdsaPublicKey = "ecdsa_public_key"

    // Setting sub-types
    case json
    case yaml
    case env
    case properties
    case toml
}

/// Maps sub-types to their parent storage types.
public let subTypeToType: [SecretSubType: SecretType] = [
    // Credential sub-types
    .password: .credential,
    .apiKey: .credential,
    // Opaque sub-types
    .file: .opaque,
    .certificate: .opaque,
    .privateKey: .opaque,
    .keypair: .opaque,
    .sshKey: .opaque,
    .token: .opaque,
    .generic: .opaque,
    // Public key sub-types
    .rsaPublicKey: .opaque,
    .ed25519PublicKey: .opaque,
    .ecdsaPublicKey: .opaque,
    // Setting sub-types
    .json: .setting,
    .yaml: .setting,
    .env: .setting,
    .properties: .setting,
    .toml: .setting
]

/// Represents a secret stored in ZnVault.
public struct Secret: Codable, Sendable, Identifiable {
    public let id: String
    public let alias: String
    public let tenant: String
    public let type: SecretType
    public let subType: SecretSubType?
    public let version: Int
    public let tags: [String]?

    // File metadata (queryable without decryption)
    public let fileName: String?
    public let fileSize: Int64?
    public let fileMime: String?
    public let fileChecksum: String?

    // Expiration tracking
    public let expiresAt: Date?
    public let ttlUntil: Date?

    // Content type (for settings)
    public let contentType: String?

    // Audit
    public let createdBy: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, alias, tenant, type, version, tags
        case subType
        case fileName
        case fileSize
        case fileMime
        case fileChecksum
        case expiresAt
        case ttlUntil
        case contentType
        case createdBy
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        alias = try container.decode(String.self, forKey: .alias)
        tenant = try container.decode(String.self, forKey: .tenant)
        type = try container.decode(SecretType.self, forKey: .type)
        subType = try container.decodeIfPresent(SecretSubType.self, forKey: .subType)
        version = try container.decode(Int.self, forKey: .version)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)

        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
        fileMime = try container.decodeIfPresent(String.self, forKey: .fileMime)
        fileChecksum = try container.decodeIfPresent(String.self, forKey: .fileChecksum)

        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        ttlUntil = try container.decodeIfPresent(Date.self, forKey: .ttlUntil)

        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)

        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

/// Decrypted secret data.
public struct SecretData: Codable, Sendable {
    public let id: String
    public let alias: String
    public let tenant: String
    public let type: SecretType
    public let subType: SecretSubType?
    public let version: Int
    public let data: [String: AnyCodable]

    // File metadata
    public let fileName: String?
    public let fileSize: Int64?
    public let fileMime: String?
    public let fileChecksum: String?

    // Expiration tracking
    public let expiresAt: Date?
    public let ttlUntil: Date?

    // Content type
    public let contentType: String?

    // Audit
    public let createdBy: String?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let decryptedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, alias, tenant, type, version, data
        case subType
        case fileName
        case fileSize
        case fileMime
        case fileChecksum
        case expiresAt
        case ttlUntil
        case contentType
        case createdBy
        case createdAt
        case updatedAt
        case decryptedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        alias = try container.decodeIfPresent(String.self, forKey: .alias) ?? ""
        tenant = try container.decodeIfPresent(String.self, forKey: .tenant) ?? ""
        type = try container.decodeIfPresent(SecretType.self, forKey: .type) ?? .opaque
        subType = try container.decodeIfPresent(SecretSubType.self, forKey: .subType)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        data = try container.decode([String: AnyCodable].self, forKey: .data)

        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
        fileMime = try container.decodeIfPresent(String.self, forKey: .fileMime)
        fileChecksum = try container.decodeIfPresent(String.self, forKey: .fileChecksum)

        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        ttlUntil = try container.decodeIfPresent(Date.self, forKey: .ttlUntil)

        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)

        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        decryptedAt = try container.decodeIfPresent(Date.self, forKey: .decryptedAt) ?? Date()
    }
}

/// Request to create a new secret.
public struct CreateSecretRequest: Codable, Sendable {
    public let alias: String
    public let type: SecretType
    public let subType: SecretSubType?
    public let data: [String: AnyCodable]
    public let fileName: String?
    public let expiresAt: Date?
    public let ttlUntil: Date?
    public let tags: [String]?
    public let contentType: String?
    public let tenant: String?  // Required for superadmin

    enum CodingKeys: String, CodingKey {
        case alias, type, data, tags, tenant
        case subType
        case fileName
        case expiresAt
        case ttlUntil
        case contentType
    }

    public init(
        alias: String,
        type: SecretType,
        subType: SecretSubType? = nil,
        data: [String: AnyCodable],
        fileName: String? = nil,
        expiresAt: Date? = nil,
        ttlUntil: Date? = nil,
        tags: [String]? = nil,
        contentType: String? = nil,
        tenant: String? = nil
    ) {
        self.alias = alias
        self.type = type
        self.subType = subType
        self.data = data
        self.fileName = fileName
        self.expiresAt = expiresAt
        self.ttlUntil = ttlUntil
        self.tags = tags
        self.contentType = contentType
        self.tenant = tenant
    }
}

/// Request to update an existing secret.
public struct UpdateSecretRequest: Codable, Sendable {
    public let data: [String: AnyCodable]
    public let subType: SecretSubType?
    public let fileName: String?
    public let expiresAt: Date?
    public let ttlUntil: Date?
    public let tags: [String]?
    public let contentType: String?

    enum CodingKeys: String, CodingKey {
        case data, tags
        case subType
        case fileName
        case expiresAt
        case ttlUntil
        case contentType
    }

    public init(
        data: [String: AnyCodable],
        subType: SecretSubType? = nil,
        fileName: String? = nil,
        expiresAt: Date? = nil,
        ttlUntil: Date? = nil,
        tags: [String]? = nil,
        contentType: String? = nil
    ) {
        self.data = data
        self.subType = subType
        self.fileName = fileName
        self.expiresAt = expiresAt
        self.ttlUntil = ttlUntil
        self.tags = tags
        self.contentType = contentType
    }
}

/// Request to update secret metadata (tags only).
public struct UpdateSecretMetadataRequest: Codable, Sendable {
    public let tags: [String]
    public let expiresAt: Date?
    public let ttlUntil: Date?

    public init(tags: [String], expiresAt: Date? = nil, ttlUntil: Date? = nil) {
        self.tags = tags
        self.expiresAt = expiresAt
        self.ttlUntil = ttlUntil
    }
}

/// Filter for listing secrets.
///
/// **Wildcard Pattern Matching:**
/// Use `*` as a wildcard in `aliasPattern` to match any characters:
/// - `web/*` matches all secrets under "web/" (e.g., "web/prod/api", "web/staging/db")
/// - `*/env/*` matches paths containing "/env/" anywhere
/// - `db-*/prod*` matches "db-mysql/production", "db-postgres/prod-us"
/// - `*secret*` matches any alias containing "secret"
///
/// Examples:
/// ```swift
/// // Find all production secrets
/// let filter = SecretFilter(aliasPattern: "*/production/*")
///
/// // Find all database credentials
/// let filter = SecretFilter(aliasPattern: "*/db-*", subType: .password)
///
/// // Find expiring certificates
/// let filter = SecretFilter(subType: .certificate, expiringBefore: Date().addingTimeInterval(86400 * 30))
/// ```
public struct SecretFilter: Sendable {
    public let type: SecretType?
    public let subType: SecretSubType?
    public let fileMime: String?
    public let expiringBefore: Date?
    /// Alias pattern with wildcard support. Use `*` to match any characters.
    /// Examples: `web/*`, `*/env/*`, `db-*/prod*`
    public let aliasPattern: String?
    public let tags: [String]?
    public let page: Int
    public let pageSize: Int

    /// Backward compatibility alias for aliasPattern
    public var aliasPrefix: String? { aliasPattern }

    public init(
        type: SecretType? = nil,
        subType: SecretSubType? = nil,
        fileMime: String? = nil,
        expiringBefore: Date? = nil,
        aliasPattern: String? = nil,
        tags: [String]? = nil,
        page: Int = 1,
        pageSize: Int = 100
    ) {
        self.type = type
        self.subType = subType
        self.fileMime = fileMime
        self.expiringBefore = expiringBefore
        self.aliasPattern = aliasPattern
        self.tags = tags
        self.page = page
        self.pageSize = pageSize
    }

    /// Backward compatible initializer with aliasPrefix parameter name
    public init(
        type: SecretType? = nil,
        subType: SecretSubType? = nil,
        fileMime: String? = nil,
        expiringBefore: Date? = nil,
        aliasPrefix: String?,
        tags: [String]? = nil,
        page: Int = 1,
        pageSize: Int = 100
    ) {
        self.type = type
        self.subType = subType
        self.fileMime = fileMime
        self.expiringBefore = expiringBefore
        self.aliasPattern = aliasPrefix
        self.tags = tags
        self.page = page
        self.pageSize = pageSize
    }
}

/// Historical version of a secret.
public struct SecretVersion: Codable, Sendable, Identifiable {
    public let id: Int
    public let tenant: String?
    public let alias: String?
    public let type: String?
    public let subType: SecretSubType?
    public let version: Int
    public let tags: [String]?

    // File metadata
    public let fileName: String?
    public let fileSize: Int64?
    public let fileMime: String?

    // Expiration tracking
    public let expiresAt: Date?

    // Audit
    public let createdAt: Date?
    public let createdBy: String?
    public let supersededAt: Date?
    public let supersededBy: String?

    enum CodingKeys: String, CodingKey {
        case id, tenant, alias, type, version, tags
        case subType
        case fileName
        case fileSize
        case fileMime
        case expiresAt
        case createdAt
        case createdBy
        case supersededAt
        case supersededBy
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
        case contentType
        case checksum, size
        case certificateExpiry
    }
}

// MARK: - Keypair Generation

/// Keypair algorithm type.
public enum KeypairAlgorithm: String, Codable, Sendable {
    case rsa = "RSA"
    case ed25519 = "Ed25519"
    case ecdsa = "ECDSA"
}

/// RSA key size.
public enum RSABits: Int, Codable, Sendable {
    case rsa2048 = 2048
    case rsa4096 = 4096
}

/// ECDSA curve.
public enum ECDSACurve: String, Codable, Sendable {
    case p256 = "P-256"
    case p384 = "P-384"
}

/// Request to generate a keypair.
public struct GenerateKeypairRequest: Codable, Sendable {
    public let algorithm: KeypairAlgorithm
    public let alias: String
    public let tenant: String
    public let rsaBits: RSABits?
    public let ecdsaCurve: ECDSACurve?
    public let comment: String?
    public let publishPublicKey: Bool?
    public let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case algorithm, alias, tenant, comment, tags
        case rsaBits
        case ecdsaCurve
        case publishPublicKey
    }

    public init(
        algorithm: KeypairAlgorithm,
        alias: String,
        tenant: String,
        rsaBits: RSABits? = nil,
        ecdsaCurve: ECDSACurve? = nil,
        comment: String? = nil,
        publishPublicKey: Bool? = nil,
        tags: [String]? = nil
    ) {
        self.algorithm = algorithm
        self.alias = alias
        self.tenant = tenant
        self.rsaBits = rsaBits
        self.ecdsaCurve = ecdsaCurve
        self.comment = comment
        self.publishPublicKey = publishPublicKey
        self.tags = tags
    }
}

/// Public key information in a generated keypair.
public struct PublicKeyInfo: Codable, Sendable {
    public let id: String
    public let alias: String
    public let isPublic: Bool?
    public let fingerprint: String
    public let algorithm: String
    public let bits: Int?
    public let publicKeyPem: String
    public let publicKeyOpenSSH: String

    enum CodingKeys: String, CodingKey {
        case id, alias, fingerprint, algorithm, bits
        case isPublic
        case publicKeyPem
        case publicKeyOpenSSH
    }
}

/// Private key information in a generated keypair.
public struct PrivateKeyInfo: Codable, Sendable {
    public let id: String
    public let alias: String

    enum CodingKeys: String, CodingKey {
        case id, alias
    }
}

/// Response from keypair generation.
public struct GeneratedKeypair: Codable, Sendable {
    public let privateKey: PrivateKeyInfo
    public let publicKey: PublicKeyInfo

    enum CodingKeys: String, CodingKey {
        case privateKey
        case publicKey
    }
}

/// Result from publishing a public key.
public struct PublishResult: Codable, Sendable {
    public let message: String
    public let publicUrl: String
    public let fingerprint: String
    public let algorithm: String

    enum CodingKeys: String, CodingKey {
        case message, fingerprint, algorithm
        case publicUrl
    }
}

/// Published public key information.
public struct PublishedPublicKey: Codable, Sendable {
    public let id: String
    public let alias: String
    public let tenant: String
    public let subType: String?
    public let publicKey: String
    public let fingerprint: String
    public let algorithm: String
    public let bits: Int?

    enum CodingKeys: String, CodingKey {
        case id, alias, tenant, fingerprint, algorithm, bits
        case subType
        case publicKey
    }
}

/// Response from listing public keys for a tenant.
public struct PublicKeysListResponse: Codable, Sendable {
    public let tenant: String
    public let keys: [PublishedPublicKey]

    enum CodingKeys: String, CodingKey {
        case tenant, keys
    }
}
