import Foundation

/// A time zone shown in the menu bar: a short label plus an IANA identifier.
public struct Zone: Equatable, Hashable {
    public let label: String
    public let id: String

    public init(label: String, id: String) {
        self.label = label
        self.id = id
    }

    /// Parses the persisted form `LABEL|Region/City`. Returns nil for malformed
    /// input or an identifier the system does not know.
    public init?(stored: String) {
        let parts = stored.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let label = parts[0].trimmingCharacters(in: .whitespaces)
        let id = parts[1].trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty, TimeZone(identifier: id) != nil else { return nil }
        self.init(label: label, id: id)
    }

    public var stored: String { "\(label)|\(id)" }

    public var timeZone: TimeZone { TimeZone(identifier: id) ?? TimeZone(secondsFromGMT: 0)! }

    /// Default label for a custom identifier: up to 4 uppercase letters of the city part.
    /// `Europe/Lisbon` -> `LISB`, `UTC` -> `UTC`.
    public static func defaultLabel(for identifier: String) -> String {
        let city = identifier.split(separator: "/").last.map(String.init) ?? identifier
        let letters = city.replacingOccurrences(of: "_", with: "")
        return String(letters.prefix(4)).uppercased()
    }
}

public enum Presets {
    public static let zones: [Zone] = [
        Zone(label: "DE",   id: "Europe/Berlin"),
        Zone(label: "MSK",  id: "Europe/Moscow"),
        Zone(label: "UA",   id: "Europe/Kyiv"),
        Zone(label: "UK",   id: "Europe/London"),
        Zone(label: "PT",   id: "Europe/Lisbon"),
        Zone(label: "RS",   id: "Europe/Belgrade"),
        Zone(label: "TR",   id: "Europe/Istanbul"),
        Zone(label: "GE",   id: "Asia/Tbilisi"),
        Zone(label: "AM",   id: "Asia/Yerevan"),
        Zone(label: "UAE",  id: "Asia/Dubai"),
        Zone(label: "KZ",   id: "Asia/Almaty"),
        Zone(label: "IN",   id: "Asia/Kolkata"),
        Zone(label: "TH",   id: "Asia/Bangkok"),
        Zone(label: "BALI", id: "Asia/Makassar"),
        Zone(label: "SG",   id: "Asia/Singapore"),
        Zone(label: "JP",   id: "Asia/Tokyo"),
        Zone(label: "SYD",  id: "Australia/Sydney"),
        Zone(label: "NY",   id: "America/New_York"),
        Zone(label: "LA",   id: "America/Los_Angeles"),
        Zone(label: "UTC",  id: "UTC"),
    ]

    public static let first = zones[0]
    public static let second = zones[1]
}
