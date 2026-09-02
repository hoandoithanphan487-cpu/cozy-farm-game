#!/usr/bin/env python3
"""Generate the typed N-027 Swift story catalog from the frozen N-026 script.

Markdown is a development-time authority only. The app compiles and consumes
the generated Swift definitions; it never parses the manuscript at runtime.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from dataclasses import dataclass
from pathlib import Path


FROZEN_SHA256 = "7986d4247e2ad2d23e0af3195788257a1c4d166582911f3e4ca280e6e80d3d52"
EXPECTED_MANUSCRIPT_LINES = 236
EXPECTED_INLINE_RESPONSES = 20

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "docs/game/main-story-dialogue-script.md"
DEFAULT_OUTPUT = (
    ROOT
    / "macos/CreekSprout/CreekSprout/Content/StoryGeneratedContent.swift"
)

SOURCE_LINE = re.compile(
    r"^(?P<indent>\s*)- `(?P<source>Q\d{2}_[A-Z0-9_]+)` "
    r"(?P<speaker>[^：]+)：“(?P<text>.*)”\s*$"
)
INLINE_RESPONSE = re.compile(
    r"^(?P<indent>\s*)- `?\[(?P<label>[^]]+)\]`? "
    r"(?P<speaker>[^：]+)：“(?P<text>.*)”\s*$"
)
CHOICE_LABEL = re.compile(r"^(?P<indent>\s*)- `?\[(?P<label>[^]]+)\]`?\s*$")
ARC_HEADER = re.compile(r"^## Q(?P<number>\d{2})《(?P<title>[^》]+)》")
STAGE_HEADER = re.compile(r"^### (?P<title>.+)$")


ACTOR_IDS = {
    "水工学徒": "StoryActorID.waterApprentice",
    "种源管理员": "StoryActorID.seedSteward",
    "溪岸巡护员": "StoryActorID.creekWarden",
    "涧麦婶": "StoryActorID.neighborHearsay",
    "石灯": "StoryActorID.neighborStoryteller",
    "青砚": "StoryActorID.neighborEvidence",
    "絮宁": "StoryActorID.neighborConsensus",
    "黑猫店员": "StoryActorID.catShopBlack",
    "三花店员": "StoryActorID.catShopCalico",
    "布偶猫店员": "StoryActorID.catShopRagdoll",
    "绒铃": "StoryActorID.bellPrincess",
    "灰栅代表": "StoryActorID.greygateRepresentative",
    "灰栅农场主": "StoryActorID.greygateFarmer",
    "系统": "StoryActorID.system",
    "账簿": "StoryActorID.ledger",
}

ATTRIBUTED_LEDGER = {
    "青砚": "StoryActorID.neighborEvidence",
    "种源管理员": "StoryActorID.seedSteward",
    "绒铃": "StoryActorID.bellPrincess",
}

# Chinese intent label -> Swift enum case. These are the branch labels frozen
# in the manuscript, not localized matching performed by the app.
CHOICE_CASES = {
    "先保生长田": "fieldFirst",
    "先稳下游芦线": "reedFirst",
    "先查闸再分水": "inspectFirst",
    "派人抢收": "harvest",
    "派人搬沙袋": "sandbag",
    "派人巡田": "patrol",
    "派人安置动物": "livestock",
    "公开切果检验": "cutTest",
    "追查三种说法": "traceRumor",
    "先保护库存": "protectInventory",
    "按根系和生长记录重分组": "regroup",
    "两批继续并种": "parallelCrop",
    "公开缺页与标签异常": "publishMissingPage",
    "拒绝独家，要求公开数量单": "publicOrder",
    "提出多农场联合供货": "coop",
    "暂缓签约，先完成现有订单": "delay",
    "请两人分别说事实与感受": "talk",
    "拒绝替任何人站队": "noSide",
    "建议暂时分开冷静": "pause",
    "优先开放保底菜单": "menu",
    "优先调度现有库存": "inventory",
    "优先组织临时采收": "harvest",
    "优先照料动物与供货交接": "livestock",
    "证据路线": "evidence",
    "商业联合路线": "tradeUnion",
    "旧水道营救路线": "oldWaterway",
    "带走账簿，当众对质": "takeLedger",
    "留在原地，继续读完": "keepReading",
    "合上账簿，不回应": "closeLedger",
    "把两块英雄牌放到账簿上": "returnTitles",
    "质问：为什么是我": "whyMe",
    "质问：有没有一句是真的": "anyTruth",
    "沉默": "silence",
    "摔下守渠木牌与主心骨披肩": "breakTitles",
    "回田里完成最后一次浇水": "water",
    "停止浇水并离开农场": "leave",
}

ACTION_IDS = {
    "确认托管并出发": "brookseed.story.q08.action.confirm_departure",
    "暂不出发": "brookseed.story.q08.action.wait",
}

ORDERED_STAGES = {
    **{
        f"q{number:02d}": [
            "benefit",
            "warningOne",
            "warningTwo",
            "eruption",
            "aftermath",
            "revealCallback",
        ]
        for number in range(1, 8)
    },
    "q08": [
        "benefit",
        "warningOne",
        "warningTwo",
        "eruption",
        "departureConfirmation",
        "climax",
        "aftermath",
        "revealCallback",
    ],
    "q09": ["discovery", "interrupt", "playerIntent", "turningPoint"],
    "q10": [
        "confrontationOpen",
        "playerIntent",
        "allEvil",
        "lastFarmAction",
        "graduation",
    ],
}

STAGE_RAW = {
    "benefit": "benefit",
    "warningOne": "warning_1",
    "warningTwo": "warning_2",
    "eruption": "eruption",
    "departureConfirmation": "departure_confirmation",
    "climax": "climax",
    "aftermath": "aftermath",
    "revealCallback": "reveal_callback",
    "discovery": "discovery",
    "interrupt": "interrupt",
    "playerIntent": "player_intent",
    "turningPoint": "turning_point",
    "confrontationOpen": "confrontation_open",
    "allEvil": "all_evil",
    "lastFarmAction": "last_farm_action",
    "graduation": "graduation",
}

STAGE_CHOICES = {
    ("q01", "eruption"): ["fieldFirst", "reedFirst", "inspectFirst"],
    ("q02", "eruption"): ["harvest", "sandbag", "patrol", "livestock"],
    ("q03", "eruption"): ["cutTest", "traceRumor", "protectInventory"],
    ("q04", "eruption"): ["regroup", "parallelCrop", "publishMissingPage"],
    ("q05", "eruption"): ["publicOrder", "coop", "delay"],
    ("q06", "eruption"): ["talk", "noSide", "pause"],
    ("q06", "aftermath"): ["love", "tender", "friend"],
    ("q07", "eruption"): ["menu", "inventory", "harvest", "livestock"],
    ("q08", "climax"): ["evidence", "tradeUnion", "oldWaterway"],
    ("q09", "playerIntent"): [
        "takeLedger",
        "keepReading",
        "closeLedger",
        "returnTitles",
    ],
    ("q10", "playerIntent"): ["whyMe", "anyTruth", "silence", "breakTitles"],
    ("q10", "lastFarmAction"): ["water", "leave"],
}


@dataclass(frozen=True)
class ParsedSpeaker:
    actor: str
    attributed_actor: str | None
    annotation: str | None


@dataclass(frozen=True)
class ParsedLine:
    arc: str
    stage: str
    source_id: str | None
    runtime_id: str
    origin: str
    speaker: ParsedSpeaker
    text: str
    condition: str
    cue_id: str


def fail(message: str) -> "None":
    raise ValueError(message)


def swift_string(value: str) -> str:
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
    )
    return f'"{escaped}"'


def normalize_stage(arc: str, heading: str) -> str | None:
    heading = heading.strip()
    if "`benefit`" in heading:
        return "benefit"
    if "`warning_1`" in heading:
        return "warningOne"
    if "`warning_2`" in heading:
        return "warningTwo"
    if "`departure_confirmation`" in heading:
        return "departureConfirmation"
    if "`aftermath`" in heading:
        return "aftermath"
    if "`reveal_callback`" in heading:
        return "revealCallback"
    if "`discovery`" in heading:
        return "discovery"
    if "`interrupt`" in heading:
        return "interrupt"
    if "`turning_point`" in heading:
        return "turningPoint"
    if "`confrontation_open`" in heading:
        return "confrontationOpen"
    if "`all_evil`" in heading:
        return "allEvil"
    if "`last_farm_action`" in heading:
        return "lastFarmAction"
    if "`graduation`" in heading:
        return "graduation"
    if "灰栅对峙" in heading:
        return "climax"
    if "`eruption`" in heading:
        return "eruption"
    if heading.startswith("玩家意图"):
        return "playerIntent"
    return None


def parse_speaker(raw: str) -> ParsedSpeaker:
    annotation = None
    attributed = None
    speaker_name = raw

    ledger_match = re.fullmatch(r"账簿批注（(.+)字迹）", raw)
    if ledger_match:
        author = ledger_match.group(1)
        if author not in ATTRIBUTED_LEDGER:
            fail(f"unknown attributed ledger author: {author}")
        speaker_name = "账簿"
        attributed = ATTRIBUTED_LEDGER[author]
        annotation = f"{author}字迹"
    else:
        annotation_match = re.fullmatch(r"(.+)（(.+)）", raw)
        if annotation_match:
            speaker_name = annotation_match.group(1)
            annotation = annotation_match.group(2)

    if speaker_name not in ACTOR_IDS:
        fail(f"unknown speaker: {raw}")
    return ParsedSpeaker(ACTOR_IDS[speaker_name], attributed, annotation)


def condition_for(
    arc: str,
    source_id: str | None,
    choice_label: str | None,
) -> str:
    if choice_label in ACTION_IDS:
        return f".selectedAction({swift_string(ACTION_IDS[choice_label])})"
    if choice_label in CHOICE_CASES:
        choice = CHOICE_CASES[choice_label]
        return f".selectedChoice(.{choice}, arcID: .{arc})"

    if not source_id:
        return ".always"
    if source_id.startswith("Q05_AFT_PUBLIC") or source_id.startswith("Q05_REV_PUBLIC"):
        return ".q05Resolution(.publicOrder)"
    if source_id.startswith("Q05_AFT_COOP") or source_id.startswith("Q05_REV_COOP"):
        return ".q05Resolution(.coop)"
    if source_id.startswith("Q05_AFT_DELAY") or source_id.startswith("Q05_REV_DELAY"):
        return ".q05Resolution(.delay)"
    if source_id in {"Q06_EXP_001", "Q06_EXP_002"}:
        return ".romanceTender(true)"
    if source_id.startswith("Q06_EXP_FRIEND"):
        return ".romanceTender(false)"
    if source_id.startswith("Q06_AFT_LOVE"):
        return ".selectedChoice(.love, arcID: .q06)"
    if source_id.startswith("Q06_AFT_TENDER"):
        return ".selectedChoice(.tender, arcID: .q06)"
    if source_id.startswith("Q06_AFT_FRIEND"):
        return ".selectedChoice(.friend, arcID: .q06)"
    return ".always"


def cue_number(arc: str, stage: str) -> int:
    if arc == "q08":
        return {
            "benefit": 1,
            "warningOne": 1,
            "warningTwo": 1,
            "eruption": 2,
            "departureConfirmation": 2,
            "climax": 4,
            "aftermath": 4,
            "revealCallback": 5,
        }[stage]
    if arc == "q09":
        return {"discovery": 1, "interrupt": 2, "playerIntent": 3, "turningPoint": 4}[stage]
    if arc == "q10":
        return {
            "confrontationOpen": 1,
            "playerIntent": 2,
            "allEvil": 3,
            "lastFarmAction": 5,
            "graduation": 5,
        }[stage]
    return {
        "benefit": 1,
        "warningOne": 2,
        "warningTwo": 2,
        "eruption": 3,
        "aftermath": 4,
        "revealCallback": 5,
    }[stage]


def runtime_line_id(source_id: str) -> str:
    arc = source_id[:3].lower()
    suffix = source_id[4:].lower()
    return f"brookseed.story.{arc}.line.{suffix}"


def parse(source: Path) -> tuple[dict[str, str], list[ParsedLine]]:
    data = source.read_bytes()
    actual_hash = hashlib.sha256(data).hexdigest()
    if actual_hash != FROZEN_SHA256:
        fail(
            "frozen manuscript hash mismatch: "
            f"expected {FROZEN_SHA256}, got {actual_hash}"
        )

    titles: dict[str, str] = {}
    parsed: list[ParsedLine] = []
    current_arc: str | None = None
    current_stage: str | None = None
    active_choice: tuple[str, int] | None = None
    inline_counts: dict[tuple[str, str], int] = {}

    for line_number, raw_line in enumerate(data.decode("utf-8").splitlines(), 1):
        arc_match = ARC_HEADER.match(raw_line)
        if arc_match:
            current_arc = f"q{arc_match.group('number')}"
            titles[current_arc] = arc_match.group("title")
            current_stage = None
            active_choice = None
            continue

        stage_match = STAGE_HEADER.match(raw_line)
        if stage_match and current_arc:
            normalized = normalize_stage(current_arc, stage_match.group("title"))
            if normalized:
                current_stage = normalized
                active_choice = None
            continue

        label_match = CHOICE_LABEL.match(raw_line)
        if label_match and current_arc:
            active_choice = (label_match.group("label"), len(label_match.group("indent")))
            continue

        source_match = SOURCE_LINE.match(raw_line)
        if source_match:
            if not current_arc or not current_stage:
                fail(f"line {line_number}: dialogue outside an arc/stage")
            source_id = source_match.group("source")
            if source_id[:3].lower() != current_arc:
                fail(f"line {line_number}: source ID disagrees with arc: {source_id}")
            indent = len(source_match.group("indent"))
            choice_label = None
            if active_choice and indent > active_choice[1]:
                choice_label = active_choice[0]
            elif active_choice and indent <= active_choice[1]:
                active_choice = None

            parsed.append(
                ParsedLine(
                    arc=current_arc,
                    stage=current_stage,
                    source_id=source_id,
                    runtime_id=runtime_line_id(source_id),
                    origin="manuscript",
                    speaker=parse_speaker(source_match.group("speaker")),
                    text=source_match.group("text"),
                    condition=condition_for(current_arc, source_id, choice_label),
                    cue_id=(
                        f"brookseed.story.{current_arc}.cue."
                        f"blk_{cue_number(current_arc, current_stage):02d}"
                    ),
                )
            )
            continue

        inline_match = INLINE_RESPONSE.match(raw_line)
        if inline_match:
            if not current_arc or not current_stage:
                fail(f"line {line_number}: inline response outside an arc/stage")
            label = inline_match.group("label")
            if label not in CHOICE_CASES:
                # Q08 depart/wait are followed by source-ID lines and are not
                # among the 20 source-free manuscript responses.
                continue
            choice = CHOICE_CASES[label]
            key = (current_arc, choice)
            inline_counts[key] = inline_counts.get(key, 0) + 1
            ordinal = inline_counts[key]
            parsed.append(
                ParsedLine(
                    arc=current_arc,
                    stage=current_stage,
                    source_id=None,
                    runtime_id=(
                        f"brookseed.story.{current_arc}.choice_response."
                        f"{choice_to_raw(choice)}.response_{ordinal:02d}"
                    ),
                    origin="inlineChoiceResponse",
                    speaker=parse_speaker(inline_match.group("speaker")),
                    text=inline_match.group("text"),
                    condition=condition_for(current_arc, None, label),
                    cue_id=(
                        f"brookseed.story.{current_arc}.cue."
                        f"blk_{cue_number(current_arc, current_stage):02d}"
                    ),
                )
            )

    manuscript = [line for line in parsed if line.origin == "manuscript"]
    inline = [line for line in parsed if line.origin == "inlineChoiceResponse"]
    if len(titles) != 10:
        fail(f"expected 10 stories, got {len(titles)}")
    if len(manuscript) != EXPECTED_MANUSCRIPT_LINES:
        fail(
            f"expected {EXPECTED_MANUSCRIPT_LINES} manuscript lines, "
            f"got {len(manuscript)}"
        )
    if len(inline) != EXPECTED_INLINE_RESPONSES:
        fail(
            f"expected {EXPECTED_INLINE_RESPONSES} inline responses, "
            f"got {len(inline)}"
        )
    source_ids = [line.source_id for line in manuscript]
    runtime_ids = [line.runtime_id for line in parsed]
    if len(source_ids) != len(set(source_ids)):
        fail("duplicate source dialogue ID")
    if len(runtime_ids) != len(set(runtime_ids)):
        fail("duplicate generated runtime line ID")
    return titles, parsed


def choice_to_raw(swift_case: str) -> str:
    for label, candidate in CHOICE_CASES.items():
        if candidate == swift_case:
            # Canonical spellings are frozen in StoryChoiceID.
            break
    special = {
        "fieldFirst": "field_first",
        "reedFirst": "reed_first",
        "inspectFirst": "inspect_first",
        "cutTest": "cut_test",
        "traceRumor": "trace_rumor",
        "protectInventory": "protect_inventory",
        "parallelCrop": "parallel_crop",
        "publishMissingPage": "publish_missing_page",
        "publicOrder": "public",
        "noSide": "no_side",
        "tradeUnion": "trade_union",
        "oldWaterway": "old_waterway",
        "takeLedger": "take_ledger",
        "keepReading": "keep_reading",
        "closeLedger": "close_ledger",
        "returnTitles": "return_titles",
        "whyMe": "why_me",
        "anyTruth": "any_truth",
        "breakTitles": "break_titles",
    }
    return special.get(swift_case, swift_case)


def render_optional_string(value: str | None) -> str:
    return "nil" if value is None else swift_string(value)


def render_optional_symbol(value: str | None) -> str:
    return "nil" if value is None else value


def render_line(line: ParsedLine) -> list[str]:
    visibility = ".finaleOnly" if line.stage == "revealCallback" else ".ordinary"
    source = render_optional_string(line.source_id)
    portrait = (
        "nil"
        if line.speaker.actor in {"StoryActorID.system", "StoryActorID.ledger"}
        else line.speaker.actor
    )
    return [
        "StoryDialogueLineDefinition(",
        f"    id: {swift_string(line.runtime_id)},",
        f"    sourceID: {source},",
        f"    origin: .{line.origin},",
        f"    speakerID: {line.speaker.actor},",
        f"    attributedActorID: {render_optional_symbol(line.speaker.attributed_actor)},",
        f"    speakerAnnotation: {render_optional_string(line.speaker.annotation)},",
        f"    text: {swift_string(line.text)},",
        f"    portraitID: {portrait},",
        f"    condition: {line.condition},",
        f"    blockingCueID: {swift_string(line.cue_id)},",
        f"    visibility: {visibility}",
        ")",
    ]


def graph_next(arc: str, stage: str) -> list[str]:
    stages = ORDERED_STAGES[arc]
    if stage == "revealCallback":
        return []
    index = stages.index(stage)
    if index + 1 >= len(stages):
        return []
    next_stage = stages[index + 1]
    if next_stage == "revealCallback":
        return []
    return [f"brookseed.story.{arc}.stage.{STAGE_RAW[next_stage]}"]


def render(titles: dict[str, str], lines: list[ParsedLine]) -> str:
    grouped: dict[tuple[str, str], list[ParsedLine]] = {}
    for line in lines:
        grouped.setdefault((line.arc, line.stage), []).append(line)

    output = [
        "// Generated by scripts/generate-n027-story-content.py.",
        f"// Frozen manuscript SHA-256: {FROZEN_SHA256}",
        "// Do not hand-edit; the app consumes this Swift and never parses Markdown.",
        "",
        "enum StoryGeneratedContent {",
        "    static let frozenManuscriptSHA256 = " + swift_string(FROZEN_SHA256),
        "",
        "    static let storyDefinitions: [StoryDefinition] = [",
    ]

    for arc_number in range(1, 11):
        arc = f"q{arc_number:02d}"
        output.extend(
            [
                "        StoryDefinition(",
                f"            id: .{arc},",
                f"            title: {swift_string(titles[arc])},",
                "            stages: [",
            ]
        )
        for stage in ORDERED_STAGES[arc]:
            stage_lines = grouped.get((arc, stage), [])
            visibility = ".finaleOnly" if stage == "revealCallback" else ".ordinary"
            choices = STAGE_CHOICES.get((arc, stage), [])
            next_ids = graph_next(arc, stage)
            output.extend(
                [
                    "                StoryStageDefinition(",
                    (
                        "                    id: "
                        + swift_string(
                            f"brookseed.story.{arc}.stage.{STAGE_RAW[stage]}"
                        )
                        + ","
                    ),
                    f"                    kind: .{stage},",
                    f"                    visibility: {visibility},",
                    "                    lines: [",
                ]
            )
            for line in stage_lines:
                rendered = render_line(line)
                output.append("                        " + rendered[0])
                output.extend("                        " + part for part in rendered[1:-1])
                output.append("                        " + rendered[-1] + ",")
            output.extend(
                [
                    "                    ],",
                    (
                        "                    choices: ["
                        + ", ".join(f".{choice}" for choice in choices)
                        + "],"
                    ),
                    (
                        "                    nextStageIDs: ["
                        + ", ".join(swift_string(value) for value in next_ids)
                        + "]"
                    ),
                    "                ),",
                ]
            )
        output.extend(
            [
                "            ],",
                f"            branchChoices: StoryChoiceID.choices(for: .{arc})",
                "        ),",
            ]
        )

    output.extend(["    ]", "}", ""])
    return "\n".join(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify that the checked-in generated file is current",
    )
    args = parser.parse_args()

    try:
        titles, lines = parse(args.source)
        generated = render(titles, lines)
    except (OSError, UnicodeError, ValueError) as error:
        print(f"N-027 story generation failed: {error}", file=sys.stderr)
        return 1

    if args.check:
        try:
            existing = args.output.read_text(encoding="utf-8")
        except OSError as error:
            print(f"N-027 generated catalog missing: {error}", file=sys.stderr)
            return 1
        if existing != generated:
            print("N-027 generated catalog is stale", file=sys.stderr)
            return 1
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(generated, encoding="utf-8")

    manuscript_count = sum(line.origin == "manuscript" for line in lines)
    inline_count = sum(line.origin == "inlineChoiceResponse" for line in lines)
    print(
        "N-027 story catalog OK: "
        f"10 stories, {manuscript_count} manuscript lines, "
        f"{inline_count} inline choice responses, SHA-256 {FROZEN_SHA256}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
