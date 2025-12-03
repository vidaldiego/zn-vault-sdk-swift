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
    ///   - tenant: Optional tenant ID. If not provided, uses the authenticated user's tenant.
    ///   - type: The type of secret (opaque, credential, setting)
    ///   - data: The secret data as key-value pairs
    ///   - env: Optional environment (e.g., "production", "staging")
    ///   - service: Optional service name
    ///   - tags: Optional tags for categorization
    ///   - ttlUntil: Optional expiration date
    public func create(
        alias: String,
        tenant: String? = nil,
        type: SecretType,
        data: [String: Any],
        env: String? = nil,
        service: String? = nil,
        tags: [String]? = nil,
        ttlUntil: Date? = nil
    ) async throws -> Secret {
        let request = CreateSecretRequest(
            alias: alias,
            tenant: tenant,
            type: type,
            data: data.mapValues { AnyCodable($0) },
            env: env,
            service: service,
            tags: tags,
            ttlUntil: ttlUntil
        )
        return try await http.post("/v1/secrets", body: request, responseType: Secret.self)
    }

    /// Create a new secret with request object.
    public func create(request: CreateSecretRequest) async throws -> Secret {
        return try await http.post("/v1/secrets", body: request, responseType: Secret.self)
    }

    /// Get secret metadata by ID.
    public func get(id: String) async throws -> Secret {
        return try await http.get("/v1/secrets/\(id)", responseType: Secret.self)
    }

    /// Get secret by alias.
    public func getByAlias(tenant: String, alias: String) async throws -> Secret {
        let query = ["tenant": tenant, "alias": alias]
        return try await http.get("/v1/secrets/by-alias", query: query, responseType: Secret.self)
    }

    /// Decrypt and get secret value.
    public func decrypt(id: String) async throws -> SecretData {
        return try await http.post("/v1/secrets/\(id)/decrypt", responseType: SecretData.self)
    }

    /// Update secret data (creates new version).
    public func update(id: String, data: [String: Any], tags: [String]? = nil) async throws -> Secret {
        let request = UpdateSecretRequest(
            data: data.mapValues { AnyCodable($0) },
            tags: tags
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

        if let tenant = filter.tenant {
            query["tenant"] = tenant
        }
        if let env = filter.env {
            query["env"] = env
        }
        if let service = filter.service {
            query["service"] = service
        }
        if let type = filter.type {
            query["type"] = type.rawValue
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
        return try await http.get("/v1/secrets/\(id)/history", responseType: [SecretVersion].self)
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

    // MARK: - File Operations

    /// Upload a file as a secret.
    /// - Parameters:
    ///   - alias: The alias/name for the secret
    ///   - tenant: Optional tenant ID. If not provided, uses the authenticated user's tenant.
    ///   - fileData: The file data to upload
    ///   - filename: The original filename
    ///   - contentType: Optional MIME type (auto-detected if not provided)
    ///   - tags: Optional tags for categorization
    public func uploadFile(
        alias: String,
        tenant: String? = nil,
        fileData: Data,
        filename: String,
        contentType: String? = nil,
        tags: [String]? = nil
    ) async throws -> Secret {
        let base64Content = fileData.base64EncodedString()
        let mimeType = contentType ?? detectMimeType(data: fileData) ?? "application/octet-stream"

        return try await create(
            alias: alias,
            tenant: tenant,
            type: .opaque,
            data: [
                "filename": filename,
                "content": base64Content,
                "contentType": mimeType
            ],
            tags: tags
        )
    }

    /// Download file from secret.
    public func downloadFile(id: String) async throws -> (data: Data, filename: String, contentType: String) {
        let secretData = try await decrypt(id: id)

        guard let content = secretData.data["content"]?.stringValue,
              let fileData = Data(base64Encoded: content) else {
            throw ZnVaultError.decodingError(underlying: NSError(
                domain: "ZnVault",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid file content"]
            ))
        }

        let filename = secretData.data["filename"]?.stringValue ?? "file"
        let contentType = secretData.data["contentType"]?.stringValue ?? "application/octet-stream"

        return (fileData, filename, contentType)
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
