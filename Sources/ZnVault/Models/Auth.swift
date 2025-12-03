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

/// API key information.
public struct ApiKey: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let prefix: String?
    public let userId: String?
    public let createdAt: Date?
    public let expiresAt: Date?
    public let lastUsed: Date?
    public let scope: String?

    enum CodingKeys: String, CodingKey {
        case id, name, prefix
        case userId = "user_id"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case lastUsed = "last_used"
        case scope
    }
}

/// Request to create an API key.
public struct CreateApiKeyRequest: Codable, Sendable {
    public let name: String
    public let expiresIn: String?
    public let permissions: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case expiresIn = "expires_in"
        case permissions
    }

    public init(name: String, expiresIn: String? = nil, permissions: [String]? = nil) {
        self.name = name
        self.expiresIn = expiresIn
        self.permissions = permissions
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
