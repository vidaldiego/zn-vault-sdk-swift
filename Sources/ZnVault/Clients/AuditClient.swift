// Path: zn-vault-sdk-swift/Sources/ZnVault/Clients/AuditClient.swift

import Foundation

/// Client for audit log operations.
public final class AuditClient: Sendable {
    private let http: ZnVaultHttpClient

    internal init(http: ZnVaultHttpClient) {
        self.http = http
    }

    // MARK: - Query Operations

    /// List audit entries with filters.
    public func list(filter: AuditFilter = AuditFilter()) async throws -> Page<AuditEntry> {
        var query: [String: String] = [:]

        if let clientCn = filter.clientCn {
            query["clientCn"] = clientCn
        }
        if let action = filter.action {
            query["action"] = action
        }
        if let resource = filter.resource {
            query["resource"] = resource
        }
        if let result = filter.result {
            query["result"] = result
        }
        if let userId = filter.userId {
            query["userId"] = userId
        }
        if let tenantId = filter.tenantId {
            query["tenantId"] = tenantId
        }
        if let startDate = filter.startDate {
            query["startDate"] = ISO8601DateFormatter().string(from: startDate)
        }
        if let endDate = filter.endDate {
            query["endDate"] = ISO8601DateFormatter().string(from: endDate)
        }
        query["limit"] = String(filter.limit)
        query["offset"] = String(filter.offset)

        return try await http.get("/v1/audit", query: query, responseType: Page<AuditEntry>.self)
    }

    /// Get audit entry by ID.
    public func get(id: Int) async throws -> AuditEntry {
        return try await http.get("/v1/audit/\(id)", responseType: AuditEntry.self)
    }

    /// Stream all audit entries matching filter.
    public func listAll(filter: AuditFilter = AuditFilter()) -> AsyncThrowingStream<AuditEntry, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                var currentOffset = filter.offset
                var hasMore = true

                while hasMore {
                    do {
                        let currentFilter = AuditFilter(
                            clientCn: filter.clientCn,
                            action: filter.action,
                            resource: filter.resource,
                            result: filter.result,
                            startDate: filter.startDate,
                            endDate: filter.endDate,
                            userId: filter.userId,
                            tenantId: filter.tenantId,
                            limit: filter.limit,
                            offset: currentOffset
                        )
                        let page = try await self.list(filter: currentFilter)
                        for entry in page.items {
                            continuation.yield(entry)
                        }
                        hasMore = page.hasMore
                        currentOffset += page.items.count
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Statistics

    /// Get audit statistics.
    public func getStats(
        startDate: Date? = nil,
        endDate: Date? = nil,
        tenantId: String? = nil
    ) async throws -> AuditStats {
        var query: [String: String] = [:]

        if let startDate = startDate {
            query["startDate"] = ISO8601DateFormatter().string(from: startDate)
        }
        if let endDate = endDate {
            query["endDate"] = ISO8601DateFormatter().string(from: endDate)
        }
        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }

        return try await http.get("/v1/audit/stats", query: query, responseType: AuditStats.self)
    }

    // MARK: - Integrity Verification

    /// Verify audit chain integrity.
    public func verify() async throws -> AuditVerifyResult {
        return try await http.get("/v1/audit/verify", responseType: AuditVerifyResult.self)
    }

    // MARK: - Export

    /// Export audit logs.
    public func export(
        format: AuditExportFormat = .json,
        filter: AuditFilter = AuditFilter()
    ) async throws -> Data {
        var query: [String: String] = [:]

        query["format"] = format.rawValue
        if let clientCn = filter.clientCn {
            query["clientCn"] = clientCn
        }
        if let action = filter.action {
            query["action"] = action
        }
        if let resource = filter.resource {
            query["resource"] = resource
        }
        if let startDate = filter.startDate {
            query["startDate"] = ISO8601DateFormatter().string(from: startDate)
        }
        if let endDate = filter.endDate {
            query["endDate"] = ISO8601DateFormatter().string(from: endDate)
        }

        // For export, we need raw data response
        let response = try await http.get("/v1/audit/export", query: query, responseType: ExportResponse.self)
        return response.data
    }

    // MARK: - Search

    /// Search audit logs with text query.
    public func search(
        query: String,
        filter: AuditFilter = AuditFilter()
    ) async throws -> Page<AuditEntry> {
        var queryParams: [String: String] = ["q": query]

        if let action = filter.action {
            queryParams["action"] = action
        }
        if let startDate = filter.startDate {
            queryParams["startDate"] = ISO8601DateFormatter().string(from: startDate)
        }
        if let endDate = filter.endDate {
            queryParams["endDate"] = ISO8601DateFormatter().string(from: endDate)
        }
        queryParams["limit"] = String(filter.limit)
        queryParams["offset"] = String(filter.offset)

        return try await http.get("/v1/audit/search", query: queryParams, responseType: Page<AuditEntry>.self)
    }

    // MARK: - Activity Summary

    /// Get recent activity for a user.
    public func getUserActivity(userId: String, limit: Int = 100) async throws -> [AuditEntry] {
        let filter = AuditFilter(userId: userId, limit: limit)
        let page = try await list(filter: filter)
        return page.items
    }

    /// Get recent activity for a tenant.
    public func getTenantActivity(tenantId: String, limit: Int = 100) async throws -> [AuditEntry] {
        let filter = AuditFilter(tenantId: tenantId, limit: limit)
        let page = try await list(filter: filter)
        return page.items
    }

    /// Get recent failures.
    public func getRecentFailures(limit: Int = 100) async throws -> [AuditEntry] {
        let filter = AuditFilter(result: "failure", limit: limit)
        let page = try await list(filter: filter)
        return page.items
    }
}

// MARK: - Additional Types

/// Export response wrapper.
private struct ExportResponse: Codable, Sendable {
    let data: Data

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.data = Data(string.utf8)
        } else {
            self.data = try container.decode(Data.self)
        }
    }
}
