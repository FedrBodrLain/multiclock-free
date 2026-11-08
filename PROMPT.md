# Prompt-plan: build MultiClock Free on a Mac

Paste everything below this line into Claude Code, Codex or any coding agent
running on a Mac. It contains the goal, the constraints, the acceptance tests
and the traps we already fell into, so the agent gets it right the first time.

---

## Goal

Build **MultiClock Free**: a tiny macOS menu bar app that shows two time zones
next to the system clock, for example `DE 23:57   MSK 01:57⁺¹`. It must build,
test, install and run on this Mac today, with nothing but Apple's Command Line
Tools. No Xcode.app, no Homebrew, no third-party packages, no network calls.

## Hard constraints

1. Language and frameworks: Swift and AppKit only. Package manager: SwiftPM
   with `Package.swift` (`swift-tools-version:5.9`, platform `.macOS(.v10_15)`).
2. Must run on macOS 10.15 Catalina and newer, on Apple Silicon and Intel.
   Ship a universal binary.
3. No XCTest. Command Line Tools installs do not have it, and `swift test`
   fails with `error: XCTest not available`. Tests are an executable target
   `multiclock-check` with its own three-line assertion helper; `swift run
   multiclock-check` exits non-zero on any failure.
4. No Dock icon: `LSUIElement = true` and `NSApp.setActivationPolicy(.accessory)`.
5. Single instance: on launch, if another process with the same bundle
   identifier is running, quit.
6. Settings in `UserDefaults` under keys `zone1` and `zone2`, stored as
   `LABEL|Region/City`. Invalid or missing values fall back to defaults.
7. Launch at login through a per-user LaunchAgent
   `~/Library/LaunchAgents/com.fedrbodr.multiclock.plist`, written and removed
   by the app itself from a menu toggle. No SMAppService, no helper tools, no
   `launchctl` calls (the file takes effect at next login, which is enough).
8. Every string that can be unit-tested lives in a library target
   `MultiClockCore`. The executable target `MultiClock` is AppKit glue only.

## Features

- Status item with a text title, monospaced digits
  (`NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)`), updated
  by a 1-second `Timer` with tolerance 0.3, but the title is re-set only when
  the string changes.
- Title format: `<label> <time>` per zone, zones joined by three spaces.
  Time format from the user's locale via the `jmm` template (24h in de_DE,
  `11:57 PM` in en_US).
- Day marker: if the zone's calendar date differs from the local date at the
  same instant, append `⁺¹` or `⁻¹` (Unicode superscripts).
- Defaults: zone 1 `DE` = `Europe/Berlin`, zone 2 `MSK` = `Europe/Moscow`.
- Presets (label ≤ 4 characters, all IANA identifiers valid, no duplicates):
  DE Berlin, MSK Moscow, UA Kyiv, UK London, PT Lisbon, RS Belgrade, TR
  Istanbul, GE Tbilisi, AM Yerevan, UAE Dubai, KZ Almaty, IN Kolkata, TH
  Bangkok, BALI Makassar, SG Singapore, JP Tokyo, SYD Sydney, NY New_York,
  LA Los_Angeles, UTC.
- Menu: two disabled info lines (`MSK  Sun 9 Nov 01:57  ·  Europe/Moscow`),
  separator, submenus **First zone** and **Second zone** (presets with a
  checkmark on the current one, separator, **Other…**), separator, **Launch
  at login** toggle with checkmark, **Quit** (⌘Q). Labels bilingual
  `Первый пояс / First zone`.
- **Other…** opens an `NSAlert` with two accessory fields: a label
  `NSTextField` and an `NSComboBox` filled with
  `TimeZone.knownTimeZoneIdentifiers`, `completes = true`. Unknown identifier
  → warning alert, nothing saved. Empty label → default label: up to 4
  uppercase letters of the city part (`Europe/Lisbon` → `LISB`,
  `America/New_York` → `NEWY`, `UTC` → `UTC`).

## Repository layout

```
Package.swift
Sources/MultiClockCore/Zone.swift          Zone, Presets
Sources/MultiClockCore/ClockRenderer.swift title(), segment(), dayOffset(), dayMarker(), detailLine()
Sources/MultiClockCore/LaunchAgent.swift   plist, install(), uninstall(), toggle(), isInstalled
Sources/MultiClock/main.swift              App: NSApplicationDelegate
Sources/multiclock-check/main.swift        the checks
Resources/Info.plist
build.sh
README.md  PROMPT.md  PROMPT.ru.md  LICENSE (MIT)  .gitignore (.build/ .swiftpm/ *.zip)
docs/native-clock.md  docs/images/before.png  docs/images/after.png
```

`ClockRenderer(locale:localZone:separator:)` is injectable so tests are
deterministic: tests use `Locale(identifier: "de_DE")`, `Europe/Berlin` as
local zone and fixed `Date(timeIntervalSince1970:)` values.

## Acceptance tests (`swift run -c release multiclock-check`)

Fixed instants: `late = 1_793_573_820` (2026-11-08 22:57 UTC = 23:57 Berlin,
01:57 next day Moscow), `noon = 1_782_900_000` (2026-07-01 10:00 UTC = 12:00
Berlin, 13:00 Moscow, 19:00 Tokyo).

1. `Zone(label:"MSK", id:"Europe/Moscow").stored == "MSK|Europe/Moscow"` and
   parses back to an equal value.
2. `Zone(stored:)` returns nil for `""`, `"no-separator"`, `"|Europe/Berlin"`,
   `"X|Mars/Olympus_Mons"`; trims whitespace in `" DE | Europe/Berlin "`.
3. `Zone.defaultLabel(for:)`: `Europe/Lisbon → LISB`, `America/New_York →
   NEWY`, `UTC → UTC`.
4. Every preset identifier is accepted by `TimeZone(identifier:)`; labels ≤ 4
   chars; labels unique; ids unique; first is Berlin, second Moscow.
5. `title([DE Berlin, MSK Moscow], at: late) == "DE 23:57   MSK 01:57⁺¹"`.
6. `segment(MSK, at: noon) == "MSK 13:00"`, `dayOffset(Moscow, noon) == 0`.
7. `dayOffset(Moscow, late) == 1`; `dayOffset(Los_Angeles, late) == 0`;
   at `late + 3780 s` (01:00 Berlin) `dayOffset(Los_Angeles) == -1` and
   `dayMarker == "⁻¹"`.
8. With `en_US` the Berlin segment at `late` starts with `DE 11:57` and
   contains `pm` (case-insensitive).
9. `detailLine(JP Tokyo, at: noon)` starts with `JP  `, ends with
   `Asia/Tokyo`, contains `19:00`.
10. Title is identical at `noon` and `noon + 59 s`, different at `noon + 60 s`.
11. `LaunchAgent` in a temp directory: plist has `Label`, `ProgramArguments ==
    [executablePath]`, `RunAtLoad == true`, `KeepAlive == false`; file name is
    `<label>.plist`; `toggle()` installs, the written file parses back with
    the same label, `toggle()` again removes, `uninstall()` is idempotent.

Expected output: `multiclock-check: N checks passed, 0 failed`, exit code 0.

## Manual checks (do them, do not assume)

1. `./build.sh` prints the install path and `file` reports
   `Mach-O universal binary with 2 architectures`.
2. `pgrep -x MultiClock` shows exactly one process after a second launch.
3. `screencapture -x -R <x>,0,1000,30 out.png` of the menu bar shows
   `DE HH:MM   MSK HH:MM` (compare with `TZ=Europe/Berlin date +%H:%M`).
4. Click the item: both submenus open, picking a preset changes the title
   immediately and `defaults read com.fedrbodr.multiclock` shows it.
5. **Launch at login** creates and removes the plist; `plutil -lint` passes.

## Build script contract (`build.sh`)

- Builds release per architecture: `swift build -c release --triple
  arm64-apple-macosx10.15 --product MultiClock` and the same with `x86_64`,
  then `lipo -create` into `MultiClock.app/Contents/MacOS/MultiClock`.
  Do **not** use `--arch arm64 --arch x86_64`: that path needs xcbuild from
  Xcode.app and fails on Command Line Tools.
- Copies `Resources/Info.plist`, `codesign --force --sign -` (ad hoc),
  kills a running instance, `open`s the new one. Target path
  `~/Applications/MultiClock.app`, overridable with `APP=`.

## Info.plist keys

`CFBundleIdentifier com.fedrbodr.multiclock`, `CFBundleExecutable MultiClock`,
`CFBundleName MultiClock`, `CFBundleDisplayName MultiClock Free`,
`CFBundlePackageType APPL`, `CFBundleShortVersionString 1.0.0`,
`LSMinimumSystemVersion 10.15`, `LSUIElement true`, `NSHighResolutionCapable true`.

## Traps we already hit

- Command Line Tools have no XCTest and no xcbuild. See constraints 3 and the
  build script contract.
- If the agent's sandbox refuses to write `~/Library/LaunchAgents`, do not
  fight it: the app writes the file when the user clicks the toggle.
- Changing the bundle identifier makes macOS forget the item's position in the
  menu bar. Tell the user to ⌘-drag it once.
- The system clock cannot be removed from the menu bar. It can be shrunk to an
  analog dial without date and weekday; the recipe is in `docs/native-clock.md`.
- Items to the right of Control Center and the system clock are not allowed;
  the closest position is immediately left of them.
- An ad hoc signed app downloaded from the internet is quarantined. README
  tells users to right-click → Open once, or `xattr -d com.apple.quarantine`.

## Plan

1. Scaffold the package, write `MultiClockCore` and the check runner first,
   run `swift run multiclock-check` until it prints `0 failed`.
2. Write `main.swift`, `Info.plist`, `build.sh`; run `./build.sh`; do the
   manual checks with a real screenshot.
3. Write `README.md` (install from Releases or build, usage, hide the system
   clock), `docs/native-clock.md`, `LICENSE`, `.gitignore`.
4. `git init`, commit, create the public GitHub repository, push, tag `v1.0.0`,
   attach `MultiClock-1.0.0.zip` made with
   `ditto -c -k --keepParent ~/Applications/MultiClock.app MultiClock-1.0.0.zip`.
5. Report: check output, screenshot, repository and release URLs, and anything
   skipped with the reason.
