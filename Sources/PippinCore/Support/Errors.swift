import Foundation

public enum PippinError: Error, CustomStringConvertible, Sendable {
    case invalidInput(String)
    case fileNotFound(String)
    case unsupportedFormat(String)
    case capabilityUnavailable(String)
    case underlying(String)

    public var description: String {
        switch self {
        case .invalidInput(let m): return "invalid input: \(m)"
        case .fileNotFound(let m): return "file not found: \(m)"
        case .unsupportedFormat(let m): return "unsupported format: \(m)"
        case .capabilityUnavailable(let m): return "capability unavailable: \(m)"
        case .underlying(let m): return m
        }
    }
}
