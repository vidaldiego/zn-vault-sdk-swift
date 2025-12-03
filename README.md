# ZN-Vault Swift SDK

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS-blue.svg)](https://developer.apple.com)

A type-safe, idiomatic Swift client library for ZN-Vault secrets management.

**GitHub:** https://github.com/vidaldiego/zn-vault-sdk-swift

## Features

- Full async/await support
- Type-safe API with Codable models
- Complete coverage of ZN-Vault REST API
- Automatic token management
- Self-signed certificate support for development
- AsyncStream support for paginated results

## Requirements

- Swift 5.9+
- macOS 12+ / iOS 15+ / tvOS 15+ / watchOS 8+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vidaldiego/zn-vault-sdk-swift.git", from: "1.0.0")
]
```

Or add it in Xcode via File → Add Package Dependencies.

## Quick Start

```swift
import ZnVault

// Create client
let client = ZnVaultClient.builder()
    .baseURL("https://vault.example.com:8443")
    .trustSelfSigned(true)  // For development only
    .build()

// Login
let tokens = try await client.auth.login(
    username: "user",
    password: "password"
)

// Create a secret
let secret = try await client.secrets.create(
    alias: "api/production/db-credentials",
    tenant: "acme",
    type: .credential,
    data: [
        "username": "dbuser",
        "password": "secretpass123"
    ]
)

// Decrypt a secret
let data = try await client.secrets.decrypt(id: secret.id)
print(data.data["password"]?.stringValue)
```

## Usage Examples

### Authentication

```swift
// Login with username/password
let response = try await client.auth.login(
    username: "alice",
    password: "secure-password"
)

// Login with 2FA
let loginResponse = try await client.auth.login(
    username: "alice",
    password: "secure-password"
)

if loginResponse.requires2fa, let tempToken = loginResponse.tempToken {
    let tokens = try await client.auth.completeTotpLogin(
        tempToken: tempToken,
        totpCode: "123456"
    )
}

// Using API key
let client = ZnVaultClient.builder()
    .baseURL("https://vault.example.com:8443")
    .apiKey("znv_xxxx_your_api_key")
    .build()

// Refresh token
let newTokens = try await client.auth.refreshToken()

// Get current user
let user = try await client.auth.me()
```

### Secret Management

```swift
// Create a credential secret
let secret = try await client.secrets.create(
    alias: "api/prod/database",
    tenant: "acme",
    type: .credential,
    data: [
        "username": "dbuser",
        "password": "secretpass"
    ],
    tags: ["database", "production"]
)

// Get secret metadata
let metadata = try await client.secrets.get(id: secret.id)

// Get by alias
let byAlias = try await client.secrets.getByAlias(
    tenant: "acme",
    alias: "api/prod/database"
)

// Decrypt secret value
let decrypted = try await client.secrets.decrypt(id: secret.id)
let password = decrypted.data["password"]?.stringValue

// Update secret (creates new version)
let updated = try await client.secrets.update(
    id: secret.id,
    data: ["password": "newpassword"]
)

// Rotate secret
let rotated = try await client.secrets.rotate(
    id: secret.id,
    data: ["password": "rotatedpassword"]
)

// List secrets
let page = try await client.secrets.list(filter: SecretFilter(
    tenant: "acme",
    type: .credential,
    limit: 50
))

// Stream all secrets
for try await secret in client.secrets.listAll(filter: SecretFilter(tenant: "acme")) {
    print(secret.alias)
}

// Get version history
let history = try await client.secrets.getHistory(id: secret.id)

// Decrypt specific version
let oldVersion = try await client.secrets.decryptVersion(id: secret.id, version: 1)

// Delete secret
try await client.secrets.delete(id: secret.id)
```

### File Storage

```swift
// Upload a file
let fileData = try Data(contentsOf: URL(fileURLWithPath: "certificate.pem"))
let fileSecret = try await client.secrets.uploadFile(
    alias: "ssl/production/cert",
    tenant: "acme",
    fileData: fileData,
    filename: "certificate.pem",
    tags: ["ssl", "certificate"]
)

// Download a file
let (data, filename, contentType) = try await client.secrets.downloadFile(id: fileSecret.id)
try data.write(to: URL(fileURLWithPath: filename))
```

### KMS Operations

```swift
// Create a KMS key
let key = try await client.kms.createKey(
    alias: "alias/my-encryption-key",
    description: "Main encryption key",
    usage: .encryptDecrypt,
    keySpec: .aes256
)

// Encrypt data
let plaintext = "sensitive data".data(using: .utf8)!
let encrypted = try await client.kms.encrypt(
    keyId: key.keyId,
    plaintext: plaintext,
    context: ["app": "myapp"]
)

// Decrypt data
let cipherData = Data(base64Encoded: encrypted.ciphertext)!
let decrypted = try await client.kms.decrypt(
    keyId: key.keyId,
    ciphertext: cipherData,
    context: ["app": "myapp"]
)
let originalText = String(data: decrypted, encoding: .utf8)

// Generate data key for envelope encryption
let dataKey = try await client.kms.generateDataKey(
    keyId: key.keyId,
    keySpec: .aes256
)
// Use dataKey.plaintextKey for encryption
// Store dataKey.encryptedKey with the encrypted data

// Rotate key
let rotatedKey = try await client.kms.rotateKey(keyId: key.keyId)

// List keys
let keys = try await client.kms.listKeys(filter: KeyFilter(state: .enabled))
```

### User Management

```swift
// Create a user
let user = try await client.users.create(
    username: "bob",
    password: "securepassword",
    email: "bob@example.com",
    tenantId: "acme"
)

// List users
let users = try await client.users.list(filter: UserFilter(
    tenantId: "acme",
    status: .active
))

// Assign role
try await client.users.assignRole(userId: user.id, roleId: "editor")

// Deactivate user
try await client.users.deactivate(id: user.id)
```

### Tenant Management

```swift
// Create tenant
let tenant = try await client.tenants.create(
    id: "acme",
    name: "Acme Corporation",
    description: "Main tenant"
)

// Get tenant stats
let stats = try await client.tenants.getStats(id: "acme")
print("Secrets: \(stats.secretCount), Users: \(stats.userCount)")

// List tenants
let tenants = try await client.tenants.list()
```

### Role & Policy Management

```swift
// Create a role
let role = try await client.roles.create(
    name: "secret-reader",
    description: "Can read secrets",
    permissions: ["secret:read:metadata", "secret:read:value"]
)

// Create an ABAC policy
let policy = try await client.policies.create(
    name: "production-access",
    description: "Access to production secrets",
    document: PolicyDocument(
        statements: [
            PolicyStatement(
                effect: .allow,
                actions: ["secret:read:*"],
                resources: ["secret:*/production/*"],
                conditions: [
                    PolicyCondition(
                        type: "StringEquals",
                        key: "resource:env",
                        values: ["production"]
                    )
                ]
            )
        ]
    )
)

// Attach policy to user
try await client.policies.attachToUser(policyId: policy.id, userId: "user-id")
```

### Audit Logs

```swift
// List audit entries
let entries = try await client.audit.list(filter: AuditFilter(
    action: "secret:read",
    startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
    limit: 100
))

// Get statistics
let stats = try await client.audit.getStats()
print("Total entries: \(stats.total)")

// Verify audit chain integrity
let verification = try await client.audit.verify()
if !verification.valid {
    print("Chain broken at entry: \(verification.brokenAt ?? -1)")
}

// Get recent failures
let failures = try await client.audit.getRecentFailures(limit: 50)
```

### Health Checks

```swift
// Check health
let health = try await client.health.check()
print("Status: \(health.status), Healthy: \(health.isHealthy)")

// Quick health check
let isHealthy = await client.health.isHealthy()

// Wait for service to become healthy
let ready = try await client.health.waitForHealthy(timeout: 60)

// Component health
let dbHealth = try await client.health.checkDatabase()
let kmsHealth = try await client.health.checkKms()
```

## Error Handling

```swift
do {
    let secret = try await client.secrets.get(id: "nonexistent")
} catch let error as ZnVaultError {
    switch error {
    case .notFound(let resource):
        print("Resource not found: \(resource)")
    case .authenticationError(let message):
        print("Authentication failed: \(message)")
    case .authorizationError(let message):
        print("Access denied: \(message)")
    case .validationError(let message, let fields):
        print("Validation error: \(message)")
        fields?.forEach { print("  \($0.key): \($0.value)") }
    case .rateLimitExceeded(let retryAfter):
        print("Rate limited. Retry after: \(retryAfter ?? 0) seconds")
    case .serverError(let message):
        print("Server error: \(message)")
    case .networkError(let underlying):
        print("Network error: \(underlying.localizedDescription)")
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```

## Configuration

```swift
let client = ZnVaultClient.builder()
    .baseURL("https://vault.example.com:8443")
    .apiKey("znv_xxxx_your_api_key")  // Optional: for API key auth
    .timeout(30)                        // Request timeout in seconds
    .trustSelfSigned(true)             // Trust self-signed certs (dev only!)
    .build()
```

## Thread Safety

All client types are `Sendable` and safe to use from multiple concurrent tasks. The `ZnVaultHttpClient` is an actor, ensuring thread-safe token management.

```swift
// Safe to use from multiple tasks
await withTaskGroup(of: Secret.self) { group in
    for alias in aliases {
        group.addTask {
            try await client.secrets.getByAlias(tenant: "acme", alias: alias)
        }
    }
}
```

## License

Apache-2.0
