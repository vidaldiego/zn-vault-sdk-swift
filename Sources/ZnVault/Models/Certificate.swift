// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/Certificate.swift

import Foundation

// MARK: - Enums

/// Certificate format types.
public enum CertificateType: String, Codable, Sendable {
    case p12 = "P12"
    case pem = "PEM"
    case der = "DER"
}

/// Certificate purpose/usage.
public enum CertificatePurpose: String, Codable, Sendable {
    case tls = "TLS"
    case mtls = "mTLS"
    case signing = "SIGNING"
    case encryption = "ENCRYPTION"
    case authentication = "AUTHENTICATION"
}

/// Certificate lifecycle status.
public enum CertificateStatus: String, Codable, Sendable {
    case active = "ACTIVE"
    case expired = "EXPIRED"
    case revoked = "REVOKED"
    case suspended = "SUSPENDED"
    case pendingDeletion = "PENDING_DELETION"
}

/// Certificate kind/category.
public enum CertificateKind: String, Codable, Sendable {
    case aeat = "AEAT"
    case fnmt = "FNMT"
    case camerfirma = "CAMERFIRMA"
    case custom = "CUSTOM"
}

// MARK: - Models

/// Certificate metadata (without encrypted data).
public struct Certificate: Codable, Sendable, Identifiable {
    public let id: String
    public let tenantId: String
    public let clientId: String
    public let kind: String
    public let alias: String
    public let certificateType: CertificateType
    public let purpose: CertificatePurpose
    public let fingerprintSha256: String
    public let subjectCn: String
    public let issuerCn: String
    public let notBefore: Date
    public let notAfter: Date
    public let clientName: String
    public let organizationId: String?
    public let contactEmail: String?
    public let status: CertificateStatus
    public let version: Int
    public let createdAt: Date
    public let createdBy: String
    public let updatedAt: Date
    public let lastAccessedAt: Date?
    public let accessCount: Int
    public let tags: [String]
    public let daysUntilExpiry: Int
    public let isExpired: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case tenantId
        case clientId
        case kind
        case alias
        case certificateType
        case purpose
        case fingerprintSha256
        case subjectCn
        case issuerCn
        case notBefore
        case notAfter
        case clientName
        case organizationId
        case contactEmail
        case status
        case version
        case createdAt
        case createdBy
        case updatedAt
        case lastAccessedAt
        case accessCount
        case tags
        case daysUntilExpiry
        case isExpired
    }
}

/// Decrypted certificate response.
public struct DecryptedCertificate: Codable, Sendable {
    public let id: String
    public let certificateData: String
    public let certificateType: CertificateType
    public let fingerprintSha256: String

    enum CodingKeys: String, CodingKey {
        case id
        case certificateData
        case certificateType
        case fingerprintSha256
    }
}

/// Request to store a new certificate.
public struct StoreCertificateRequest: Codable, Sendable {
    public let clientId: String
    public let kind: String
    public let alias: String
    public let certificateData: String
    public let certificateType: CertificateType
    public let purpose: CertificatePurpose
    public let passphrase: String?
    public let clientName: String?
    public let organizationId: String?
    public let contactEmail: String?
    public let tags: [String]?
    public let metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case clientId
        case kind
        case alias
        case certificateData
        case certificateType
        case purpose
        case passphrase
        case clientName
        case organizationId
        case contactEmail
        case tags
        case metadata
    }

    public init(
        clientId: String,
        kind: String,
        alias: String,
        certificateData: String,
        certificateType: CertificateType,
        purpose: CertificatePurpose,
        passphrase: String? = nil,
        clientName: String? = nil,
        organizationId: String? = nil,
        contactEmail: String? = nil,
        tags: [String]? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.clientId = clientId
        self.kind = kind
        self.alias = alias
        self.certificateData = certificateData
        self.certificateType = certificateType
        self.purpose = purpose
        self.passphrase = passphrase
        self.clientName = clientName
        self.organizationId = organizationId
        self.contactEmail = contactEmail
        self.tags = tags
        self.metadata = metadata
    }
}

/// Request to update certificate metadata.
public struct UpdateCertificateRequest: Codable, Sendable {
    public let alias: String?
    public let clientName: String?
    public let contactEmail: String?
    public let tags: [String]?
    public let metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case alias
        case clientName
        case contactEmail
        case tags
        case metadata
    }

    public init(
        alias: String? = nil,
        clientName: String? = nil,
        contactEmail: String? = nil,
        tags: [String]? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.alias = alias
        self.clientName = clientName
        self.contactEmail = contactEmail
        self.tags = tags
        self.metadata = metadata
    }
}

/// Request to rotate a certificate.
public struct RotateCertificateRequest: Codable, Sendable {
    public let certificateData: String
    public let certificateType: CertificateType
    public let passphrase: String?
    public let reason: String?

    enum CodingKeys: String, CodingKey {
        case certificateData
        case certificateType
        case passphrase
        case reason
    }

    public init(
        certificateData: String,
        certificateType: CertificateType,
        passphrase: String? = nil,
        reason: String? = nil
    ) {
        self.certificateData = certificateData
        self.certificateType = certificateType
        self.passphrase = passphrase
        self.reason = reason
    }
}

/// Filter options for listing certificates.
public struct CertificateFilter: Sendable {
    public let clientId: String?
    public let kind: String?
    public let status: CertificateStatus?
    public let expiringBefore: Date?
    public let tags: [String]?
    public let page: Int
    public let pageSize: Int

    public init(
        clientId: String? = nil,
        kind: String? = nil,
        status: CertificateStatus? = nil,
        expiringBefore: Date? = nil,
        tags: [String]? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) {
        self.clientId = clientId
        self.kind = kind
        self.status = status
        self.expiringBefore = expiringBefore
        self.tags = tags
        self.page = page
        self.pageSize = pageSize
    }
}

/// Certificate statistics.
public struct CertificateStats: Codable, Sendable {
    public let total: Int
    public let byStatus: [String: Int]
    public let byKind: [String: Int]
    public let expiringIn30Days: Int
    public let expiringIn7Days: Int

    enum CodingKeys: String, CodingKey {
        case total
        case byStatus
        case byKind
        case expiringIn30Days
        case expiringIn7Days
    }
}

/// Certificate access log entry.
public struct CertificateAccessLogEntry: Codable, Sendable, Identifiable {
    public let id: Int
    public let certificateId: String
    public let tenantId: String
    public let userId: String?
    public let apiKeyId: String?
    public let purpose: String
    public let operation: String
    public let ipAddress: String?
    public let userAgent: String?
    public let accessedAt: Date
    public let success: Bool
    public let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case certificateId
        case tenantId
        case userId
        case apiKeyId
        case purpose
        case operation
        case ipAddress
        case userAgent
        case accessedAt
        case success
        case errorMessage
    }
}

/// Paginated list response for certificates.
public struct CertificateListResponse: Codable, Sendable {
    public let items: [Certificate]
    public let total: Int
    public let page: Int
    public let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case items
        case total
        case page
        case pageSize
    }
}

/// Certificate access log response.
public struct CertificateAccessLogResponse: Codable, Sendable {
    public let entries: [CertificateAccessLogEntry]

    enum CodingKeys: String, CodingKey {
        case entries
    }
}

/// Request to decrypt a certificate.
internal struct DecryptCertificateRequest: Codable, Sendable {
    let purpose: String

    init(purpose: String) {
        self.purpose = purpose
    }
}
