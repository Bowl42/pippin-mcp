import XCTest
@testable import PippinCore

final class ImageLoaderTests: XCTestCase {
    func testPathDecode() throws {
        let data = #"{"path":"/tmp/x.png"}"#.data(using: .utf8)!
        let ref = try JSONDecoder().decode(ImageRef.self, from: data)
        guard case .path(let p) = ref else { return XCTFail("expected .path") }
        XCTAssertEqual(p, "/tmp/x.png")
    }

    func testBase64Decode() throws {
        let data = #"{"base64":"aGVsbG8="}"#.data(using: .utf8)!
        let ref = try JSONDecoder().decode(ImageRef.self, from: data)
        guard case .base64(let s) = ref else { return XCTFail("expected .base64") }
        XCTAssertEqual(s, "aGVsbG8=")
    }

    func testMissingFieldsFails() {
        let data = "{}".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ImageRef.self, from: data))
    }

    func testStripsDataURLPrefix() throws {
        let payload = "data:image/png;base64,aGVsbG8="
        let raw = try ImageLoader.rawData(.base64(payload))
        XCTAssertEqual(String(data: raw, encoding: .utf8), "hello")
    }

    func testFileNotFound() {
        XCTAssertThrowsError(try ImageLoader.rawData(.path("/tmp/does-not-exist-pippin.png"))) { err in
            guard let e = err as? PippinError, case .fileNotFound = e else {
                return XCTFail("expected fileNotFound, got \(err)")
            }
        }
    }
}
