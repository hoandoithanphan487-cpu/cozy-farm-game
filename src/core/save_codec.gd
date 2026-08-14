## Explicit schema-v1 mapping. Validation errors invalidate the entire generation.
class_name SaveCodec
extends RefCounted

const DeterministicRandomStreamsScript = preload("res://src/core/deterministic_random_streams.gd")
const GameLogScript = preload("res://src/core/game_log.gd")
const GameSessionScript = preload("res://src/core/game_session.gd")
const SaveGameDtoScript = preload("res://src/core/save_game_dto.gd")

const BUILD_VERSION: String = "0.1.0-dev"
const SCHEMA_VERSION: int = 1
const MAX_ABS_COORDINATE: int = 10000
const MAX_QUANTITY: int = 999999
const VALID_SEASONS: PackedStringArray = ["spring", "summer", "autumn", "winter"]
const VALID_WEATHER: PackedStringArray = ["clear", "rain"]
const VALID_QUALITIES: PackedStringArray = ["normal", "silver", "gold", "iridium"]


func encode_snapshot(snapshot: Variant) -> Dictionary:
	var validation := _validate_session(snapshot)
	if not validation.ok:
		return validation
	var dto := SaveGameDtoScript.new({
		"schema_version": SCHEMA_VERSION,
		"build_version": BUILD_VERSION,
		"saved_at_utc": Time.get_datetime_string_from_system(true, true),
		"scenario_id": str(snapshot.scenario_id),
		"calendar": _encode_calendar(snapshot.calendar),
		"player": _encode_player(snapshot.player),
		"inventory": _encode_inventory(snapshot.inventory),
		"farm": {"farm_cells": _encode_farm_cells(snapshot.farm_cells)},
		"economy": _encode_economy(snapshot.economy),
		"quests": _encode_stable_records(snapshot.quests, "quest_id"),
		"relationships": _encode_relationships(snapshot.relationships),
		"community": _encode_community(snapshot.community),
		"random": {"streams": _encode_random_streams(snapshot.random_streams)},
		"watershed": _encode_watershed(snapshot.watershed),
		"world": _encode_world(snapshot.world),
		"settings": _copy_json_value(snapshot.settings_snapshot),
	})
	return {"ok": true, "value": dto}


func encode_json(snapshot: Variant) -> Dictionary:
	var encoded := encode_snapshot(snapshot)
	if not encoded.ok:
		return encoded
	return {"ok": true, "value": JSON.stringify(encoded.value.to_dictionary(), "\t", false)}


func decode_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return _invalid("invalid JSON document")
	return decode_dto(SaveGameDtoScript.new(json.data))


func decode_dto(dto: Variant) -> Dictionary:
	var root: Dictionary = dto.to_dictionary()
	for key: String in ["schema_version", "build_version", "saved_at_utc", "scenario_id", "calendar", "player", "inventory", "farm", "economy", "quests", "relationships", "community", "random", "watershed", "world", "settings"]:
		if not root.has(key):
			return _invalid("missing required field: %s" % key)
	if not _is_integer(root.schema_version) or int(root.schema_version) != SCHEMA_VERSION:
		return _invalid("unsupported schema")
	if not root.build_version is String or not root.saved_at_utc is String or not _is_valid_id(root.scenario_id):
		return _invalid("invalid save identity")
	var session := GameSessionScript.create_empty(StringName(root.scenario_id))
	var calendar := _decode_calendar(root.calendar)
	var player := _decode_player(root.player)
	var inventory := _decode_inventory(root.inventory)
	var farm := _decode_farm(root.farm)
	var economy := _decode_economy(root.economy)
	var quests := _decode_stable_records(root.quests, "quest_id")
	var relationships := _decode_relationships(root.relationships)
	var community := _decode_community(root.community)
	var random_streams := _decode_random(root.random)
	var watershed := _decode_watershed(root.watershed)
	var world := _decode_world(root.world)
	var settings := _decode_json_object(root.settings, "settings")
	for result: Dictionary in [calendar, player, inventory, farm, economy, quests, relationships, community, random_streams, watershed, world, settings]:
		if not result.ok:
			return _invalid(String(result.error))
	session.calendar = calendar.value
	session.player = player.value
	session.inventory = inventory.value
	session.farm_cells = farm.value
	session.economy = economy.value
	session.quests = quests.value
	session.relationships = relationships.value
	session.community = community.value
	session.random_streams = random_streams.value
	session.watershed = watershed.value
	session.world = world.value
	session.settings_snapshot = settings.value
	return {"ok": true, "value": session}


func _validate_session(snapshot: Variant) -> Dictionary:
	if not _is_valid_id(str(snapshot.scenario_id)):
		return _invalid("invalid scenario id")
	if not snapshot.calendar is Dictionary or not snapshot.player is Dictionary:
		return _invalid("missing session structures")
	var random_check := _decode_random({"streams": _encode_random_streams(snapshot.random_streams)})
	if not random_check.ok:
		return random_check
	return {"ok": true}


func _encode_calendar(value: Dictionary) -> Dictionary:
	return {"day": value.get("day", 1), "minute": value.get("minute", 480), "season": str(value.get("season", "spring")), "weather": str(value.get("weather", "clear"))}


func _decode_calendar(value: Variant) -> Dictionary:
	if not value is Dictionary or not _is_integer(value.get("day", null)) or not _is_integer(value.get("minute", null)) or not value.get("season", null) is String:
		return _invalid("invalid calendar")
	var weather := String(value.get("weather", "clear"))
	if int(value.day) < 1 or int(value.minute) < 0 or int(value.minute) > 1439 or not VALID_SEASONS.has(value.season) or not VALID_WEATHER.has(weather):
		return _invalid("calendar values out of range")
	return {"ok": true, "value": {"day": int(value.day), "minute": int(value.minute), "season": value.season, "weather": weather}}


func _encode_player(value: Dictionary) -> Dictionary:
	var position: Vector2i = value.get("position", Vector2i.ZERO)
	return {"spawn_id": str(value.get("spawn_id", "")), "position": _encode_vector2i(position), "stamina": value.get("stamina", 100), "inventory_capacity": value.get("inventory_capacity", 16)}


func _decode_player(value: Variant) -> Dictionary:
	if not value is Dictionary or not _is_valid_id(value.get("spawn_id", "")) or not _is_integer(value.get("stamina", null)):
		return _invalid("invalid player")
	var position := _decode_vector2i(value.get("position", null))
	var inventory_capacity := value.get("inventory_capacity", 16)
	if not position.ok or int(value.stamina) < 0 or int(value.stamina) > 100 or not _is_integer(inventory_capacity) or int(inventory_capacity) < 1 or int(inventory_capacity) > 999:
		return _invalid("invalid player position or stamina")
	return {"ok": true, "value": {"spawn_id": value.spawn_id, "position": position.value, "stamina": int(value.stamina), "inventory_capacity": int(inventory_capacity)}}


func _encode_inventory(value: Array) -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry: Dictionary in value:
		copy.append({"item_id": str(entry.get("item_id", "")), "quantity": entry.get("quantity", 0), "quality": str(entry.get("quality", "normal"))})
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.item_id < b.item_id)
	return copy


func _decode_inventory(value: Variant) -> Dictionary:
	if not value is Array:
		return _invalid("invalid inventory")
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for entry: Variant in value:
		if not entry is Dictionary or not _is_valid_id(entry.get("item_id", "")) or not _is_integer(entry.get("quantity", null)) or not VALID_QUALITIES.has(entry.get("quality", "")):
			return _invalid("invalid inventory entry")
		if int(entry.quantity) < 1 or int(entry.quantity) > MAX_QUANTITY or seen.has(entry.item_id):
			return _invalid("inventory quantity or duplicate item")
		seen[entry.item_id] = true
		result.append({"item_id": entry.item_id, "quantity": int(entry.quantity), "quality": entry.quality})
	return {"ok": true, "value": result}


func _encode_farm_cells(cells: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for coordinate: Variant in cells:
		var cell: Dictionary = cells[coordinate]
		result.append({"x": coordinate.x, "y": coordinate.y, "prepared": cell.get("prepared", false), "watered_today": cell.get("watered_today", false), "fertility": cell.get("fertility", 0), "crop_id": str(cell.get("crop_id", "")), "crop_stage": cell.get("crop_stage", 0), "stage_progress_days": cell.get("stage_progress_days", 0), "planted_day": cell.get("planted_day", 0), "ready_to_harvest": cell.get("ready_to_harvest", false)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	return result


func _decode_farm(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("farm_cells", null) is Array:
		return _invalid("invalid farm")
	var result: Dictionary = {}
	for cell: Variant in value.farm_cells:
		if not cell is Dictionary or not _is_integer(cell.get("x", null)) or not _is_integer(cell.get("y", null)) or not cell.get("prepared", null) is bool or not cell.get("watered_today", null) is bool or not _is_integer(cell.get("crop_stage", null)) or not _is_integer(cell.get("stage_progress_days", null)):
			return _invalid("invalid farm cell")
		var coordinate := Vector2i(int(cell.x), int(cell.y))
		var fertility := cell.get("fertility", 0)
		var planted_day := cell.get("planted_day", 0)
		var ready_to_harvest := cell.get("ready_to_harvest", false)
		if abs(coordinate.x) > MAX_ABS_COORDINATE or abs(coordinate.y) > MAX_ABS_COORDINATE or result.has(coordinate) or int(cell.crop_stage) < 0 or int(cell.stage_progress_days) < 0 or not _is_integer(fertility) or not _is_integer(planted_day) or int(fertility) < 0 or not ready_to_harvest is bool:
			return _invalid("invalid or duplicate farm coordinate")
		if not String(cell.get("crop_id", "")).is_empty() and not _is_valid_id(cell.crop_id):
			return _invalid("invalid crop id")
		result[coordinate] = {"prepared": cell.prepared, "watered_today": cell.watered_today, "fertility": int(fertility), "crop_id": cell.crop_id, "crop_stage": int(cell.crop_stage), "stage_progress_days": int(cell.stage_progress_days), "planted_day": int(planted_day), "ready_to_harvest": ready_to_harvest}
	return {"ok": true, "value": result}


func _encode_economy(value: Dictionary) -> Dictionary:
	return {"balance": value.get("balance", 0), "shipping_entries": _encode_stable_records(value.get("shipping_entries", []), "entry_id"), "settlement_history": _encode_stable_records(value.get("settlement_history", []), "settlement_id")}


func _decode_economy(value: Variant) -> Dictionary:
	if not value is Dictionary or not _is_integer(value.get("balance", null)) or int(value.balance) < 0:
		return _invalid("invalid economy")
	var shipping := _decode_stable_records(value.get("shipping_entries", null), "entry_id")
	var settlements := _decode_stable_records(value.get("settlement_history", null), "settlement_id")
	if not shipping.ok or not settlements.ok:
		return _invalid("invalid economy records")
	for entry: Dictionary in shipping.value:
		if not _is_valid_id(entry.get("item_id", "")) or not _is_integer(entry.get("quantity", null)) or int(entry.quantity) < 1 or int(entry.quantity) > MAX_QUANTITY or not VALID_QUALITIES.has(entry.get("quality", "")) or not _is_integer(entry.get("deposited_day", null)) or int(entry.deposited_day) < 1 or not _is_integer(entry.get("unit_price_snapshot", null)) or int(entry.unit_price_snapshot) < 0:
			return _invalid("invalid shipping entry")
	return {"ok": true, "value": {"balance": int(value.balance), "shipping_entries": shipping.value, "settlement_history": settlements.value}}


func _encode_relationships(value: Dictionary) -> Dictionary:
	return {"trust_subpoints": _encode_id_int_records(value.get("trust_subpoints", {})), "multiplier_remainders": _encode_id_int_records(value.get("multiplier_remainders", {})), "active_effects": _encode_stable_records(value.get("active_effects", []), "effect_id")}


func _decode_relationships(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _invalid("invalid relationships")
	var trust := _decode_id_int_records(value.get("trust_subpoints", null), 0, 1000000)
	var remainders := _decode_id_int_records(value.get("multiplier_remainders", null), 0, 99)
	var effects := _decode_stable_records(value.get("active_effects", null), "effect_id")
	if not trust.ok or not remainders.ok or not effects.ok:
		return _invalid("invalid relationship records")
	return {"ok": true, "value": {"trust_subpoints": trust.value, "multiplier_remainders": remainders.value, "active_effects": effects.value}}


func _encode_community(value: Dictionary) -> Dictionary:
	return {"standing": value.get("standing", 50), "neighbors": _encode_id_dictionary_records(value.get("neighbors", {}), "neighbor_id"), "active_events": _encode_stable_records(value.get("active_events", []), "instance_id"), "event_history": _encode_stable_records(value.get("event_history", []), "instance_id")}


func _decode_community(value: Variant) -> Dictionary:
	if not value is Dictionary or not _is_integer(value.get("standing", null)) or int(value.standing) < 0 or int(value.standing) > 100:
		return _invalid("invalid community")
	var neighbors := _decode_id_dictionary_records(value.get("neighbors", null), "neighbor_id")
	var active := _decode_stable_records(value.get("active_events", null), "instance_id")
	var history := _decode_stable_records(value.get("event_history", null), "instance_id")
	if not neighbors.ok or not active.ok or not history.ok:
		return _invalid("invalid community records")
	return {"ok": true, "value": {"standing": int(value.standing), "neighbors": neighbors.value, "active_events": active.value, "event_history": history.value}}


func _encode_random_streams(value: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for id_text: String in DeterministicRandomStreamsScript.REQUIRED_STREAM_IDS:
		var record: Dictionary = value.get(id_text, {})
		records.append({"stream_id": id_text, "initial_seed": record.get("initial_seed", 0), "consumption_count": record.get("consumption_count", -1)})
	return records


func _decode_random(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("streams", null) is Array:
		return _invalid("invalid random state")
	var parsed := DeterministicRandomStreamsScript.from_state_records(value.streams)
	if not parsed.ok:
		return _invalid(String(parsed.error))
	var records: Dictionary = {}
	for record: Dictionary in value.streams:
		records[record["stream_id"]] = {"initial_seed": int(record["initial_seed"]), "consumption_count": int(record["consumption_count"])}
	return {"ok": true, "value": records}


func _encode_world(value: Dictionary) -> Dictionary:
	return {"flags": _encode_id_int_records(value.get("flags", {}))}


func _decode_world(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _invalid("invalid world")
	var flags := _decode_id_int_records(value.get("flags", null), 0, 1)
	if not flags.ok:
		return _invalid("invalid world flags")
	return {"ok": true, "value": {"flags": flags.value}}


func _encode_watershed(value: Dictionary) -> Dictionary:
	return {
		"restoration_points": value.get("restoration_points", 0),
		"contribution_ids": _encode_string_id_list(value.get("contribution_ids", [])),
	}


func _decode_watershed(value: Variant) -> Dictionary:
	if not value is Dictionary or not _is_integer(value.get("restoration_points", null)) or int(value.restoration_points) < 0:
		return _invalid("invalid watershed")
	var contribution_ids := _decode_string_id_list(value.get("contribution_ids", null))
	if not contribution_ids.ok:
		return _invalid("invalid watershed contribution IDs")
	return {"ok": true, "value": {"restoration_points": int(value.restoration_points), "contribution_ids": contribution_ids.value}}


func _encode_string_id_list(value: Array) -> Array[String]:
	var result: Array[String] = []
	for id: Variant in value:
		result.append(str(id))
	result.sort()
	return result


func _decode_string_id_list(value: Variant) -> Dictionary:
	if not value is Array:
		return _invalid("invalid stable ID list")
	var result: Array[StringName] = []
	var seen: Dictionary = {}
	for id: Variant in value:
		if not _is_valid_id(id) or seen.has(StringName(id)):
			return _invalid("invalid or duplicate stable ID list entry")
		seen[StringName(id)] = true
		result.append(StringName(id))
	return {"ok": true, "value": result}


func _encode_stable_records(value: Array, id_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in value:
		result.append(_copy_json_value(entry))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get(id_key, "")) < str(b.get(id_key, "")))
	return result


func _decode_stable_records(value: Variant, id_key: String) -> Dictionary:
	if not value is Array:
		return _invalid("invalid record list")
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for entry: Variant in value:
		if not entry is Dictionary or not _is_valid_id(entry.get(id_key, "")) or seen.has(entry[id_key]):
			return _invalid("invalid or duplicate record id")
		seen[entry[id_key]] = true
		result.append(_copy_json_value(entry))
	return {"ok": true, "value": result}


func _encode_id_int_records(value: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: Variant in value:
		result.append({"id": str(id), "value": value[id]})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return result


func _decode_id_int_records(value: Variant, minimum: int, maximum: int) -> Dictionary:
	if not value is Array:
		return _invalid("invalid id/int records")
	var result: Dictionary = {}
	for entry: Variant in value:
		if not entry is Dictionary or not _is_valid_id(entry.get("id", "")) or not _is_integer(entry.get("value", null)) or int(entry.value) < minimum or int(entry.value) > maximum or result.has(StringName(entry.id)):
			return _invalid("invalid id/int record")
		result[StringName(entry.id)] = int(entry.value)
	return {"ok": true, "value": result}


func _encode_id_dictionary_records(value: Dictionary, id_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: Variant in value:
		var record: Dictionary = _copy_json_value(value[id])
		record[id_key] = str(id)
		result.append(record)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a[id_key]) < str(b[id_key]))
	return result


func _decode_id_dictionary_records(value: Variant, id_key: String) -> Dictionary:
	var records := _decode_stable_records(value, id_key)
	if not records.ok:
		return records
	var result: Dictionary = {}
	for record: Dictionary in records.value:
		var copy: Dictionary = _copy_json_value(record)
		copy.erase(id_key)
		result[StringName(record[id_key])] = copy
	return {"ok": true, "value": result}


func _encode_vector2i(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _decode_vector2i(value: Variant) -> Dictionary:
	if not value is Dictionary or not _is_integer(value.get("x", null)) or not _is_integer(value.get("y", null)):
		return _invalid("invalid Vector2i")
	var vector := Vector2i(int(value.x), int(value.y))
	if abs(vector.x) > MAX_ABS_COORDINATE or abs(vector.y) > MAX_ABS_COORDINATE:
		return _invalid("Vector2i out of range")
	return {"ok": true, "value": vector}


func _decode_json_object(value: Variant, label: String) -> Dictionary:
	if not value is Dictionary:
		return _invalid("invalid %s" % label)
	return {"ok": true, "value": _copy_json_value(value)}


func _copy_json_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[str(key)] = _copy_json_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_copy_json_value(entry))
		return result
	if value is StringName:
		return str(value)
	return value


func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, floor(value)))


func _is_valid_id(value: Variant) -> bool:
	if not value is String or String(value).is_empty() or String(value).length() > 120:
		return false
	var segments := String(value).split(".")
	if segments.size() < 2:
		return false
	for segment: String in segments:
		if not segment.is_valid_identifier():
			return false
	return true


func _invalid(reason: String) -> Dictionary:
	GameLogScript.warning(GameLogScript.Category.SAVE, "Save validation rejected a generation.", {"reason": reason})
	return {"ok": false, "error": reason}
