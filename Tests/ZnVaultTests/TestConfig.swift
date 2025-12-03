// Path: zn-vault-sdk-swift/Tests/ZnVaultTests/TestConfig.swift

import Foundation
@testable import ZnVault

/// Test configuration for integration tests.
enum TestConfig {
    // Test server
    static let baseURL = "https://localhost:8443"

    // Test users
    enum Users {
        // Superadmin - full access
        static let superadminUsername = "admin"
        static let superadminPassword = "Admin123456#"

        // Tenant admin - manages tenant resources
        static let tenantAdminUsername = "zincadmin"
        static let tenantAdminPassword = "Admin123456#"

        // Regular user - limited access
        static let regularUserUsername = "zincuser"
        static let regularUserPassword = "Admin123456#"
    }

    // Default tenant for tests
    static let defaultTenant = "zincapp"

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
