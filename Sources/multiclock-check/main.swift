import Foundation
import MultiClockCore

// Dependency-free test runner. `swift run multiclock-check` exits 1 on any failure.
// XCTest is not used on purpose: it is missing from Command Line Tools installs.

var failures = 0
var passed = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition() { passed += 1 } else {
        failures += 1
        print("FAIL \(URL(fileURLWithPath: file).lastPathComponent):\(line)  \(message)")
    }
}
func equal<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: String = #file, line: Int = #line) {
    check(a == b, "\(message) expected «\(b)», got «\(a)»", file: file, line: line)
}
func test(_ name: String, _ body: () throws -> Void) {
    do { try body() } catch { failures += 1; print("FAIL \(name): threw \(error)") }
}

let berlin = TimeZone(identifier: "Europe/Berlin")!
let moscow = TimeZone(identifier: "Europe/Moscow")!
let la = TimeZone(identifier: "America/Los_Angeles")!
// 2026-11-08 22:57:00 UTC == 23:57 Berlin (CET) == 01:57 next day Moscow (the screenshot moment).
let late = Date(timeIntervalSince1970: 1_793_573_820)
// 2026-07-01 10:00:00 UTC == 12:00 Berlin (CEST) == 13:00 Moscow == 19:00 Tokyo.
let noon = Date(timeIntervalSince1970: 1_782_900_000)
let de = ClockRenderer(locale: Locale(identifier: "de_DE"), localZone: berlin, separator: "   ")

// MARK: Zone

test("Zone stored round trip") {
    let z = Zone(label: "MSK", id: "Europe/Moscow")
    equal(z.stored, "MSK|Europe/Moscow")
    equal(Zone(stored: z.stored), z)
}
test("Zone rejects garbage") {
    check(Zone(stored: "") == nil, "empty string")
    check(Zone(stored: "no-separator") == nil, "no separator")
    check(Zone(stored: "|Europe/Berlin") == nil, "empty label")
    check(Zone(stored: "X|Mars/Olympus_Mons") == nil, "unknown zone")
}
test("Zone trims whitespace") {
    equal(Zone(stored: " DE | Europe/Berlin "), Zone(label: "DE", id: "Europe/Berlin"))
}
test("Zone default label") {
    equal(Zone.defaultLabel(for: "Europe/Lisbon"), "LISB")
    equal(Zone.defaultLabel(for: "America/New_York"), "NEWY")
    equal(Zone.defaultLabel(for: "UTC"), "UTC")
}
test("Presets valid and unique") {
    for z in Presets.zones {
        check(TimeZone(identifier: z.id) != nil, "system rejects preset \(z.id)")
        check(z.label.count <= 4, "label too long: \(z.label)")
    }
    equal(Set(Presets.zones.map(\.label)).count, Presets.zones.count, "duplicate labels")
    equal(Set(Presets.zones.map(\.id)).count, Presets.zones.count, "duplicate ids")
    equal(Presets.first.id, "Europe/Berlin")
    equal(Presets.second.id, "Europe/Moscow")
}

// MARK: ClockRenderer

test("Title matches the menu bar screenshot") {
    let zones = [Zone(label: "DE", id: "Europe/Berlin"), Zone(label: "MSK", id: "Europe/Moscow")]
    equal(de.title(for: zones, at: late), "DE 23:57   MSK 01:57⁺¹")
}
test("No day marker on the same day") {
    equal(de.segment(for: Zone(label: "MSK", id: "Europe/Moscow"), at: noon), "MSK 13:00")
    equal(de.dayOffset(of: moscow, at: noon), 0)
}
test("Day offset plus and minus") {
    equal(de.dayOffset(of: moscow, at: late), 1)
    equal(de.dayOffset(of: la, at: late), 0, "LA is 14:57 same day")
    let earlyMorning = late.addingTimeInterval(3600 + 180)   // 01:00 Berlin next day == 16:00 LA previous day
    equal(de.dayOffset(of: la, at: earlyMorning), -1)
    equal(de.dayMarker(of: la, at: earlyMorning), "⁻¹")
}
test("12-hour locale") {
    let us = ClockRenderer(locale: Locale(identifier: "en_US"), localZone: berlin)
    let s = us.segment(for: Zone(label: "DE", id: "Europe/Berlin"), at: late)
    check(s.hasPrefix("DE 11:57"), "12h prefix: \(s)")
    check(s.lowercased().contains("pm"), "12h suffix: \(s)")
}
test("Detail line") {
    let line = de.detailLine(for: Zone(label: "JP", id: "Asia/Tokyo"), at: noon)
    check(line.hasPrefix("JP  "), line)
    check(line.hasSuffix("Asia/Tokyo"), line)
    check(line.contains("19:00"), line)
}
test("Title stable within a minute, changes on the next") {
    let zones = [Presets.first, Presets.second]
    equal(de.title(for: zones, at: noon), de.title(for: zones, at: noon.addingTimeInterval(59)))
    check(de.title(for: zones, at: noon) != de.title(for: zones, at: noon.addingTimeInterval(60)), "minute rollover")
}

// MARK: LaunchAgent

test("LaunchAgent plist shape, install, toggle, uninstall") {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("multiclock-check-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let a = LaunchAgent(label: "com.example.multiclock.test",
                        executablePath: "/Applications/MultiClock.app/Contents/MacOS/MultiClock",
                        directory: dir)
    equal(a.plist["Label"] as? String, "com.example.multiclock.test")
    equal(a.plist["ProgramArguments"] as? [String], [a.executablePath])
    equal(a.plist["RunAtLoad"] as? Bool, true)
    equal(a.plist["KeepAlive"] as? Bool, false)
    equal(a.fileURL.lastPathComponent, "com.example.multiclock.test.plist")
    check(!a.isInstalled, "fresh dir has no agent")
    try a.toggle()
    check(a.isInstalled, "toggle installs")
    let parsed = try PropertyListSerialization.propertyList(from: Data(contentsOf: a.fileURL), format: nil) as? [String: Any]
    equal(parsed?["Label"] as? String, a.label)
    try a.toggle()
    check(!a.isInstalled, "toggle uninstalls")
    try a.uninstall()
    check(!a.isInstalled, "uninstall is idempotent")
}

print("multiclock-check: \(passed) checks passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
