class_name TestSaveCodec
extends RefCounted

const GameSession = preload("res://src/core/game_session.gd")
const SaveGameDto = preload("res://src/core/save_game_dto.gd")
const SaveCodec = preload("res://src/core/save_codec.gd")
const DeterministicRandomStreams = preload("res://src/core/deterministic_random_streams.gd")


func run() -> Array[Dictionary]:
	return [_round_trip(), _typed_round_trip(), _invalid_save_rejected(), _invalid_values_rejected(), _snapshot_is_immutable(), _random_streams_are_independent()]


func _round_trip() -> Dictionary:
	var codec := SaveCodec.new()
	var session := GameSession.create_empty()
	session.inventory = [{"item_id": "brookseed.item.seed", "quantity": 2, "quality": "silver"}]
	session.farm_cells[Vector2i(12, 8)] = {"prepared": true, "watered_today": false, "crop_id": "brookseed.crop.mist_radish", "crop_stage": 2, "stage_progress_days": 1}
	var decoded := codec.decode_json(codec.encode_json(session.create_snapshot()).value)
	return _assert(decoded.ok and _canonical(codec, session) == _canonical(codec, decoded.value), "empty_session_save_load_deep_equality", "decoded session differs from original")


func _typed_round_trip() -> Dictionary:
	var codec := SaveCodec.new()
	var session := GameSession.create_empty()
	session.farm_cells[Vector2i(3, -2)] = {"prepared": true, "watered_today": true, "crop_id": "brookseed.crop.mist_radish", "crop_stage": 1, "stage_progress_days": 0}
	session.farm_cells[Vector2i(-1, -2)] = {"prepared": true, "watered_today": false, "crop_id": "", "crop_stage": 0, "stage_progress_days": 0}
	session.relationships.trust_subpoints[StringName("brookseed.npc.rin")] = 300
	var encoded: Dictionary = codec.encode_snapshot(session.create_snapshot()).value.to_dictionary()
	var cell: Dictionary = encoded.farm.farm_cells[0]
	var decoded := codec.decode_dto(SaveGameDto.new(encoded))
	var passed: bool = cell.x == -1 and cell.y == -2 and cell.crop_id is String and encoded.farm.farm_cells[1].x == 3 and decoded.ok and decoded.value.farm_cells.has(Vector2i(3, -2)) and decoded.value.relationships.trust_subpoints.has(StringName("brookseed.npc.rin"))
	return _assert(passed, "vector_stringname_enum_dictionary_round_trip", "explicit DTO type mapping failed")


func _invalid_save_rejected() -> Dictionary:
	var codec := SaveCodec.new()
	var session := GameSession.create_empty()
	var root: Dictionary = codec.encode_snapshot(session.create_snapshot()).value.to_dictionary()
	root.farm.farm_cells = [{"x": 1, "y": 1, "prepared": true, "watered_today": false, "crop_id": "brookseed.crop.mist_radish", "crop_stage": 0, "stage_progress_days": 0}, {"x": 1, "y": 1, "prepared": true, "watered_today": false, "crop_id": "brookseed.crop.mist_radish", "crop_stage": 0, "stage_progress_days": 0}]
	var rejected := codec.decode_dto(SaveGameDto.new(root))
	return _assert(not rejected.ok and not rejected.has("value"), "invalid_save_rejects_whole_generation", "invalid save was partially loaded")


func _snapshot_is_immutable() -> Dictionary:
	var codec := SaveCodec.new()
	var session := GameSession.create_empty()
	session.economy.balance = 3
	var snapshot := session.create_snapshot()
	session.economy.balance = 99
	var encoded := codec.encode_snapshot(snapshot)
	return _assert(encoded.ok and encoded.value.to_dictionary().economy.balance == 3, "snapshot_ignores_later_live_mutation", "snapshot read active session state")


func _invalid_values_rejected() -> Dictionary:
	var codec := SaveCodec.new()
	var session := GameSession.create_empty()
	var quantity_root: Dictionary = codec.encode_snapshot(session.create_snapshot()).value.to_dictionary()
	quantity_root.inventory = [{"item_id": "brookseed.item.seed", "quantity": 0, "quality": "normal"}]
	var bad_quantity := codec.decode_dto(SaveGameDto.new(quantity_root))
	var random_root: Dictionary = codec.encode_snapshot(session.create_snapshot()).value.to_dictionary()
	random_root.random.streams[0].consumption_count = -1
	var bad_random := codec.decode_dto(SaveGameDto.new(random_root))
	return _assert(not bad_quantity.ok and not bad_random.ok, "invalid_quantity_and_random_state_rejected", "invalid enum-like value or random state was accepted")


func _random_streams_are_independent() -> Dictionary:
	var streams := DeterministicRandomStreams.create_default(1234)
	var expected_quality: int = DeterministicRandomStreams.create_default(1234).next_int(&"quality")
	streams.next_int(&"weather")
	streams.next_int(&"weather")
	var quality_after_weather: int = streams.next_int(&"quality")
	var restored := DeterministicRandomStreams.from_state_records(streams.to_state_records())
	var next_live: int = streams.next_int(&"gossip")
	var next_restored := (restored.value as DeterministicRandomStreams).next_int(&"gossip")
	return _assert(quality_after_weather == expected_quality and restored.ok and next_live == next_restored, "random_streams_independent_and_continuable", "stream consumption affected another stream or reload")


func _canonical(codec: Variant, session: Variant) -> String:
	var root: Dictionary = codec.encode_snapshot(session.create_snapshot()).value.to_dictionary()
	root.erase("saved_at_utc")
	return JSON.stringify(root)


func _assert(condition: bool, name: String, message: String) -> Dictionary:
	return {"name": name, "ok": condition, "message": message}
