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
    ///
    /// The username must include the tenant prefix in the format `tenant/username`
    /// (e.g., "acme/admin"). This allows multiple tenants to have users with the
    /// same username. Email addresses can also be used as username.
    ///
    /// - Parameters:
    ///   - username: Username in format "tenant/username" or email
    ///   - password: User password
    ///   - totpCode: Optional TOTP code if 2FA is enabled
    /// - Returns: Login response with tokens
    public func login(username: String, password: String, totpCode: String? = nil) async throws -> LoginResponse {
        let request = LoginRequest(username: username, password: password, totpCode: totpCode)
        let response = try await http.post("/auth/login", body: request, responseType: LoginResponse.self)

        // Store tokens in HTTP client
        await http.setAccessToken(response.accessToken)
        await http.setRefreshToken(response.refreshToken)

        return response
    }

    /// Login with tenant and username separately.
    ///
    /// Convenience method that formats the username as "tenant/username".
    ///
    /// - Parameters:
    ///   - tenant: Tenant identifier (e.g., "acme")
    ///   - username: Username within the tenant (e.g., "admin")
    ///   - password: User password
    ///   - totpCode: Optional TOTP code if 2FA is enabled
    /// - Returns: Login response with tokens
    public func login(tenant: String, username: String, password: String, totpCode: String? = nil) async throws -> LoginResponse {
        let fullUsername = "\(tenant)/\(username)"
        return try await login(username: fullUsername, password: password, totpCode: totpCode)
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

    /// Create an API key in the caller's tenant.
    ///
    /// Tenant is derived server-side from the authenticated principal. For
    /// cross-tenant API key creation, use `ZnVaultSuperadminClient`.
    ///
    /// - Returns: The created API key with key value (only shown once!)
    public func createApiKey(
        name: String,
        permissions: [String],
        expiresInDays: Int? = nil,
        description: String? = nil,
        ipAllowlist: [String]? = nil,
        conditions: ApiKeyConditions? = nil
    ) async throws -> CreateApiKeyResponse {
        let request = CreateApiKeyRequest(
            name: name,
            permissions: permissions,
            expiresInDays: expiresInDays,
            description: description,
            ipAllowlist: ipAllowlist,
            conditions: conditions
        )
        return try await http.post("/auth/api-keys", body: request, responseType: CreateApiKeyResponse.self)
    }

    /// List API keys.
    public func listApiKeys() async throws -> [ApiKey] {
        let response = try await http.get("/auth/api-keys", responseType: ApiKeyListResponse.self)
        return response.items
    }

    /// Revoke an API key.
    public func revokeApiKey(id: String) async throws {
        try await http.delete("/auth/api-keys/\(id)")
    }

    /// Rotate an API key by ID.
    ///
    /// This creates a new API key with the same configuration and revokes the old one.
    /// - Parameter id: The ID of the API key to rotate.
    /// - Returns: The new API key (key value is only shown once!).
    public func rotateApiKey(id: String) async throws -> CreateApiKeyResponse {
        return try await http.post("/auth/api-keys/\(id)/rotate", responseType: CreateApiKeyResponse.self)
    }

    /// Get information about the current API key (when authenticated via API key).
    /// - Returns: The current API key information.
    public func getCurrentApiKey() async throws -> ApiKey {
        return try await http.get("/auth/api-keys/self", responseType: ApiKey.self)
    }

    /// Rotate the current API key (self-rotation when authenticated via API key).
    ///
    /// This creates a new API key with the same configuration and revokes the current one.
    /// - Returns: The new API key (key value is only shown once!).
    public func rotateCurrentApiKey() async throws -> CreateApiKeyResponse {
        return try await http.post("/auth/api-keys/self/rotate", responseType: CreateApiKeyResponse.self)
    }

    // MARK: - Token Information

    /// Get current user information.
    public func me() async throws -> MeResponse {
        return try await http.get("/auth/me", responseType: MeResponse.self)
    }

    // MARK: - Managed API Keys
    //
    // All managed-key and registration-token methods are scoped to the
    // caller's tenant. For cross-tenant management, use ZnVaultSuperadminClient
    // (server route /v1/superadmin/api-keys/* — not yet implemented).

    /// Create a managed API key with auto-rotation in the caller's tenant.
    public func createManagedApiKey(
        name: String,
        permissions: [String],
        rotationMode: RotationMode,
        rotationInterval: String? = nil,
        gracePeriod: String? = nil,
        description: String? = nil,
        expiresInDays: Int? = nil
    ) async throws -> CreateManagedApiKeyResponse {
        let request = CreateManagedApiKeyRequest(
            name: name,
            permissions: permissions,
            rotationMode: rotationMode,
            rotationInterval: rotationInterval,
            gracePeriod: gracePeriod,
            description: description,
            expiresInDays: expiresInDays
        )
        return try await http.post("/auth/api-keys/managed", body: request, responseType: CreateManagedApiKeyResponse.self)
    }

    /// List managed API keys in the caller's tenant.
    public func listManagedApiKeys() async throws -> [ManagedApiKey] {
        let response = try await http.get("/auth/api-keys/managed", responseType: ManagedApiKeyListResponse.self)
        return response.keys
    }

    /// Get a managed API key by name in the caller's tenant.
    public func getManagedApiKey(name: String) async throws -> ManagedApiKey {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try await http.get("/auth/api-keys/managed/\(encodedName)", responseType: ManagedApiKey.self)
    }

    /// Bind to a managed API key to get the current key value.
    ///
    /// This is the primary method for agents to obtain their API key.
    /// Security: requires the caller to already have a valid API key
    /// (the current one, even during grace period).
    public func bindManagedApiKey(name: String) async throws -> ManagedKeyBindResponse {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try await http.post("/auth/api-keys/managed/\(encodedName)/bind", responseType: ManagedKeyBindResponse.self)
    }

    /// Force rotate a managed API key.
    ///
    /// Creates a new key immediately, regardless of the rotation schedule.
    /// The old key remains valid during the grace period.
    public func rotateManagedApiKey(name: String) async throws -> ManagedKeyRotateResponse {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try await http.post("/auth/api-keys/managed/\(encodedName)/rotate", responseType: ManagedKeyRotateResponse.self)
    }

    /// Update managed API key configuration.
    public func updateManagedApiKeyConfig(
        name: String,
        rotationInterval: String? = nil,
        gracePeriod: String? = nil,
        enabled: Bool? = nil
    ) async throws -> ManagedApiKey {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let request = UpdateManagedApiKeyConfigRequest(
            rotationInterval: rotationInterval,
            gracePeriod: gracePeriod,
            enabled: enabled
        )
        return try await http.patch("/auth/api-keys/managed/\(encodedName)/config", body: request, responseType: ManagedApiKey.self)
    }

    /// Delete a managed API key.
    public func deleteManagedApiKey(name: String) async throws {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        try await http.delete("/auth/api-keys/managed/\(encodedName)")
    }

    // MARK: - Registration Tokens (Agent Bootstrap)

    /// Create a registration token for agent bootstrapping.
    public func createRegistrationToken(
        managedKeyName: String,
        expiresIn: String? = nil,
        description: String? = nil
    ) async throws -> CreateRegistrationTokenResponse {
        let encodedName = managedKeyName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? managedKeyName
        let request = CreateRegistrationTokenRequest(expiresIn: expiresIn, description: description)
        return try await http.post(
            "/auth/api-keys/managed/\(encodedName)/registration-tokens",
            body: request,
            responseType: CreateRegistrationTokenResponse.self
        )
    }

    /// List registration tokens for a managed key.
    public func listRegistrationTokens(
        managedKeyName: String,
        includeUsed: Bool = false
    ) async throws -> [RegistrationToken] {
        let encodedName = managedKeyName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? managedKeyName
        let path = includeUsed
            ? "/auth/api-keys/managed/\(encodedName)/registration-tokens?includeUsed=true"
            : "/auth/api-keys/managed/\(encodedName)/registration-tokens"
        let response = try await http.get(path, responseType: RegistrationTokenListResponse.self)
        return response.tokens
    }

    /// Revoke a registration token.
    public func revokeRegistrationToken(
        managedKeyName: String,
        tokenId: String
    ) async throws {
        let encodedName = managedKeyName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? managedKeyName
        try await http.delete("/auth/api-keys/managed/\(encodedName)/registration-tokens/\(tokenId)")
    }

    /// Bootstrap an agent using a registration token.
    ///
    /// This is the unauthenticated endpoint used by agents to exchange a
    /// one-time registration token for a managed API key binding.
    ///
    /// Note: This method does not require prior authentication.
    ///
    /// - Parameter token: The registration token (format: zrt_...)
    /// - Returns: The API key binding response
    public func bootstrap(token: String) async throws -> BootstrapResponse {
        let request = BootstrapRequest(token: token)
        return try await http.post("/agent/bootstrap", body: request, responseType: BootstrapResponse.self)
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

