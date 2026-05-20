import ArgumentParser
import Foundation
import PippinCore

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check availability of each Apple capability used by pippin-mcp."
    )

    func run() async throws {
        print("pippin-mcp doctor")
        print("================")
        print("Platform: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print()

        check(name: "Vision (vision_ocr, vision_classify)",
              detail: "always available on macOS 12+")

        check(name: "NaturalLanguage (nl_analyze)",
              detail: "always available on macOS 10.14+")

        let fmStatus = FMGenerate.availabilityDescription()
        check(name: "FoundationModels (fm_generate)",
              ok: FMGenerate.isAvailable(),
              detail: fmStatus,
              hint: FMGenerate.isAvailable() ? nil : "Enable in System Settings → Apple Intelligence & Siri. Requires macOS 26+, Apple Silicon, and a supported region.")

        check(name: "Translation (translate)",
              detail: "framework present; language packs are downloaded on demand",
              hint: "If translate returns 'notInstalled', open the Translate app and download the language pair once (e.g. English ↔ Simplified Chinese).")
    }

    private func check(name: String, ok: Bool = true, detail: String, hint: String? = nil) {
        let mark = ok ? "✓" : "✗"
        print("\(mark) \(name)")
        print("  \(detail)")
        if let hint, !ok {
            print("  → \(hint)")
        }
        print()
    }
}
