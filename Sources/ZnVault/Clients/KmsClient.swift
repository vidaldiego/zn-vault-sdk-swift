// Path: zn-vault-sdk-swift/Sources/ZnVault/Clients/KmsClient.swift

import Foundation

/// Client for KMS (Key Management Service) operations.
public final class KmsClient: Sendable {
    private let http: ZnVaultHttpClient

    internal init(http: ZnVaultHttpClient) {
        self.http = http
    }

    // MARK: - Key Management

    /// Create a new KMS key.
    public func createKey(
        alias: String,
        description: String? = nil,
        usage: KeyUsage = .encryptDecrypt,
        keySpec: KeySpec = .aes256,
        tags: [String: String]? = nil,
        rotationEnabled: Bool = false,
        rotationDays: Int? = nil
    ) async throws -> KmsKey {
        let request = CreateKmsKeyRequest(
            alias: alias,
            description: description,
            usage: usage,
            keySpec: keySpec,
            tags: tags,
            rotationEnabled: rotationEnabled,
            rotationDays: rotationDays
        )
        return try await http.post("/v1/kms/keys", body: request, responseType: KmsKey.self)
    }

    /// Create a new KMS key with request object.
    public func createKey(request: CreateKmsKeyRequest) async throws -> KmsKey {
        return try await http.post("/v1/kms/keys", body: request, responseType: KmsKey.self)
    }

    /// Get key metadata by ID.
    public func getKey(keyId: String) async throws -> KmsKey {
        return try await http.get("/v1/kms/keys/\(keyId)", responseType: KmsKey.self)
    }

    /// List KMS keys for a tenant.
    public func listKeys(filter: KeyFilter) async throws -> Page<KmsKey> {
        var query: [String: String] = [:]

        query["tenant"] = filter.tenant
        if let state = filter.state {
            query["state"] = state.rawValue
        }
        if let usage = filter.usage {
            query["usage"] = usage.rawValue
        }
        query["limit"] = String(filter.limit)
        query["offset"] = String(filter.offset)

        return try await http.get("/v1/kms/keys", query: query, responseType: Page<KmsKey>.self)
    }

    /// List KMS keys for a tenant (convenience method).
    public func listKeys(tenant: String) async throws -> Page<KmsKey> {
        return try await listKeys(filter: KeyFilter(tenant: tenant))
    }

    /// Update key metadata.
    public func updateKey(keyId: String, request: UpdateKmsKeyRequest) async throws -> KmsKey {
        return try await http.patch("/v1/kms/keys/\(keyId)", body: request, responseType: KmsKey.self)
    }

    /// Enable a key.
    public func enableKey(keyId: String) async throws -> KmsKey {
        return try await http.post("/v1/kms/keys/\(keyId)/enable", responseType: KmsKey.self)
    }

    /// Disable a key.
    public func disableKey(keyId: String) async throws -> KmsKey {
        return try await http.post("/v1/kms/keys/\(keyId)/disable", responseType: KmsKey.self)
    }

    /// Schedule key deletion.
    public func scheduleKeyDeletion(keyId: String, pendingWindowDays: Int = 7) async throws -> KmsKey {
        let request = ScheduleDeletionRequest(pendingWindowDays: pendingWindowDays)
        return try await http.post("/v1/kms/keys/\(keyId)/schedule-deletion", body: request, responseType: KmsKey.self)
    }

    /// Cancel scheduled key deletion.
    public func cancelKeyDeletion(keyId: String) async throws -> KmsKey {
        return try await http.post("/v1/kms/keys/\(keyId)/cancel-deletion", responseType: KmsKey.self)
    }

    /// Rotate a key (creates new version).
    public func rotateKey(keyId: String) async throws -> KmsKey {
        return try await http.post("/v1/kms/keys/\(keyId)/rotate", responseType: KmsKey.self)
    }

    // MARK: - Cryptographic Operations

    /// Encrypt data using a KMS key.
    public func encrypt(
        keyId: String,
        plaintext: Data,
        context: [String: String]? = nil
    ) async throws -> EncryptResult {
        let request = EncryptRequest(
            keyId: keyId,
            plaintext: plaintext.base64EncodedString(),
            context: context ?? [:]
        )
        return try await http.post("/v1/kms/encrypt", body: request, responseType: EncryptResult.self)
    }

    /// Encrypt string data.
    public func encrypt(
        keyId: String,
        plaintext: String,
        context: [String: String]? = nil
    ) async throws -> EncryptResult {
        guard let data = plaintext.data(using: .utf8) else {
            throw ZnVaultError.validationError(message: "Invalid string encoding", fields: nil)
        }
        return try await encrypt(keyId: keyId, plaintext: data, context: context)
    }

    /// Decrypt data using a KMS key.
    public func decrypt(
        keyId: String,
        ciphertext: Data,
        context: [String: String]? = nil
    ) async throws -> Data {
        let request = DecryptRequestBody(
            keyId: keyId,
            ciphertext: ciphertext.base64EncodedString(),
            context: context ?? [:]
        )
        let result = try await http.post("/v1/kms/decrypt", body: request, responseType: DecryptResult.self)

        guard let data = Data(base64Encoded: result.plaintext) else {
            throw ZnVaultError.decodingError(underlying: NSError(
                domain: "ZnVault",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid plaintext encoding"]
            ))
        }
        return data
    }

    /// Decrypt to string.
    public func decryptToString(
        keyId: String,
        ciphertext: Data,
        context: [String: String]? = nil
    ) async throws -> String {
        let data = try await decrypt(keyId: keyId, ciphertext: ciphertext, context: context)
        guard let string = String(data: data, encoding: .utf8) else {
            throw ZnVaultError.decodingError(underlying: NSError(
                domain: "ZnVault",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 encoding"]
            ))
        }
        return string
    }

    // MARK: - Data Key Operations

    /// Generate a data key for envelope encryption.
    public func generateDataKey(
        keyId: String,
        keySpec: KeySpec = .aes256,
        context: [String: String]? = nil
    ) async throws -> DataKeyResult {
        let request = GenerateDataKeyRequestBody(
            keyId: keyId,
            keySpec: keySpec,
            context: context ?? [:]
        )
        return try await http.post("/v1/kms/generate-data-key", body: request, responseType: DataKeyResult.self)
    }

    /// Generate a data key without plaintext (for storage).
    public func generateDataKeyWithoutPlaintext(
        keyId: String,
        keySpec: KeySpec = .aes256,
        context: [String: String]? = nil
    ) async throws -> String {
        let request = GenerateDataKeyRequestBody(
            keyId: keyId,
            keySpec: keySpec,
            context: context ?? [:]
        )
        let result = try await http.post(
            "/v1/kms/generate-data-key-without-plaintext",
            body: request,
            responseType: DataKeyResult.self
        )
        return result.encryptedKey
    }

    /// Decrypt a data key.
    public func decryptDataKey(
        encryptedKey: String,
        keyId: String,
        context: [String: String]? = nil
    ) async throws -> Data {
        guard let cipherData = Data(base64Encoded: encryptedKey) else {
            throw ZnVaultError.validationError(message: "Invalid encrypted key encoding", fields: nil)
        }
        return try await decrypt(keyId: keyId, ciphertext: cipherData, context: context)
    }

    // MARK: - Key Versions

    /// List key versions.
    public func listKeyVersions(keyId: String) async throws -> [KmsKeyVersion] {
        return try await http.get("/v1/kms/keys/\(keyId)/versions", responseType: [KmsKeyVersion].self)
    }
}

// MARK: - Request Types

/// Request to encrypt data.
public struct EncryptRequest: Codable, Sendable {
    public let keyId: String
    public let plaintext: String
    public let context: [String: String]

    public init(keyId: String, plaintext: String, context: [String: String] = [:]) {
        self.keyId = keyId
        self.plaintext = plaintext
        self.context = context
    }
}

/// Request to decrypt data.
public struct DecryptRequestBody: Codable, Sendable {
    public let keyId: String
    public let ciphertext: String
    public let context: [String: String]

    public init(keyId: String, ciphertext: String, context: [String: String] = [:]) {
        self.keyId = keyId
        self.ciphertext = ciphertext
        self.context = context
    }
}

/// Request to generate data key.
public struct GenerateDataKeyRequestBody: Codable, Sendable {
    public let keyId: String
    public let keySpec: KeySpec
    public let context: [String: String]

    enum CodingKeys: String, CodingKey {
        case keyId = "key_id"
        case keySpec = "key_spec"
        case context
    }

    public init(keyId: String, keySpec: KeySpec = .aes256, context: [String: String] = [:]) {
        self.keyId = keyId
        self.keySpec = keySpec
        self.context = context
    }
}

/// Request to schedule key deletion.
public struct ScheduleDeletionRequest: Codable, Sendable {
    public let pendingWindowDays: Int

    enum CodingKeys: String, CodingKey {
        case pendingWindowDays = "pending_window_days"
    }

    public init(pendingWindowDays: Int = 7) {
        self.pendingWindowDays = pendingWindowDays
    }
}
