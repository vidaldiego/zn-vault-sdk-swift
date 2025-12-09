// Path: zn-vault-sdk-swift/Sources/ZnVault/Clients/CertificateClient.swift

import Foundation

/// Client for certificate lifecycle management operations.
public final class CertificateClient: Sendable {
    private let http: ZnVaultHttpClient

    internal init(http: ZnVaultHttpClient) {
        self.http = http
    }

    // MARK: - CRUD Operations

    /// Store a new certificate for custody.
    /// - Parameters:
    ///   - request: The certificate storage request.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: The certificate metadata.
    public func store(
        request: StoreCertificateRequest,
        tenantId: String? = nil
    ) async throws -> Certificate {
        var query: [String: String] = [:]
        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }
        return try await http.post("/v1/certificates", body: request, query: query, responseType: Certificate.self)
    }

    /// Get certificate metadata by ID.
    /// - Parameters:
    ///   - id: The certificate ID.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: The certificate metadata.
    public func get(id: String, tenantId: String? = nil) async throws -> Certificate {
        var query: [String: String] = [:]
        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }
        return try await http.get("/v1/certificates/\(id)", query: query, responseType: Certificate.self)
    }

    /// Get certificate by business identity (clientId/kind/alias).
    /// - Parameters:
    ///   - clientId: External customer identifier (e.g., NIF/CIF).
    ///   - kind: Certificate kind (AEAT, FNMT, CUSTOM, etc.).
    ///   - alias: Human-readable identifier.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: The certificate metadata.
    public func getByIdentity(
        clientId: String,
        kind: String,
        alias: String,
        tenantId: String? = nil
    ) async throws -> Certificate {
        let encodedClientId = clientId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? clientId
        let encodedKind = kind.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? kind
        let encodedAlias = alias.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? alias
        var query: [String: String] = [:]
        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }
        return try await http.get(
            "/v1/certificates/by-identity/\(encodedClientId)/\(encodedKind)/\(encodedAlias)",
            query: query,
            responseType: Certificate.self
        )
    }

    /// List certificates with optional filtering.
    /// - Parameters:
    ///   - filter: Optional filter parameters.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: Paginated list of certificates.
    public func list(
        filter: CertificateFilter = CertificateFilter(),
        tenantId: String? = nil
    ) async throws -> CertificateListResponse {
        var query: [String: String] = [:]

        if let clientId = filter.clientId {
            query["clientId"] = clientId
        }
        if let kind = filter.kind {
            query["kind"] = kind
        }
        if let status = filter.status {
            query["status"] = status.rawValue
        }
        if let expiringBefore = filter.expiringBefore {
            query["expiringBefore"] = ISO8601DateFormatter().string(from: expiringBefore)
        }
        if let tags = filter.tags, !tags.isEmpty {
            query["tags"] = tags.joined(separator: ",")
        }
        query["page"] = String(filter.page)
        query["pageSize"] = String(filter.pageSize)

        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }

        return try await http.get("/v1/certificates", query: query, responseType: CertificateListResponse.self)
    }

    /// Get certificate statistics.
    /// - Parameter tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: Statistics including counts by status and kind.
    public func getStats(tenantId: String? = nil) async throws -> CertificateStats {
        var query: [String: String] = [:]
        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }
        return try await http.get("/v1/certificates/stats", query: query, responseType: CertificateStats.self)
    }

    /// List certificates expiring within a specified number of days.
    /// - Parameters:
    ///   - days: Number of days to look ahead (default: 30).
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: List of expiring certificates.
    public func listExpiring(days: Int = 30, tenantId: String? = nil) async throws -> [Certificate] {
        var query: [String: String] = ["days": String(days)]
        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }
        return try await http.get("/v1/certificates/expiring", query: query, responseType: [Certificate].self)
    }

    /// Update certificate metadata.
    /// - Parameters:
    ///   - id: The certificate ID.
    ///   - request: The update request.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: The updated certificate metadata.
    public func update(
        id: String,
        request: UpdateCertificateRequest,
        tenantId: String? = nil
    ) async throws -> Certificate {
        var query: [String: String] = [:]
        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }
        return try await http.patch("/v1/certificates/\(id)", body: request, query: query, responseType: Certificate.self)
    }

    /// Decrypt certificate (retrieve the actual certificate data).
    /// Requires business justification - the purpose is logged for audit.
    /// - Parameters:
    ///   - id: The certificate ID.
    ///   - purpose: Business justification for accessing the certificate.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: Decrypted certificate data (base64 encoded).
    public func decrypt(
        id: String,
        purpose: String,
        tenantId: String? = nil
    ) async throws -> DecryptedCertificate {
        var query: [String: String] = [:]
        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }
        let request = DecryptCertificateRequest(purpose: purpose)
        return try await http.post(
            "/v1/certificates/\(id)/decrypt",
            body: request,
            query: query,
            responseType: DecryptedCertificate.self
        )
    }

    /// Rotate certificate (replace with a new certificate).
    /// The old certificate is preserved in history.
    /// - Parameters:
    ///   - id: The certificate ID.
    ///   - request: The rotation request with new certificate data.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: The updated certificate metadata.
    public func rotate(
        id: String,
        request: RotateCertificateRequest,
        tenantId: String? = nil
    ) async throws -> Certificate {
        var query: [String: String] = [:]
        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }
        return try await http.post(
            "/v1/certificates/\(id)/rotate",
            body: request,
            query: query,
            responseType: Certificate.self
        )
    }

    /// Delete a certificate.
    /// The underlying secret data is preserved for audit purposes.
    /// - Parameters:
    ///   - id: The certificate ID.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    public func delete(id: String, tenantId: String? = nil) async throws {
        var query: [String: String] = [:]
        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }
        try await http.delete("/v1/certificates/\(id)", query: query)
    }

    /// Get certificate access log.
    /// - Parameters:
    ///   - id: The certificate ID.
    ///   - limit: Maximum number of entries to return (default: 100).
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: Access log entries.
    public func getAccessLog(
        id: String,
        limit: Int = 100,
        tenantId: String? = nil
    ) async throws -> [CertificateAccessLogEntry] {
        var query: [String: String] = ["limit": String(limit)]
        if let tenantId = tenantId {
            query["tenantId"] = tenantId
        }
        let response = try await http.get(
            "/v1/certificates/\(id)/access-log",
            query: query,
            responseType: CertificateAccessLogResponse.self
        )
        return response.entries
    }

    // MARK: - Convenience Methods

    /// Store a P12 certificate with simplified parameters.
    /// - Parameters:
    ///   - clientId: External customer identifier (e.g., NIF/CIF).
    ///   - kind: Certificate kind (AEAT, FNMT, CUSTOM, etc.).
    ///   - alias: Human-readable identifier.
    ///   - p12Data: P12 certificate data.
    ///   - passphrase: P12 passphrase.
    ///   - purpose: Certificate purpose.
    ///   - clientName: Optional customer display name.
    ///   - organizationId: Optional organization identifier.
    ///   - contactEmail: Optional contact email.
    ///   - tags: Optional tags.
    ///   - metadata: Optional custom metadata.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: The certificate metadata.
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
        metadata: [String: AnyCodable]? = nil,
        tenantId: String? = nil
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
        return try await store(request: request, tenantId: tenantId)
    }

    /// Store a PEM certificate with simplified parameters.
    /// - Parameters:
    ///   - clientId: External customer identifier (e.g., NIF/CIF).
    ///   - kind: Certificate kind.
    ///   - alias: Human-readable identifier.
    ///   - pemData: PEM certificate data.
    ///   - purpose: Certificate purpose.
    ///   - clientName: Optional customer display name.
    ///   - organizationId: Optional organization identifier.
    ///   - contactEmail: Optional contact email.
    ///   - tags: Optional tags.
    ///   - metadata: Optional custom metadata.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    /// - Returns: The certificate metadata.
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
        metadata: [String: AnyCodable]? = nil,
        tenantId: String? = nil
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
        return try await store(request: request, tenantId: tenantId)
    }

    /// List certificates by client ID.
    /// - Parameters:
    ///   - clientId: The client ID to filter by.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    ///   - page: Page number.
    ///   - pageSize: Page size.
    /// - Returns: Paginated list of certificates.
    public func listByClient(
        clientId: String,
        tenantId: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> CertificateListResponse {
        return try await list(
            filter: CertificateFilter(clientId: clientId, page: page, pageSize: pageSize),
            tenantId: tenantId
        )
    }

    /// List certificates by kind (AEAT, FNMT, CUSTOM, etc.).
    /// - Parameters:
    ///   - kind: The kind to filter by.
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    ///   - page: Page number.
    ///   - pageSize: Page size.
    /// - Returns: Paginated list of certificates.
    public func listByKind(
        kind: String,
        tenantId: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> CertificateListResponse {
        return try await list(
            filter: CertificateFilter(kind: kind, page: page, pageSize: pageSize),
            tenantId: tenantId
        )
    }

    /// List active certificates only.
    /// - Parameters:
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    ///   - page: Page number.
    ///   - pageSize: Page size.
    /// - Returns: Paginated list of active certificates.
    public func listActive(
        tenantId: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> CertificateListResponse {
        return try await list(
            filter: CertificateFilter(status: .active, page: page, pageSize: pageSize),
            tenantId: tenantId
        )
    }

    /// List expired certificates only.
    /// - Parameters:
    ///   - tenantId: Optional tenant ID (required if not in JWT).
    ///   - page: Page number.
    ///   - pageSize: Page size.
    /// - Returns: Paginated list of expired certificates.
    public func listExpired(
        tenantId: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> CertificateListResponse {
        return try await list(
            filter: CertificateFilter(status: .expired, page: page, pageSize: pageSize),
            tenantId: tenantId
        )
    }

    /// Download certificate as bytes.
    /// - Parameters:
    ///   - id: The certificate ID.
    ///   - purpose: Business justification.
    ///   - tenantId: Optional tenant ID.
    /// - Returns: Certificate data as bytes.
    public func download(
        id: String,
        purpose: String,
        tenantId: String? = nil
    ) async throws -> Data {
        let decrypted = try await decrypt(id: id, purpose: purpose, tenantId: tenantId)
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
