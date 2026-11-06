#!/usr/bin/env python3
"""Package the addon as dist/ForeverTouch-<version>.zip (folder at zip root)."""
import os
import re
import zipfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ADDON = "ForeverTouch"


def main():
    toc = open(os.path.join(ROOT, ADDON, ADDON + ".toc"), encoding="utf-8").read()
    version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
    os.makedirs(os.path.join(ROOT, "dist"), exist_ok=True)
    out = os.path.join(ROOT, "dist", f"{ADDON}-{version}.zip")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for base, _, files in os.walk(os.path.join(ROOT, ADDON)):
            for name in sorted(files):
                path = os.path.join(base, name)
                z.write(path, os.path.relpath(path, ROOT))
    print("built", os.path.relpath(out, ROOT))


if __name__ == "__main__":
    main()
