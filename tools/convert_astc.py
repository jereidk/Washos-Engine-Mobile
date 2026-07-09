#!/usr/bin/env python3
"""
convert_astc.py — Batch PNG → ASTC texture compressor for Washos Engine Mobile.

This script converts PNG images to ASTC format for optimized texture loading
on Android devices with ASTC hardware support.

Requirements
------------
  astcenc   ARM ASTC Encoder — https://github.com/ARM-software/astc-encoder/releases
            Place the binary in PATH or pass --astcenc /path/to/astcenc
  Pillow    pip install Pillow
  NumPy     pip install numpy   (optional — used for edge_energy; falls back to
                                 default block size if not installed)

Usage examples
--------------
  # Preview what would be converted (no files written)
  python tools/convert_astc.py --input assets/shared/images --dry-run

  # Convert all images in a directory, keep PNG alongside .astc
  python tools/convert_astc.py --input assets/shared/images

  # Convert and DELETE PNGs (ASTC-only mode, smaller APK)
  python tools/convert_astc.py --input assets/shared/images --delete-png

  # Use a custom config file
  python tools/convert_astc.py --input assets/ --config tools/astc-config.json

  # Re-convert even if .astc already exists
  python tools/convert_astc.py --input assets/shared/images --force

Config file (astc-config.json)
-------------------------------
  {
    "blocksize": "8x8",
    "quality": "thorough",
    "colorprofile": "cl",
    "exclusions": ["*pixel*", "fonts/"],
    "overrides": {
      "NOTE_assets": { "blocksize": "4x4" },
      "menuBG":      { "blocksize": "12x12" }
    }
  }

Block size guide
----------------
  4x4   — Best quality, largest file. Use for: note skins, health icons,
           UI elements with hard edges, small detailed sprites.
  6x6   — Good quality. Use for: character spritesheets, mid-size sprites.
  8x8   — Balanced. Default for most game assets.
  10x10 — Lower quality, smallest file. Use for: large smooth backgrounds,
           gradient overlays, simple lighting effects.
  12x12 — Lowest quality, smallest file. Use for: very large backgrounds.
"""

import argparse
import fnmatch
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Optional dependencies
# ---------------------------------------------------------------------------

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False

# ---------------------------------------------------------------------------
# Built-in default config
# ---------------------------------------------------------------------------

DEFAULT_CONFIG = {
    "blocksize": "12x12",
    "quality": "exhaustive",
    "colorprofile": "cs",
    "min_size": 500,
    "exclusions": [
        "pixel/",
        "Pixel/",
        "pixelUI/",
        "bfPixel",
        "bfPixels",
        "weebAlt",
        "gfPixel",
        "gf_pixel",
        "fonts/",
        "alphabet",
        "icons/",
    ],
    "overrides": {
        "NOTE_assets":       {"blocksize": "6x6"},
        "sustainHold":       {"blocksize": "6x6"},
        "noteSplashes":      {"blocksize": "6x6"},
        "icon-":             {"blocksize": "4x4"},
        "greenmenu":         {"blocksize": "12x12"},
        "GF_assets":         {"blocksize": "12x12"},
    },
}

# ---------------------------------------------------------------------------
# Edge energy — adaptive block size
# ---------------------------------------------------------------------------

def compute_edge_energy(image_path: Path) -> float:
    """
    Returns a float representing how visually 'detailed' an image is.
    Measures average absolute pixel differences (gradient magnitude) in
    greyscale. Higher = more edges/detail = use smaller ASTC blocks.
    Falls back to 5.0 (→ 8x8) if PIL/NumPy are unavailable.
    """
    if not HAS_PIL or not HAS_NUMPY:
        return 5.0

    try:
        img = Image.open(image_path).convert("L")
        arr = np.array(img, dtype=np.float32)
        dx = np.abs(np.diff(arr, axis=1))
        dy = np.abs(np.diff(arr, axis=0))
        return float(dx.mean() + dy.mean()) / 2.0
    except Exception:
        return 5.0


def blocksize_from_energy(energy: float) -> str:
    if energy > 15.0:
        return "4x4"
    if energy > 8.0:
        return "6x6"
    if energy > 3.0:
        return "8x8"
    return "10x10"

# ---------------------------------------------------------------------------
# Block size selection
# ---------------------------------------------------------------------------

def pick_blocksize(png_path: Path, config: dict) -> str:
    """
    Priority: force_blocksize (--blocksize CLI) → per-asset JSON override → adaptive edge_energy → config default.
    """
    if "force_blocksize" in config:
        return config["force_blocksize"]

    path_str = str(png_path).replace("\\", "/")

    for pattern, override in config.get("overrides", {}).items():
        if pattern in path_str:
            return override.get("blocksize", config["blocksize"])

    if HAS_PIL and HAS_NUMPY:
        energy = compute_edge_energy(png_path)
        return blocksize_from_energy(energy)

    return config["blocksize"]

# ---------------------------------------------------------------------------
# File conversion
# ---------------------------------------------------------------------------

def convert_file(png_path: Path, config: dict, astcenc_path: str, dry_run: bool = False,
                 force: bool = False, delete_png: bool = False) -> tuple:
    """
    Converts a single PNG to ASTC.
    Returns (status, blocksize) where status is 'ok', 'skipped', 'excluded', 'error', 'dry_run'.
    """
    path_str = str(png_path).replace("\\", "/")

    for pattern in config.get("exclusions", []):
        if fnmatch.fnmatch(path_str, f"*{pattern}*") or pattern in path_str:
            return ("excluded", None)

    astc_path = png_path.with_suffix(".astc")

    if astc_path.exists() and not force:
        return ("skipped", None)

    blocksize = pick_blocksize(png_path, config)

    if dry_run:
        return ("dry_run", blocksize)

    bw, bh = blocksize.split("x")

    cmd = [
        astcenc_path,
        "-dxr",
        "-fast",
        "-f",
        config["quality"],
        "-c",
        str(png_path),
        str(astc_path),
        f"{bw}x{bh}",
        config["colorprofile"]
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            print(f"  ✗  astcenc failed for {png_path}: {result.stderr}", file=sys.stderr)
            return ("error", blocksize)
    except subprocess.TimeoutExpired:
        print(f"  ✗  astcenc timed out for {png_path}", file=sys.stderr)
        return ("error", blocksize)
    except Exception as e:
        print(f"  ✗  Failed to run astcenc: {e}", file=sys.stderr)
        return ("error", blocksize)

    if delete_png:
        try:
            png_path.unlink()
        except Exception as e:
            print(f"  ✗  Failed to delete PNG: {e}", file=sys.stderr)

    return ("ok", blocksize)

# ---------------------------------------------------------------------------
# Find astcenc
# ---------------------------------------------------------------------------

def find_astcenc() -> str:
    """Search for astcenc in common locations."""
    candidates = [
        "astcenc",
        "astcenc-avx2",
        "astcenc-sse4.1",
        "astcenc-sse2",
        "./tools/bin/astcenc",
        "./tools/bin/astcenc-avx2",
        Path(__file__).parent / "bin" / "astcenc",
        Path(__file__).parent / "bin" / "astcenc-avx2",
    ]

    for candidate in candidates:
        if sys.platform == "win32" and not str(candidate).endswith(".exe"):
            candidate = str(candidate) + ".exe"
        path = shutil.which(candidate) or (Path(candidate) if Path(candidate).exists() else None)
        if path:
            return str(path)

    return ""

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Convert PNG images to ASTC format.")
    parser.add_argument("input", help="Input directory (recursive) or single PNG file.")
    parser.add_argument("--config", "-c", help="JSON config file. Defaults to tools/astc-config.json.")
    parser.add_argument("--astcenc", help="Path to astcenc binary.")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be converted without writing files.")
    parser.add_argument("--delete-png", action="store_true", help="Delete each PNG after successful conversion.")
    parser.add_argument("--force", action="store_true", help="Re-convert even if .astc already exists.")
    parser.add_argument("--only-oversized", action="store_true", help="Only process images wider or taller than 4096 px.")
    parser.add_argument("--blocksize", "-b", help="Override block size for ALL files.")
    parser.add_argument("--quality", "-q", help="astcenc quality preset: fastest, fast, medium, thorough, verythorough, exhaustive.")
    args = parser.parse_args()

    # Load config
    config = dict(DEFAULT_CONFIG)

    config_path = args.config
    if config_path is None:
        candidate = Path("tools/astc-config.json")
        if candidate.exists():
            config_path = str(candidate)

    if config_path and Path(config_path).exists():
        with open(config_path, encoding="utf-8") as f:
            user_config = json.load(f)
        for key, value in user_config.items():
            if key == "exclusions" and isinstance(value, list):
                config["exclusions"] = list(dict.fromkeys(config.get("exclusions", []) + value))
            elif key == "overrides" and isinstance(value, dict):
                config.setdefault("overrides", {}).update(value)
            elif key not in ("_comment", "_doc"):
                config[key] = value
        print(f"Config loaded from: {config_path}")

    if args.blocksize:
        config["force_blocksize"] = args.blocksize
        config["overrides"] = {}
    if args.quality:
        config["quality"] = args.quality

    delete_png = args.delete_png or config.get("delete_png", False)

    # Find astcenc
    astcenc_path = args.astcenc or find_astcenc()
    if astcenc_path is None and not args.dry_run:
        print("ERROR: astcenc not found in PATH.\n"
              "Download from https://github.com/ARM-software/astc-encoder/releases\n"
              "and place the binary in PATH, or pass --astcenc /path/to/astcenc.",
              file=sys.stderr)
        sys.exit(1)

    if astcenc_path:
        print(f"astcenc: {astcenc_path}")

    # Warn about missing deps
    if not HAS_PIL:
        print("WARNING: Pillow not installed — --only-oversized will not work. pip install Pillow")
    if not HAS_NUMPY:
        print("WARNING: NumPy not installed — adaptive block size disabled. pip install numpy")

    # Collect PNG files
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"ERROR: input path does not exist: {input_path}", file=sys.stderr)
        sys.exit(1)

    if input_path.is_file():
        if input_path.suffix.lower() != ".png":
            print(f"ERROR: input file must be a PNG: {input_path}", file=sys.stderr)
            sys.exit(1)
        png_files = [input_path]
    else:
        png_files = sorted(input_path.rglob("*.png"))

    # Filter by size
    min_size = config.get("min_size", 500)
    if min_size > 0 and HAS_PIL:
        filtered = []
        for f in png_files:
            try:
                with Image.open(f) as img:
                    w, h = img.size
                if w >= min_size or h >= min_size:
                    filtered.append(f)
            except Exception:
                filtered.append(f)
        excluded = len(png_files) - len(filtered)
        if excluded > 0:
            print(f"Size filter (>{min_size}px): {len(png_files)} total → {len(filtered)} ({excluded} excluded)")
        png_files = filtered

    if not png_files:
        print("No PNG files to process.")
        return

    print(f"\nProcessing {len(png_files)} PNG file(s)...\n")

    # Convert
    stats = {"ok": 0, "skipped": 0, "excluded": 0, "error": 0, "dry_run": 0}
    errors = []

    for png_path in png_files:
        status, blocksize = convert_file(
            png_path, config, astcenc_path,
            dry_run=args.dry_run,
            force=args.force,
            delete_png=delete_png,
        )
        stats[status] = stats.get(status, 0) + 1

        if status == "ok":
            suffix = " + PNG deleted" if delete_png else ""
            print(f"  ✓  [{blocksize:>5}]  {png_path}{suffix}")
        elif status == "dry_run":
            print(f"  ~  [{blocksize:>5}]  {png_path}  (dry run)")
        elif status == "excluded":
            print(f"  ─  [  ---  ]  {png_path}  (excluded)")
        elif status == "error":
            print(f"  ✗  [{blocksize:>5}]  {png_path}  FAILED", file=sys.stderr)
            errors.append(png_path)

    # Summary
    print(f"\n{'DRY RUN — ' if args.dry_run else ''}Results:")
    print(f"  Converted : {stats['ok']}")
    print(f"  Dry-run   : {stats['dry_run']}")
    print(f"  Skipped   : {stats['skipped']}  (use --force to redo)")
    print(f"  Excluded  : {stats['excluded']}")
    print(f"  Errors    : {stats['error']}")

    if errors:
        print("\nFailed files:")
        for p in errors:
            print(f"  {p}")
        sys.exit(1)


if __name__ == "__main__":
    main()
