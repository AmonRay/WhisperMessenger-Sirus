#!/usr/bin/env python3
"""Convert Media/*.png to 32-bit uncompressed .tga for the 3.3.5a client.

The WotLK client loads TGA and BLP only; PNG files render as a missing
texture. Every image must also have power-of-two dimensions, which the
current art already satisfies (the script fails loudly otherwise).

Usage:
  python scripts/convert_media_wrath.py          # write Media/*.tga
  python scripts/convert_media_wrath.py --check  # verify only, non-zero on drift
"""

import argparse
import os
import sys

from PIL import Image

MEDIA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Media")


def is_power_of_two(value):
    return value > 0 and value & (value - 1) == 0


def convert(path, check):
    with Image.open(path) as image:
        width, height = image.size
        if not (is_power_of_two(width) and is_power_of_two(height)):
            raise SystemExit(f"{os.path.basename(path)}: {width}x{height} is not power-of-two")
        target = os.path.splitext(path)[0] + ".tga"
        converted = image.convert("RGBA")
        if check:
            if not os.path.exists(target):
                raise SystemExit(f"missing {os.path.basename(target)}")
            with Image.open(target) as existing:
                if existing.convert("RGBA").tobytes() != converted.tobytes():
                    raise SystemExit(f"stale {os.path.basename(target)}")
            return target
        # compression=None keeps the TGA uncompressed, which the client expects.
        converted.save(target, format="TGA", compression=None)
        return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify the .tga files match the .png art")
    args = parser.parse_args()

    sources = sorted(
        os.path.join(MEDIA_DIR, name) for name in os.listdir(MEDIA_DIR) if name.lower().endswith(".png")
    )
    if not sources:
        print("no PNG media found", file=sys.stderr)
        return 1
    for path in sources:
        target = convert(path, args.check)
        print(("verified " if args.check else "wrote ") + os.path.relpath(target))
    return 0


if __name__ == "__main__":
    sys.exit(main())
