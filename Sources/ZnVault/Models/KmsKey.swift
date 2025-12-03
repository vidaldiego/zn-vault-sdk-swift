// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/KmsKey.swift

import Foundation

/// Key usage type.
public enum KeyUsage: String, Codable, Sendable {
    case encryptDecrypt = "ENCRYPT_DECRYPT"
    case signVerify = "SIGN_VERIFY"
    case generateDataKey = "GENERATE_DATA_KEY"
}

/// Key specification (algorithm and size).
public enum KeySpec: String, Codable, Sendable {
    case aes256 = "AES_256"
    case aes128 = "AES_128"
    case rsa2048 = "RSA_2048"
    case rsa4096 = "RSA_4096"
    case eccNistP256 = "ECC_NIST_P256"
    case eccNistP384 = "ECC_NIST_P384"
}

/// Key origin.
public enum KeyOrigin: String, Codable, Sendable {
    case znVault = "ZN_VAULT"
    case external = "EXTERNAL"
    case awsKms = "AWS_KMS"
}

/// Key state.
public enum KeyState: String, Codable, Sendable {
    case enabled = "ENABLED"
    case disabled = "DISABLED"
    case pendingDeletion = "PENDING_DELETION"
    case pendingImport = "PENDING_IMPORT"
}

/// Key tag.
public struct KeyTag: Codable, Sendable {
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// Represents a KMS Customer Master Key (CMK).
public struct KmsKey: Codable, Sendable, Identifiable {
    public var id: String { keyId }

    public let keyId: String
    public let alias: String?
    public let description: String?
    public let usage: KeyUsage?
    public let keySpec: KeySpec?
    public let origin: KeyOrigin
    public let state: KeyState?
    public let tenant: String?
    public let arn: String?
    public let createdDate: Date?
    public let deletionDate: Date?
    public let multiRegion: Bool
    public let tags: [KeyTag]
    public let currentVersion: Int

    /// Computed property for enabled status.
    public var enabled: Bool { state == .enabled }

    enum CodingKeys: String, CodingKey {
        case keyId, alias, description
        case usage = "keyUsage"
        case keySpec, origin
        case state = "keyState"
        case tenant, arn, createdDate, deletionDate, multiRegion, tags, currentVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyId = try container.decode(String.self, forKey: .keyId)
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        usage = try container.decodeIfPresent(KeyUsage.self, forKey: .usage)
        keySpec = try container.decodeIfPresent(KeySpec.self, forKey: .keySpec)
        origin = try container.decodeIfPresent(KeyOrigin.self, forKey: .origin) ?? .znVault
        state = try container.decodeIfPresent(KeyState.self, forKey: .state)
        tenant = try container.decodeIfPresent(String.self, forKey: .tenant)
        arn = try container.decodeIfPresent(String.self, forKey: .arn)
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate)
        deletionDate = try container.decodeIfPresent(Date.self, forKey: .deletionDate)
        multiRegion = try container.decodeIfPresent(Bool.self, forKey: .multiRegion) ?? false
        tags = try container.decodeIfPresent([KeyTag].self, forKey: .tags) ?? []
        currentVersion = try container.decodeIfPresent(Int.self, forKey: .currentVersion) ?? 1
    }
}

/// KMS key version.
public struct KmsKeyVersion: Codable, Sendable {
    public let version: Int
    public let createdDate: Date?
    public let status: String?

    enum CodingKeys: String, CodingKey {
        case version
        case createdDate = "created_date"
        case status
    }
}

/// Request to create a new KMS key.
public struct CreateKmsKeyRequest: Codable, Sendable {
    public let alias: String?
    public let description: String?
    public let usage: KeyUsage
    public let keySpec: KeySpec
    public let tags: [String: String]?
    public let rotationEnabled: Bool?
    public let rotationDays: Int?

    enum CodingKeys: String, CodingKey {
        case alias, description, usage
        case keySpec = "key_spec"
        case tags
        case rotationEnabled = "rotation_enabled"
        case rotationDays = "rotation_days"
    }

    public init(
        alias: String? = nil,
        description: String? = nil,
        usage: KeyUsage = .encryptDecrypt,
        keySpec: KeySpec = .aes256,
        tags: [String: String]? = nil,
        rotationEnabled: Bool? = nil,
        rotationDays: Int? = nil
    ) {
        self.alias = alias
        self.description = description
        self.usage = usage
        self.keySpec = keySpec
        self.tags = tags
        self.rotationEnabled = rotationEnabled
        self.rotationDays = rotationDays
    }
}

/// Request to update a KMS key.
public struct UpdateKmsKeyRequest: Codable, Sendable {
    public let description: String?
    public let tags: [String: String]?

    public init(description: String? = nil, tags: [String: String]? = nil) {
        self.description = description
        self.tags = tags
    }
}

/// Filter for listing KMS keys.
public struct KeyFilter: Sendable {
    public let state: KeyState?
    public let usage: KeyUsage?
    public let limit: Int
    public let offset: Int

    public init(
        state: KeyState? = nil,
        usage: KeyUsage? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.state = state
        self.usage = usage
        self.limit = limit
        self.offset = offset
    }
}

/// Result of an encryption operation.
public struct EncryptResult: Codable, Sendable {
    public let ciphertext: String
    public let keyId: String
    public let encryptionContext: [String: String]?
    public let keyVersion: Int?
}

/// Result of a decrypt operation.
public struct DecryptResult: Codable, Sendable {
    public let plaintext: String
    public let keyId: String
    public let encryptionContext: [String: String]?
}

/// Result of generate data key operation.
public struct DataKeyResult: Codable, Sendable {
    public let plaintextKey: String
    public let encryptedKey: String
    public let keyId: String

    enum CodingKeys: String, CodingKey {
        case plaintextKey = "plaintext_key"
        case encryptedKey = "encrypted_key"
        case keyId = "key_id"
    }
}
