// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/Health.swift

import Foundation

/// Health check response.
public struct HealthResponse: Codable, Sendable {
    public let status: String
    public let version: String?
    public let uptime: Double?
    public let timestamp: Date?
    public let database: DatabaseHealth?
    public let kms: KmsHealth?

    public var isHealthy: Bool {
        status == "ok" || status == "healthy"
    }
}

/// Database health status.
public struct DatabaseHealth: Codable, Sendable {
    public let status: String
    public let connected: Bool?
    public let path: String?
}

/// KMS health status.
public struct KmsHealth: Codable, Sendable {
    public let status: String
    public let initialized: Bool?
    public let keyCount: Int?

    enum CodingKeys: String, CodingKey {
        case status, initialized
        case keyCount = "key_count"
    }
}
