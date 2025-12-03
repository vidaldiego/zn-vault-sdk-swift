// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/Audit.swift

import Foundation

/// Audit log entry.
public struct AuditEntry: Codable, Sendable, Identifiable {
    public let id: Int
    public let timestamp: Date
    public let clientCn: String?
    public let action: String
    public let resource: String
    public let result: String
    public let ip: String
    public let userId: String?
    public let username: String?
    public let tenantId: String?
    public let metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp = "ts"
        case clientCn = "client_cn"
        case action, resource, result, ip
        case userId = "user_id"
        case username
        case tenantId = "tenant_id"
        case metadata
    }
}

/// Audit log filter.
public struct AuditFilter: Sendable {
    public let clientCn: String?
    public let action: String?
    public let resource: String?
    public let result: String?
    public let startDate: Date?
    public let endDate: Date?
    public let userId: String?
    public let tenantId: String?
    public let limit: Int
    public let offset: Int

    public init(
        clientCn: String? = nil,
        action: String? = nil,
        resource: String? = nil,
        result: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        userId: String? = nil,
        tenantId: String? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) {
        self.clientCn = clientCn
        self.action = action
        self.resource = resource
        self.result = result
        self.startDate = startDate
        self.endDate = endDate
        self.userId = userId
        self.tenantId = tenantId
        self.limit = limit
        self.offset = offset
    }
}

/// Audit statistics.
public struct AuditStats: Codable, Sendable {
    public let total: Int
    public let byAction: [String: Int]
    public let byResult: [String: Int]
    public let recentFailures: Int

    enum CodingKeys: String, CodingKey {
        case total
        case byAction = "by_action"
        case byResult = "by_result"
        case recentFailures = "recent_failures"
    }
}

/// Audit chain verification result.
public struct AuditVerifyResult: Codable, Sendable {
    public let valid: Bool
    public let entriesVerified: Int
    public let brokenAt: Int?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case valid
        case entriesVerified = "entries_verified"
        case brokenAt = "broken_at"
        case message
    }
}

/// Export format.
public enum AuditExportFormat: String, Sendable {
    case json
    case csv
}
