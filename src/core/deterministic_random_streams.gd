class_name DeterministicRandomStreams
extends RefCounted

const DeterministicRandomStreamScript = preload("res://src/core/deterministic_random_stream.gd")

const REQUIRED_STREAM_IDS: PackedStringArray = ["weather", "quality", "gossip"]

var streams: Dictionary = {}


static func create_default(seed: int) -> RefCounted:
	var result: Variant = load("res://src/core/deterministic_random_streams.gd").new()
	result.streams[&"weather"] = DeterministicRandomStreamScript.new(&"weather", seed + 11)
	result.streams[&"quality"] = DeterministicRandomStreamScript.new(&"quality", seed + 23)
	result.streams[&"gossip"] = DeterministicRandomStreamScript.new(&"gossip", seed + 37)
	return result


static func from_state_records(records: Array) -> Dictionary:
	var result: Variant = load("res://src/core/deterministic_random_streams.gd").new()
	var seen: Dictionary = {}
	for record: Variant in records:
		if not record is Dictionary or not DeterministicRandomStreamScript.is_valid_state(record):
			return {"ok": false, "error": "invalid random stream state"}
		var id := StringName(String(record["stream_id"]))
		if seen.has(id) or not REQUIRED_STREAM_IDS.has(str(id)):
			return {"ok": false, "error": "duplicate or unknown random stream"}
		seen[id] = true
		result.streams[id] = DeterministicRandomStreamScript.new(id, record["initial_seed"], record["consumption_count"])
	for id_text: String in REQUIRED_STREAM_IDS:
		if not seen.has(StringName(id_text)):
			return {"ok": false, "error": "missing required random stream"}
	return {"ok": true, "value": result}


func next_int(id: StringName) -> int:
	return streams[id].next_int()


func to_state_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id_text: String in REQUIRED_STREAM_IDS:
		var id := StringName(id_text)
		result.append(streams[id].to_state_record())
	return result
