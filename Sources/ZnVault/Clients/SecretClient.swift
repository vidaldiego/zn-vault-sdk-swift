// Path: zn-vault-sdk-swift/Sources/ZnVault/Clients/SecretClient.swift

import Foundation

/// Client for secret management operations.
public final class SecretClient: Sendable {
    private let http: ZnVaultHttpClient

    internal init(http: ZnVaultHttpClient) {
        self.http = http
    }

    // MARK: - CRUD Operations

    /// Create a new secret.
    /// - Parameters:
    ///   - alias: The alias/name for the secret
    ///   - type: The type of secret (opaque, credential, setting)
    ///   - subType: Optional semantic sub-type (password, apiKey, certificate, etc.)
    ///   - data: The secret data as key-value pairs
    ///   - fileName: Optional filename for file-based secrets
    ///   - expiresAt: Optional natural expiration date (for certs/tokens)
    ///   - ttlUntil: Optional user-defined expiration date
    ///   - tags: Optional tags for categorization
    ///   - contentType: Optional MIME type
    ///   - tenant: Optional tenant (required for superadmin)
    public func create(
        alias: String,
        type: SecretType,
        subType: SecretSubType? = nil,
        data: [String: Any],
        fileName: String? = nil,
        expiresAt: Date? = nil,
        ttlUntil: Date? = nil,
        tags: [String]? = nil,
        contentType: String? = nil,
        tenant: String? = nil
    ) async throws -> Secret {
        let request = CreateSecretRequest(
            alias: alias,
            type: type,
            subType: subType,
            data: data.mapValues { AnyCodable($0) },
            fileName: fileName,
            expiresAt: expiresAt,
            ttlUntil: ttlUntil,
            tags: tags,
            contentType: contentType,
            tenant: tenant
        )
        return try await http.post("/v1/secrets", body: request, responseType: Secret.self)
    }

    /// Create a new secret with request object.
    public func create(request: CreateSecretRequest) async throws -> Secret {
        return try await http.post("/v1/secrets", body: request, responseType: Secret.self)
    }

    /// Get secret metadata by ID.
    public func get(id: String) async throws -> Secret {
        return try await http.get("/v1/secrets/\(id)/meta", responseType: Secret.self)
    }

    /// Get secret by alias.
    public func getByAlias(alias: String) async throws -> Secret {
        // URL-encode the alias in case it contains special characters
        let encodedAlias = alias.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? alias
        return try await http.get("/v1/secrets/alias/\(encodedAlias)", responseType: Secret.self)
    }

    /// Decrypt and get secret value.
    public func decrypt(id: String) async throws -> SecretData {
        return try await http.post("/v1/secrets/\(id)/decrypt", responseType: SecretData.self)
    }

    /// Update secret data (creates new version).
    public func update(
        id: String,
        data: [String: Any],
        subType: SecretSubType? = nil,
        fileName: String? = nil,
        expiresAt: Date? = nil,
        ttlUntil: Date? = nil,
        tags: [String]? = nil,
        contentType: String? = nil
    ) async throws -> Secret {
        let request = UpdateSecretRequest(
            data: data.mapValues { AnyCodable($0) },
            subType: subType,
            fileName: fileName,
            expiresAt: expiresAt,
            ttlUntil: ttlUntil,
            tags: tags,
            contentType: contentType
        )
        return try await http.put("/v1/secrets/\(id)", body: request, responseType: Secret.self)
    }

    /// Update secret with request object.
    public func update(id: String, request: UpdateSecretRequest) async throws -> Secret {
        return try await http.put("/v1/secrets/\(id)", body: request, responseType: Secret.self)
    }

    /// Rotate secret (creates new version with new data).
    public func rotate(id: String, data: [String: Any]) async throws -> Secret {
        let request = RotateSecretRequest(data: data.mapValues { AnyCodable($0) })
        return try await http.post("/v1/secrets/\(id)/rotate", body: request, responseType: Secret.self)
    }

    /// Delete a secret.
    public func delete(id: String) async throws {
        try await http.delete("/v1/secrets/\(id)")
    }

    // MARK: - Listing

    /// List secrets with optional filters.
    /// Returns an array of secrets (metadata only, not decrypted values).
    public func list(filter: SecretFilter = SecretFilter()) async throws -> [Secret] {
        var query: [String: String] = [:]

        if let type = filter.type {
            query["type"] = type.rawValue
        }
        if let subType = filter.subType {
            query["subType"] = subType.rawValue
        }
        if let fileMime = filter.fileMime {
            query["fileMime"] = fileMime
        }
        if let expiringBefore = filter.expiringBefore {
            query["expiringBefore"] = ISO8601DateFormatter().string(from: expiringBefore)
        }
        if let aliasPattern = filter.aliasPattern {
            query["aliasPrefix"] = aliasPattern  // Server uses aliasPrefix parameter
        }
        if let tags = filter.tags, !tags.isEmpty {
            query["tags"] = tags.joined(separator: ",")
        }
        query["limit"] = String(filter.limit)
        query["offset"] = String(filter.offset)

        return try await http.get("/v1/secrets", query: query, responseType: [Secret].self)
    }

    /// List all secrets using async sequence.
    /// Note: The API returns all matching secrets in a single response,
    /// so this is just a convenience wrapper that yields each secret.
    public func listAll(filter: SecretFilter = SecretFilter()) -> AsyncThrowingStream<Secret, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let secrets = try await self.list(filter: filter)
                    for secret in secrets {
                        continuation.yield(secret)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Version History

    /// Get secret version history.
    public func getHistory(id: String) async throws -> [SecretVersion] {
        let response = try await http.get("/v1/secrets/\(id)/history", responseType: SecretHistoryResponse.self)
        return response.history
    }

    /// Decrypt a specific version.
    public func decryptVersion(id: String, version: Int) async throws -> SecretData {
        return try await http.post("/v1/secrets/\(id)/history/\(version)/decrypt", responseType: SecretData.self)
    }

    /// Rollback to a previous version.
    public func rollback(id: String, version: Int) async throws -> Secret {
        let request = RollbackRequest(version: version)
        return try await http.post("/v1/secrets/\(id)/rollback", body: request, responseType: Secret.self)
    }

    // MARK: - Convenience Methods for Typed Secret Creation

    /// Create a password credential secret.
    public func createPassword(
        alias: String,
        username: String,
        password: String,
        url: String? = nil,
        notes: String? = nil,
        tags: [String]? = nil,
        ttlUntil: Date? = nil
    ) async throws -> Secret {
        var data: [String: Any] = ["username": username, "password": password]
        if let url = url { data["url"] = url }
        if let notes = notes { data["notes"] = notes }

        return try await create(
            alias: alias,
            type: .credential,
            subType: .password,
            data: data,
            ttlUntil: ttlUntil,
            tags: tags
        )
    }

    /// Create an API key credential secret.
    public func createApiKey(
        alias: String,
        key: String,
        secret: String? = nil,
        endpoint: String? = nil,
        notes: String? = nil,
        tags: [String]? = nil,
        ttlUntil: Date? = nil
    ) async throws -> Secret {
        var data: [String: Any] = ["key": key]
        if let secret = secret { data["secret"] = secret }
        if let endpoint = endpoint { data["endpoint"] = endpoint }
        if let notes = notes { data["notes"] = notes }

        return try await create(
            alias: alias,
            type: .credential,
            subType: .apiKey,
            data: data,
            ttlUntil: ttlUntil,
            tags: tags
        )
    }

    /// Create a certificate secret with automatic expiration tracking.
    public func createCertificate(
        alias: String,
        content: Data,
        fileName: String? = nil,
        chain: [String]? = nil,
        expiresAt: Date? = nil,
        tags: [String]? = nil
    ) async throws -> Secret {
        var data: [String: Any] = ["content": content.base64EncodedString()]
        if let chain = chain { data["chain"] = chain }

        return try await create(
            alias: alias,
            type: .opaque,
            subType: .certificate,
            data: data,
            fileName: fileName,
            expiresAt: expiresAt,
            tags: tags,
            contentType: "application/x-pem-file"
        )
    }

    /// Create a private key secret.
    public func createPrivateKey(
        alias: String,
        privateKey: Data,
        fileName: String? = nil,
        passphrase: String? = nil,
        tags: [String]? = nil
    ) async throws -> Secret {
        var data: [String: Any] = ["privateKey": privateKey.base64EncodedString()]
        if let passphrase = passphrase { data["passphrase"] = passphrase }

        return try await create(
            alias: alias,
            type: .opaque,
            subType: .privateKey,
            data: data,
            fileName: fileName,
            tags: tags
        )
    }

    /// Create a key pair secret (public + private key).
    public func createKeypair(
        alias: String,
        privateKey: Data,
        publicKey: Data,
        fileName: String? = nil,
        passphrase: String? = nil,
        tags: [String]? = nil
    ) async throws -> Secret {
        var data: [String: Any] = [
            "privateKey": privateKey.base64EncodedString(),
            "publicKey": publicKey.base64EncodedString()
        ]
        if let passphrase = passphrase { data["passphrase"] = passphrase }

        return try await create(
            alias: alias,
            type: .opaque,
            subType: .keypair,
            data: data,
            fileName: fileName,
            tags: tags
        )
    }

    /// Create a token secret (JWT, OAuth, bearer token).
    public func createToken(
        alias: String,
        token: String,
        tokenType: String? = nil,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        tags: [String]? = nil
    ) async throws -> Secret {
        var data: [String: Any] = ["token": token]
        if let tokenType = tokenType { data["tokenType"] = tokenType }
        if let refreshToken = refreshToken { data["refreshToken"] = refreshToken }

        return try await create(
            alias: alias,
            type: .opaque,
            subType: .token,
            data: data,
            expiresAt: expiresAt,
            tags: tags
        )
    }

    /// Create a JSON configuration setting.
    public func createJsonSetting(
        alias: String,
        content: [String: Any],
        tags: [String]? = nil
    ) async throws -> Secret {
        return try await create(
            alias: alias,
            type: .setting,
            subType: .json,
            data: ["content": content],
            tags: tags,
            contentType: "application/json"
        )
    }

    /// Create a YAML configuration setting.
    public func createYamlSetting(
        alias: String,
        content: String,
        tags: [String]? = nil
    ) async throws -> Secret {
        return try await create(
            alias: alias,
            type: .setting,
            subType: .yaml,
            data: ["content": content],
            tags: tags,
            contentType: "application/x-yaml"
        )
    }

    /// Create an environment variables setting (.env format).
    public func createEnvSetting(
        alias: String,
        content: [String: String],
        tags: [String]? = nil
    ) async throws -> Secret {
        let envContent = content.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")

        return try await create(
            alias: alias,
            type: .setting,
            subType: .env,
            data: ["content": envContent],
            tags: tags,
            contentType: "text/plain"
        )
    }

    // MARK: - Convenience Methods for Filtering

    /// List secrets by sub-type.
    public func listBySubType(
        _ subType: SecretSubType,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Secret] {
        return try await list(filter: SecretFilter(subType: subType, limit: limit, offset: offset))
    }

    /// List secrets by type.
    public func listByType(
        _ type: SecretType,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Secret] {
        return try await list(filter: SecretFilter(type: type, limit: limit, offset: offset))
    }

    /// List certificates expiring before a specific date.
    public func listExpiringCertificates(
        before date: Date,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Secret] {
        return try await list(filter: SecretFilter(
            subType: .certificate,
            expiringBefore: date,
            limit: limit,
            offset: offset
        ))
    }

    /// List all expiring secrets (certificates, tokens) before a specific date.
    public func listExpiring(
        before date: Date,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Secret] {
        return try await list(filter: SecretFilter(
            expiringBefore: date,
            limit: limit,
            offset: offset
        ))
    }

    /// List secrets by alias prefix (hierarchical path).
    public func listByPath(
        _ aliasPrefix: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Secret] {
        return try await list(filter: SecretFilter(
            aliasPattern: aliasPrefix,
            limit: limit,
            offset: offset
        ))
    }

    /// List secrets matching a wildcard pattern.
    ///
    /// Use `*` as a wildcard to match any characters:
    /// - `web/*` matches all under "web/"
    /// - `*/env/*` matches paths containing "/env/"
    /// - `db-*/prod*` matches "db-mysql/production", "db-postgres/prod-us"
    /// - `*secret*` matches any alias containing "secret"
    ///
    /// Examples:
    /// ```swift
    /// // Find all production secrets
    /// let secrets = try await client.secrets.listByPattern("*/production/*")
    ///
    /// // Find all env configs
    /// let secrets = try await client.secrets.listByPattern("*/env/*")
    ///
    /// // Find secrets matching SQL-like pattern
    /// let secrets = try await client.secrets.listByPattern("*/env/secret_*")
    /// ```
    public func listByPattern(
        _ pattern: String,
        type: SecretType? = nil,
        subType: SecretSubType? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Secret] {
        return try await list(filter: SecretFilter(
            type: type,
            subType: subType,
            aliasPattern: pattern,
            limit: limit,
            offset: offset
        ))
    }

    /// Search secrets by pattern with multiple filters.
    ///
    /// Convenience method combining pattern matching with other filters.
    ///
    /// Example:
    /// ```swift
    /// // Find expiring certificates matching pattern
    /// let certs = try await client.secrets.search(
    ///     pattern: "*/ssl/*",
    ///     subType: .certificate,
    ///     expiringBefore: Date().addingTimeInterval(86400 * 30)
    /// )
    /// ```
    public func search(
        pattern: String? = nil,
        type: SecretType? = nil,
        subType: SecretSubType? = nil,
        tags: [String]? = nil,
        expiringBefore: Date? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Secret] {
        return try await list(filter: SecretFilter(
            type: type,
            subType: subType,
            expiringBefore: expiringBefore,
            aliasPattern: pattern,
            tags: tags,
            limit: limit,
            offset: offset
        ))
    }

    // MARK: - File Operations

    /// Upload a file as a secret.
    /// - Parameters:
    ///   - alias: The alias/name for the secret
    ///   - fileData: The file data to upload
    ///   - filename: The original filename
    ///   - subType: Optional sub-type (defaults to .file)
    ///   - contentType: Optional MIME type (auto-detected if not provided)
    ///   - expiresAt: Optional expiration date
    ///   - tags: Optional tags for categorization
    public func uploadFile(
        alias: String,
        fileData: Data,
        filename: String,
        subType: SecretSubType? = nil,
        contentType: String? = nil,
        expiresAt: Date? = nil,
        tags: [String]? = nil
    ) async throws -> Secret {
        let base64Content = fileData.base64EncodedString()
        let mimeType = contentType ?? detectMimeType(data: fileData) ?? "application/octet-stream"

        return try await create(
            alias: alias,
            type: .opaque,
            subType: subType ?? .file,
            data: [
                "filename": filename,
                "content": base64Content,
                "contentType": mimeType
            ],
            fileName: filename,
            expiresAt: expiresAt,
            tags: tags,
            contentType: mimeType
        )
    }

    /// Download file from secret.
    public func downloadFile(id: String) async throws -> (data: Data, filename: String, contentType: String, checksum: String?) {
        let secretData = try await decrypt(id: id)

        guard let content = secretData.data["content"]?.stringValue,
              let fileData = Data(base64Encoded: content) else {
            throw ZnVaultError.decodingError(underlying: NSError(
                domain: "ZnVault",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid file content"]
            ))
        }

        let filename = secretData.data["filename"]?.stringValue ?? secretData.fileName ?? "file"
        let contentType = secretData.data["contentType"]?.stringValue ?? secretData.fileMime ?? "application/octet-stream"
        let checksum = secretData.fileChecksum

        return (fileData, filename, contentType, checksum)
    }

    // MARK: - Keypair Generation

    /// Generate a cryptographic keypair (RSA, Ed25519, or ECDSA).
    /// - Parameters:
    ///   - algorithm: The keypair algorithm (RSA, Ed25519, ECDSA)
    ///   - alias: The alias/name for the keypair
    ///   - tenant: The tenant identifier
    ///   - rsaBits: RSA key size (2048 or 4096, required for RSA)
    ///   - ecdsaCurve: ECDSA curve (P-256 or P-384, required for ECDSA)
    ///   - comment: Optional comment for the keypair
    ///   - publishPublicKey: Whether to make the public key publicly accessible
    ///   - tags: Optional tags for categorization
    /// - Returns: Generated keypair with private and public key information
    public func generateKeypair(
        algorithm: KeypairAlgorithm,
        alias: String,
        tenant: String,
        rsaBits: RSABits? = nil,
        ecdsaCurve: ECDSACurve? = nil,
        comment: String? = nil,
        publishPublicKey: Bool? = nil,
        tags: [String]? = nil
    ) async throws -> GeneratedKeypair {
        let request = GenerateKeypairRequest(
            algorithm: algorithm,
            alias: alias,
            tenant: tenant,
            rsaBits: rsaBits,
            ecdsaCurve: ecdsaCurve,
            comment: comment,
            publishPublicKey: publishPublicKey,
            tags: tags
        )
        return try await http.post("/v1/secrets/generate-keypair", body: request, responseType: GeneratedKeypair.self)
    }

    /// Generate a keypair with a request object.
    public func generateKeypair(request: GenerateKeypairRequest) async throws -> GeneratedKeypair {
        return try await http.post("/v1/secrets/generate-keypair", body: request, responseType: GeneratedKeypair.self)
    }

    // MARK: - Public Key Publishing

    /// Publish a public key to make it publicly accessible.
    /// Only works for public key sub-types (ed25519_public_key, rsa_public_key, ecdsa_public_key).
    /// - Parameter secretId: The ID of the public key secret to publish
    /// - Returns: Information about the published key including public URL
    public func publish(secretId: String) async throws -> PublishResult {
        return try await http.post("/v1/secrets/\(secretId)/publish", responseType: PublishResult.self)
    }

    /// Unpublish a public key (make it private again).
    /// - Parameter secretId: The ID of the public key secret to unpublish
    public func unpublish(secretId: String) async throws {
        let _: SuccessResponse = try await http.post("/v1/secrets/\(secretId)/unpublish", responseType: SuccessResponse.self)
    }

    // MARK: - Public Key Retrieval (No Authentication Required)

    /// Get a published public key by tenant and alias.
    /// This endpoint does not require authentication.
    /// - Parameters:
    ///   - tenant: The tenant identifier
    ///   - alias: The key alias
    /// - Returns: Published public key information
    public func getPublicKey(tenant: String, alias: String) async throws -> PublishedPublicKey {
        let encodedAlias = alias.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? alias
        return try await http.getPublic("/v1/public/\(tenant)/\(encodedAlias)", responseType: PublishedPublicKey.self)
    }

    /// List all published public keys for a tenant.
    /// This endpoint does not require authentication.
    /// - Parameter tenant: The tenant identifier
    /// - Returns: Array of published public keys for the tenant
    public func listPublicKeys(tenant: String) async throws -> [PublishedPublicKey] {
        let response = try await http.getPublic("/v1/public/\(tenant)", responseType: PublicKeysListResponse.self)
        return response.keys
    }

    // MARK: - Helpers

    private func detectMimeType(data: Data) -> String? {
        guard data.count >= 4 else { return nil }

        let bytes = [UInt8](data.prefix(4))

        // JPEG
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "image/jpeg"
        }
        // PNG
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }
        // PDF
        if bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46 {
            return "application/pdf"
        }
        // ZIP
        if bytes[0] == 0x50 && bytes[1] == 0x4B {
            return "application/zip"
        }

        return nil
    }
}

// MARK: - Request Types

/// Request to rotate a secret.
public struct RotateSecretRequest: Codable, Sendable {
    public let data: [String: AnyCodable]

    public init(data: [String: AnyCodable]) {
        self.data = data
    }
}

/// Request to rollback a secret.
public struct RollbackRequest: Codable, Sendable {
    public let version: Int

    public init(version: Int) {
        self.version = version
    }
}
