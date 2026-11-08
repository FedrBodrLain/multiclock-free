#!/bin/sh
# Builds a universal (arm64 + x86_64) MultiClock.app into ~/Applications, signs it ad hoc
# and (re)starts it. Needs only Xcode Command Line Tools:  xcode-select --install
set -e
cd "$(dirname "$0")"
APP="${APP:-$HOME/Applications/MultiClock.app}"

bin_for() { swift build -c release --triple "$1-apple-macosx10.15" --show-bin-path; }
for arch in arm64 x86_64; do
  swift build -c release --triple "$arch-apple-macosx10.15" --product MultiClock 2>&1 | grep -Ev '^(warning: could not determine XCTest|\s+xcrun|\s*$)' || true
done
ARM="$(bin_for arm64)/MultiClock"
X86="$(bin_for x86_64)/MultiClock"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
if [ -x "$ARM" ] && [ -x "$X86" ]; then
  lipo -create "$ARM" "$X86" -output "$APP/Contents/MacOS/MultiClock"
else
  cp "${ARM:-$X86}" "$APP/Contents/MacOS/MultiClock"
fi
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

pkill -x MultiClock 2>/dev/null || true
pkill -x MenuClock  2>/dev/null || true   # v0 name
rm -rf "$HOME/Applications/MenuClock.app"
sleep 0.5
open "$APP"
echo "MultiClock Free installed at $APP"
file "$APP/Contents/MacOS/MultiClock"
