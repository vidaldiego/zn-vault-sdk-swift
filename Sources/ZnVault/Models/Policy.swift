// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/Policy.swift

import Foundation

/// ABAC Policy.
public struct Policy: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let policyDocument: String
    public let isActive: Bool
    public let createdBy: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case policyDocument = "policy_document"
        case isActive = "is_active"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        policyDocument = try container.decode(String.self, forKey: .policyDocument)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

/// Policy document structure.
public struct PolicyDocument: Codable, Sendable {
    public let version: String
    public let statements: [PolicyStatement]

    public init(version: String = "2024-01-01", statements: [PolicyStatement]) {
        self.version = version
        self.statements = statements
    }

    /// Encode to JSON string.
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

/// Policy statement.
public struct PolicyStatement: Codable, Sendable {
    public let effect: PolicyEffect
    public let actions: [String]
    public let resources: [String]
    public let conditions: [PolicyCondition]?

    public init(
        effect: PolicyEffect,
        actions: [String],
        resources: [String],
        conditions: [PolicyCondition]? = nil
    ) {
        self.effect = effect
        self.actions = actions
        self.resources = resources
        self.conditions = conditions
    }
}

/// Policy effect.
public enum PolicyEffect: String, Codable, Sendable {
    case allow = "Allow"
    case deny = "Deny"
}

/// Policy condition.
public struct PolicyCondition: Codable, Sendable {
    public let type: String
    public let key: String
    public let values: [String]

    public init(type: String, key: String, values: [String]) {
        self.type = type
        self.key = key
        self.values = values
    }
}

/// Request to create a policy.
public struct CreatePolicyRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let policyDocument: String

    enum CodingKeys: String, CodingKey {
        case name, description
        case policyDocument = "policy_document"
    }

    public init(name: String, description: String? = nil, policyDocument: String) {
        self.name = name
        self.description = description
        self.policyDocument = policyDocument
    }

    public init(name: String, description: String? = nil, document: PolicyDocument) throws {
        self.name = name
        self.description = description
        self.policyDocument = try document.toJSON()
    }
}

/// Request to update a policy.
public struct UpdatePolicyRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let policyDocument: String?
    public let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case name, description
        case policyDocument = "policy_document"
        case isActive = "is_active"
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        policyDocument: String? = nil,
        isActive: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.policyDocument = policyDocument
        self.isActive = isActive
    }
}

/// Policy filter.
public struct PolicyFilter: Sendable {
    public let isActive: Bool?
    public let limit: Int
    public let offset: Int

    public init(isActive: Bool? = nil, limit: Int = 50, offset: Int = 0) {
        self.isActive = isActive
        self.limit = limit
        self.offset = offset
    }
}

/// Policy attachment.
public struct PolicyAttachment: Codable, Sendable {
    public let policyId: String
    public let userId: String?
    public let roleId: String?
    public let attachedBy: String?
    public let attachedAt: Date?

    enum CodingKeys: String, CodingKey {
        case policyId = "policy_id"
        case userId = "user_id"
        case roleId = "role_id"
        case attachedBy = "attached_by"
        case attachedAt = "attached_at"
    }
}

/// Request to attach policy.
public struct AttachPolicyRequest: Codable, Sendable {
    public let policyId: String
    public let userId: String?
    public let roleId: String?

    enum CodingKeys: String, CodingKey {
        case policyId = "policy_id"
        case userId = "user_id"
        case roleId = "role_id"
    }

    public init(policyId: String, userId: String) {
        self.policyId = policyId
        self.userId = userId
        self.roleId = nil
    }

    public init(policyId: String, roleId: String) {
        self.policyId = policyId
        self.userId = nil
        self.roleId = roleId
    }
}
