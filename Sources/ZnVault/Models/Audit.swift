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

/// Audit log filter. The list is always scoped to the caller's tenant by
/// the server; there is no client-supplied tenant filter.
public struct AuditFilter: Sendable {
    public let clientCn: String?
    public let action: String?
    public let resource: String?
    public let result: String?
    public let startDate: Date?
    public let endDate: Date?
    public let userId: String?
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
public struct AuditVerificationInterval: Codable, Sendable {
    public let firstId: Int?
    public let lastId: Int?
}
public struct AuditVerifyResult: Codable, Sendable {
    public private(set) var valid: Bool
    public var entriesVerified: Int { authenticatedEntries ?? 0 }
    public let status: String?
    public let reason: String?
    public let reasons: [String]?
    public let errors: [String]?
    public let checkedEntries: Int?
    public let readEntries: Int?
    public let authenticatedEntries: Int?
    public let unverifiedEntries: Int?
    public let unsignedDetailsEntries: Int?
    public let scope: String?
    public let interval: AuditVerificationInterval?
    public let completed: Bool?
    public let startedAt: String?
    public let finishedAt: String?
    public let consistency: String?
    public let historicalCompleteness: String?
    public let brokenAt: Int?
    public let message: String?
    public let lastVerified: String?
    enum CodingKeys: String, CodingKey {
        case valid, status, reason, reasons, errors, checkedEntries, readEntries, authenticatedEntries, unverifiedEntries, unsignedDetailsEntries, scope, interval, completed, startedAt, finishedAt, consistency, historicalCompleteness, brokenAt, message, lastVerified
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        reasons = try c.decodeIfPresent([String].self, forKey: .reasons)
        errors = try c.decodeIfPresent([String].self, forKey: .errors)
        checkedEntries = try c.decodeIfPresent(Int.self, forKey: .checkedEntries)
        readEntries = try c.decodeIfPresent(Int.self, forKey: .readEntries)
        authenticatedEntries = try c.decodeIfPresent(Int.self, forKey: .authenticatedEntries)
        unverifiedEntries = try c.decodeIfPresent(Int.self, forKey: .unverifiedEntries)
        unsignedDetailsEntries = try c.decodeIfPresent(Int.self, forKey: .unsignedDetailsEntries)
        scope = try c.decodeIfPresent(String.self, forKey: .scope)
        interval = try c.decodeIfPresent(AuditVerificationInterval.self, forKey: .interval)
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed)
        startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
        finishedAt = try c.decodeIfPresent(String.self, forKey: .finishedAt)
        consistency = try c.decodeIfPresent(String.self, forKey: .consistency)
        historicalCompleteness = try c.decodeIfPresent(String.self, forKey: .historicalCompleteness)
        brokenAt = try c.decodeIfPresent(Int.self, forKey: .brokenAt)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        lastVerified = try c.decodeIfPresent(String.self, forKey: .lastVerified)
        let reportedValid = try c.decodeIfPresent(Bool.self, forKey: .valid) ?? false
        valid = reportedValid && status == "verified" && scope == "retained" && completed == true
            && (readEntries ?? 0) > 0 && authenticatedEntries == readEntries
            && unverifiedEntries == 0 && unsignedDetailsEntries == 0
    }
}

/// Export format.
public enum AuditExportFormat: String, Sendable {
    case json
    case csv
}
