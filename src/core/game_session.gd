## Authoritative M0 session state. Gameplay systems may extend the contained records
## only through versioned SaveCodec mappings.
class_name GameSession
extends RefCounted

const GameSessionSnapshotScript = preload("res://src/core/game_session_snapshot.gd")
const DeterministicRandomStreamsScript = preload("res://src/core/deterministic_random_streams.gd")

const SCHEMA_VERSION: int = 1
const DEFAULT_SCENARIO_ID: StringName = &"brookseed.scenario.empty"

var scenario_id: StringName
var calendar: Dictionary
var player: Dictionary
var inventory: Array
var farm_cells: Dictionary
var economy: Dictionary
var quests: Array
var relationships: Dictionary
var community: Dictionary
var random_streams: Dictionary
var watershed: Dictionary
var world: Dictionary
var settings_snapshot: Dictionary


static func create_empty(scenario: StringName = DEFAULT_SCENARIO_ID) -> GameSession:
	var session: Variant = load("res://src/core/game_session.gd").new()
	session.scenario_id = scenario
	session.calendar = {"day": 1, "minute": 480, "season": "spring", "weather": "clear"}
	session.player = {"spawn_id": "brookseed.spawn.farmhouse", "position": Vector2i.ZERO, "stamina": 100, "inventory_capacity": 16}
	session.inventory = []
	session.farm_cells = {}
	session.economy = {"balance": 0, "shipping_entries": [], "settlement_history": []}
	session.quests = []
	session.relationships = {"trust_subpoints": {}, "multiplier_remainders": {}, "active_effects": []}
	session.community = {"standing": 50, "neighbors": {}, "active_events": [], "event_history": []}
	session.random_streams = {}
	for record: Dictionary in DeterministicRandomStreamsScript.create_default(24681357).to_state_records():
		session.random_streams[record["stream_id"]] = {"initial_seed": record["initial_seed"], "consumption_count": record["consumption_count"]}
	session.watershed = {"restoration_points": 0, "contribution_ids": []}
	session.world = {"flags": {}}
	session.settings_snapshot = {}
	return session


func create_snapshot() -> RefCounted:
	return GameSessionSnapshotScript.new(self)
