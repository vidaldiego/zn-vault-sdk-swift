// Path: zn-vault-sdk-swift/Sources/ZnVault/Clients/PolicyClient.swift

import Foundation

/// Client for ABAC policy management operations.
public final class PolicyClient: Sendable {
    private let http: ZnVaultHttpClient

    internal init(http: ZnVaultHttpClient) {
        self.http = http
    }

    // MARK: - CRUD Operations

    /// Create a new policy.
    public func create(
        name: String,
        description: String? = nil,
        document: PolicyDocument
    ) async throws -> Policy {
        let request = try CreatePolicyRequest(name: name, description: description, document: document)
        return try await http.post("/v1/admin/policies", body: request, responseType: Policy.self)
    }

    /// Create policy with JSON document string.
    public func create(
        name: String,
        description: String? = nil,
        policyDocument: String
    ) async throws -> Policy {
        let request = CreatePolicyRequest(name: name, description: description, policyDocument: policyDocument)
        return try await http.post("/v1/admin/policies", body: request, responseType: Policy.self)
    }

    /// Create policy with request object.
    public func create(request: CreatePolicyRequest) async throws -> Policy {
        return try await http.post("/v1/admin/policies", body: request, responseType: Policy.self)
    }

    /// Get policy by ID.
    public func get(id: String) async throws -> Policy {
        return try await http.get("/v1/admin/policies/\(id)", responseType: Policy.self)
    }

    /// List policies.
    public func list(filter: PolicyFilter = PolicyFilter()) async throws -> Page<Policy> {
        var query: [String: String] = [:]

        if let isActive = filter.isActive {
            query["isActive"] = String(isActive)
        }
        query["limit"] = String(filter.limit)
        query["offset"] = String(filter.offset)

        return try await http.get("/v1/admin/policies", query: query, responseType: Page<Policy>.self)
    }

    /// Update policy.
    public func update(id: String, request: UpdatePolicyRequest) async throws -> Policy {
        return try await http.patch("/v1/admin/policies/\(id)", body: request, responseType: Policy.self)
    }

    /// Delete policy.
    public func delete(id: String) async throws {
        try await http.delete("/v1/admin/policies/\(id)")
    }

    // MARK: - Policy Status

    /// Activate policy.
    public func activate(id: String) async throws -> Policy {
        return try await http.post("/v1/admin/policies/\(id)/activate", responseType: Policy.self)
    }

    /// Deactivate policy.
    public func deactivate(id: String) async throws -> Policy {
        return try await http.post("/v1/admin/policies/\(id)/deactivate", responseType: Policy.self)
    }

    // MARK: - Attachments

    /// Attach policy to user.
    public func attachToUser(policyId: String, userId: String) async throws -> PolicyAttachment {
        let request = AttachPolicyRequest(policyId: policyId, userId: userId)
        return try await http.post("/v1/admin/policies/\(policyId)/attach", body: request, responseType: PolicyAttachment.self)
    }

    /// Attach policy to role.
    public func attachToRole(policyId: String, roleId: String) async throws -> PolicyAttachment {
        let request = AttachPolicyRequest(policyId: policyId, roleId: roleId)
        return try await http.post("/v1/admin/policies/\(policyId)/attach", body: request, responseType: PolicyAttachment.self)
    }

    /// Detach policy from user.
    public func detachFromUser(policyId: String, userId: String) async throws {
        try await http.delete("/v1/admin/policies/\(policyId)/users/\(userId)")
    }

    /// Detach policy from role.
    public func detachFromRole(policyId: String, roleId: String) async throws {
        try await http.delete("/v1/admin/policies/\(policyId)/roles/\(roleId)")
    }

    /// List policy attachments.
    public func listAttachments(policyId: String) async throws -> [PolicyAttachment] {
        return try await http.get("/v1/admin/policies/\(policyId)/attachments", responseType: [PolicyAttachment].self)
    }

    // MARK: - Evaluation

    /// Evaluate policy for a request.
    public func evaluate(request: PolicyEvaluationRequest) async throws -> PolicyEvaluationResult {
        return try await http.post("/v1/admin/policies/evaluate", body: request, responseType: PolicyEvaluationResult.self)
    }

    // MARK: - Helper Methods

    /// Create a simple allow policy.
    public static func allowPolicy(
        name: String,
        actions: [String],
        resources: [String],
        conditions: [PolicyCondition]? = nil
    ) -> PolicyDocument {
        return PolicyDocument(
            statements: [
                PolicyStatement(
                    effect: .allow,
                    actions: actions,
                    resources: resources,
                    conditions: conditions
                )
            ]
        )
    }

    /// Create a simple deny policy.
    public static func denyPolicy(
        name: String,
        actions: [String],
        resources: [String],
        conditions: [PolicyCondition]? = nil
    ) -> PolicyDocument {
        return PolicyDocument(
            statements: [
                PolicyStatement(
                    effect: .deny,
                    actions: actions,
                    resources: resources,
                    conditions: conditions
                )
            ]
        )
    }
}

// MARK: - Additional Types

/// Policy evaluation request.
public struct PolicyEvaluationRequest: Codable, Sendable {
    public let userId: String
    public let action: String
    public let resource: String
    public let context: [String: String]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case action, resource, context
    }

    public init(userId: String, action: String, resource: String, context: [String: String]? = nil) {
        self.userId = userId
        self.action = action
        self.resource = resource
        self.context = context
    }
}

/// Policy evaluation result.
public struct PolicyEvaluationResult: Codable, Sendable {
    public let allowed: Bool
    public let matchedPolicies: [String]?
    public let deniedBy: String?
    public let reason: String?

    enum CodingKeys: String, CodingKey {
        case allowed
        case matchedPolicies = "matched_policies"
        case deniedBy = "denied_by"
        case reason
    }
}
