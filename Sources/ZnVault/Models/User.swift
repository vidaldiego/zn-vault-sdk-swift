// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/User.swift

import Foundation

/// User role.
public enum UserRole: String, Codable, Sendable {
    case superadmin
    case admin
    case user
    case service
}

/// User status.
public enum UserStatus: String, Codable, Sendable {
    case active
    case disabled
    case locked
}

/// User account.
public struct User: Codable, Sendable, Identifiable {
    public let id: String
    public let username: String
    public let email: String?
    public let role: UserRole
    public let tenantId: String?
    public let totpEnabled: Bool
    public let status: UserStatus?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let lastLogin: Date?
    public let permissions: [String]?

    enum CodingKeys: String, CodingKey {
        case id, username, email, role
        case tenantId = "tenant_id"
        case totpEnabled = "totp_enabled"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastLogin = "last_login"
        case permissions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        role = try container.decode(UserRole.self, forKey: .role)
        tenantId = try container.decodeIfPresent(String.self, forKey: .tenantId)
        totpEnabled = try container.decodeIfPresent(Bool.self, forKey: .totpEnabled) ?? false
        status = try container.decodeIfPresent(UserStatus.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        lastLogin = try container.decodeIfPresent(Date.self, forKey: .lastLogin)
        permissions = try container.decodeIfPresent([String].self, forKey: .permissions)
    }
}

/// Request to create a user.
public struct CreateUserRequest: Codable, Sendable {
    public let username: String
    public let password: String
    public let email: String?
    public let role: String?
    public let tenantId: String?

    enum CodingKeys: String, CodingKey {
        case username, password, email, role
        case tenantId = "tenant_id"
    }

    public init(
        username: String,
        password: String,
        email: String? = nil,
        tenantId: String? = nil,
        role: String? = nil
    ) {
        self.username = username
        self.password = password
        self.email = email
        self.role = role
        self.tenantId = tenantId
    }
}
