// Path: zn-vault-sdk-swift/Sources/ZnVault/ZnVaultClient.swift

import Foundation

/// Main client for ZN-Vault API.
///
/// Example usage:
/// ```swift
/// let client = ZnVaultClient.builder()
///     .baseURL("https://vault.example.com:8443")
///     .apiKey("znv_xxxx")
///     .build()
///
/// // Login with credentials
/// let tokens = try await client.auth.login(username: "user", password: "pass")
///
/// // Create a secret
/// let secret = try await client.secrets.create(
///     alias: "api/prod/db-creds",
///     tenant: "acme",
///     type: .credential,
///     data: ["username": "dbuser", "password": "secret123"]
/// )
///
/// // Decrypt a secret
/// let data = try await client.secrets.decrypt(id: secret.id)
/// ```
public final class ZnVaultClient: Sendable {
    /// HTTP client for API requests.
    public let http: ZnVaultHttpClient

    /// Authentication operations.
    public let auth: AuthClient

    /// Secret management operations.
    public let secrets: SecretClient

    /// KMS operations.
    public let kms: KmsClient

    /// User management operations.
    public let users: UserClient

    /// Tenant management operations.
    public let tenants: TenantClient

    /// Role management operations.
    public let roles: RoleClient

    /// Policy management operations.
    public let policies: PolicyClient

    /// Audit log operations.
    public let audit: AuditClient

    /// Health check operations.
    public let health: HealthClient

    /// Create client with configuration.
    public init(config: ZnVaultConfig) {
        self.http = ZnVaultHttpClient(config: config)
        self.auth = AuthClient(http: http)
        self.secrets = SecretClient(http: http)
        self.kms = KmsClient(http: http)
        self.users = UserClient(http: http)
        self.tenants = TenantClient(http: http)
        self.roles = RoleClient(http: http)
        self.policies = PolicyClient(http: http)
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

    /// Builder for creating ZnVaultClient.
    public final class Builder: @unchecked Sendable {
        private var baseURL: String = ""
        private var apiKey: String?
        private var accessToken: String?
        private var timeout: TimeInterval = 30
        private var trustSelfSigned: Bool = false
        private var insecureTLS: Bool = false

        public init() {}

        /// Set base URL.
        @discardableResult
        public func baseURL(_ url: String) -> Builder {
            self.baseURL = url
            return self
        }

        /// Set API key for authentication.
        @discardableResult
        public func apiKey(_ key: String) -> Builder {
            self.apiKey = key
            return self
        }

        /// Set access token for authentication (JWT).
        @discardableResult
        public func accessToken(_ token: String) -> Builder {
            self.accessToken = token
            return self
        }

        /// Set request timeout.
        @discardableResult
        public func timeout(_ timeout: TimeInterval) -> Builder {
            self.timeout = timeout
            return self
        }

        /// Trust self-signed certificates (development only).
        @discardableResult
        public func trustSelfSigned(_ trust: Bool) -> Builder {
            self.trustSelfSigned = trust
            return self
        }

        /// Disable TLS certificate validation entirely (testing only).
        @discardableResult
        public func insecureTLS(_ insecure: Bool) -> Builder {
            self.insecureTLS = insecure
            return self
        }

        /// Build the client.
        public func build() throws -> ZnVaultClient {
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
            return ZnVaultClient(config: config)
        }
    }
}
