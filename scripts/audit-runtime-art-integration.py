#!/usr/bin/env python3
"""Audit N-006 runtime art integrity and current literal Swift consumption.

The default audit is read-only and prints JSON. Literal Swift references are an
informational baseline because later catalogs may construct filenames from typed
descriptors. Use --require-all-consumers only after N-015 integration is complete.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "artifacts/art-style/runtime-batch-r0/manifest.json"
DEFAULT_OVERRIDES = ROOT / "artifacts/art-style/n-003-first-round/pixel-check.json"
DEFAULT_CHARACTER_OVERRIDES = ROOT / "docs/game/n-015-character-overrides.json"
DEFAULT_ADDITIONS = ROOT / "docs/game/n-015-runtime-additions.json"
DEFAULT_ASSETS = ROOT / "macos/CreekSprout/CreekSprout/Assets"
DEFAULT_SWIFT = ROOT / "macos/CreekSprout/CreekSprout"


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG file")
    return struct.unpack(">II", header[16:24])


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def category(filename: str) -> str:
    return filename.split("_", 1)[0]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--approved-overrides", type=Path, default=DEFAULT_OVERRIDES)
    parser.add_argument(
        "--approved-character-overrides", type=Path, default=DEFAULT_CHARACTER_OVERRIDES
    )
    parser.add_argument("--approved-additions", type=Path, default=DEFAULT_ADDITIONS)
    parser.add_argument("--assets", type=Path, default=DEFAULT_ASSETS)
    parser.add_argument("--swift-root", type=Path, default=DEFAULT_SWIFT)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--require-all-consumers", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    runtime = [item for item in manifest["assets"] if item["scope"] == "runtime"]
    expected = {item["file"]: item for item in runtime}
    base_hashes = {item["file"]: item["sha256"] for item in runtime}
    overrides_document = json.loads(args.approved_overrides.read_text(encoding="utf-8"))
    overrides = {item["file"]: item for item in overrides_document["assets"]}
    unknown_overrides = sorted(set(overrides) - set(expected))
    expected.update({name: item for name, item in overrides.items() if name in expected})
    character_overrides_document = json.loads(
        args.approved_character_overrides.read_text(encoding="utf-8")
    )
    character_overrides = {
        item["file"]: item for item in character_overrides_document["assets"]
    }
    unknown_character_overrides = sorted(set(character_overrides) - set(expected))
    expected.update(
        {name: item for name, item in character_overrides.items() if name in expected}
    )
    additions_document = json.loads(args.approved_additions.read_text(encoding="utf-8"))
    additions = {item["file"]: item for item in additions_document["assets"]}
    duplicate_additions = sorted(set(additions) & set(expected))
    expected.update({name: item for name, item in additions.items() if name not in expected})
    actual = {path.name: path for path in args.assets.glob("*.png")}

    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))
    dimension_mismatches: list[dict[str, object]] = []
    hash_mismatches: list[dict[str, str]] = []
    invalid_png: list[dict[str, str]] = []

    for filename in sorted(set(expected) & set(actual)):
        item = expected[filename]
        path = actual[filename]
        try:
            observed_size = png_size(path)
        except ValueError as error:
            invalid_png.append({"file": filename, "error": str(error)})
            continue
        wanted_size = (item["width"], item["height"])
        if observed_size != wanted_size:
            dimension_mismatches.append(
                {"file": filename, "expected": wanted_size, "actual": observed_size}
            )
        observed_hash = sha256(path)
        if observed_hash != item["sha256"]:
            hash_mismatches.append(
                {"file": filename, "expected": item["sha256"], "actual": observed_hash}
            )

    swift_sources = sorted(args.swift_root.rglob("*.swift"))
    swift_text = "\n".join(path.read_text(encoding="utf-8") for path in swift_sources)
    literal_consumers = sorted(
        filename for filename in expected if Path(filename).stem in swift_text
    )
    typed_consumers = set(literal_consumers)
    if '"crop_\\(slug)_stage_\\(visualStage)"' in swift_text:
        typed_consumers.update(
            filename
            for filename in expected
            if filename.startswith("crop_") and "_stage_" in filename
        )
    resolved_consumers = sorted(typed_consumers)
    unreferenced = sorted(set(expected) - set(resolved_consumers))

    category_counts = Counter(category(filename) for filename in expected)
    resolved_category_counts = Counter(category(filename) for filename in resolved_consumers)
    integrity_pass = not (
        missing or extra or dimension_mismatches or hash_mismatches or invalid_png
    ) and len(runtime) == 131 and not unknown_overrides and not unknown_character_overrides and not duplicate_additions
    consumer_pass = len(resolved_consumers) == len(expected)

    report = {
        "schema_version": 1,
        "baseline": {
            "base_manifest": str(args.manifest.relative_to(ROOT)),
            "approved_overrides": str(args.approved_overrides.relative_to(ROOT)),
            "approved_character_overrides": str(
                args.approved_character_overrides.relative_to(ROOT)
            ),
            "approved_additions": str(args.approved_additions.relative_to(ROOT)),
            "base_count": len(runtime),
            "approved_override_count": len(overrides),
            "approved_character_override_count": len(character_overrides),
            "approved_addition_count": len(additions),
            "unknown_overrides": unknown_overrides,
            "unknown_character_overrides": unknown_character_overrides,
            "duplicate_additions": duplicate_additions,
            "override_files": sorted(overrides),
            "character_override_files": sorted(character_overrides),
            "base_hashes_replaced": sorted(
                name
                for name, item in overrides.items()
                if name in base_hashes and item["sha256"] != base_hashes[name]
            ),
            "character_base_hashes_replaced": sorted(
                name
                for name, item in character_overrides.items()
                if name in base_hashes and item["sha256"] != base_hashes[name]
            ),
        },
        "assets_directory": str(args.assets.relative_to(ROOT)),
        "runtime_manifest_count": len(expected),
        "asset_png_count": len(actual),
        "category_counts": dict(sorted(category_counts.items())),
        "integrity": {
            "pass": integrity_pass,
            "missing": missing,
            "extra": extra,
            "dimension_mismatches": dimension_mismatches,
            "hash_mismatches": hash_mismatches,
            "invalid_png": invalid_png,
        },
        "swift_literal_consumption": {
            "informational_only": not args.require_all_consumers,
            "swift_file_count": len(swift_sources),
            "literal_referenced_count": len(literal_consumers),
            "resolved_referenced_count": len(resolved_consumers),
            "unreferenced_count": len(unreferenced),
            "category_counts": dict(sorted(resolved_category_counts.items())),
            "literal_referenced": literal_consumers,
            "resolved_referenced": resolved_consumers,
            "unreferenced": unreferenced,
            "pass": consumer_pass,
        },
        "overall_pass": integrity_pass and (
            consumer_pass if args.require_all_consumers else True
        ),
    }
    rendered = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    sys.stdout.write(rendered)
    return 0 if report["overall_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
