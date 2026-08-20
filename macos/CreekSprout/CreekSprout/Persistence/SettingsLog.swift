import Foundation

enum SettingsLog {
    static func logSettingsFallback(reason: String, path: String, directory: URL = SettingsStore.defaultDirectory) {
        append(level: "WARNING", category: "settings", message: reason, metadata: ["path": path], directory: directory)
    }

    static func logSaveFailure(reason: String, directory: URL = SettingsStore.defaultDirectory) {
        append(level: "ERROR", category: "settings", message: reason, metadata: [:], directory: directory)
    }

    private static func append(
        level: String,
        category: String,
        message: String,
        metadata: [String: String],
        directory: URL
    ) {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("settings-errors.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var line = "[\(timestamp)] [\(level)] [\(category)] \(message)"
        if !metadata.isEmpty {
            let meta = metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
            line += " {\(meta)}"
        }
        line += "\n"
        if fileManager.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
