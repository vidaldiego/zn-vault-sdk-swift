// Path: zn-vault-sdk-swift/Sources/ZnVault/Clients/AuthClient.swift

import Foundation

/// Client for authentication operations.
public final class AuthClient: Sendable {
    private let http: ZnVaultHttpClient

    internal init(http: ZnVaultHttpClient) {
        self.http = http
    }

    // MARK: - Login/Logout

    /// Login with username and password.
    public func login(username: String, password: String, totpCode: String? = nil) async throws -> LoginResponse {
        let request = LoginRequest(username: username, password: password, totpCode: totpCode)
        let response = try await http.post("/auth/login", body: request, responseType: LoginResponse.self)

        // Store tokens in HTTP client
        await http.setAccessToken(response.accessToken)
        await http.setRefreshToken(response.refreshToken)

        return response
    }

    /// Login with request object.
    public func login(request: LoginRequest) async throws -> LoginResponse {
        return try await login(username: request.username, password: request.password, totpCode: request.totpCode)
    }

    /// Complete login with TOTP code (when 2FA is required).
    public func completeTotpLogin(tempToken: String, totpCode: String) async throws -> LoginResponse {
        let request = TotpVerifyRequest(tempToken: tempToken, totpCode: totpCode)
        let response = try await http.post("/auth/2fa/verify", body: request, responseType: LoginResponse.self)

        // Store tokens in HTTP client
        await http.setAccessToken(response.accessToken)
        await http.setRefreshToken(response.refreshToken)

        return response
    }

    /// Refresh access token.
    public func refreshToken() async throws -> LoginResponse {
        guard let refreshToken = await http.getRefreshToken() else {
            throw ZnVaultError.notAuthenticated
        }

        let request = RefreshTokenRequest(refreshToken: refreshToken)
        let response = try await http.post("/auth/refresh", body: request, responseType: LoginResponse.self)

        // Update tokens
        await http.setAccessToken(response.accessToken)
        await http.setRefreshToken(response.refreshToken)

        return response
    }

    /// Logout (invalidate tokens).
    public func logout() async throws {
        try await http.post("/auth/logout", body: EmptyRequest())
        await http.setAccessToken(nil)
        await http.setRefreshToken(nil)
    }

    // MARK: - Registration

    /// Register a new user.
    public func register(username: String, password: String, email: String? = nil) async throws -> User {
        let request = RegisterUserRequest(username: username, password: password, email: email)
        return try await http.post("/auth/register", body: request, responseType: User.self)
    }

    // MARK: - Password Management

    /// Change password.
    public func changePassword(currentPassword: String, newPassword: String) async throws {
        let request = ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword)
        try await http.post("/auth/change-password", body: request)
    }

    /// Request password reset.
    public func requestPasswordReset(email: String) async throws {
        let request = PasswordResetRequest(email: email)
        try await http.post("/auth/forgot-password", body: request)
    }

    /// Reset password with token.
    public func resetPassword(token: String, newPassword: String) async throws {
        let request = ResetPasswordRequest(token: token, newPassword: newPassword)
        try await http.post("/auth/reset-password", body: request)
    }

    // MARK: - Two-Factor Authentication

    /// Setup 2FA (get QR code).
    public func setup2FA() async throws -> TotpSetupResponse {
        return try await http.post("/auth/2fa/setup", responseType: TotpSetupResponse.self)
    }

    /// Enable 2FA with verification code.
    public func enable2FA(totpCode: String) async throws -> TotpEnableResponse {
        let request = TotpEnableRequest(totpCode: totpCode)
        return try await http.post("/auth/2fa/enable", body: request, responseType: TotpEnableResponse.self)
    }

    /// Disable 2FA.
    public func disable2FA(totpCode: String) async throws {
        let request = TotpDisableRequest(totpCode: totpCode)
        try await http.post("/auth/2fa/disable", body: request)
    }

    /// Get 2FA status.
    public func get2FAStatus() async throws -> TotpStatusResponse {
        return try await http.get("/auth/2fa/status", responseType: TotpStatusResponse.self)
    }

    // MARK: - API Keys

    /// Create an API key.
    public func createApiKey(name: String, expiresIn: String? = nil, permissions: [String]? = nil) async throws -> CreateApiKeyResponse {
        let request = CreateApiKeyRequest(name: name, expiresIn: expiresIn, permissions: permissions)
        return try await http.post("/auth/api-keys", body: request, responseType: CreateApiKeyResponse.self)
    }

    /// List API keys.
    public func listApiKeys() async throws -> [ApiKey] {
        return try await http.get("/auth/api-keys", responseType: [ApiKey].self)
    }

    /// Revoke an API key.
    public func revokeApiKey(id: String) async throws {
        try await http.delete("/auth/api-keys/\(id)")
    }

    // MARK: - Token Information

    /// Get current user information.
    public func me() async throws -> User {
        return try await http.get("/auth/me", responseType: User.self)
    }

    /// Verify token is valid.
    public func verifyToken() async throws -> TokenVerifyResponse {
        return try await http.get("/auth/verify", responseType: TokenVerifyResponse.self)
    }
}

// MARK: - Request/Response Types

/// Empty request body.
private struct EmptyRequest: Codable, Sendable {}

/// Request to refresh token.
public struct RefreshTokenRequest: Codable, Sendable {
    public let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

/// Request to register a user.
public struct RegisterUserRequest: Codable, Sendable {
    public let username: String
    public let password: String
    public let email: String?

    public init(username: String, password: String, email: String? = nil) {
        self.username = username
        self.password = password
        self.email = email
    }
}

/// Request to change password.
public struct ChangePasswordRequest: Codable, Sendable {
    public let currentPassword: String
    public let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }

    public init(currentPassword: String, newPassword: String) {
        self.currentPassword = currentPassword
        self.newPassword = newPassword
    }
}

/// Request for password reset.
public struct PasswordResetRequest: Codable, Sendable {
    public let email: String

    public init(email: String) {
        self.email = email
    }
}

/// Request to reset password.
public struct ResetPasswordRequest: Codable, Sendable {
    public let token: String
    public let newPassword: String

    enum CodingKeys: String, CodingKey {
        case token
        case newPassword = "new_password"
    }

    public init(token: String, newPassword: String) {
        self.token = token
        self.newPassword = newPassword
    }
}

/// Request to enable TOTP.
public struct TotpEnableRequest: Codable, Sendable {
    public let totpCode: String

    enum CodingKeys: String, CodingKey {
        case totpCode = "totp_code"
    }

    public init(totpCode: String) {
        self.totpCode = totpCode
    }
}

/// Request to disable TOTP.
public struct TotpDisableRequest: Codable, Sendable {
    public let totpCode: String

    enum CodingKeys: String, CodingKey {
        case totpCode = "totp_code"
    }

    public init(totpCode: String) {
        self.totpCode = totpCode
    }
}

/// Request to verify TOTP.
public struct TotpVerifyRequest: Codable, Sendable {
    public let tempToken: String
    public let totpCode: String

    enum CodingKeys: String, CodingKey {
        case tempToken = "temp_token"
        case totpCode = "totp_code"
    }

    public init(tempToken: String, totpCode: String) {
        self.tempToken = tempToken
        self.totpCode = totpCode
    }
}

/// Response from TOTP enable.
public struct TotpEnableResponse: Codable, Sendable {
    public let enabled: Bool
    public let backupCodes: [String]?

    enum CodingKeys: String, CodingKey {
        case enabled
        case backupCodes = "backup_codes"
    }
}

/// Response from TOTP status.
public struct TotpStatusResponse: Codable, Sendable {
    public let enabled: Bool
    public let lastUsed: Date?

    enum CodingKeys: String, CodingKey {
        case enabled
        case lastUsed = "last_used"
    }
}

/// Response from token verification.
public struct TokenVerifyResponse: Codable, Sendable {
    public let valid: Bool
    public let userId: String?
    public let username: String?
    public let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case valid
        case userId = "user_id"
        case username
        case expiresAt = "expires_at"
    }
}
