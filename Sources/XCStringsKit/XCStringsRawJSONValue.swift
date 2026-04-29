import Foundation

package enum XCStringsRawJSONValue: Codable, Sendable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case object(OrderedStringDictionary<XCStringsRawJSONValue>)
    case array([XCStringsRawJSONValue])
    case null

    package init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicJSONCodingKey.self) {
            let elements = try container.allKeys.map { key in
                (key.stringValue, try container.decode(XCStringsRawJSONValue.self, forKey: key))
            }
            self = .object(OrderedStringDictionary(elements))
            return
        }

        if var container = try? decoder.unkeyedContainer() {
            var values: [XCStringsRawJSONValue] = []
            while !container.isAtEnd {
                values.append(try container.decode(XCStringsRawJSONValue.self))
            }
            self = .array(values)
            return
        }

        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    package func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let string):
            var container = encoder.singleValueContainer()
            try container.encode(string)
        case .bool(let bool):
            var container = encoder.singleValueContainer()
            try container.encode(bool)
        case .int(let int):
            var container = encoder.singleValueContainer()
            try container.encode(int)
        case .double(let double):
            var container = encoder.singleValueContainer()
            try container.encode(double)
        case .object(let object):
            var container = encoder.container(keyedBy: DynamicJSONCodingKey.self)
            for (key, value) in object {
                try container.encode(value, forKey: DynamicJSONCodingKey(key))
            }
        case .array(let values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

struct DynamicJSONCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

extension KeyedDecodingContainer where Key == DynamicJSONCodingKey {
    func decodeUnknownFields(excluding knownKeys: Set<String>) throws -> OrderedStringDictionary<XCStringsRawJSONValue> {
        let elements = try allKeys.compactMap { key -> (String, XCStringsRawJSONValue)? in
            guard !knownKeys.contains(key.stringValue) else {
                return nil
            }
            return (key.stringValue, try decode(XCStringsRawJSONValue.self, forKey: key))
        }

        return OrderedStringDictionary(elements)
    }
}

extension KeyedEncodingContainer where Key == DynamicJSONCodingKey {
    mutating func encodeUnknownFields(_ fields: OrderedStringDictionary<XCStringsRawJSONValue>) throws {
        for (key, value) in fields {
            try encode(value, forKey: DynamicJSONCodingKey(key))
        }
    }

    mutating func encodeIfPresent<T: Encodable>(_ value: T?, for key: String) throws {
        guard let value else {
            return
        }
        try encode(value, forKey: DynamicJSONCodingKey(key))
    }
}
