// Path: zn-vault-sdk-swift/Sources/ZnVault/Exception/ZnVaultError.swift

import Foundation

/// ZN-Vault SDK errors.
public enum ZnVaultError: Error, Sendable {
    /// HTTP error with status code and message.
    case httpError(statusCode: Int, message: String, details: String?)

    /// Authentication error (401).
    case authenticationError(message: String)

    /// Unauthorized error (401) - alias for authenticationError.
    case unauthorized(message: String)

    /// Authorization error (403).
    case authorizationError(message: String)

    /// Resource not found (404).
    case notFound(resource: String)

    /// Validation error (400).
    case validationError(message: String, fields: [String: String]?)

    /// Rate limit exceeded (429).
    case rateLimitExceeded(retryAfter: TimeInterval?)

    /// Conflict error (409).
    case conflict(message: String)

    /// Server error (5xx).
    case serverError(message: String)

    /// Network error.
    case networkError(underlying: Error)

    /// Decoding error.
    case decodingError(underlying: Error)

    /// Configuration error.
    case configurationError(message: String)

    /// Not authenticated.
    case notAuthenticated

    /// Token expired.
    case tokenExpired
}

extension ZnVaultError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .httpError(let statusCode, let message, _):
            return "HTTP \(statusCode): \(message)"
        case .authenticationError(let message):
            return "Authentication failed: \(message)"
        case .unauthorized(let message):
            return "Unauthorized: \(message)"
        case .authorizationError(let message):
            return "Access denied: \(message)"
        case .notFound(let resource):
            return "Resource not found: \(resource)"
        case .validationError(let message, _):
            return "Validation error: \(message)"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Retry after \(Int(retryAfter)) seconds"
            }
            return "Rate limit exceeded"
        case .conflict(let message):
            return "Conflict: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .decodingError(let underlying):
            return "Decoding error: \(underlying.localizedDescription)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .notAuthenticated:
            return "Not authenticated. Please login first."
        case .tokenExpired:
            return "Authentication token expired. Please refresh or login again."
        }
    }
}

/// API error response from server.
public struct ApiErrorResponse: Codable, Sendable {
    public let error: String?
    public let message: String?
    public let statusCode: Int?
    public let details: String?
    public let fields: [String: String]?
}

/// Parse error from HTTP response.
internal func parseError(statusCode: Int, data: Data?) -> ZnVaultError {
    let message: String
    var details: String?
    var fields: [String: String]?

    if let data = data,
       let errorResponse = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) {
        message = errorResponse.message ?? errorResponse.error ?? "Unknown error"
        details = errorResponse.details
        fields = errorResponse.fields
    } else if let data = data,
              let text = String(data: data, encoding: .utf8), !text.isEmpty {
        message = text
    } else {
        message = HTTPURLResponse.localizedString(forStatusCode: statusCode)
    }

    switch statusCode {
    case 400:
        return .validationError(message: message, fields: fields)
    case 401:
        return .authenticationError(message: message)
    case 403:
        return .authorizationError(message: message)
    case 404:
        return .notFound(resource: message)
    case 409:
        return .conflict(message: message)
    case 429:
        return .rateLimitExceeded(retryAfter: nil)
    case 500...599:
        return .serverError(message: message)
    default:
        return .httpError(statusCode: statusCode, message: message, details: details)
    }
}
