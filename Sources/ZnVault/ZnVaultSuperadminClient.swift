// Path: zn-vault-sdk-swift/Sources/ZnVault/ZnVaultSuperadminClient.swift

import Foundation

/// Superadmin-scoped client for cross-tenant administrative operations.
///
/// Use this client only with a superadmin principal. For tenant operations
/// (encrypt/decrypt, secrets, your own tenant's users/roles/policies), use
/// ``ZnVaultClient``.
///
/// The split is intentional: a service that holds a tenant-scoped API key
/// cannot compile against the superadmin surface, so it can't accidentally
/// call cross-tenant operations even if it wanted to.
///
/// Example:
/// ```swift
/// let admin = try ZnVaultSuperadminClient.builder()
///     .baseURL("https://vault.example.com:8443")
///     .apiKey("znv_superadmin_xxx")
///     .build()
///
/// let tenant = try await admin.tenants.create(...)
/// ```
public final class ZnVaultSuperadminClient: Sendable {
    /// HTTP client for API requests.
    public let http: ZnVaultHttpClient

    /// Tenant CRUD (superadmin only).
    public let tenants: TenantClient

    /// Audit log across all tenants.
    public let audit: AuditClient

    /// Health check operations.
    public let health: HealthClient

    /// Create client with configuration.
    public init(config: ZnVaultConfig) {
        self.http = ZnVaultHttpClient(config: config)
        self.tenants = TenantClient(http: http)
        self.audit = AuditClient(http: http)
        self.health = HealthClient(http: http)
    }

    /// Create client with base URL.
    public convenience init(baseURL: String) {
        self.init(config: ZnVaultConfig(baseURL: baseURL))
    }

    /// Create a configuration builder.
    public static func builder() -> Builder {
        return Builder()
    }

    /// Builder for creating ZnVaultSuperadminClient.
    public final class Builder: @unchecked Sendable {
        private var baseURL: String = ""
        private var apiKey: String?
        private var accessToken: String?
        private var timeout: TimeInterval = 30
        private var trustSelfSigned: Bool = false
        private var insecureTLS: Bool = false

        public init() {}

        @discardableResult
        public func baseURL(_ url: String) -> Builder {
            self.baseURL = url
            return self
        }

        @discardableResult
        public func apiKey(_ key: String) -> Builder {
            self.apiKey = key
            return self
        }

        @discardableResult
        public func accessToken(_ token: String) -> Builder {
            self.accessToken = token
            return self
        }

        @discardableResult
        public func timeout(_ timeout: TimeInterval) -> Builder {
            self.timeout = timeout
            return self
        }

        @discardableResult
        public func trustSelfSigned(_ trust: Bool) -> Builder {
            self.trustSelfSigned = trust
            return self
        }

        @discardableResult
        public func insecureTLS(_ insecure: Bool) -> Builder {
            self.insecureTLS = insecure
            return self
        }

        public func build() throws -> ZnVaultSuperadminClient {
            guard !baseURL.isEmpty else {
                throw ZnVaultError.configurationError(message: "Base URL is required")
            }
            let config = ZnVaultConfig(
                baseURL: baseURL,
                apiKey: apiKey,
                accessToken: accessToken,
                timeout: timeout,
                trustSelfSigned: trustSelfSigned,
                insecureTLS: insecureTLS
            )
            return ZnVaultSuperadminClient(config: config)
        }
    }
}
