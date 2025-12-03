// Path: zn-vault-sdk-swift/Sources/ZnVault/Clients/UserClient.swift

import Foundation

/// Client for user management operations.
public final class UserClient: Sendable {
    private let http: ZnVaultHttpClient

    internal init(http: ZnVaultHttpClient) {
        self.http = http
    }

    // MARK: - CRUD Operations

    /// Create a new user.
    public func create(
        username: String,
        password: String,
        email: String? = nil,
        tenantId: String? = nil,
        role: String? = nil
    ) async throws -> User {
        let request = CreateUserRequest(
            username: username,
            password: password,
            email: email,
            tenantId: tenantId,
            role: role
        )
        return try await http.post("/v1/admin/users", body: request, responseType: User.self)
    }

    /// Create user with request object.
    public func create(request: CreateUserRequest) async throws -> User {
        return try await http.post("/v1/admin/users", body: request, responseType: User.self)
    }

    /// Get user by ID.
    public func get(id: String) async throws -> User {
        return try await http.get("/v1/admin/users/\(id)", responseType: User.self)
    }

    /// Get user by username.
    public func getByUsername(username: String) async throws -> User {
        let query = ["username": username]
        return try await http.get("/v1/admin/users/by-username", query: query, responseType: User.self)
    }

    /// List users.
    public func list(filter: UserFilter = UserFilter()) async throws -> Page<User> {
        var query: [String: String] = [:]

        if let tenantId = filter.tenantId {
            query["tenantId"] = tenantId
        }
        if let status = filter.status {
            query["status"] = status.rawValue
        }
        if let role = filter.role {
            query["role"] = role
        }
        query["limit"] = String(filter.limit)
        query["offset"] = String(filter.offset)

        return try await http.get("/v1/admin/users", query: query, responseType: Page<User>.self)
    }

    /// Update user.
    public func update(id: String, request: UpdateUserRequest) async throws -> User {
        return try await http.patch("/v1/admin/users/\(id)", body: request, responseType: User.self)
    }

    /// Delete user.
    public func delete(id: String) async throws {
        try await http.delete("/v1/admin/users/\(id)")
    }

    // MARK: - Status Management

    /// Activate user.
    public func activate(id: String) async throws -> User {
        return try await http.post("/v1/admin/users/\(id)/activate", responseType: User.self)
    }

    /// Deactivate user.
    public func deactivate(id: String) async throws -> User {
        return try await http.post("/v1/admin/users/\(id)/deactivate", responseType: User.self)
    }

    /// Suspend user.
    public func suspend(id: String) async throws -> User {
        return try await http.post("/v1/admin/users/\(id)/suspend", responseType: User.self)
    }

    /// Unlock user account.
    public func unlock(id: String) async throws -> User {
        return try await http.post("/v1/admin/users/\(id)/unlock", responseType: User.self)
    }

    // MARK: - Password Management

    /// Reset user password (admin).
    public func resetPassword(id: String, newPassword: String) async throws {
        let request = AdminResetPasswordRequest(newPassword: newPassword)
        try await http.post("/v1/admin/users/\(id)/reset-password", body: request)
    }

    /// Force password change on next login.
    public func forcePasswordChange(id: String) async throws -> User {
        return try await http.post("/v1/admin/users/\(id)/force-password-change", responseType: User.self)
    }

    // MARK: - Role Management

    /// Assign role to user.
    public func assignRole(userId: String, roleId: String) async throws {
        let request = AssignRoleRequest(userId: userId, roleId: roleId)
        try await http.post("/v1/admin/users/\(userId)/roles", body: request)
    }

    /// Remove role from user.
    public func removeRole(userId: String, roleId: String) async throws {
        try await http.delete("/v1/admin/users/\(userId)/roles/\(roleId)")
    }

    /// Get user roles.
    public func getRoles(userId: String) async throws -> [Role] {
        return try await http.get("/v1/admin/users/\(userId)/roles", responseType: [Role].self)
    }

    // MARK: - 2FA Management (Admin)

    /// Reset user 2FA.
    public func reset2FA(id: String) async throws {
        try await http.post("/v1/admin/users/\(id)/reset-2fa", body: EmptyBody())
    }
}

// MARK: - Request Types

/// Request to update user.
public struct UpdateUserRequest: Codable, Sendable {
    public let email: String?
    public let tenantId: String?
    public let status: UserStatus?

    enum CodingKeys: String, CodingKey {
        case email
        case tenantId = "tenant_id"
        case status
    }

    public init(email: String? = nil, tenantId: String? = nil, status: UserStatus? = nil) {
        self.email = email
        self.tenantId = tenantId
        self.status = status
    }
}

/// Admin password reset request.
public struct AdminResetPasswordRequest: Codable, Sendable {
    public let newPassword: String

    enum CodingKeys: String, CodingKey {
        case newPassword = "new_password"
    }

    public init(newPassword: String) {
        self.newPassword = newPassword
    }
}

/// User filter.
public struct UserFilter: Sendable {
    public let tenantId: String?
    public let status: UserStatus?
    public let role: String?
    public let limit: Int
    public let offset: Int

    public init(
        tenantId: String? = nil,
        status: UserStatus? = nil,
        role: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.tenantId = tenantId
        self.status = status
        self.role = role
        self.limit = limit
        self.offset = offset
    }
}

/// Empty body for POST requests without data.
private struct EmptyBody: Codable, Sendable {}
