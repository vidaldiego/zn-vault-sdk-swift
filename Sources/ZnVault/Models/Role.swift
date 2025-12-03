// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/Role.swift

import Foundation

/// RBAC Role.
public struct Role: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let isSystem: Bool
    public let permissions: [String]
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case isSystem = "is_system"
        case permissions
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isSystem = try container.decodeIfPresent(Bool.self, forKey: .isSystem) ?? false

        // Permissions can be a JSON string or array
        if let permString = try? container.decode(String.self, forKey: .permissions),
           let data = permString.data(using: .utf8),
           let perms = try? JSONDecoder().decode([String].self, from: data) {
            permissions = perms
        } else {
            permissions = try container.decodeIfPresent([String].self, forKey: .permissions) ?? []
        }

        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

/// Request to create a role.
public struct CreateRoleRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let permissions: [String]

    public init(name: String, description: String? = nil, permissions: [String]) {
        self.name = name
        self.description = description
        self.permissions = permissions
    }
}

/// Request to update a role.
public struct UpdateRoleRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let permissions: [String]?

    public init(name: String? = nil, description: String? = nil, permissions: [String]? = nil) {
        self.name = name
        self.description = description
        self.permissions = permissions
    }
}

/// Role filter.
public struct RoleFilter: Sendable {
    public let includeSystem: Bool
    public let tenantId: String?
    public let limit: Int
    public let offset: Int

    public init(
        includeSystem: Bool = false,
        tenantId: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.includeSystem = includeSystem
        self.tenantId = tenantId
        self.limit = limit
        self.offset = offset
    }
}

/// User-role assignment.
public struct UserRoleAssignment: Codable, Sendable {
    public let userId: String
    public let roleId: String
    public let grantedBy: String?
    public let grantedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case roleId = "role_id"
        case grantedBy = "granted_by"
        case grantedAt = "granted_at"
    }
}

/// Request to assign role to user.
public struct AssignRoleRequest: Codable, Sendable {
    public let userId: String
    public let roleId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case roleId = "role_id"
    }

    public init(userId: String, roleId: String) {
        self.userId = userId
        self.roleId = roleId
    }
}
