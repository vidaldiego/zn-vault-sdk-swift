// Path: zn-vault-sdk-swift/Sources/ZnVault/Models/Common.swift

import Foundation

/// Generic API response wrapper.
public struct ApiResponse<T: Codable>: Codable where T: Sendable {
    public let success: Bool?
    public let data: T?
    public let message: String?
    public let error: String?
}

/// Simple success response.
public struct SuccessResponse: Codable, Sendable {
    public let success: Bool?
    public let message: String?
}

/// Paginated response.
public struct Page<T: Codable>: Codable where T: Sendable {
    public let data: [T]
    public let total: Int?
    public let page: Int?
    public let pageSize: Int?
    public let hasMore: Bool
    public let nextMarker: String?

    /// Alias for data to match common patterns.
    public var items: [T] { data }

    /// Limit used in request.
    public let limit: Int?

    /// Offset used in request.
    public let offset: Int?

    enum CodingKeys: String, CodingKey {
        case data, total, page
        case pageSize = "page_size"
        case hasMore = "has_more"
        case nextMarker = "next_marker"
        case limit, offset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent([T].self, forKey: .data) ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        page = try container.decodeIfPresent(Int.self, forKey: .page)
        pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        nextMarker = try container.decodeIfPresent(String.self, forKey: .nextMarker)
        limit = try container.decodeIfPresent(Int.self, forKey: .limit)
        offset = try container.decodeIfPresent(Int.self, forKey: .offset)
    }

    /// Create a page with specific items for testing.
    public init(items: [T], total: Int? = nil, limit: Int = 50, offset: Int = 0, nextMarker: String? = nil) {
        self.data = items
        self.total = total
        self.page = nil
        self.pageSize = limit
        self.hasMore = nextMarker != nil
        self.nextMarker = nextMarker
        self.limit = limit
        self.offset = offset
    }
}

/// Type-erased Codable wrapper for dynamic JSON values.
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Cannot encode value of type \(type(of: value))")
            throw EncodingError.invalidValue(value, context)
        }
    }

    /// Get value as String
    public var stringValue: String? { value as? String }

    /// Get value as Int
    public var intValue: Int? { value as? Int }

    /// Get value as Double
    public var doubleValue: Double? { value as? Double }

    /// Get value as Bool
    public var boolValue: Bool? { value as? Bool }

    /// Get value as Array
    public var arrayValue: [Any]? { value as? [Any] }

    /// Get value as Dictionary
    public var dictionaryValue: [String: Any]? { value as? [String: Any] }
}
