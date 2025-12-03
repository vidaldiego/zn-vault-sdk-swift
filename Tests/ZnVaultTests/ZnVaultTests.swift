// Path: zn-vault-sdk-swift/Tests/ZnVaultTests/ZnVaultTests.swift

import XCTest
@testable import ZnVault

final class ZnVaultTests: XCTestCase {

    // MARK: - Configuration Tests

    func testConfigBuilder() {
        let config = ZnVaultConfig.Builder()
            .baseURL("https://vault.example.com:8443")
            .apiKey("test-key")
            .timeout(60)
            .trustSelfSigned(true)
            .build()

        XCTAssertEqual(config.baseURL, "https://vault.example.com:8443")
        XCTAssertEqual(config.apiKey, "test-key")
        XCTAssertEqual(config.timeout, 60)
        XCTAssertTrue(config.trustSelfSigned)
    }

    func testClientBuilder() throws {
        let client = try ZnVaultClient.builder()
            .baseURL("https://vault.example.com:8443")
            .apiKey("test-key")
            .build()

        XCTAssertNotNil(client.auth)
        XCTAssertNotNil(client.secrets)
        XCTAssertNotNil(client.kms)
        XCTAssertNotNil(client.users)
        XCTAssertNotNil(client.tenants)
        XCTAssertNotNil(client.roles)
        XCTAssertNotNil(client.policies)
        XCTAssertNotNil(client.audit)
        XCTAssertNotNil(client.health)
    }

    func testClientBuilderThrowsWithoutBaseURL() {
        XCTAssertThrowsError(try ZnVaultClient.builder().build()) { error in
            guard case ZnVaultError.configurationError(let message) = error else {
                XCTFail("Expected configurationError")
                return
            }
            XCTAssertTrue(message.contains("Base URL"))
        }
    }

    // MARK: - Model Tests

    func testSecretTypeEncoding() throws {
        let encoder = JSONEncoder()

        let opaque = SecretType.opaque
        let credential = SecretType.credential
        let setting = SecretType.setting

        XCTAssertEqual(try String(data: encoder.encode(opaque), encoding: .utf8), "\"opaque\"")
        XCTAssertEqual(try String(data: encoder.encode(credential), encoding: .utf8), "\"credential\"")
        XCTAssertEqual(try String(data: encoder.encode(setting), encoding: .utf8), "\"setting\"")
    }

    func testKeySpecEncoding() throws {
        let encoder = JSONEncoder()

        let aes256 = KeySpec.aes256
        let aes128 = KeySpec.aes128
        let rsa2048 = KeySpec.rsa2048

        XCTAssertEqual(try String(data: encoder.encode(aes256), encoding: .utf8), "\"AES_256\"")
        XCTAssertEqual(try String(data: encoder.encode(aes128), encoding: .utf8), "\"AES_128\"")
        XCTAssertEqual(try String(data: encoder.encode(rsa2048), encoding: .utf8), "\"RSA_2048\"")
    }

    func testKeyUsageEncoding() throws {
        let encoder = JSONEncoder()

        let encryptDecrypt = KeyUsage.encryptDecrypt
        let signVerify = KeyUsage.signVerify
        let generateDataKey = KeyUsage.generateDataKey

        XCTAssertEqual(try String(data: encoder.encode(encryptDecrypt), encoding: .utf8), "\"ENCRYPT_DECRYPT\"")
        XCTAssertEqual(try String(data: encoder.encode(signVerify), encoding: .utf8), "\"SIGN_VERIFY\"")
        XCTAssertEqual(try String(data: encoder.encode(generateDataKey), encoding: .utf8), "\"GENERATE_DATA_KEY\"")
    }

    func testPolicyEffectEncoding() throws {
        let encoder = JSONEncoder()

        let allow = PolicyEffect.allow
        let deny = PolicyEffect.deny

        XCTAssertEqual(try String(data: encoder.encode(allow), encoding: .utf8), "\"Allow\"")
        XCTAssertEqual(try String(data: encoder.encode(deny), encoding: .utf8), "\"Deny\"")
    }

    func testPolicyDocumentToJSON() throws {
        let document = PolicyDocument(
            statements: [
                PolicyStatement(
                    effect: .allow,
                    actions: ["secret:read:*"],
                    resources: ["secret:acme/*"]
                )
            ]
        )

        let json = try document.toJSON()
        // Note: JSON encoder escapes "/" as "\/"
        XCTAssertTrue(json.contains("Allow"))
        XCTAssertTrue(json.contains("secret:read:"))
        XCTAssertTrue(json.contains("secret:acme"))
    }

    func testAnyCodable() throws {
        let stringValue = AnyCodable("hello")
        let intValue = AnyCodable(42)
        let doubleValue = AnyCodable(3.14)
        let boolValue = AnyCodable(true)
        let arrayValue = AnyCodable([1, 2, 3])
        let dictValue = AnyCodable(["key": "value"])

        XCTAssertEqual(stringValue.stringValue, "hello")
        XCTAssertEqual(intValue.intValue, 42)
        XCTAssertEqual(doubleValue.doubleValue, 3.14)
        XCTAssertEqual(boolValue.boolValue, true)
        XCTAssertEqual(arrayValue.arrayValue?.count, 3)
        XCTAssertNotNil(dictValue.dictionaryValue)
    }

    func testAnyCodableEncoding() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let value = AnyCodable(["name": "test", "count": 42])
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"name\""))
        XCTAssertTrue(json.contains("\"test\""))
        XCTAssertTrue(json.contains("\"count\""))
        XCTAssertTrue(json.contains("42"))
    }

    // MARK: - Filter Tests

    func testSecretFilter() {
        let filter = SecretFilter(
            tenant: "acme",
            env: "production",
            type: .credential,
            limit: 100
        )

        XCTAssertEqual(filter.tenant, "acme")
        XCTAssertEqual(filter.env, "production")
        XCTAssertEqual(filter.type, .credential)
        XCTAssertEqual(filter.limit, 100)
        XCTAssertEqual(filter.offset, 0)
    }

    func testKeyFilter() {
        let filter = KeyFilter(
            state: .enabled,
            usage: .encryptDecrypt,
            limit: 50
        )

        XCTAssertEqual(filter.state, .enabled)
        XCTAssertEqual(filter.usage, .encryptDecrypt)
        XCTAssertEqual(filter.limit, 50)
    }

    func testAuditFilter() {
        let startDate = Date()
        let endDate = Date()

        let filter = AuditFilter(
            action: "secret:read",
            result: "success",
            startDate: startDate,
            endDate: endDate,
            limit: 200
        )

        XCTAssertEqual(filter.action, "secret:read")
        XCTAssertEqual(filter.result, "success")
        XCTAssertEqual(filter.startDate, startDate)
        XCTAssertEqual(filter.endDate, endDate)
        XCTAssertEqual(filter.limit, 200)
    }

    // MARK: - Request Types Tests

    func testCreateSecretRequest() throws {
        let request = CreateSecretRequest(
            alias: "test/secret",
            tenant: "acme",
            type: .credential,
            data: ["username": AnyCodable("user"), "password": AnyCodable("pass")],
            tags: ["test"]
        )

        XCTAssertEqual(request.alias, "test/secret")
        XCTAssertEqual(request.tenant, "acme")
        XCTAssertEqual(request.type, .credential)
        XCTAssertEqual(request.tags, ["test"])
    }

    func testCreateKmsKeyRequest() throws {
        let request = CreateKmsKeyRequest(
            alias: "alias/test-key",
            description: "Test key",
            usage: .encryptDecrypt,
            keySpec: .aes256,
            rotationEnabled: true,
            rotationDays: 90
        )

        XCTAssertEqual(request.alias, "alias/test-key")
        XCTAssertEqual(request.description, "Test key")
        XCTAssertEqual(request.usage, .encryptDecrypt)
        XCTAssertEqual(request.keySpec, .aes256)
        XCTAssertEqual(request.rotationEnabled, true)
        XCTAssertEqual(request.rotationDays, 90)
    }

    // MARK: - Error Tests

    func testZnVaultErrorDescriptions() {
        let errors: [ZnVaultError] = [
            .httpError(statusCode: 500, message: "Internal error", details: nil),
            .authenticationError(message: "Invalid credentials"),
            .authorizationError(message: "Access denied"),
            .notFound(resource: "secret-123"),
            .validationError(message: "Invalid input", fields: ["name": "required"]),
            .rateLimitExceeded(retryAfter: 60),
            .conflict(message: "Already exists"),
            .serverError(message: "Database error"),
            .notAuthenticated,
            .tokenExpired
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: - Page Tests

    func testPageHasMore() {
        let pageWithMore = Page<String>(
            items: ["a", "b", "c"],
            total: 10,
            limit: 3,
            offset: 0,
            nextMarker: "next"
        )

        let lastPage = Page<String>(
            items: ["a"],
            total: 10,
            limit: 3,
            offset: 9,
            nextMarker: nil
        )

        XCTAssertTrue(pageWithMore.hasMore)
        XCTAssertFalse(lastPage.hasMore)
    }
}
