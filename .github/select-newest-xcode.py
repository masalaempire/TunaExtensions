#!/usr/bin/env python3
"""Print the newest Xcode 16 or later installed under /Applications."""

import pathlib
import plistlib
import sys


def version(app):
    plist = app / "Contents" / "Info.plist"
    if not plist.exists():
        return (0,)
    with plist.open("rb") as handle:
        info = plistlib.load(handle)
    parts = []
    raw = str(info.get("CFBundleShortVersionString", "0"))
    for piece in raw.split("."):
        digits = "".join(character for character in piece if character.isdigit())
        parts.append(int(digits or "0"))
    return tuple(parts)


def main():
    apps = [
        app
        for app in pathlib.Path("/Applications").glob("Xcode*.app")
        if version(app) >= (16,)
    ]
    if not apps:
        print("no Xcode 16 or newer found", file=sys.stderr)
        return 1
    print(max(apps, key=version))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
