import Cocoa
import MultiClockCore

// MultiClock Free: two time zones in the macOS menu bar.
// All logic that can be unit-tested lives in MultiClockCore; this file is AppKit glue.

final class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    let defaults = UserDefaults.standard
    var renderer = ClockRenderer()
    var zones: [Zone] = []
    var infoItems: [NSMenuItem] = []
    var timer: Timer?
    var lastTitle = ""

    var agent: LaunchAgent {
        LaunchAgent(label: "com.fedrbodr.multiclock",
                    executablePath: Bundle.main.executablePath ?? CommandLine.arguments[0])
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        if let bid = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bid).count > 1 {
            NSApp.terminate(nil)
            return
        }
        zones = [
            Zone(stored: defaults.string(forKey: "zone1") ?? "") ?? Presets.first,
            Zone(stored: defaults.string(forKey: "zone2") ?? "") ?? Presets.second,
        ]
        defaults.register(defaults: ["showDate": true])
        migrateLegacyAgent()
        menu.autoenablesItems = false
        item.menu = menu
        rebuildMenu()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        timer?.tolerance = 0.3
    }

    /// v0 shipped as "MenuClock" with its own LaunchAgent; move opted-in users over once.
    func migrateLegacyAgent() {
        let old = LaunchAgent(label: "com.fedrbodr.menuclock", executablePath: "")
        guard old.isInstalled, !agent.isInstalled else { return }
        try? agent.install()
        try? old.uninstall()
    }

    // MARK: - Rendering

    func tick() {
        let now = Date()
        renderer.showDate = defaults.bool(forKey: "showDate")
        renderer.localZone = zones.first?.timeZone ?? .autoupdatingCurrent   // one date for all zones: the first zone's
        let title = renderer.title(for: zones, at: now)
        guard title != lastTitle else { return }
        lastTitle = title
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        item.button?.attributedTitle = NSAttributedString(string: title, attributes: [.font: font])
        for (i, z) in zones.enumerated() where i < infoItems.count {
            infoItems[i].title = renderer.detailLine(for: z, at: now)
        }
    }

    // MARK: - Menu

    func rebuildMenu() {
        menu.removeAllItems()
        infoItems = zones.map { _ in
            let mi = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            mi.isEnabled = false
            return mi
        }
        infoItems.forEach { menu.addItem($0) }
        menu.addItem(.separator())
        menu.addItem(zoneSubmenu(title: "Первый пояс / First zone", slot: 0))
        menu.addItem(zoneSubmenu(title: "Второй пояс / Second zone", slot: 1))
        menu.addItem(.separator())
        let dateItem = NSMenuItem(title: "Показывать дату / Show date", action: #selector(toggleDate(_:)), keyEquivalent: "")
        dateItem.target = self
        dateItem.state = defaults.bool(forKey: "showDate") ? .on : .off
        menu.addItem(dateItem)
        let auto = NSMenuItem(title: "Запускать при входе / Launch at login",
                              action: #selector(toggleAutostart(_:)), keyEquivalent: "")
        auto.target = self
        auto.state = agent.isInstalled ? .on : .off
        menu.addItem(auto)
        menu.addItem(NSMenuItem(title: "Выход / Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        lastTitle = ""
        tick()
    }

    func zoneSubmenu(title: String, slot: Int) -> NSMenuItem {
        let sub = NSMenu()
        sub.autoenablesItems = false
        for (i, z) in Presets.zones.enumerated() {
            let mi = NSMenuItem(title: "\(z.label)  —  \(z.id)", action: #selector(pickZone(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = slot * 1000 + i
            mi.state = zones[slot] == z ? .on : .off
            sub.addItem(mi)
        }
        sub.addItem(.separator())
        let custom = NSMenuItem(title: "Другой… / Other…", action: #selector(customZone(_:)), keyEquivalent: "")
        custom.target = self
        custom.tag = slot
        if !Presets.zones.contains(zones[slot]) {
            custom.state = .on
            custom.title = "Другой… / Other…  (\(zones[slot].label)  —  \(zones[slot].id))"
        }
        sub.addItem(custom)
        let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        holder.submenu = sub
        return holder
    }

    func setZone(_ z: Zone, slot: Int) {
        zones[slot] = z
        defaults.set(z.stored, forKey: slot == 0 ? "zone1" : "zone2")
        rebuildMenu()
    }

    @objc func pickZone(_ sender: NSMenuItem) {
        let slot = sender.tag / 1000, idx = sender.tag % 1000
        guard slot < zones.count, idx < Presets.zones.count else { return }
        setZone(Presets.zones[idx], slot: slot)
    }

    @objc func customZone(_ sender: NSMenuItem) {
        let slot = sender.tag
        guard slot < zones.count else { return }
        let current = zones[slot]

        let alert = NSAlert()
        alert.messageText = "Свой часовой пояс / Custom time zone"
        alert.informativeText = "Короткая подпись и идентификатор пояса, например Europe/Lisbon.\nShort label and IANA identifier."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Отмена / Cancel")

        let label = NSTextField(string: current.label)
        label.placeholderString = "Подпись / Label"
        let combo = NSComboBox(frame: .zero)
        combo.addItems(withObjectValues: TimeZone.knownTimeZoneIdentifiers)
        combo.completes = true
        combo.stringValue = current.id
        combo.placeholderString = "Region/City"
        let stack = NSStackView(views: [label, combo])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 320, height: 58)
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 320),
            combo.widthAnchor.constraint(equalToConstant: 320),
        ])
        alert.accessoryView = stack
        alert.window.initialFirstResponder = label

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let id = combo.stringValue.trimmingCharacters(in: .whitespaces)
        var lbl = label.stringValue.trimmingCharacters(in: .whitespaces)
        guard TimeZone(identifier: id) != nil else {
            let err = NSAlert()
            err.alertStyle = .warning
            err.messageText = "Неизвестный пояс / Unknown time zone"
            err.informativeText = "«\(id)» нет в списке часовых поясов системы."
            err.runModal()
            return
        }
        if lbl.isEmpty { lbl = Zone.defaultLabel(for: id) }
        setZone(Zone(label: lbl, id: id), slot: slot)
    }

    @objc func toggleDate(_ sender: NSMenuItem) {
        defaults.set(!defaults.bool(forKey: "showDate"), forKey: "showDate")
        rebuildMenu()
    }

    // MARK: - Autostart

    @objc func toggleAutostart(_ sender: NSMenuItem) {
        try? agent.toggle()
        rebuildMenu()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
