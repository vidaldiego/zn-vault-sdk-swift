// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/Auth.swift

import Foundation

/// Login request.
public struct LoginRequest: Codable, Sendable {
    public let username: String
    public let password: String
    public let totpCode: String?

    enum CodingKeys: String, CodingKey {
        case username, password
        case totpCode = "totp_code"
    }

    public init(username: String, password: String, totpCode: String? = nil) {
        self.username = username
        self.password = password
        self.totpCode = totpCode
    }
}

/// Login response with JWT tokens.
public struct LoginResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let requires2fa: Bool
    public let tempToken: String?
    public let user: User?

    enum CodingKeys: String, CodingKey {
        case accessToken, refreshToken, tokenType, expiresIn
        case requires2fa = "requires_2fa"
        case tempToken = "temp_token"
        case user
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken) ?? ""
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken) ?? ""
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType) ?? "Bearer"
        expiresIn = try container.decodeIfPresent(Int.self, forKey: .expiresIn) ?? 3600
        requires2fa = try container.decodeIfPresent(Bool.self, forKey: .requires2fa) ?? false
        tempToken = try container.decodeIfPresent(String.self, forKey: .tempToken)
        user = try container.decodeIfPresent(User.self, forKey: .user)
    }
}

/// API key scope.
public enum ApiKeyScope: String, Codable, Sendable {
    case full
    case readOnly = "read_only"
    case limited
}

/// Time range condition for API key access.
public struct ApiKeyTimeRange: Codable, Sendable {
    public let start: String?      // e.g., "09:00"
    public let end: String?        // e.g., "17:00"
    public let timezone: String?   // e.g., "UTC"

    public init(start: String? = nil, end: String? = nil, timezone: String? = nil) {
        self.start = start
        self.end = end
        self.timezone = timezone
    }
}

/// Resource-specific conditions for API keys.
public struct ApiKeyResourceConditions: Codable, Sendable {
    public let certificates: [String]?
    public let secrets: [String]?

    public init(certificates: [String]? = nil, secrets: [String]? = nil) {
        self.certificates = certificates
        self.secrets = secrets
    }
}

/// Inline ABAC conditions for API keys.
public struct ApiKeyConditions: Codable, Sendable {
    public let ip: [String]?                              // IP/CIDR allowlist
    public let timeRange: ApiKeyTimeRange?                // Time-of-day restriction
    public let methods: [String]?                         // HTTP methods allowed
    public let resources: ApiKeyResourceConditions?       // Specific resource IDs
    public let aliases: [String]?                         // Glob patterns for aliases
    public let resourceTags: [String: String]?            // Tag matching

    enum CodingKeys: String, CodingKey {
        case ip, timeRange, methods, resources, aliases, resourceTags
    }

    public init(
        ip: [String]? = nil,
        timeRange: ApiKeyTimeRange? = nil,
        methods: [String]? = nil,
        resources: ApiKeyResourceConditions? = nil,
        aliases: [String]? = nil,
        resourceTags: [String: String]? = nil
    ) {
        self.ip = ip
        self.timeRange = timeRange
        self.methods = methods
        self.resources = resources
        self.aliases = aliases
        self.resourceTags = resourceTags
    }
}

/// API key information.
public struct ApiKey: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let prefix: String?
    public let userId: String?
    public let tenantId: String?
    public let createdAt: Date?
    public let expiresAt: Date?
    public let lastUsed: Date?
    public let scope: String?
    public let permissions: [String]?
    public let ipAllowlist: [String]?
    public let conditions: ApiKeyConditions?

    enum CodingKeys: String, CodingKey {
        case id, name, prefix
        case userId = "user_id"
        case tenantId
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case lastUsed = "last_used"
        case scope, permissions, ipAllowlist, conditions
    }
}

/// Request to create an API key.
public struct CreateApiKeyRequest: Codable, Sendable {
    public let name: String
    public let permissions: [String]
    public let expiresInDays: Int?
    public let description: String?
    public let ipAllowlist: [String]?
    public let conditions: ApiKeyConditions?

    enum CodingKeys: String, CodingKey {
        case name, permissions, expiresInDays, description, ipAllowlist, conditions
    }

    public init(
        name: String,
        permissions: [String],
        expiresInDays: Int? = nil,
        description: String? = nil,
        ipAllowlist: [String]? = nil,
        conditions: ApiKeyConditions? = nil
    ) {
        self.name = name
        self.permissions = permissions
        self.expiresInDays = expiresInDays
        self.description = description
        self.ipAllowlist = ipAllowlist
        self.conditions = conditions
    }
}

/// Response when creating an API key.
public struct CreateApiKeyResponse: Codable, Sendable {
    public let key: String
    public let apiKey: ApiKey?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case key
        case apiKey = "api_key"
        case message
    }
}

/// TOTP setup response.
public struct TotpSetupResponse: Codable, Sendable {
    public let secret: String
    public let qrCode: String
    public let otpauthUrl: String?

    enum CodingKeys: String, CodingKey {
        case secret
        case qrCode = "qr_code"
        case otpauthUrl = "otpauth_url"
    }
}

// MARK: - Managed API Keys

/// Rotation mode for managed API keys.
///
/// - `scheduled`: Key rotates at fixed intervals (e.g., every 24 hours)
/// - `onUse`: Key rotates after being used (TTL resets on each use)
/// - `onBind`: Key rotates each time bind is called
public enum RotationMode: String, Codable, Sendable {
    case scheduled = "scheduled"
    case onUse = "on-use"
    case onBind = "on-bind"
}

/// Managed API key with auto-rotation configuration.
///
/// Managed keys automatically rotate based on the configured mode,
/// providing seamless credential rotation for services and agents.
public struct ManagedApiKey: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let tenantId: String
    public let permissions: [String]
    public let rotationMode: RotationMode
    public let gracePeriod: String
    public let enabled: Bool
    public let createdAt: Date?
    public let description: String?
    public let rotationInterval: String?
    public let lastRotatedAt: Date?
    public let nextRotationAt: Date?
    public let createdBy: String?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, tenantId, permissions, rotationMode, gracePeriod, enabled
        case createdAt, description, rotationInterval, lastRotatedAt
        case nextRotationAt, createdBy, updatedAt
    }
}

/// Response from binding to a managed API key.
///
/// This is what agents use to get the current key value and rotation metadata.
public struct ManagedKeyBindResponse: Codable, Sendable {
    /// The API key ID
    public let id: String
    /// The current API key value - use this for authentication
    public let key: String
    /// Key prefix for identification
    public let prefix: String
    /// Managed key name
    public let name: String
    /// When this key expires
    public let expiresAt: Date?
    /// Grace period duration
    public let gracePeriod: String
    /// Rotation mode
    public let rotationMode: RotationMode
    /// Permissions on the key
    public let permissions: [String]
    /// When the next rotation will occur (helps SDK know when to re-bind)
    public let nextRotationAt: Date?
    /// When the grace period expires (after this, old key stops working)
    public let graceExpiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, key, prefix, name, expiresAt, gracePeriod
        case rotationMode, permissions, nextRotationAt, graceExpiresAt
    }
}

/// Response from rotating a managed API key.
public struct ManagedKeyRotateResponse: Codable, Sendable {
    /// The new API key value
    public let key: String
    /// Managed key metadata
    public let apiKey: ManagedApiKey
    /// When the old key expires (grace period end)
    public let graceExpiresAt: Date?
    /// Optional message
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case key, apiKey, graceExpiresAt, message
    }
}

/// Request to create a managed API key.
public struct CreateManagedApiKeyRequest: Codable, Sendable {
    public let name: String
    public let permissions: [String]
    public let rotationMode: RotationMode
    public let rotationInterval: String?
    public let gracePeriod: String?
    public let description: String?
    public let expiresInDays: Int?

    enum CodingKeys: String, CodingKey {
        case name, permissions, rotationMode, rotationInterval
        case gracePeriod, description, expiresInDays
    }

    public init(
        name: String,
        permissions: [String],
        rotationMode: RotationMode,
        rotationInterval: String? = nil,
        gracePeriod: String? = nil,
        description: String? = nil,
        expiresInDays: Int? = nil
    ) {
        self.name = name
        self.permissions = permissions
        self.rotationMode = rotationMode
        self.rotationInterval = rotationInterval
        self.gracePeriod = gracePeriod
        self.description = description
        self.expiresInDays = expiresInDays
    }
}

/// Response when creating a managed API key.
public struct CreateManagedApiKeyResponse: Codable, Sendable {
    public let apiKey: ManagedApiKey
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case apiKey, message
    }
}

/// Response listing managed API keys.
public struct ManagedApiKeyListResponse: Codable, Sendable {
    public let keys: [ManagedApiKey]
    public let total: Int

    enum CodingKeys: String, CodingKey {
        case keys, total
    }
}

/// Request to update managed API key configuration.
public struct UpdateManagedApiKeyConfigRequest: Codable, Sendable {
    public let rotationInterval: String?
    public let gracePeriod: String?
    public let enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case rotationInterval, gracePeriod, enabled
    }

    public init(
        rotationInterval: String? = nil,
        gracePeriod: String? = nil,
        enabled: Bool? = nil
    ) {
        self.rotationInterval = rotationInterval
        self.gracePeriod = gracePeriod
        self.enabled = enabled
    }
}
