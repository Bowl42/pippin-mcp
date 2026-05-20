import Foundation
import CoreImage

public enum ImageRef: Codable, Sendable, Hashable {
    case path(String)
    case base64(String)

    private enum CodingKeys: String, CodingKey { case path, base64 }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let p = try c.decodeIfPresent(String.self, forKey: .path) {
            self = .path(p)
        } else if let b = try c.decodeIfPresent(String.self, forKey: .base64) {
            self = .base64(b)
        } else {
            throw PippinError.invalidInput("image must have either 'path' or 'base64'")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .path(let p): try c.encode(p, forKey: .path)
        case .base64(let b): try c.encode(b, forKey: .base64)
        }
    }
}

public enum ImageLoader {
    public static func load(_ ref: ImageRef) throws -> CIImage {
        let data = try rawData(ref)
        guard let image = CIImage(data: data) else {
            throw PippinError.unsupportedFormat("could not decode image data")
        }
        return image
    }

    public static func rawData(_ ref: ImageRef) throws -> Data {
        switch ref {
        case .path(let p):
            let url = URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw PippinError.fileNotFound(p)
            }
            return try Data(contentsOf: url)
        case .base64(let s):
            let payload = stripDataURLPrefix(s)
            guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) else {
                throw PippinError.invalidInput("invalid base64 image data")
            }
            return data
        }
    }

    private static func stripDataURLPrefix(_ s: String) -> String {
        guard s.hasPrefix("data:"), let comma = s.firstIndex(of: ",") else { return s }
        return String(s[s.index(after: comma)...])
    }
}
