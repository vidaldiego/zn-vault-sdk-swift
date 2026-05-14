// Path: zn-vault-sdk-swift/Sources/ZnVault/Clients/CertificateClient.swift

import Foundation

/// Client for certificate lifecycle management operations.
///
/// Tenant is always derived from the authenticated principal by the server;
/// there are no client-supplied tenant parameters on this client. For
/// cross-tenant certificate operations, use `ZnVaultSuperadminClient`.
public final class CertificateClient: Sendable {
    private let http: ZnVaultHttpClient

    internal init(http: ZnVaultHttpClient) {
        self.http = http
    }

    // MARK: - CRUD Operations

    /// Store a new certificate for custody.
    public func store(request: StoreCertificateRequest) async throws -> Certificate {
        return try await http.post("/v1/certificates", body: request, query: [:], responseType: Certificate.self)
    }

    /// Get certificate metadata by ID.
    public func get(id: String) async throws -> Certificate {
        return try await http.get("/v1/certificates/\(id)", query: [:], responseType: Certificate.self)
    }

    /// Get certificate by business identity (clientId/kind/alias).
    public func getByIdentity(
        clientId: String,
        kind: String,
        alias: String
    ) async throws -> Certificate {
        let encodedClientId = clientId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? clientId
        let encodedKind = kind.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? kind
        let encodedAlias = alias.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? alias
        return try await http.get(
            "/v1/certificates/by-identity/\(encodedClientId)/\(encodedKind)/\(encodedAlias)",
            query: [:],
            responseType: Certificate.self
        )
    }

    /// List certificates with optional filtering.
    public func list(filter: CertificateFilter = CertificateFilter()) async throws -> CertificateListResponse {
        var query: [String: String] = [:]
        if let clientId = filter.clientId { query["clientId"] = clientId }
        if let kind = filter.kind { query["kind"] = kind }
        if let status = filter.status { query["status"] = status.rawValue }
        if let expiringBefore = filter.expiringBefore {
            query["expiringBefore"] = ISO8601DateFormatter().string(from: expiringBefore)
        }
        if let tags = filter.tags, !tags.isEmpty {
            query["tags"] = tags.joined(separator: ",")
        }
        query["page"] = String(filter.page)
        query["pageSize"] = String(filter.pageSize)
        return try await http.get("/v1/certificates", query: query, responseType: CertificateListResponse.self)
    }

    /// Get certificate statistics.
    public func getStats() async throws -> CertificateStats {
        return try await http.get("/v1/certificates/stats", query: [:], responseType: CertificateStats.self)
    }

    /// List certificates expiring within a specified number of days.
    public func listExpiring(days: Int = 30) async throws -> [Certificate] {
        return try await http.get(
            "/v1/certificates/expiring",
            query: ["days": String(days)],
            responseType: [Certificate].self
        )
    }

    /// Update certificate metadata.
    public func update(id: String, request: UpdateCertificateRequest) async throws -> Certificate {
        return try await http.patch("/v1/certificates/\(id)", body: request, query: [:], responseType: Certificate.self)
    }

    /// Decrypt certificate (retrieve the actual certificate data).
    /// Requires business justification — the purpose is logged for audit.
    public func decrypt(id: String, purpose: String) async throws -> DecryptedCertificate {
        let request = DecryptCertificateRequest(purpose: purpose)
        return try await http.post(
            "/v1/certificates/\(id)/decrypt",
            body: request,
            query: [:],
            responseType: DecryptedCertificate.self
        )
    }

    /// Rotate certificate (replace with a new certificate).
    /// The old certificate is preserved in history.
    public func rotate(id: String, request: RotateCertificateRequest) async throws -> Certificate {
        return try await http.post(
            "/v1/certificates/\(id)/rotate",
            body: request,
            query: [:],
            responseType: Certificate.self
        )
    }

    /// Delete a certificate. The underlying secret data is preserved for audit.
    public func delete(id: String) async throws {
        try await http.delete("/v1/certificates/\(id)", query: [:])
    }

    /// Get certificate access log.
    public func getAccessLog(id: String, limit: Int = 100) async throws -> [CertificateAccessLogEntry] {
        let response = try await http.get(
            "/v1/certificates/\(id)/access-log",
            query: ["limit": String(limit)],
            responseType: CertificateAccessLogResponse.self
        )
        return response.entries
    }

    // MARK: - Convenience Methods

    /// Store a P12 certificate with simplified parameters.
    public func storeP12(
        clientId: String,
        kind: String,
        alias: String,
        p12Data: Data,
        passphrase: String,
        purpose: CertificatePurpose,
        clientName: String? = nil,
        organizationId: String? = nil,
        contactEmail: String? = nil,
        tags: [String]? = nil,
        metadata: [String: AnyCodable]? = nil
    ) async throws -> Certificate {
        let certificateData = p12Data.base64EncodedString()
        let request = StoreCertificateRequest(
            clientId: clientId,
            kind: kind,
            alias: alias,
            certificateData: certificateData,
            certificateType: .p12,
            purpose: purpose,
            passphrase: passphrase,
            clientName: clientName,
            organizationId: organizationId,
            contactEmail: contactEmail,
            tags: tags,
            metadata: metadata
        )
        return try await store(request: request)
    }

    /// Store a PEM certificate with simplified parameters.
    public func storePEM(
        clientId: String,
        kind: String,
        alias: String,
        pemData: Data,
        purpose: CertificatePurpose,
        clientName: String? = nil,
        organizationId: String? = nil,
        contactEmail: String? = nil,
        tags: [String]? = nil,
        metadata: [String: AnyCodable]? = nil
    ) async throws -> Certificate {
        let certificateData = pemData.base64EncodedString()
        let request = StoreCertificateRequest(
            clientId: clientId,
            kind: kind,
            alias: alias,
            certificateData: certificateData,
            certificateType: .pem,
            purpose: purpose,
            clientName: clientName,
            organizationId: organizationId,
            contactEmail: contactEmail,
            tags: tags,
            metadata: metadata
        )
        return try await store(request: request)
    }

    /// List certificates by client ID.
    public func listByClient(
        clientId: String,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> CertificateListResponse {
        return try await list(
            filter: CertificateFilter(clientId: clientId, page: page, pageSize: pageSize)
        )
    }

    /// List certificates by kind (AEAT, FNMT, CUSTOM, etc.).
    public func listByKind(
        kind: String,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> CertificateListResponse {
        return try await list(
            filter: CertificateFilter(kind: kind, page: page, pageSize: pageSize)
        )
    }

    /// List active certificates only.
    public func listActive(
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> CertificateListResponse {
        return try await list(
            filter: CertificateFilter(status: .active, page: page, pageSize: pageSize)
        )
    }

    /// List expired certificates only.
    public func listExpired(
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> CertificateListResponse {
        return try await list(
            filter: CertificateFilter(status: .expired, page: page, pageSize: pageSize)
        )
    }

    /// Download certificate as bytes.
    public func download(id: String, purpose: String) async throws -> Data {
        let decrypted = try await decrypt(id: id, purpose: purpose)
        guard let data = Data(base64Encoded: decrypted.certificateData) else {
            throw ZnVaultError.decodingError(underlying: NSError(
                domain: "ZnVault",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid base64 certificate data"]
            ))
        }
        return data
    }
}
