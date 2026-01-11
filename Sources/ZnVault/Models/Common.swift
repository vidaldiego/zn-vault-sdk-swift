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

/// Pagination metadata from API response.
public struct Pagination: Codable, Sendable {
    public let total: Int
    public let limit: Int
    public let offset: Int
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case total, limit, offset
        case hasMore
    }

    public init(total: Int, limit: Int, offset: Int, hasMore: Bool) {
        self.total = total
        self.limit = limit
        self.offset = offset
        self.hasMore = hasMore
    }
}

/// Paginated response.
/// Supports both new format ({ items, pagination }) and legacy formats.
public struct Page<T: Codable>: Codable where T: Sendable {
    /// Items in this page.
    public let items: [T]

    /// Pagination metadata.
    public let pagination: Pagination

    /// Total items matching query.
    public var total: Int { pagination.total }

    /// Limit used in request.
    public var limit: Int { pagination.limit }

    /// Offset used in request.
    public var offset: Int { pagination.offset }

    /// Whether more items exist.
    public var hasMore: Bool { pagination.hasMore }

    enum CodingKeys: String, CodingKey {
        case items, data, pagination
        // Legacy flat fields
        case total, limit, offset, hasMore
        case page, pageSize = "page_size"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode items: try 'items' first, then 'data', then empty array
        if let items = try container.decodeIfPresent([T].self, forKey: .items) {
            self.items = items
        } else if let data = try container.decodeIfPresent([T].self, forKey: .data) {
            self.items = data
        } else {
            self.items = []
        }

        // Decode pagination: try nested 'pagination' object first, then flat fields
        if let pagination = try container.decodeIfPresent(Pagination.self, forKey: .pagination) {
            self.pagination = pagination
        } else {
            // Legacy flat format
            let total = try container.decodeIfPresent(Int.self, forKey: .total) ?? items.count
            var limit = try container.decodeIfPresent(Int.self, forKey: .limit)
            if limit == nil {
                limit = try container.decodeIfPresent(Int.self, forKey: .pageSize)
            }
            let offset = try container.decodeIfPresent(Int.self, forKey: .offset) ?? 0
            let hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
            self.pagination = Pagination(total: total, limit: limit ?? 50, offset: offset, hasMore: hasMore)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        try container.encode(pagination, forKey: .pagination)
    }

    /// Create a page with specific items for testing.
    public init(items: [T], total: Int? = nil, limit: Int = 50, offset: Int = 0, hasMore: Bool = false) {
        self.items = items
        self.pagination = Pagination(
            total: total ?? items.count,
            limit: limit,
            offset: offset,
            hasMore: hasMore
        )
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
