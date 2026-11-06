#!/usr/bin/env python3
"""Package a real, unsigned device build for local signing with AltStore Classic."""
import argparse
import os
from pathlib import Path
import plistlib
import stat
import zipfile


def package(app: Path, output: Path) -> None:
    if not app.is_dir() or app.suffix != ".app":
        raise ValueError("Expected a compiled .app directory from the iphoneos SDK.")
    with (app / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    executable = app / info["CFBundleExecutable"]
    if not executable.is_file():
        raise ValueError("The compiled app executable is missing.")
    if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
        raise ValueError("Expected an iPhoneOS device build, not an iPhone simulator build.")
    if not os.access(executable, os.X_OK):
        raise ValueError("The app executable is not marked executable.")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for item in sorted(app.rglob("*")):
            name = "Payload/" + app.name + "/" + item.relative_to(app).as_posix()
            if item.is_symlink():
                entry = zipfile.ZipInfo(name)
                entry.create_system = 3
                entry.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(entry, os.readlink(item))
            elif item.is_file():
                archive.write(item, name)
    print(f"Unsigned app package created: {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    package(args.app, args.output)
