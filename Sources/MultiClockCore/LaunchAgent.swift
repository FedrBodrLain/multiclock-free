import Foundation

/// Login autostart via a per-user LaunchAgent. No daemons, no helper tools.
public struct LaunchAgent {
    public let label: String
    public let executablePath: String
    public let directory: URL

    public init(label: String, executablePath: String,
                directory: URL = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/LaunchAgents")) {
        self.label = label
        self.executablePath = executablePath
        self.directory = directory
    }

    public var fileURL: URL { directory.appendingPathComponent("\(label).plist") }

    public var plist: [String: Any] {
        [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
        ]
    }

    public var isInstalled: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    public func install() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    public func uninstall() throws {
        guard isInstalled else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    public func toggle() throws {
        if isInstalled { try uninstall() } else { try install() }
    }
}
