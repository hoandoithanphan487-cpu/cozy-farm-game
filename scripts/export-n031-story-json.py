#!/usr/bin/env python3
"""Export the frozen N-027 manuscript as browser-consumable JSON for N-031."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "scripts/generate-n027-story-content.py"
SOURCE = ROOT / "docs/game/main-story-dialogue-script.md"
OUTPUT = ROOT / "web/creek-sprout/public/full-assets/story.json"


def load_generator():
    spec = importlib.util.spec_from_file_location("n027_story_generator", GENERATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load N-027 story generator")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    generator = load_generator()
    titles, lines = generator.parse(SOURCE)
    stories = []
    for number in range(1, 11):
        arc = f"q{number:02d}"
        stages = []
        for stage in generator.ORDERED_STAGES[arc]:
            stage_lines = [line for line in lines if line.arc == arc and line.stage == stage]
            choices = [generator.choice_to_raw(value) for value in generator.STAGE_CHOICES.get((arc, stage), [])]
            if arc == "q08" and stage == "departureConfirmation":
                choices = ["confirm_departure", "wait"]
            stages.append(
                {
                    "id": generator.STAGE_RAW[stage],
                    "label": stage,
                    "choices": choices,
                    "lines": [
                        {
                            "id": line.runtime_id,
                            "source": line.source_id,
                            "speaker": line.speaker.actor.replace("StoryActorID.", ""),
                            "annotation": line.speaker.annotation,
                            "text": line.text,
                            "condition": line.condition,
                            "origin": line.origin,
                        }
                        for line in stage_lines
                    ],
                }
            )
        stories.append({"id": arc, "title": titles[arc], "stages": stages})

    payload = {
        "schema": 1,
        "source_sha256": generator.FROZEN_SHA256,
        "manuscript_line_count": generator.EXPECTED_MANUSCRIPT_LINES,
        "inline_response_count": generator.EXPECTED_INLINE_RESPONSES,
        "stories": stories,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"N-031 story JSON OK: {len(stories)} stories, {len(lines)} total lines -> {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
