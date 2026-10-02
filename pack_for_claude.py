#!/usr/bin/env python3
"""
pack_for_claude.py

Zips your Godot project for uploading to a Claude chat. Exclude-based:
everything is included EXCEPT what matches the skip lists below, so new
scripts and scenes are picked up automatically.

Place this file in the project root (next to project.godot), then run:

    python pack_for_claude.py
    python pack_for_claude.py --only scripts/player scenes/player

With --only, just those files/folders are packed, plus project.godot and
docs/ (so the handoff and agreement always travel with the snapshot).

Output: snapshots/claude_snapshot_<date>_<time>.zip
(add "snapshots/" to .gitignore)

Standard library only. Does not modify your project.
"""

import argparse
import os
import sys
import zipfile
from datetime import datetime
from pathlib import Path

# ----------------------------------------------------------------------
# EDIT THESE LISTS
# ----------------------------------------------------------------------

# Folders skipped entirely (matched by folder name at any depth).
EXCLUDE_DIRS = {
    ".godot",
    ".git",
    ".vscode",
    ".idea",
    "snapshots",
    "__pycache__",
}

# Files skipped by exact name.
EXCLUDE_FILES = {
    ".gitattributes",
    ".gitignore",
    "icon.svg",
    "pack_for_claude.py",
}

# Generated files skipped by extension.
EXCLUDE_SUFFIXES = {
    ".import",
    ".uid",
    ".tmp",
}

# Binary assets Claude can't read. Skipped, but their NAMES are listed in
# _snapshot_info.txt so Claude knows which assets exist.
BINARY_SUFFIXES = {
    # images
    ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".exr", ".hdr",
    ".dds", ".ktx", ".svg", ".ico", ".gif",
    # audio
    ".wav", ".ogg", ".mp3", ".flac",
    # video
    ".webm", ".mp4", ".ogv",
    # 3D / source art
    ".glb", ".gltf", ".fbx", ".obj", ".dae", ".blend", ".blend1",
    # fonts
    ".ttf", ".otf", ".woff", ".woff2",
    # archives / executables
    ".zip", ".7z", ".rar", ".exe", ".dll", ".pck",
}

# Always included when using --only (relative to the project root).
ALWAYS_INCLUDE = ["project.godot", "docs"]

OUTPUT_DIR = "snapshots"

# ----------------------------------------------------------------------


def is_excluded_file(path: Path) -> str:
    """Return '' if the file should be included, else the reason category."""
    name = path.name
    suffix = path.suffix.lower()
    if name in EXCLUDE_FILES:
        return "skip"
    if suffix in EXCLUDE_SUFFIXES:
        return "skip"
    if suffix in BINARY_SUFFIXES:
        return "binary"
    return ""


def walk_dir(root: Path, start: Path, included: set, binaries: set):
    """Walk 'start', pruning excluded folders, collecting file paths."""
    for dirpath, dirnames, filenames in os.walk(start):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for fname in filenames:
            fpath = Path(dirpath) / fname
            result = is_excluded_file(fpath)
            rel = fpath.relative_to(root)
            if result == "":
                included.add(rel)
            elif result == "binary":
                binaries.add(rel)


def collect(root: Path, only: list):
    included = set()
    binaries = set()

    if not only:
        walk_dir(root, root, included, binaries)
        return included, binaries

    targets = list(ALWAYS_INCLUDE) + list(only)
    for target in targets:
        p = (root / target).resolve()
        try:
            p.relative_to(root)
        except ValueError:
            print(f"  ! skipped (outside the project): {target}")
            continue
        if not p.exists():
            print(f"  ! not found: {target}")
            continue
        if p.is_dir():
            walk_dir(root, p, included, binaries)
        else:
            result = is_excluded_file(p)
            rel = p.relative_to(root)
            if result == "":
                included.add(rel)
            elif result == "binary":
                binaries.add(rel)
    return included, binaries


def build_info(root: Path, included: set, binaries: set, only: list) -> str:
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = [
        "SNAPSHOT INFO",
        f"Created: {now}",
        f"Project folder: {root.name}",
        f"Mode: {'--only ' + ' '.join(only) if only else 'full (everything not excluded)'}",
        "",
        f"INCLUDED FILES ({len(included)})",
    ]
    for rel in sorted(included, key=lambda p: p.as_posix()):
        size = (root / rel).stat().st_size
        lines.append(f"  {rel.as_posix()}  ({size} bytes)")
    lines.append("")
    lines.append(
        f"BINARY ASSETS PRESENT BUT NOT INCLUDED ({len(binaries)}), names only"
    )
    for rel in sorted(binaries, key=lambda p: p.as_posix()):
        lines.append(f"  {rel.as_posix()}")
    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Zip the Godot project for Claude (exclude-based)."
    )
    parser.add_argument(
        "--only",
        nargs="+",
        default=[],
        metavar="PATH",
        help="pack only these files/folders (plus project.godot and docs/)",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent
    if not (root / "project.godot").exists():
        print("project.godot not found next to this script.")
        print("Place pack_for_claude.py in the project root and run it again.")
        sys.exit(1)

    included, binaries = collect(root, args.only)
    if not included:
        print("Nothing to pack. Check your --only paths.")
        sys.exit(1)

    out_dir = root / OUTPUT_DIR
    out_dir.mkdir(exist_ok=True)
    stamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    zip_path = out_dir / f"claude_snapshot_{stamp}.zip"

    info = build_info(root, included, binaries, args.only)

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for rel in sorted(included, key=lambda p: p.as_posix()):
            zf.write(root / rel, arcname=rel.as_posix())
        zf.writestr("_snapshot_info.txt", info)

    total = sum((root / rel).stat().st_size for rel in included)
    print(f"Packed {len(included)} files ({total / 1024:.1f} KB uncompressed)")
    print(f"Skipped {len(binaries)} binary assets (names listed in the info file)")
    print(f"Created: {zip_path}")


if __name__ == "__main__":
    main()
