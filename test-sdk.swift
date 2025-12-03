#!/usr/bin/env swift
// Path: zn-vault-sdk-swift/test-sdk.swift
// Quick integration test for Swift SDK

import Foundation

// Since we can't import the SDK directly from a script, we'll use URLSession to test
// This script tests the core HTTP calls that the SDK would make

let baseURL = "https://localhost:8443"

// Trust all certificates for local testing
class InsecureDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

let delegate = InsecureDelegate()
let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

struct TestResult {
    let name: String
    let passed: Bool
    let message: String
}

var results: [TestResult] = []

func test(_ name: String, _ block: () async throws -> Void) async {
    print("Testing: \(name)...")
    do {
        try await block()
        results.append(TestResult(name: name, passed: true, message: "OK"))
        print("  ✅ PASSED")
    } catch {
        results.append(TestResult(name: name, passed: false, message: error.localizedDescription))
        print("  ❌ FAILED: \(error)")
    }
}

func request(_ method: String, _ path: String, body: Data? = nil, token: String? = nil) async throws -> (Data, Int) {
    var request = URLRequest(url: URL(string: baseURL + path)!)
    request.httpMethod = method
    request.httpBody = body
    if body != nil {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    if let token = token {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let (data, response) = try await session.data(for: request)
    let httpResponse = response as! HTTPURLResponse
    return (data, httpResponse.statusCode)
}

// Tests
@main
struct Main {
    static func main() async {
        print("\n========================================")
        print("ZN-Vault Swift SDK Integration Tests")
        print("========================================\n")

        var accessToken: String?

        // Test 1: Health Check
        await test("Health Check") {
            let (data, status) = try await request("GET", "/v1/health")
            guard status == 200 else { throw NSError(domain: "", code: status) }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            guard json["status"] as? String == "ok" else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Status not ok"])
            }
            print("    Status: \(json["status"] ?? "unknown")")
        }

        // Test 2: Login
        await test("Login") {
            let loginBody = try JSONSerialization.data(withJSONObject: [
                "username": "admin",
                "password": "Admin123456#"
            ])
            let (data, status) = try await request("POST", "/auth/login", body: loginBody)
            guard status == 200 else {
                let text = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "", code: status, userInfo: [NSLocalizedDescriptionKey: text])
            }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            accessToken = json["accessToken"] as? String
            guard accessToken != nil else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
            }
            print("    Got access token: \(accessToken!.prefix(20))...")
        }

        // Test 3: Get Current User
        await test("Get Current User") {
            guard let token = accessToken else { throw NSError(domain: "", code: -1) }
            let (data, status) = try await request("GET", "/auth/me", token: token)
            guard status == 200 else { throw NSError(domain: "", code: status) }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let username = json["username"] as? String
            print("    Username: \(username ?? "unknown")")
        }

        // Test 4: Create Secret
        var secretId: String?
        await test("Create Secret") {
            guard let token = accessToken else { throw NSError(domain: "", code: -1) }
            let alias = "swift-test/secret-\(Int(Date().timeIntervalSince1970))"
            let body = try JSONSerialization.data(withJSONObject: [
                "alias": alias,
                "tenant": "zincapp",
                "type": "credential",
                "data": ["username": "testuser", "password": "testpass"]
            ])
            let (data, status) = try await request("POST", "/v1/secrets", body: body, token: token)
            guard status == 201 || status == 200 else {
                let text = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "", code: status, userInfo: [NSLocalizedDescriptionKey: text])
            }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            secretId = json["id"] as? String
            print("    Created secret: \(secretId ?? "unknown")")
        }

        // Test 5: Get Secret
        await test("Get Secret") {
            guard let token = accessToken, let id = secretId else { throw NSError(domain: "", code: -1) }
            let (data, status) = try await request("GET", "/v1/secrets/\(id)", token: token)
            guard status == 200 else { throw NSError(domain: "", code: status) }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            print("    Alias: \(json["alias"] ?? "unknown")")
            print("    Version: \(json["version"] ?? "unknown")")
        }

        // Test 6: Decrypt Secret
        await test("Decrypt Secret") {
            guard let token = accessToken, let id = secretId else { throw NSError(domain: "", code: -1) }
            let (data, status) = try await request("GET", "/v1/secrets/\(id)/value", token: token)
            guard status == 200 else { throw NSError(domain: "", code: status) }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let secretData = json["data"] as? [String: Any]
            print("    Decrypted: username=\(secretData?["username"] ?? "?")")
        }

        // Test 7: Update Secret
        await test("Update Secret") {
            guard let token = accessToken, let id = secretId else { throw NSError(domain: "", code: -1) }
            let body = try JSONSerialization.data(withJSONObject: [
                "data": ["username": "updated", "password": "newpass"]
            ])
            let (data, status) = try await request("PUT", "/v1/secrets/\(id)", body: body, token: token)
            guard status == 200 else { throw NSError(domain: "", code: status) }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let version = json["version"] as? Int
            print("    New version: \(version ?? 0)")
        }

        // Test 8: Delete Secret
        await test("Delete Secret") {
            guard let token = accessToken, let id = secretId else { throw NSError(domain: "", code: -1) }
            let (_, status) = try await request("DELETE", "/v1/secrets/\(id)", token: token)
            guard status == 200 || status == 204 else { throw NSError(domain: "", code: status) }
            print("    Deleted successfully")
        }

        // Test 9: List Secrets
        await test("List Secrets") {
            guard let token = accessToken else { throw NSError(domain: "", code: -1) }
            let (data, status) = try await request("GET", "/v1/secrets?tenant=zincapp&limit=5", token: token)
            guard status == 200 else { throw NSError(domain: "", code: status) }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["data"] as? [[String: Any]] ?? []
            print("    Found \(items.count) secrets")
        }

        // Test 10: List KMS Keys
        await test("List KMS Keys") {
            guard let token = accessToken else { throw NSError(domain: "", code: -1) }
            let (data, status) = try await request("GET", "/v1/kms/keys?limit=5", token: token)
            guard status == 200 else { throw NSError(domain: "", code: status) }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["data"] as? [[String: Any]] ?? []
            print("    Found \(items.count) keys")
        }

        // Test 11: Create KMS Key
        var keyId: String?
        await test("Create KMS Key") {
            guard let token = accessToken else { throw NSError(domain: "", code: -1) }
            let alias = "alias/swift-test-\(Int(Date().timeIntervalSince1970))"
            let body = try JSONSerialization.data(withJSONObject: [
                "alias": alias,
                "keySpec": "AES_256",
                "usage": "ENCRYPT_DECRYPT",
                "description": "Swift SDK test key"
            ])
            let (data, status) = try await request("POST", "/v1/kms/keys", body: body, token: token)
            guard status == 201 || status == 200 else {
                let text = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "", code: status, userInfo: [NSLocalizedDescriptionKey: text])
            }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            keyId = json["keyId"] as? String
            print("    Created key: \(keyId ?? "unknown")")
        }

        // Test 12: KMS Encrypt
        var ciphertext: String?
        await test("KMS Encrypt") {
            guard let token = accessToken, let kId = keyId else { throw NSError(domain: "", code: -1) }
            let plaintext = Data("Hello from Swift!".utf8).base64EncodedString()
            let body = try JSONSerialization.data(withJSONObject: [
                "keyId": kId,
                "plaintext": plaintext
            ])
            let (data, status) = try await request("POST", "/v1/kms/encrypt", body: body, token: token)
            guard status == 200 else {
                let text = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "", code: status, userInfo: [NSLocalizedDescriptionKey: text])
            }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            ciphertext = json["ciphertext"] as? String
            print("    Encrypted: \(ciphertext?.prefix(30) ?? "")...")
        }

        // Test 13: KMS Decrypt
        await test("KMS Decrypt") {
            guard let token = accessToken, let kId = keyId, let ct = ciphertext else {
                throw NSError(domain: "", code: -1)
            }
            let body = try JSONSerialization.data(withJSONObject: [
                "keyId": kId,
                "ciphertext": ct
            ])
            let (data, status) = try await request("POST", "/v1/kms/decrypt", body: body, token: token)
            guard status == 200 else { throw NSError(domain: "", code: status) }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            if let pt = json["plaintext"] as? String, let decoded = Data(base64Encoded: pt) {
                let text = String(data: decoded, encoding: .utf8)
                print("    Decrypted: \(text ?? "?")")
            }
        }

        // Test 14: List Audit Logs
        await test("List Audit Logs") {
            guard let token = accessToken else { throw NSError(domain: "", code: -1) }
            let (data, status) = try await request("GET", "/v1/audit?limit=5", token: token)
            guard status == 200 else { throw NSError(domain: "", code: status) }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let items = json["data"] as? [[String: Any]] ?? []
            print("    Found \(items.count) audit entries")
        }

        // Test 15: Verify Audit Chain
        await test("Verify Audit Chain") {
            guard let token = accessToken else { throw NSError(domain: "", code: -1) }
            let (data, status) = try await request("GET", "/v1/audit/verify", token: token)
            guard status == 200 else { throw NSError(domain: "", code: status) }

            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let valid = json["valid"] as? Bool ?? false
            print("    Chain valid: \(valid)")
        }

        // Summary
        print("\n========================================")
        print("Test Summary")
        print("========================================")

        let passed = results.filter { $0.passed }.count
        let failed = results.filter { !$0.passed }.count

        print("\n✅ Passed: \(passed)")
        print("❌ Failed: \(failed)")
        print("📊 Total:  \(results.count)")

        if failed > 0 {
            print("\nFailed tests:")
            for result in results.filter({ !$0.passed }) {
                print("  - \(result.name): \(result.message)")
            }
        }

        print("\n========================================\n")

        exit(failed > 0 ? 1 : 0)
    }
}
