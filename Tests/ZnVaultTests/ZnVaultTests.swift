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
            type: .credential,
            tags: ["test"],
            pageSize: 100
        )

        XCTAssertEqual(filter.type, SecretType.credential)
        XCTAssertEqual(filter.tags, ["test"])
        XCTAssertEqual(filter.pageSize, 100)
        XCTAssertEqual(filter.page, 1)
    }

    func testSecretFilterWithPattern() {
        // Test wildcard pattern matching
        let filter = SecretFilter(
            aliasPattern: "*/env/secret_*",
            page: 1,
            pageSize: 50
        )

        XCTAssertEqual(filter.aliasPattern, "*/env/secret_*")
        XCTAssertEqual(filter.aliasPrefix, "*/env/secret_*")  // Backward compat
        XCTAssertEqual(filter.pageSize, 50)
    }

    func testSecretFilterBackwardCompatibility() {
        // Test backward compatibility with aliasPrefix parameter
        let filter = SecretFilter(
            aliasPrefix: "web/*",
            page: 1,
            pageSize: 100
        )

        XCTAssertEqual(filter.aliasPattern, "web/*")
        XCTAssertEqual(filter.aliasPrefix, "web/*")
    }

    func testKeyFilter() {
        let filter = KeyFilter(
            tenant: "test-tenant",
            state: .enabled,
            usage: .encryptDecrypt,
            limit: 50
        )

        XCTAssertEqual(filter.tenant, "test-tenant")
        XCTAssertEqual(filter.state, KeyState.enabled)
        XCTAssertEqual(filter.usage, KeyUsage.encryptDecrypt)
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
            type: .credential,
            data: ["username": AnyCodable("user"), "password": AnyCodable("pass")],
            tags: ["test"]
        )

        XCTAssertEqual(request.alias, "test/secret")
        XCTAssertEqual(request.type, SecretType.credential)
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

    // MARK: - API Key Request Types Tests

    func testCreateApiKeyRequest() throws {
        let request = CreateApiKeyRequest(
            name: "test-api-key",
            permissions: ["secret:read:metadata", "secret:read:value"],
            expiresInDays: 90
        )

        XCTAssertEqual(request.name, "test-api-key")
        XCTAssertEqual(request.expiresInDays, 90)
        XCTAssertEqual(request.permissions, ["secret:read:metadata", "secret:read:value"])
    }

    func testCreateApiKeyRequestWithConditions() throws {
        let conditions = ApiKeyConditions(
            ip: ["10.0.0.0/8"],
            methods: ["GET"]
        )

        let request = CreateApiKeyRequest(
            name: "restricted-key",
            permissions: ["secret:read:metadata"],
            expiresInDays: 30,
            conditions: conditions
        )

        XCTAssertEqual(request.name, "restricted-key")
        XCTAssertEqual(request.permissions, ["secret:read:metadata"])
        XCTAssertNotNil(request.conditions)
        XCTAssertEqual(request.conditions?.ip, ["10.0.0.0/8"])
    }

    func testCreateApiKeyRequestEncoding() throws {
        let encoder = JSONEncoder()

        let request = CreateApiKeyRequest(
            name: "my-service-key",
            permissions: ["secret:read:metadata"]
        )

        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"name\""))
        XCTAssertTrue(json.contains("\"my-service-key\""))
        XCTAssertTrue(json.contains("\"permissions\""))
    }

    func testApiKeyDecoding() throws {
        let json = """
        {
            "id": "key-123",
            "name": "test-key",
            "prefix": "znv_abc",
            "user_id": "user-456",
            "created_at": "2024-01-01T00:00:00Z",
            "expires_at": "2024-04-01T00:00:00Z",
            "last_used": "2024-01-15T00:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let apiKey = try decoder.decode(ApiKey.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(apiKey.id, "key-123")
        XCTAssertEqual(apiKey.name, "test-key")
        XCTAssertEqual(apiKey.prefix, "znv_abc")
        XCTAssertEqual(apiKey.userId, "user-456")
        XCTAssertNotNil(apiKey.createdAt)
        XCTAssertNotNil(apiKey.expiresAt)
        XCTAssertNotNil(apiKey.lastUsed)
    }

    func testCreateApiKeyResponseDecoding() throws {
        let json = """
        {
            "key": "znv_abc123xyz789",
            "api_key": {
                "id": "key-123",
                "name": "test-key",
                "prefix": "znv_abc",
                "created_at": "2024-01-01T00:00:00Z",
                "expires_at": "2024-04-01T00:00:00Z"
            },
            "message": "API key created successfully"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let response = try decoder.decode(CreateApiKeyResponse.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(response.key, "znv_abc123xyz789")
        XCTAssertEqual(response.apiKey?.id, "key-123")
        XCTAssertEqual(response.apiKey?.name, "test-key")
        XCTAssertEqual(response.apiKey?.prefix, "znv_abc")
        XCTAssertEqual(response.message, "API key created successfully")
    }

    // MARK: - Date Format Tests (using real API decoder)

    func testDateDecodingWithSQLiteFormat() throws {
        // Test with SQLite datetime format that the real API returns
        let json = """
        {
            "id": "user-123",
            "username": "testuser",
            "totp_enabled": false,
            "created_at": "2025-12-03 14:18:42"
        }
        """

        let decoder = makeApiDecoder()
        let user = try decoder.decode(User.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(user.id, "user-123")
        XCTAssertEqual(user.username, "testuser")
        XCTAssertNotNil(user.createdAt)
    }

    func testDateDecodingWithISO8601Format() throws {
        // Test with ISO8601 format
        let json = """
        {
            "id": "user-123",
            "username": "testuser",
            "totp_enabled": false,
            "created_at": "2025-12-03T14:18:42Z"
        }
        """

        let decoder = makeApiDecoder()
        let user = try decoder.decode(User.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(user.id, "user-123")
        XCTAssertNotNil(user.createdAt)
    }

    func testDateDecodingWithISO8601FractionalSeconds() throws {
        // Test with ISO8601 + fractional seconds
        let json = """
        {
            "id": "user-123",
            "username": "testuser",
            "totp_enabled": false,
            "created_at": "2025-12-03T14:18:42.123Z"
        }
        """

        let decoder = makeApiDecoder()
        let user = try decoder.decode(User.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(user.id, "user-123")
        XCTAssertNotNil(user.createdAt)
    }

    func testDateDecodingWithPostgreSQLFractionalSeconds() throws {
        // Test with PostgreSQL datetime format with 5-digit fractional seconds
        // This is the exact format the server returns: "2025-12-22 19:36:44.72083"
        let json = """
        {
            "id": "user-123",
            "username": "testuser",
            "totp_enabled": false,
            "created_at": "2025-12-22 19:36:44.72083"
        }
        """

        let decoder = makeApiDecoder()
        let user = try decoder.decode(User.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(user.id, "user-123")
        XCTAssertNotNil(user.createdAt)
    }

    func testDateDecodingWithPostgreSQLMilliseconds() throws {
        // Test with PostgreSQL datetime format with 3-digit fractional seconds
        let json = """
        {
            "id": "user-123",
            "username": "testuser",
            "totp_enabled": false,
            "created_at": "2025-12-22 19:36:44.720"
        }
        """

        let decoder = makeApiDecoder()
        let user = try decoder.decode(User.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(user.id, "user-123")
        XCTAssertNotNil(user.createdAt)
    }

    func testDateDecodingWithPostgreSQLMicroseconds() throws {
        // Test with PostgreSQL datetime format with 6-digit fractional seconds (microseconds)
        let json = """
        {
            "id": "user-123",
            "username": "testuser",
            "totp_enabled": false,
            "created_at": "2025-12-22 19:36:44.720830"
        }
        """

        let decoder = makeApiDecoder()
        let user = try decoder.decode(User.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(user.id, "user-123")
        XCTAssertNotNil(user.createdAt)
    }

    func testMeResponseDecoding() throws {
        // Test the actual /auth/me response format from the API
        let json = """
        {
            "user": {
                "id": "user-123",
                "username": "testuser",
                "totp_enabled": false,
                "created_at": "2025-12-03 14:18:42"
            },
            "authMethod": "apikey"
        }
        """

        let decoder = makeApiDecoder()
        let response = try decoder.decode(MeResponse.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(response.user.id, "user-123")
        XCTAssertEqual(response.user.username, "testuser")
        XCTAssertEqual(response.authMethod, "apikey")
        XCTAssertNotNil(response.user.createdAt)
    }

    /// Creates a decoder matching the one used by ZnVaultHttpClient
    private func makeApiDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: string) {
                return date
            }

            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: string) {
                return date
            }

            // Try PostgreSQL/SQLite datetime format with fractional seconds: "YYYY-MM-DD HH:MM:SS.SSSSSS"
            let pgFormatter = DateFormatter()
            pgFormatter.timeZone = TimeZone(identifier: "UTC")

            pgFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
            if let date = pgFormatter.date(from: string) {
                return date
            }

            // Try with fewer fractional digits (5)
            pgFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSS"
            if let date = pgFormatter.date(from: string) {
                return date
            }

            // Try with milliseconds (3 digits)
            pgFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            if let date = pgFormatter.date(from: string) {
                return date
            }

            // Try SQLite datetime format without fractional seconds: "YYYY-MM-DD HH:MM:SS"
            pgFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let date = pgFormatter.date(from: string) {
                return date
            }

            // Try Unix timestamp
            if let timestamp = Double(string) {
                return Date(timeIntervalSince1970: timestamp)
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(string)"
            )
        }
        return decoder
    }
}
