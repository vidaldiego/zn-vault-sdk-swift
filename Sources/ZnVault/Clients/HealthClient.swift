// Path: zn-vault-sdk-swift/Sources/ZnVault/Clients/HealthClient.swift

import Foundation

/// Client for health check operations.
public final class HealthClient: Sendable {
    private let http: ZnVaultHttpClient

    internal init(http: ZnVaultHttpClient) {
        self.http = http
    }

    // MARK: - Health Checks

    /// Get overall health status.
    public func check() async throws -> HealthResponse {
        return try await http.get("/v1/health", responseType: HealthResponse.self)
    }

    /// Check if service is healthy.
    public func isHealthy() async -> Bool {
        do {
            let health = try await check()
            return health.isHealthy
        } catch {
            return false
        }
    }

    /// Wait for service to become healthy.
    public func waitForHealthy(
        timeout: TimeInterval = 60,
        checkInterval: TimeInterval = 1
    ) async throws -> Bool {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if await isHealthy() {
                return true
            }
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }

        return false
    }

    // MARK: - Component Health

    /// Check database health.
    public func checkDatabase() async throws -> DatabaseHealth {
        let health = try await check()
        guard let dbHealth = health.database else {
            throw ZnVaultError.serverError(message: "Database health not available")
        }
        return dbHealth
    }

    /// Check KMS health.
    public func checkKms() async throws -> KmsHealth {
        let health = try await check()
        guard let kmsHealth = health.kms else {
            throw ZnVaultError.serverError(message: "KMS health not available")
        }
        return kmsHealth
    }

    // MARK: - Readiness

    /// Check if service is ready to handle requests.
    public func ready() async throws -> ReadinessResponse {
        return try await http.get("/v1/health/ready", responseType: ReadinessResponse.self)
    }

    /// Check if service is live (basic connectivity).
    public func live() async throws -> LivenessResponse {
        return try await http.get("/v1/health/live", responseType: LivenessResponse.self)
    }
}

// MARK: - Additional Types

/// Readiness check response.
public struct ReadinessResponse: Codable, Sendable {
    public let ready: Bool
    public let checks: [String: CheckResult]?

    public var isReady: Bool {
        return ready
    }
}

/// Liveness check response.
public struct LivenessResponse: Codable, Sendable {
    public let alive: Bool
    public let timestamp: Date?

    public var isAlive: Bool {
        return alive
    }
}

/// Individual check result.
public struct CheckResult: Codable, Sendable {
    public let status: String
    public let message: String?
    public let latency: Double?

    public var isHealthy: Bool {
        return status == "ok" || status == "healthy" || status == "pass"
    }
}
