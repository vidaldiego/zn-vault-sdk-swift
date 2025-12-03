// Path: zn-vault-sdk-swift/Sources/ZnVault/HTTP/ZnVaultHttpClient.swift

import Foundation

/// HTTP client for ZN-Vault API.
public actor ZnVaultHttpClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var accessToken: String?
    private var refreshToken: String?
    private var apiKey: String?

    /// Create HTTP client with configuration.
    public init(config: ZnVaultConfig) {
        guard let url = URL(string: config.baseURL) else {
            fatalError("Invalid base URL: \(config.baseURL)")
        }
        self.baseURL = url
        self.apiKey = config.apiKey
        self.accessToken = config.accessToken

        // Configure URL session
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        sessionConfig.timeoutIntervalForResource = config.timeout * 2

        // Handle self-signed certificates or insecure TLS if configured
        if config.insecureTLS || config.trustSelfSigned {
            self.session = URLSession(
                configuration: sessionConfig,
                delegate: TrustAllCertsDelegate(),
                delegateQueue: nil
            )
        } else {
            self.session = URLSession(configuration: sessionConfig)
        }

        // Configure JSON decoder
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) {
                return date
            }

            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) {
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

        // Configure JSON encoder
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Token Management

    /// Set access token for authentication.
    public func setAccessToken(_ token: String?) {
        self.accessToken = token
    }

    /// Set refresh token.
    public func setRefreshToken(_ token: String?) {
        self.refreshToken = token
    }

    /// Set API key for authentication.
    public func setApiKey(_ key: String?) {
        self.apiKey = key
    }

    /// Get current access token.
    public func getAccessToken() -> String? {
        return accessToken
    }

    /// Get current refresh token.
    public func getRefreshToken() -> String? {
        return refreshToken
    }

    // MARK: - HTTP Methods

    /// Perform GET request.
    public func get<T: Decodable>(
        _ path: String,
        query: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> T {
        let request = try buildRequest(path: path, method: "GET", query: query)
        return try await execute(request, responseType: responseType)
    }

    /// Perform POST request.
    public func post<T: Encodable, R: Decodable>(
        _ path: String,
        body: T,
        responseType: R.Type
    ) async throws -> R {
        var request = try buildRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request, responseType: responseType)
    }

    /// Perform POST request without body.
    public func post<R: Decodable>(
        _ path: String,
        responseType: R.Type
    ) async throws -> R {
        let request = try buildRequest(path: path, method: "POST")
        return try await execute(request, responseType: responseType)
    }

    /// Perform POST request without response.
    public func post<T: Encodable>(
        _ path: String,
        body: T
    ) async throws {
        var request = try buildRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await executeVoid(request)
    }

    /// Perform PUT request.
    public func put<T: Encodable, R: Decodable>(
        _ path: String,
        body: T,
        responseType: R.Type
    ) async throws -> R {
        var request = try buildRequest(path: path, method: "PUT")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request, responseType: responseType)
    }

    /// Perform PATCH request.
    public func patch<T: Encodable, R: Decodable>(
        _ path: String,
        body: T,
        responseType: R.Type
    ) async throws -> R {
        var request = try buildRequest(path: path, method: "PATCH")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request, responseType: responseType)
    }

    /// Perform DELETE request.
    public func delete(_ path: String) async throws {
        let request = try buildRequest(path: path, method: "DELETE")
        try await executeVoid(request)
    }

    /// Perform DELETE request with response.
    public func delete<R: Decodable>(
        _ path: String,
        responseType: R.Type
    ) async throws -> R {
        let request = try buildRequest(path: path, method: "DELETE")
        return try await execute(request, responseType: responseType)
    }

    // MARK: - Request Building

    private func buildRequest(
        path: String,
        method: String,
        query: [String: String]? = nil
    ) throws -> URLRequest {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)

        if let query = query, !query.isEmpty {
            urlComponents?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = urlComponents?.url else {
            throw ZnVaultError.configurationError(message: "Invalid URL: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        // Add authentication header
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let key = apiKey {
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
        }

        return request
    }

    // MARK: - Request Execution

    private func execute<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZnVaultError.networkError(underlying: URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw parseError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ZnVaultError.decodingError(underlying: error)
        }
    }

    private func executeVoid(_ request: URLRequest) async throws {
        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZnVaultError.networkError(underlying: URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw parseError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw ZnVaultError.networkError(underlying: error)
        }
    }
}

// MARK: - TLS Configuration

/// Configuration for ZN-Vault client.
public struct ZnVaultConfig: Sendable {
    /// Base URL of the ZN-Vault server.
    public let baseURL: String

    /// API key for authentication (optional).
    public let apiKey: String?

    /// Access token for JWT authentication (optional).
    public let accessToken: String?

    /// Request timeout in seconds.
    public let timeout: TimeInterval

    /// Trust self-signed certificates.
    public let trustSelfSigned: Bool

    /// Disable TLS certificate validation entirely (testing only).
    public let insecureTLS: Bool

    /// Create configuration.
    public init(
        baseURL: String,
        apiKey: String? = nil,
        accessToken: String? = nil,
        timeout: TimeInterval = 30,
        trustSelfSigned: Bool = false,
        insecureTLS: Bool = false
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.accessToken = accessToken
        self.timeout = timeout
        self.trustSelfSigned = trustSelfSigned
        self.insecureTLS = insecureTLS
    }

    /// Builder for creating configuration.
    public class Builder {
        private var baseURL: String = ""
        private var apiKey: String?
        private var accessToken: String?
        private var timeout: TimeInterval = 30
        private var trustSelfSigned: Bool = false
        private var insecureTLS: Bool = false

        public init() {}

        @discardableResult
        public func baseURL(_ url: String) -> Builder {
            self.baseURL = url
            return self
        }

        @discardableResult
        public func apiKey(_ key: String) -> Builder {
            self.apiKey = key
            return self
        }

        @discardableResult
        public func accessToken(_ token: String) -> Builder {
            self.accessToken = token
            return self
        }

        @discardableResult
        public func timeout(_ timeout: TimeInterval) -> Builder {
            self.timeout = timeout
            return self
        }

        @discardableResult
        public func trustSelfSigned(_ trust: Bool) -> Builder {
            self.trustSelfSigned = trust
            return self
        }

        @discardableResult
        public func insecureTLS(_ insecure: Bool) -> Builder {
            self.insecureTLS = insecure
            return self
        }

        public func build() -> ZnVaultConfig {
            return ZnVaultConfig(
                baseURL: baseURL,
                apiKey: apiKey,
                accessToken: accessToken,
                timeout: timeout,
                trustSelfSigned: trustSelfSigned,
                insecureTLS: insecureTLS
            )
        }
    }
}

// MARK: - Self-Signed Certificate Support

/// Delegate that trusts all certificates (for development only).
private final class TrustAllCertsDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
