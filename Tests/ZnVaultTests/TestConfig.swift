// Path: zn-vault-sdk-swift/Tests/ZnVaultTests/TestConfig.swift

import Foundation
@testable import ZnVault

/// Test configuration for integration tests.
/// Uses environment variables if set, otherwise falls back to defaults.
enum TestConfig {
    // Test server - can be overridden with ZNVAULT_BASE_URL env var
    static var baseURL: String {
        ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"] ?? "https://localhost:8443"
    }

    // Test users - can be overridden with ZNVAULT_USERNAME and ZNVAULT_PASSWORD env vars
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

        // Tenant admin - manages tenant resources (requires tenant/username format)
        static var tenantAdminUsername: String {
            ProcessInfo.processInfo.environment["ZNVAULT_TENANT_ADMIN_USERNAME"] ?? "zincapp/zincadmin"
        }
        static var tenantAdminPassword: String {
            ProcessInfo.processInfo.environment["ZNVAULT_TENANT_ADMIN_PASSWORD"] ?? "Admin123456#"
        }

        // Regular user - limited access (requires tenant/username format)
        static var regularUserUsername: String {
            ProcessInfo.processInfo.environment["ZNVAULT_REGULAR_USER_USERNAME"] ?? "zincapp/zincuser"
        }
        static var regularUserPassword: String {
            ProcessInfo.processInfo.environment["ZNVAULT_REGULAR_USER_PASSWORD"] ?? "Admin123456#"
        }
    }

    // Default tenant for tests
    static var defaultTenant: String {
        ProcessInfo.processInfo.environment["ZNVAULT_DEFAULT_TENANT"] ?? "zincapp"
    }

    /// Create a client for testing (insecure TLS for localhost).
    static func createTestClient() throws -> ZnVaultClient {
        return try ZnVaultClient.builder()
            .baseURL(baseURL)
            .trustSelfSigned(true)
            .insecureTLS(true)
            .build()
    }

    /// Create an authenticated client as superadmin.
    static func createSuperadminClient() async throws -> ZnVaultClient {
        let client = try createTestClient()
        _ = try await client.auth.login(
            username: Users.superadminUsername,
            password: Users.superadminPassword
        )
        return client
    }

    /// Create an authenticated client as tenant admin.
    static func createTenantAdminClient() async throws -> ZnVaultClient {
        let client = try createTestClient()
        _ = try await client.auth.login(
            username: Users.tenantAdminUsername,
            password: Users.tenantAdminPassword
        )
        return client
    }

    /// Create an authenticated client as regular user.
    static func createRegularUserClient() async throws -> ZnVaultClient {
        let client = try createTestClient()
        _ = try await client.auth.login(
            username: Users.regularUserUsername,
            password: Users.regularUserPassword
        )
        return client
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
