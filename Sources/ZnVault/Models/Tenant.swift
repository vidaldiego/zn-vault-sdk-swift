// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/Tenant.swift

import Foundation

/// Tenant status.
public enum TenantStatus: String, Codable, Sendable {
    case active
    case suspended
    case archived
}

/// Tenant organization.
public struct Tenant: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let status: TenantStatus
    public let maxSecrets: Int?
    public let maxKmsKeys: Int?
    public let maxCertificates: Int?
    public let maxConfigs: Int?
    public let maxStorageMb: Int?
    public let contactEmail: String?
    public let contactName: String?
    public let metadata: [String: AnyCodable]?
    public let createdAt: Date?
    public let createdBy: String?
    public let updatedAt: Date?
    public let lastActivity: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case maxSecrets = "max_secrets"
        case maxKmsKeys = "max_kms_keys"
        case maxCertificates = "max_certificates"
        case maxConfigs = "max_configs"
        case maxStorageMb = "max_storage_mb"
        case contactEmail = "contact_email"
        case contactName = "contact_name"
        case metadata
        case createdAt = "created_at"
        case createdBy = "created_by"
        case updatedAt = "updated_at"
        case lastActivity = "last_activity"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decodeIfPresent(TenantStatus.self, forKey: .status) ?? .active
        maxSecrets = try container.decodeIfPresent(Int.self, forKey: .maxSecrets)
        maxKmsKeys = try container.decodeIfPresent(Int.self, forKey: .maxKmsKeys)
        maxCertificates = try container.decodeIfPresent(Int.self, forKey: .maxCertificates)
        maxConfigs = try container.decodeIfPresent(Int.self, forKey: .maxConfigs)
        maxStorageMb = try container.decodeIfPresent(Int.self, forKey: .maxStorageMb)
        contactEmail = try container.decodeIfPresent(String.self, forKey: .contactEmail)
        contactName = try container.decodeIfPresent(String.self, forKey: .contactName)
        metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        lastActivity = try container.decodeIfPresent(Date.self, forKey: .lastActivity)
    }
}

/// Tenant settings.
public struct TenantSettings: Codable, Sendable {
    public let maxSecrets: Int?
    public let maxKmsKeys: Int?
    public let secretRetentionDays: Int?
    public let auditRetentionDays: Int?

    enum CodingKeys: String, CodingKey {
        case maxSecrets = "max_secrets"
        case maxKmsKeys = "max_kms_keys"
        case secretRetentionDays = "secret_retention_days"
        case auditRetentionDays = "audit_retention_days"
    }

    public init(
        maxSecrets: Int? = nil,
        maxKmsKeys: Int? = nil,
        secretRetentionDays: Int? = nil,
        auditRetentionDays: Int? = nil
    ) {
        self.maxSecrets = maxSecrets
        self.maxKmsKeys = maxKmsKeys
        self.secretRetentionDays = secretRetentionDays
        self.auditRetentionDays = auditRetentionDays
    }
}

/// Request to create a tenant.
public struct CreateTenantRequest: Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let contactEmail: String?
    public let contactName: String?
    public let settings: TenantSettings?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case contactEmail = "contact_email"
        case contactName = "contact_name"
        case settings
    }

    public init(
        id: String,
        name: String,
        description: String? = nil,
        settings: TenantSettings? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.contactEmail = nil
        self.contactName = nil
        self.settings = settings
    }
}

/// Request to update a tenant.
public struct UpdateTenantRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let status: TenantStatus?
    public let contactEmail: String?
    public let contactName: String?

    enum CodingKeys: String, CodingKey {
        case name, description, status
        case contactEmail = "contact_email"
        case contactName = "contact_name"
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        status: TenantStatus? = nil,
        contactEmail: String? = nil,
        contactName: String? = nil
    ) {
        self.name = name
        self.description = description
        self.status = status
        self.contactEmail = contactEmail
        self.contactName = contactName
    }
}
