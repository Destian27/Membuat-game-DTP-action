#!/usr/bin/env python3
"""Validate the shared technical format of animated character PNGs for Godot.

Usage:
    python3 tools/validate_character_assets.py
    python3 tools/validate_character_assets.py --assets /path/to/project/assets

Requires Pillow (already used by tools/gen_chars.py). This checks technical
consistency, not subjective visual quality.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from PIL import Image

FRAME_NAME = re.compile(r"^(idle|walk|shoot|die|jump|skill)_\d+\.png$")


def validate(assets_dir: Path, expected_size: int) -> list[str]:
    errors: list[str] = []
    character_dirs = sorted(path for path in assets_dir.glob("char_*") if path.is_dir())
    if not character_dirs:
        return [f"No character folders found: {assets_dir / 'char_*'}"]

    checked = 0
    for folder in character_dirs:
        frames = sorted(path for path in folder.glob("*.png") if FRAME_NAME.match(path.name))
        if not frames:
            continue
        for path in frames:
            checked += 1
            try:
                with Image.open(path) as image:
                    image.load()
                    if image.format != "PNG":
                        errors.append(f"{path}: file is not encoded as PNG")
                    if image.size != (expected_size, expected_size):
                        errors.append(
                            f"{path}: expected {expected_size}x{expected_size}, got {image.width}x{image.height}"
                        )
                    if image.mode != "RGBA":
                        errors.append(f"{path}: expected RGBA color with alpha, got {image.mode}")
                    elif image.getchannel("A").getextrema() == (0, 0):
                        errors.append(f"{path}: image is fully transparent")
            except Exception as exc:  # Pillow reports corrupt/unsupported image data here.
                errors.append(f"{path}: cannot read image ({exc})")

    if checked == 0:
        errors.append(f"No numbered animation frames found in {assets_dir / 'char_*'}")
    elif not errors:
        print(f"OK: validated {checked} character frames in {len(character_dirs)} character folders.")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assets", type=Path, default=Path(__file__).resolve().parents[1] / "assets",
                        help="Godot project's assets directory")
    parser.add_argument("--size", type=int, default=256, help="Required square frame size (default: 256)")
    args = parser.parse_args()

    if args.size <= 0:
        parser.error("--size must be a positive integer")
    errors = validate(args.assets, args.size)
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
