import Foundation

/// Writes machine-readable evidence JSON. Tests always write into a
/// deterministic temporary evidence root (hermetic); the evidence packager
/// copies the root into the repository artifacts folder after the run.
/// `N027_EVIDENCE_ROOT`, when set, overrides the root for CI-style runs.
enum N027EvidenceWriter {
    static var root: URL {
        if let raw = ProcessInfo.processInfo.environment["N027_EVIDENCE_ROOT"],
           !raw.isEmpty {
            return URL(fileURLWithPath: raw, isDirectory: true)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("CreekSprout-N027-Evidence", isDirectory: true)
    }

    static func writeJSON(
        _ object: Any,
        to relativePath: String
    ) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: url, options: .atomic)
    }

    static func writeText(
        _ text: String,
        to relativePath: String
    ) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: url, options: .atomic)
    }
}
