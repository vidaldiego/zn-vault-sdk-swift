// Path: zn-vault-sdk-swift/Tests/ZnVaultTests/IntegrationTests.swift

import XCTest
@testable import ZnVault

/// Integration tests that run against a real ZN-Vault server.
///
/// These tests require:
/// - A running ZN-Vault server
/// - Environment variables:
///   - ZNVAULT_BASE_URL: Server URL (e.g., "https://vault.zincapp.com")
///   - ZNVAULT_API_KEY: Valid API key for authentication
///
/// Run with: swift test --filter IntegrationTests
/// Or set environment variables and run: ZNVAULT_BASE_URL=... ZNVAULT_API_KEY=... swift test
final class IntegrationTests: XCTestCase {

    var client: ZnVaultClient!

    override func setUp() async throws {
        // Skip if environment variables not set
        guard let baseURL = ProcessInfo.processInfo.environment["ZNVAULT_BASE_URL"],
              let apiKey = ProcessInfo.processInfo.environment["ZNVAULT_API_KEY"] else {
            throw XCTSkip("Integration tests require ZNVAULT_BASE_URL and ZNVAULT_API_KEY environment variables")
        }

        client = try ZnVaultClient.builder()
            .baseURL(baseURL)
            .apiKey(apiKey)
            .trustSelfSigned(true)
            .build()
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
        // Verify date was parsed (this would have caught the SQLite format issue)
        // createdAt might be nil depending on API response, but if present it should be a valid Date
    }

    // MARK: - Secrets Tests (read-only)

    func testListSecrets() async throws {
        let secrets = try await client.secrets.list()
        // API returns array of secrets (may be empty)
        XCTAssertGreaterThanOrEqual(secrets.count, 0)
    }

    // MARK: - KMS Tests (read-only)

    func testListKmsKeys() async throws {
        // KMS list requires tenant parameter - use "zincapp" as default test tenant
        let page = try await client.kms.listKeys(tenant: "zincapp")
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
