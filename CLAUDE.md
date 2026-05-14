# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

ZnVault Swift SDK (`ZnVault`) is the official Swift client library for ZnVault secrets management. It provides full async/await support with type-safe Codable models for Apple platforms.

### Relationship to ZnVault Server

This SDK is part of the ZnVault ecosystem. The parent directory (`../`) contains the main ZnVault server - see `../CLAUDE.md` for server documentation.

```
zn-vault/                    # Parent - Vault server
├── src/                     # Server source code
├── zn-vault-sdk-swift/      # THIS REPO - Swift SDK
├── zn-vault-sdk-node/       # Node.js SDK
├── zn-vault-sdk-python/     # Python SDK
├── zn-vault-sdk-jvm/        # Kotlin/Java SDK
├── zn-vault-agent/          # Agent for certificate/secret sync
├── znvault-cli/             # Admin CLI
└── vault-secrets-app/       # macOS app (uses this SDK)
```

## Development Commands

```bash
# Build
swift build

# Run tests
swift test

# Build for release
swift build -c release

# Generate Xcode project (optional)
swift package generate-xcodeproj
```

### Integration Test Setup

Integration tests require a running vault instance:

```bash
# Set environment variables
export ZNVAULT_BASE_URL=https://localhost:8443
export ZNVAULT_USERNAME=admin
export ZNVAULT_PASSWORD=your-password

# Run tests
swift test
```

## Architecture

```
Sources/ZnVault/
├── ZnVaultClient.swift       # Main client builder
├── Http/
│   ├── HttpClient.swift      # URLSession-based HTTP client
│   └── Auth/
│       ├── ApiKeyAuth.swift  # API key authentication
│       └── JwtAuth.swift     # JWT token management
├── Clients/
│   ├── SecretsClient.swift   # Secrets CRUD
│   ├── KmsClient.swift       # Key Management Service
│   ├── AuthClient.swift      # Authentication operations
│   ├── UsersClient.swift     # User management
│   ├── RolesClient.swift     # Role management
│   ├── TenantsClient.swift   # Tenant management
│   ├── PoliciesClient.swift  # ABAC policy management
│   ├── AuditClient.swift     # Audit log operations
│   └── HealthClient.swift    # Health checks
├── Models/                   # Codable models
└── Errors/                   # Error types
```

## Release Process

**Publishing is handled automatically by GitHub Actions CI/CD.**

### Steps to Release

1. Update version in `Package.swift` (if version is hardcoded) or just use git tag.

2. Commit any changes:
   ```bash
   git add .
   git commit -m "chore(release): vX.Y.Z"
   ```

3. Create and push tag:
   ```bash
   git tag X.Y.Z
   git push origin main
   git push origin X.Y.Z
   ```

4. GitHub Actions automatically:
   - Runs tests on multiple Swift versions
   - Creates a GitHub release
   - The tag is automatically available for SPM

### Swift Package Manager

Users add the package via SPM:

```swift
dependencies: [
    .package(url: "https://github.com/vidaldiego/zn-vault-sdk-swift.git", from: "1.5.0")
]
```

### Package Information

- **Repository:** https://github.com/vidaldiego/zn-vault-sdk-swift
- **Swift Version:** 5.9+
- **Platforms:** macOS 12+, iOS 15+, tvOS 15+, watchOS 8+

### Verification

```bash
# Users can verify by adding to their Package.swift and building
swift package resolve
swift build
```

### CI/CD Configuration

The GitHub Actions workflow (`.github/workflows/test.yml`) handles:
- Running tests on PRs (multiple Swift versions)
- Creating GitHub releases on version tags

## Code Standards

- **Swift**: 5.9+ with strict concurrency
- **Async/Await**: All API methods are async
- **Sendable**: All types conform to Sendable for thread safety
- **Testing**: XCTest for unit and integration tests
