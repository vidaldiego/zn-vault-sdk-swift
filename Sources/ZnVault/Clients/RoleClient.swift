// Path: zn-vault-sdk-swift/Sources/ZnVault/Clients/RoleClient.swift

import Foundation

/// Client for role management operations.
public final class RoleClient: Sendable {
    private let http: ZnVaultHttpClient

    internal init(http: ZnVaultHttpClient) {
        self.http = http
    }

    // MARK: - CRUD Operations

    /// Create a new role.
    public func create(
        name: String,
        description: String? = nil,
        permissions: [String]
    ) async throws -> Role {
        let request = CreateRoleRequest(
            name: name,
            description: description,
            permissions: permissions
        )
        return try await http.post("/v1/admin/roles", body: request, responseType: Role.self)
    }

    /// Create role with request object.
    public func create(request: CreateRoleRequest) async throws -> Role {
        return try await http.post("/v1/admin/roles", body: request, responseType: Role.self)
    }

    /// Get role by ID.
    public func get(id: String) async throws -> Role {
        return try await http.get("/v1/admin/roles/\(id)", responseType: Role.self)
    }

    /// List roles.
    public func list(filter: RoleFilter = RoleFilter()) async throws -> Page<Role> {
        var query: [String: String] = [:]

        if filter.includeSystem {
            query["includeSystem"] = "true"
        }
        if let tenantId = filter.tenantId {
            query["tenantId"] = tenantId
        }
        query["limit"] = String(filter.limit)
        query["offset"] = String(filter.offset)

        return try await http.get("/v1/admin/roles", query: query, responseType: Page<Role>.self)
    }

    /// Update role.
    public func update(id: String, request: UpdateRoleRequest) async throws -> Role {
        return try await http.patch("/v1/admin/roles/\(id)", body: request, responseType: Role.self)
    }

    /// Delete role.
    public func delete(id: String) async throws {
        try await http.delete("/v1/admin/roles/\(id)")
    }

    // MARK: - Permission Management

    /// Add permission to role.
    public func addPermission(roleId: String, permission: String) async throws -> Role {
        let request = AddPermissionRequest(permission: permission)
        return try await http.post("/v1/admin/roles/\(roleId)/permissions", body: request, responseType: Role.self)
    }

    /// Remove permission from role.
    public func removePermission(roleId: String, permission: String) async throws -> Role {
        return try await http.delete(
            "/v1/admin/roles/\(roleId)/permissions/\(permission)",
            responseType: Role.self
        )
    }

    // MARK: - User Assignment

    /// Get users with this role.
    public func getUsers(roleId: String) async throws -> [User] {
        return try await http.get("/v1/admin/roles/\(roleId)/users", responseType: [User].self)
    }

    /// Assign role to user.
    public func assignToUser(roleId: String, userId: String) async throws {
        let request = AssignRoleRequest(userId: userId, roleId: roleId)
        try await http.post("/v1/admin/roles/\(roleId)/users", body: request)
    }

    /// Remove role from user.
    public func removeFromUser(roleId: String, userId: String) async throws {
        try await http.delete("/v1/admin/roles/\(roleId)/users/\(userId)")
    }

    // MARK: - System Roles

    /// List all available permissions.
    public func listPermissions() async throws -> [Permission] {
        return try await http.get("/v1/admin/permissions", responseType: [Permission].self)
    }
}

// MARK: - Additional Types

/// Permission definition.
public struct Permission: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let category: String?
}

/// Request to add permission.
public struct AddPermissionRequest: Codable, Sendable {
    public let permission: String

    public init(permission: String) {
        self.permission = permission
    }
}
