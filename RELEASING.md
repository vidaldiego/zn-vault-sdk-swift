# Releasing

This SDK is distributed via Swift Package Manager (SPM), which uses git tags directly.

## How to Release

1. **Update version** in `Package.swift` (if version is specified there) or just in documentation.

2. **Commit and push** any changes:
   ```bash
   git add .
   git commit -m "chore: bump version to X.Y.Z"
   git push origin main
   ```

3. **Create and push tag**:
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

That's it! SPM automatically detects the new tag.

## How Users Install

Users add the package via Xcode or `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vidaldiego/zn-vault-sdk-swift.git", from: "X.Y.Z")
]
```

## No CI/CD Required

Unlike other registries, SPM:
- Uses git tags directly (no upload step)
- No secrets or tokens needed
- Version is the git tag itself
