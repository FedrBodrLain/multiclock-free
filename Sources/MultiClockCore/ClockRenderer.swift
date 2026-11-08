import Foundation

/// Pure formatting logic for the menu bar title and the dropdown lines.
public struct ClockRenderer {
    public var locale: Locale
    /// The zone the user physically sits in. Day markers (⁺¹ / ⁻¹) are relative to it.
    public var localZone: TimeZone
    public var separator: String

    private let timeFormatter = DateFormatter()
    private let fullFormatter = DateFormatter()

    public init(locale: Locale = .autoupdatingCurrent,
                localZone: TimeZone = .autoupdatingCurrent,
                separator: String = "   ") {
        self.locale = locale
        self.localZone = localZone
        self.separator = separator
        timeFormatter.locale = locale
        timeFormatter.setLocalizedDateFormatFromTemplate("jmm")
        fullFormatter.locale = locale
        fullFormatter.setLocalizedDateFormatFromTemplate("EEE d MMM jmm")
    }

    /// Whole days between the calendar date in `zone` and the calendar date in `localZone`
    /// at the same instant: +1 when the zone is already on the next day, -1 the previous.
    public func dayOffset(of zone: TimeZone, at date: Date) -> Int {
        var local = Calendar(identifier: .gregorian); local.timeZone = localZone
        var other = Calendar(identifier: .gregorian); other.timeZone = zone
        let a = local.dateComponents([.year, .month, .day], from: date)
        let b = other.dateComponents([.year, .month, .day], from: date)
        guard let da = local.date(from: a), let db = local.date(from: b) else { return 0 }
        return Int((db.timeIntervalSince(da) / 86400).rounded())
    }

    public func dayMarker(of zone: TimeZone, at date: Date) -> String {
        let d = dayOffset(of: zone, at: date)
        if d > 0 { return "⁺\(superscript(d))" }
        if d < 0 { return "⁻\(superscript(-d))" }
        return ""
    }

    /// One segment: `DE 23:57` or `MSK 01:57⁺¹`.
    public func segment(for zone: Zone, at date: Date) -> String {
        timeFormatter.timeZone = zone.timeZone
        return "\(zone.label) \(timeFormatter.string(from: date))\(dayMarker(of: zone.timeZone, at: date))"
    }

    /// The whole menu bar title.
    public func title(for zones: [Zone], at date: Date) -> String {
        zones.map { segment(for: $0, at: date) }.joined(separator: separator)
    }

    /// Dropdown line: `MSK  Sun 9 Nov 01:57  ·  Europe/Moscow`.
    public func detailLine(for zone: Zone, at date: Date) -> String {
        fullFormatter.timeZone = zone.timeZone
        return "\(zone.label)  \(fullFormatter.string(from: date))  ·  \(zone.id)"
    }

    private func superscript(_ n: Int) -> String {
        let digits: [Character] = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
        return String(String(n).compactMap { $0.wholeNumberValue.map { digits[$0] } })
    }
}
