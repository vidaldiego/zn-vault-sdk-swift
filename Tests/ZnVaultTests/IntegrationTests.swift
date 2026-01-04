// Path: zn-vault-sdk-swift/Tests/ZnVaultTests/IntegrationTests.swift

import XCTest
@testable import ZnVault

/// Integration tests that run against a real ZN-Vault server.
///
/// These tests require:
/// - A running ZN-Vault server
/// - Environment variables:
///   - ZNVAULT_BASE_URL: Server URL (e.g., "https://localhost:8443")
///
/// Authentication (one of):
///   - ZNVAULT_API_KEY: Valid API key for authentication
///   - ZNVAULT_USERNAME + ZNVAULT_PASSWORD: Username/password for JWT login
///
/// Run with: swift test --filter IntegrationTests
/// Or set environment variables and run: ZNVAULT_BASE_URL=... ZNVAULT_USERNAME=... ZNVAULT_PASSWORD=... swift test

// MARK: - Health Integration Tests

final class HealthIntegrationTests: XCTestCase {

    var client: ZnVaultClient!

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"] != nil else {
            throw XCTSkip("Integration tests require ZNVAULT_BASE_URL environment variable")
        }
        client = try TestConfig.createTestClient()
    }

    func testHealthCheck() async throws {
        let health = try await client.health.check()
        XCTAssertEqual(health.status, "ok")
        print("✓ Health status: \(health.status)")
    }

    func testIsHealthy() async throws {
        let healthy = await client.health.isHealthy()
        XCTAssertTrue(healthy)
        print("✓ Health check successful")
    }
}

// MARK: - Authentication Integration Tests

final class AuthIntegrationTests: XCTestCase {

    var client: ZnVaultClient!

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"] != nil else {
            throw XCTSkip("Integration tests require ZNVAULT_BASE_URL environment variable")
        }
        client = try TestConfig.createTestClient()
    }

    func testLoginSuperadmin() async throws {
        let response = try await client.auth.login(
            username: TestConfig.Users.superadminUsername,
            password: TestConfig.Users.superadminPassword
        )

        XCTAssertNotNil(response.accessToken)
        XCTAssertNotNil(response.refreshToken)
        XCTAssertGreaterThan(response.expiresIn, 0)

        print("✓ Logged in as superadmin, token expires in \(response.expiresIn)s")
    }

    func testLoginReaderUser() async throws {
        let response = try await client.auth.login(
            username: TestConfig.Users.readerUsername,
            password: TestConfig.Users.readerPassword
        )

        XCTAssertNotNil(response.accessToken)
        XCTAssertNotNil(response.refreshToken)
        print("✓ Logged in as reader user")
    }

    func testLoginWriterUser() async throws {
        let response = try await client.auth.login(
            username: TestConfig.Users.writerUsername,
            password: TestConfig.Users.writerPassword
        )

        XCTAssertNotNil(response.accessToken)
        XCTAssertNotNil(response.refreshToken)
        print("✓ Logged in as writer user")
    }

    func testLoginInvalidCredentials() async throws {
        do {
            _ = try await client.auth.login(
                username: "invalid_user",
                password: "wrong_password"
            )
            XCTFail("Should have thrown authentication error")
        } catch {
            print("✓ Invalid credentials correctly rejected")
        }
    }

    func testGetCurrentUser() async throws {
        _ = try await client.auth.login(
            username: TestConfig.Users.superadminUsername,
            password: TestConfig.Users.superadminPassword
        )

        let response = try await client.auth.me()

        XCTAssertEqual(response.user.username, TestConfig.Users.superadminUsername)
        XCTAssertNotNil(response.user.id)
        print("✓ Current user: \(response.user.username) (\(response.user.role?.rawValue ?? "unknown"))")
    }
}

// MARK: - Secrets Integration Tests

final class SecretsIntegrationTests: XCTestCase {

    var client: ZnVaultClient!
    var createdSecretIds: [String] = []

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"] != nil else {
            throw XCTSkip("Integration tests require ZNVAULT_BASE_URL environment variable")
        }
        // Use tenant admin - has full tenant permissions including secret:read:value
        // (tenant has allow_admin_secret_access=true set by sdk-entrypoint.js)
        client = try await TestConfig.createTenantAdminClient()
        createdSecretIds = []
    }

    override func tearDown() async throws {
        // Cleanup created secrets
        for id in createdSecretIds {
            do {
                try await client.secrets.delete(id: id)
                print("  Cleaned up secret: \(id)")
            } catch {
                // Ignore cleanup errors
            }
        }
        createdSecretIds = []
    }

    func testCreateCredentialSecret() async throws {
        let alias = TestConfig.uniqueAlias("creds")

        let secret = try await client.secrets.create(
            alias: alias,
            type: .credential,
            data: [
                "username": "testuser",
                "password": "testpass123"
            ],
            tags: ["test", "credential"],
            tenant: TestConfig.defaultTenant
        )

        createdSecretIds.append(secret.id)

        XCTAssertNotNil(secret.id)
        XCTAssertEqual(secret.alias, alias)
        XCTAssertEqual(secret.tenant, TestConfig.defaultTenant)
        XCTAssertEqual(secret.type, SecretType.credential)
        XCTAssertEqual(secret.version, 1)

        print("✓ Created credential secret: \(secret.id)")
        print("  Alias: \(secret.alias)")
        print("  Version: \(secret.version)")
    }

    func testCreateOpaqueSecret() async throws {
        let alias = TestConfig.uniqueAlias("opaque")

        let secret = try await client.secrets.create(
            alias: alias,
            type: .opaque,
            data: [
                "api_key": "sk_live_abc123",
                "api_secret": "secret_xyz789"
            ],
            tenant: TestConfig.defaultTenant
        )

        createdSecretIds.append(secret.id)

        XCTAssertNotNil(secret.id)
        XCTAssertEqual(secret.type, SecretType.opaque)

        print("✓ Created opaque secret: \(secret.id)")
    }

    func testDecryptSecret() async throws {
        let alias = TestConfig.uniqueAlias("decrypt")

        let created = try await client.secrets.create(
            alias: alias,
            type: .credential,
            data: [
                "username": "decryptuser",
                "password": "decryptpass"
            ],
            tenant: TestConfig.defaultTenant
        )

        createdSecretIds.append(created.id)

        // Decrypt it
        let data = try await client.secrets.decrypt(id: created.id)

        XCTAssertEqual(data.data["username"]?.value as? String, "decryptuser")
        XCTAssertEqual(data.data["password"]?.value as? String, "decryptpass")

        print("✓ Decrypted secret successfully")
        print("  Username: \(data.data["username"]?.value ?? "nil")")
    }

    func testUpdateSecret() async throws {
        let alias = TestConfig.uniqueAlias("update")

        let created = try await client.secrets.create(
            alias: alias,
            type: .opaque,
            data: ["key": "original_value"],
            tenant: TestConfig.defaultTenant
        )

        createdSecretIds.append(created.id)
        XCTAssertEqual(created.version, 1)

        // Update it
        let updated = try await client.secrets.update(
            id: created.id,
            data: ["key": "updated_value"]
        )

        XCTAssertEqual(updated.version, 2)

        // Verify the value changed
        let data = try await client.secrets.decrypt(id: updated.id)
        XCTAssertEqual(data.data["key"]?.value as? String, "updated_value")

        print("✓ Updated secret, version: \(created.version) -> \(updated.version)")
    }

    func testRotateSecret() async throws {
        let alias = TestConfig.uniqueAlias("rotate")

        let created = try await client.secrets.create(
            alias: alias,
            type: .credential,
            data: [
                "username": "user",
                "password": "oldpass"
            ],
            tenant: TestConfig.defaultTenant
        )

        createdSecretIds.append(created.id)

        // Rotate it
        let rotated = try await client.secrets.rotate(
            id: created.id,
            data: [
                "username": "user",
                "password": "newpass"
            ]
        )

        XCTAssertEqual(rotated.version, 2)

        // Verify new value
        let data = try await client.secrets.decrypt(id: rotated.id)
        XCTAssertEqual(data.data["password"]?.value as? String, "newpass")

        print("✓ Rotated secret, version: \(created.version) -> \(rotated.version)")
    }

    func testSecretVersionHistory() async throws {
        let alias = TestConfig.uniqueAlias("history")

        // Create a secret
        let created = try await client.secrets.create(
            alias: alias,
            type: .opaque,
            data: ["key": "v1"],
            tenant: TestConfig.defaultTenant
        )

        createdSecretIds.append(created.id)
        XCTAssertEqual(created.version, 1)

        // Update it to create v2
        _ = try await client.secrets.update(
            id: created.id,
            data: ["key": "v2"]
        )

        // Update again to create v3
        _ = try await client.secrets.update(
            id: created.id,
            data: ["key": "v3"]
        )

        // Get version history
        let history = try await client.secrets.getHistory(id: created.id)

        XCTAssertGreaterThanOrEqual(history.count, 2)
        print("✓ Got \(history.count) versions in history")

        // Verify history contains expected versions
        let versions = history.map { $0.version }
        XCTAssertTrue(versions.contains(1), "History should contain version 1")
        XCTAssertTrue(versions.contains(2), "History should contain version 2")

        print("  Versions: \(versions)")
    }

    func testListSecrets() async throws {
        // Create some secrets
        for i in 0..<3 {
            let secret = try await client.secrets.create(
                alias: TestConfig.uniqueAlias("list-\(i)"),
                type: .opaque,
                data: ["index": i],
                tenant: TestConfig.defaultTenant
            )
            createdSecretIds.append(secret.id)
        }

        // List secrets
        let secrets = try await client.secrets.list()

        XCTAssertGreaterThanOrEqual(secrets.count, 3)
        print("✓ Listed \(secrets.count) secrets")
    }

    func testDeleteSecret() async throws {
        let alias = TestConfig.uniqueAlias("delete")

        let created = try await client.secrets.create(
            alias: alias,
            type: .opaque,
            data: ["key": "value"],
            tenant: TestConfig.defaultTenant
        )

        // Delete it (don't add to cleanup list since we're testing delete)
        try await client.secrets.delete(id: created.id)

        // Verify it's gone
        do {
            _ = try await client.secrets.get(id: created.id)
            XCTFail("Should have thrown not found error")
        } catch {
            print("✓ Deleted secret: \(created.id)")
        }
    }
}

// MARK: - KMS Integration Tests

final class KmsIntegrationTests: XCTestCase {

    var client: ZnVaultClient!
    var createdKeyIds: [String] = []

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"] != nil else {
            throw XCTSkip("Integration tests require ZNVAULT_BASE_URL environment variable")
        }
        // Use tenant admin - has access to tenant's KMS keys
        client = try await TestConfig.createTenantAdminClient()
        createdKeyIds = []
    }

    override func tearDown() async throws {
        // Schedule deletion for created keys
        for keyId in createdKeyIds {
            do {
                _ = try await client.kms.scheduleKeyDeletion(keyId: keyId, pendingWindowDays: 7)
                print("  Scheduled deletion for key: \(keyId)")
            } catch {
                // Ignore cleanup errors
            }
        }
        createdKeyIds = []
    }

    func testListKeys() async throws {
        let page = try await client.kms.listKeys(tenant: TestConfig.defaultTenant)
        XCTAssertNotNil(page.items)
        print("✓ Listed \(page.items.count) keys")
    }
}

// MARK: - User Integration Tests

final class UserIntegrationTests: XCTestCase {

    var client: ZnVaultClient!
    var createdUserIds: [String] = []

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"] != nil else {
            throw XCTSkip("Integration tests require ZNVAULT_BASE_URL environment variable")
        }
        client = try await TestConfig.createSuperadminClient()
        createdUserIds = []
    }

    override func tearDown() async throws {
        // Cleanup created users
        for id in createdUserIds {
            do {
                try await client.users.delete(id: id)
                print("  Cleaned up user: \(id)")
            } catch {
                // Ignore cleanup errors
            }
        }
        createdUserIds = []
    }

    func testListUsers() async throws {
        let page = try await client.users.list()
        XCTAssertNotNil(page.items)
        print("✓ Listed \(page.items.count) users")
    }

    func testCreateUser() async throws {
        let username = TestConfig.uniqueId("testuser")

        let user = try await client.users.create(
            username: username,
            password: "TestPassword123#",
            email: "\(username)@example.com",
            tenantId: TestConfig.defaultTenant,
            role: "user"
        )

        createdUserIds.append(user.id)

        XCTAssertNotNil(user.id)
        // Username returned includes tenant prefix: "tenant/username"
        let expectedUsername = "\(TestConfig.defaultTenant)/\(username)"
        XCTAssertEqual(user.username, expectedUsername)

        print("✓ Created user: \(user.username)")
        print("  ID: \(user.id)")
    }

    func testDeleteUser() async throws {
        let username = TestConfig.uniqueId("deleteuser")

        let user = try await client.users.create(
            username: username,
            password: "TestPassword123#",
            tenantId: TestConfig.defaultTenant
        )

        // Delete it (don't add to cleanup list)
        try await client.users.delete(id: user.id)

        print("✓ Deleted user: \(user.username)")
    }
}

// MARK: - Tenant Integration Tests

final class TenantIntegrationTests: XCTestCase {

    var client: ZnVaultClient!

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"] != nil else {
            throw XCTSkip("Integration tests require ZNVAULT_BASE_URL environment variable")
        }
        client = try await TestConfig.createSuperadminClient()
    }

    func testListTenants() async throws {
        let page = try await client.tenants.list()
        XCTAssertNotNil(page.items)
        print("✓ Listed \(page.items.count) tenants")
    }
}

// MARK: - Role Integration Tests

final class RoleIntegrationTests: XCTestCase {

    var client: ZnVaultClient!

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"] != nil else {
            throw XCTSkip("Integration tests require ZNVAULT_BASE_URL environment variable")
        }
        client = try await TestConfig.createSuperadminClient()
    }

    func testListRoles() async throws {
        let page = try await client.roles.list()
        XCTAssertNotNil(page.items)
        print("✓ Listed \(page.items.count) roles")
    }
}

// MARK: - Audit Integration Tests

final class AuditIntegrationTests: XCTestCase {

    var client: ZnVaultClient!

    override func setUp() async throws {
        guard ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"] != nil else {
            throw XCTSkip("Integration tests require ZNVAULT_BASE_URL environment variable")
        }
        client = try await TestConfig.createSuperadminClient()
    }

    func testListAuditLogs() async throws {
        let page = try await client.audit.list()
        XCTAssertNotNil(page.items)
        print("✓ Listed \(page.items.count) audit entries")
    }
}

// MARK: - Legacy Integration Tests (for backward compatibility)
// NOTE: These tests use superadmin login for full access. For API key testing,
// ensure the API key has the necessary permissions.

final class IntegrationTests: XCTestCase {

    var client: ZnVaultClient!
    static let defaultTenant = "sdk-test"

    override func setUp() async throws {
        // Skip if base URL not set
        guard ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"] != nil else {
            throw XCTSkip("Integration tests require ZNVAULT_BASE_URL environment variable")
        }

        // Use superadmin login for full access
        client = try await TestConfig.createSuperadminClient()
    }

    // MARK: - Health Check

    func testHealthCheck() async throws {
        let health = try await client.health.check()
        XCTAssertEqual(health.status, "ok")
    }

    // MARK: - Auth Tests

    func testMe() async throws {
        let response = try await client.auth.me()
        XCTAssertNotNil(response.user.id)
        XCTAssertNotNil(response.user.username)
        XCTAssertNotNil(response.authMethod)
    }

    // MARK: - Secrets Tests (read-only)

    func testListSecrets() async throws {
        let secrets = try await client.secrets.list()
        XCTAssertGreaterThanOrEqual(secrets.count, 0)
    }

    // MARK: - KMS Tests (read-only)

    func testListKmsKeys() async throws {
        let page = try await client.kms.listKeys(tenant: Self.defaultTenant)
        XCTAssertNotNil(page.items)
    }

    // MARK: - Admin Tests (read-only)

    func testListUsers() async throws {
        let page = try await client.users.list()
        XCTAssertNotNil(page.items)
    }

    func testListTenants() async throws {
        let page = try await client.tenants.list()
        XCTAssertNotNil(page.items)
    }

    func testListRoles() async throws {
        let page = try await client.roles.list()
        XCTAssertNotNil(page.items)
    }

    // MARK: - Audit Tests (read-only)

    func testListAuditLogs() async throws {
        let page = try await client.audit.list()
        XCTAssertNotNil(page.items)
    }
}
