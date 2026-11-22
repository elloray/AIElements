"""Keep the gallery's bundled resources identical to the platform-neutral wire fixtures."""

import argparse
from pathlib import Path

repo = Path(__file__).resolve().parent.parent
source = repo / "Sources" / "AIElementsUIProtocol" / "Resources"
destination = repo / "HarmonyOS" / "gallery" / "src" / "main" / "resources" / "rawfile"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--check", action="store_true", help="check for missing, stale, or unexpected fixtures")
arguments = parser.parse_args()

names = {path.name for path in source.glob("*.json") if path.stem not in {"schema", "dashboard"}}
names.add("dashboard.jsonl")
if arguments.check:
    actual = {path.name for path in destination.iterdir() if path.is_file()}
    stale = sorted(
        name for name in names & actual if (source / name).read_bytes() != (destination / name).read_bytes()
    )
    if names != actual or stale:
        parser.exit(1, f"Missing: {sorted(names - actual)}. Unexpected: {sorted(actual - names)}. Stale: {stale}.\n")
else:
    destination.mkdir(parents=True, exist_ok=True)
    for name in sorted(names):
        (destination / name).write_bytes((source / name).read_bytes())
