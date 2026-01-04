// Path: zn-vault-sdk-swift/Tests/ZnVaultTests/TestConfig.swift

import Foundation
@testable import ZnVault

/// Thread-safe client cache to avoid rate limiting issues.
/// Caches authenticated clients by user type.
actor ClientCache {
    static let shared = ClientCache()

    private var clients: [String: ZnVaultClient] = [:]

    func getOrCreate(key: String, creator: () async throws -> ZnVaultClient) async throws -> ZnVaultClient {
        if let existing = clients[key] {
            return existing
        }
        let client = try await creator()
        clients[key] = client
        print("  (Created new client for: \(key))")
        return client
    }

    func clear() {
        clients.removeAll()
    }
}

/// Test configuration for integration tests.
/// Uses environment variables if set, otherwise falls back to defaults.
///
/// All test users use the standard password: SdkTest123456#
///
/// Usage:
///   # Start the SDK test environment first (from zn-vault root):
///   npm run test:sdk:start
///
///   # Run tests:
///   swift test
///
///   # Or run against production (not recommended):
///   ZNVAULT_BASE_URL=https://vault.example.com swift test
enum TestConfig {
    // Test server - defaults to SDK test environment (port 9443)
    static var baseURL: String {
        ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"] ?? "https://localhost:9443"
    }

    // Default tenant for tests
    static var defaultTenant: String {
        ProcessInfo.processInfo.environment["ZNVAULT_TENANT"] ?? "sdk-test"
    }

    // Secondary tenant for isolation tests
    static let tenant2 = "sdk-test-2"

    // Standard password for all test users (matches sdk-test-init.js)
    private static let standardPassword = "SdkTest123456#"

    // Test users - can be overridden with environment variables
    // Note: Username must be in format "tenant/username" for non-superadmin users.
    // Superadmin can omit tenant prefix. Email can also be used as username.
    enum Users {
        // Superadmin - full access (no tenant prefix required)
        static var superadminUsername: String {
            ProcessInfo.processInfo.environment["ZNVAULT_USERNAME"] ?? "admin"
        }
        static var superadminPassword: String {
            ProcessInfo.processInfo.environment["ZNVAULT_PASSWORD"] ?? "Admin123456#"
        }

        // Tenant admin - manages tenant resources with admin-crypto (requires tenant/username format)
        static var tenantAdminUsername: String {
            ProcessInfo.processInfo.environment["ZNVAULT_TENANT_ADMIN_USERNAME"] ?? "\(defaultTenant)/sdk-admin"
        }
        static var tenantAdminPassword: String {
            ProcessInfo.processInfo.environment["ZNVAULT_TENANT_ADMIN_PASSWORD"] ?? standardPassword
        }

        // Read-only user - can only read secrets (requires tenant/username format)
        static var readerUsername: String {
            ProcessInfo.processInfo.environment["ZNVAULT_READER_USERNAME"] ?? "\(defaultTenant)/sdk-reader"
        }
        static var readerPassword: String {
            ProcessInfo.processInfo.environment["ZNVAULT_READER_PASSWORD"] ?? standardPassword
        }

        // Read-write user - can read and write secrets (requires tenant/username format)
        static var writerUsername: String {
            ProcessInfo.processInfo.environment["ZNVAULT_WRITER_USERNAME"] ?? "\(defaultTenant)/sdk-writer"
        }
        static var writerPassword: String {
            ProcessInfo.processInfo.environment["ZNVAULT_WRITER_PASSWORD"] ?? standardPassword
        }

        // KMS user - can only use KMS operations (requires tenant/username format)
        static var kmsUserUsername: String {
            ProcessInfo.processInfo.environment["ZNVAULT_KMS_USER_USERNAME"] ?? "\(defaultTenant)/sdk-kms-user"
        }
        static var kmsUserPassword: String {
            ProcessInfo.processInfo.environment["ZNVAULT_KMS_USER_PASSWORD"] ?? standardPassword
        }

        // Certificate user - can manage certificates (requires tenant/username format)
        static var certUserUsername: String {
            ProcessInfo.processInfo.environment["ZNVAULT_CERT_USER_USERNAME"] ?? "\(defaultTenant)/sdk-cert-user"
        }
        static var certUserPassword: String {
            ProcessInfo.processInfo.environment["ZNVAULT_CERT_USER_PASSWORD"] ?? standardPassword
        }

        // Second tenant admin (for isolation testing)
        static var tenant2AdminUsername: String {
            ProcessInfo.processInfo.environment["ZNVAULT_TENANT2_ADMIN_USERNAME"] ?? "\(tenant2)/sdk-admin"
        }
        static var tenant2AdminPassword: String {
            ProcessInfo.processInfo.environment["ZNVAULT_TENANT2_ADMIN_PASSWORD"] ?? standardPassword
        }
    }

    // Pre-created API keys (created by sdk-test-init.js)
    enum ApiKeys {
        static var fullAccess: String? {
            ProcessInfo.processInfo.environment["ZNVAULT_API_KEY_FULL"]
        }
        static var readOnly: String? {
            ProcessInfo.processInfo.environment["ZNVAULT_API_KEY_READONLY"]
        }
        static var kmsOnly: String? {
            ProcessInfo.processInfo.environment["ZNVAULT_API_KEY_KMS"]
        }
        static var withIpRestriction: String? {
            ProcessInfo.processInfo.environment["ZNVAULT_API_KEY_WITH_IP"]
        }
        static var prodOnly: String? {
            ProcessInfo.processInfo.environment["ZNVAULT_API_KEY_PROD_ONLY"]
        }
    }

    // Test resources
    enum Resources {
        static var testSecretAlias: String {
            ProcessInfo.processInfo.environment["ZNVAULT_TEST_SECRET_ALIAS"] ?? "sdk-test/database/credentials"
        }
    }

    /// Create a client for testing (insecure TLS for localhost).
    static func createTestClient() throws -> ZnVaultClient {
        return try ZnVaultClient.builder()
            .baseURL(baseURL)
            .trustSelfSigned(true)
            .insecureTLS(true)
            .build()
    }

    /// Create an authenticated client as superadmin (cached).
    static func createSuperadminClient() async throws -> ZnVaultClient {
        return try await ClientCache.shared.getOrCreate(key: "superadmin") {
            let client = try createTestClient()
            _ = try await client.auth.login(
                username: Users.superadminUsername,
                password: Users.superadminPassword
            )
            return client
        }
    }

    /// Create an authenticated client as tenant admin (cached).
    static func createTenantAdminClient() async throws -> ZnVaultClient {
        return try await ClientCache.shared.getOrCreate(key: "tenant-admin") {
            let client = try createTestClient()
            _ = try await client.auth.login(
                username: Users.tenantAdminUsername,
                password: Users.tenantAdminPassword
            )
            return client
        }
    }

    /// Create an authenticated client as read-only user (cached).
    static func createReaderClient() async throws -> ZnVaultClient {
        return try await ClientCache.shared.getOrCreate(key: "reader") {
            let client = try createTestClient()
            _ = try await client.auth.login(
                username: Users.readerUsername,
                password: Users.readerPassword
            )
            return client
        }
    }

    /// Create an authenticated client as read-write user (cached).
    static func createWriterClient() async throws -> ZnVaultClient {
        return try await ClientCache.shared.getOrCreate(key: "writer") {
            let client = try createTestClient()
            _ = try await client.auth.login(
                username: Users.writerUsername,
                password: Users.writerPassword
            )
            return client
        }
    }

    /// Create an authenticated client as KMS user (cached).
    static func createKmsUserClient() async throws -> ZnVaultClient {
        return try await ClientCache.shared.getOrCreate(key: "kms-user") {
            let client = try createTestClient()
            _ = try await client.auth.login(
                username: Users.kmsUserUsername,
                password: Users.kmsUserPassword
            )
            return client
        }
    }

    /// Create an authenticated client as certificate user (cached).
    static func createCertUserClient() async throws -> ZnVaultClient {
        return try await ClientCache.shared.getOrCreate(key: "cert-user") {
            let client = try createTestClient()
            _ = try await client.auth.login(
                username: Users.certUserUsername,
                password: Users.certUserPassword
            )
            return client
        }
    }

    /// Create an authenticated client as second tenant admin (cached).
    static func createTenant2AdminClient() async throws -> ZnVaultClient {
        return try await ClientCache.shared.getOrCreate(key: "tenant2-admin") {
            let client = try createTestClient()
            _ = try await client.auth.login(
                username: Users.tenant2AdminUsername,
                password: Users.tenant2AdminPassword
            )
            return client
        }
    }

    /// Generate a unique ID for testing.
    static func uniqueId(_ prefix: String = "test") -> String {
        let uuid = UUID().uuidString.prefix(8).lowercased()
        return "\(prefix)-\(uuid)"
    }

    /// Generate a unique alias for testing.
    static func uniqueAlias(_ prefix: String = "test") -> String {
        let uuid = UUID().uuidString.prefix(8).lowercased()
        return "\(prefix)/sdk-test/\(uuid)"
    }
}
