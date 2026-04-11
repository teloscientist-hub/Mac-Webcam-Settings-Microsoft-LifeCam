import Foundation

enum CameraControlValue: Codable, Hashable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case enumCase(String)

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .enumCase(value)
        } else {
            throw DecodingError.typeMismatch(
                CameraControlValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported control value payload")
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .enumCase(value):
            try container.encode(value)
        }
    }
}
