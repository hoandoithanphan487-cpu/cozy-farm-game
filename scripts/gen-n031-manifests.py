#!/usr/bin/env python3
"""Deterministic N-031 asset/source manifests generator.

Reads the authoritative macOS tree and writes:
- web/creek-sprout/content/source-lock.json  (Swift/content sources consumed)
- artifacts/integration/n-031-web-r3/asset-manifest.json (PNG/MP3 mirror map)

Both outputs are checked in; audit:parity verifies web copies against the
recorded SHA-256 and authority drift via this repository's own files.
"""

import hashlib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAC = os.path.join(ROOT, "macos", "CreekSprout", "CreekSprout")
WEB_PUBLIC = os.path.join(ROOT, "web", "creek-sprout", "public", "full-assets")
WEB_CONTENT = os.path.join(ROOT, "web", "creek-sprout", "content")
ARTIFACTS = os.path.join(ROOT, "artifacts", "integration", "n-031-web-r3")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def js(value):
    return json.dumps(value, ensure_ascii=False, indent=2)


def collect_pngs(root_dir, web_dir):
    out = []
    for name in sorted(os.listdir(root_dir)):
        if not name.lower().endswith(".png"):
            continue
        authority = os.path.join(root_dir, name)
        web_path = os.path.join(web_dir, name)
        size = os.path.getsize(authority)
        out.append(
            {
                "id": name[:-4],
                "authority_relative": os.path.relpath(authority, ROOT),
                "web_relative": os.path.relpath(web_path, ROOT),
                "bytes": size,
                "sha256": sha256(authority),
                "converted": False,
            }
        )
    return out


def main():
    assets = []
    assets += collect_pngs(os.path.join(MAC, "Assets"), os.path.join(WEB_PUBLIC, "assets"))
    assets += collect_pngs(
        os.path.join(MAC, "Presentation", "DisplayR2"),
        os.path.join(WEB_PUBLIC, "display-r2"),
    )
    assets += collect_pngs(
        os.path.join(MAC, "Presentation", "WorldLife"),
        os.path.join(WEB_PUBLIC, "world"),
    )
    assets += collect_pngs(
        os.path.join(MAC, "Presentation", "Portraits"),
        os.path.join(WEB_PUBLIC, "portraits"),
    )
    music_dir = os.path.join(MAC, "Audio", "Resources")
    if os.path.isdir(music_dir):
        for name in sorted(os.listdir(music_dir)):
            if not name.lower().endswith(".mp3"):
                continue
            authority = os.path.join(music_dir, name)
            web_path = os.path.join(WEB_PUBLIC, "music", name)
            assets.append(
                {
                    "id": name[:-4],
                    "authority_relative": os.path.relpath(authority, ROOT),
                    "web_relative": os.path.relpath(web_path, ROOT),
                    "bytes": os.path.getsize(authority),
                    "sha256": sha256(authority),
                    "converted": False,
                }
            )

    swift_sources = [
        "FarmScene.swift",
        "Content/MapDefinition.swift",
        "Content/WorldCatalog.swift",
        "Content/ContentCatalog.swift",
        "Content/NewGameScenarioDefinition.swift",
        "Content/StoryContentModels.swift",
        "Domain/MapTravelService.swift",
        "Presentation/WorldLifeCatalog.swift",
        "Presentation/WorldVisualCatalog.swift",
        "Presentation/RuntimeArtCatalog.swift",
        "Presentation/PixelAssetStore.swift",
        "Presentation/SpriteSheetAnimator.swift",
        "Presentation/CharacterVisualCatalog.swift",
        "Presentation/CharacterVisualNode.swift",
        "Presentation/WorldCamera.swift",
        "Presentation/WorldEffectPresenter.swift",
        "Presentation/BuildingVisualPresenter.swift",
        "Presentation/CharacterVisualDefinition.swift",
        "Presentation/PortraitPresentationCatalog.swift",
    ]
    docs = [
        "docs/game/n-015-map-layout-contract.json",
        "docs/game/n-019-approved-art-inventory.md",
        "docs/game/game-rules.md",
        "docs/game/story-bible.md",
        "docs/game/n-031-vscode-full-web-port-r3-prompt.md",
        "docs/game/n-031-vscode-r3-finish-task.md",
    ]
    source_lock = {
        "generated_by": "scripts/gen-n031-manifests.py",
        "note": "Web port consumes these macOS sources read-only. Any drift must fail audit:parity.",
        "swift": [
            {"relative": "macos/CreekSprout/CreekSprout/" + p, "sha256": sha256(os.path.join(MAC, p))}
            for p in swift_sources
        ],
        "docs": [
            {"relative": p, "sha256": sha256(os.path.join(ROOT, p))} for p in docs
        ],
        "generators": [
            {"relative": "scripts/gen-r22-data.py", "sha256": sha256(os.path.join(ROOT, "scripts", "gen-r22-data.py"))},
            {"relative": "scripts/gen-n031-manifests.py", "sha256": sha256(os.path.join(ROOT, "scripts", "gen-n031-manifests.py"))},
        ],
    }

    os.makedirs(WEB_CONTENT, exist_ok=True)
    os.makedirs(ARTIFACTS, exist_ok=True)
    with open(os.path.join(WEB_CONTENT, "source-lock.json"), "w", encoding="utf-8") as fh:
        fh.write(js(source_lock))
    manifest = {
        "generated_by": "scripts/gen-n031-manifests.py",
        "generated_at": "2026-09-06",
        "asset_count": len(assets),
        "assets": assets,
    }
    with open(os.path.join(ARTIFACTS, "asset-manifest.json"), "w", encoding="utf-8") as fh:
        fh.write(js(manifest))
    print("assets=%d sources=%d docs=%d" % (len(assets), len(swift_sources), len(docs)))


if __name__ == "__main__":
    sys.exit(main())
