// Path: zn-vault-sdk-swift/Sources/ZnVault/Clients/TenantClient.swift

import Foundation

/// Client for tenant management operations.
public final class TenantClient: Sendable {
    private let http: ZnVaultHttpClient

    internal init(http: ZnVaultHttpClient) {
        self.http = http
    }

    // MARK: - CRUD Operations

    /// Create a new tenant.
    public func create(
        id: String,
        name: String,
        description: String? = nil,
        settings: TenantSettings? = nil
    ) async throws -> Tenant {
        let request = CreateTenantRequest(
            id: id,
            name: name,
            description: description,
            settings: settings
        )
        return try await http.post("/v1/tenants", body: request, responseType: Tenant.self)
    }

    /// Create tenant with request object.
    public func create(request: CreateTenantRequest) async throws -> Tenant {
        return try await http.post("/v1/tenants", body: request, responseType: Tenant.self)
    }

    /// Get tenant by ID.
    public func get(id: String) async throws -> Tenant {
        return try await http.get("/v1/tenants/\(id)", responseType: Tenant.self)
    }

    /// List tenants.
    public func list(filter: TenantFilter = TenantFilter()) async throws -> Page<Tenant> {
        var query: [String: String] = [:]

        if let status = filter.status {
            query["status"] = status.rawValue
        }
        query["limit"] = String(filter.limit)
        query["offset"] = String(filter.offset)

        return try await http.get("/v1/tenants", query: query, responseType: Page<Tenant>.self)
    }

    /// Update tenant.
    public func update(id: String, request: UpdateTenantRequest) async throws -> Tenant {
        return try await http.patch("/v1/tenants/\(id)", body: request, responseType: Tenant.self)
    }

    /// Delete tenant.
    public func delete(id: String) async throws {
        try await http.delete("/v1/tenants/\(id)")
    }

    // MARK: - Status Management

    /// Activate tenant.
    public func activate(id: String) async throws -> Tenant {
        return try await http.post("/v1/tenants/\(id)/activate", responseType: Tenant.self)
    }

    /// Suspend tenant.
    public func suspend(id: String) async throws -> Tenant {
        return try await http.post("/v1/tenants/\(id)/suspend", responseType: Tenant.self)
    }

    // MARK: - Settings

    /// Get tenant settings.
    public func getSettings(id: String) async throws -> TenantSettings {
        return try await http.get("/v1/tenants/\(id)/settings", responseType: TenantSettings.self)
    }

    /// Update tenant settings.
    public func updateSettings(id: String, settings: TenantSettings) async throws -> TenantSettings {
        return try await http.put("/v1/tenants/\(id)/settings", body: settings, responseType: TenantSettings.self)
    }

    // MARK: - Statistics

    /// Get tenant statistics.
    public func getStats(id: String) async throws -> TenantStats {
        return try await http.get("/v1/tenants/\(id)/stats", responseType: TenantStats.self)
    }

    // MARK: - User Management

    /// List tenant users.
    public func listUsers(tenantId: String, limit: Int = 50, offset: Int = 0) async throws -> Page<User> {
        let query = ["limit": String(limit), "offset": String(offset)]
        return try await http.get("/v1/tenants/\(tenantId)/users", query: query, responseType: Page<User>.self)
    }

    /// Add user to tenant.
    public func addUser(tenantId: String, userId: String) async throws {
        let request = AddUserToTenantRequest(userId: userId)
        try await http.post("/v1/tenants/\(tenantId)/users", body: request)
    }

    /// Remove user from tenant.
    public func removeUser(tenantId: String, userId: String) async throws {
        try await http.delete("/v1/tenants/\(tenantId)/users/\(userId)")
    }
}

// MARK: - Additional Types

/// Tenant statistics.
public struct TenantStats: Codable, Sendable {
    public let secretCount: Int
    public let userCount: Int
    public let kmsKeyCount: Int
    public let storageUsed: Int64?
    public let lastActivity: Date?

    enum CodingKeys: String, CodingKey {
        case secretCount = "secret_count"
        case userCount = "user_count"
        case kmsKeyCount = "kms_key_count"
        case storageUsed = "storage_used"
        case lastActivity = "last_activity"
    }
}

/// Request to add user to tenant.
public struct AddUserToTenantRequest: Codable, Sendable {
    public let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }

    public init(userId: String) {
        self.userId = userId
    }
}

/// Tenant filter.
public struct TenantFilter: Sendable {
    public let status: TenantStatus?
    public let limit: Int
    public let offset: Int

    public init(status: TenantStatus? = nil, limit: Int = 50, offset: Int = 0) {
        self.status = status
        self.limit = limit
        self.offset = offset
    }
}
