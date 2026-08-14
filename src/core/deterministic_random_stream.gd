class_name DeterministicRandomStream
extends RefCounted

const MODULUS: int = 2147483647
const MULTIPLIER: int = 48271
const MAX_CONSUMPTION: int = 1000000

var stream_id: StringName
var initial_seed: int
var consumption_count: int
var _state: int


func _init(id: StringName, seed: int, consumed: int = 0) -> void:
	stream_id = id
	initial_seed = seed
	consumption_count = consumed
	_state = seed
	for _index: int in consumed:
		_state = (_state * MULTIPLIER) % MODULUS


func next_int() -> int:
	_state = (_state * MULTIPLIER) % MODULUS
	consumption_count += 1
	return _state


func to_state_record() -> Dictionary:
	return {"stream_id": str(stream_id), "initial_seed": initial_seed, "consumption_count": consumption_count}


static func is_valid_state(record: Dictionary) -> bool:
	if not record.get("stream_id", "") is String or String(record.get("stream_id", "")).is_empty():
		return false
	if not _is_integer(record.get("initial_seed", 0)) or int(record.get("initial_seed", 0)) <= 0 or int(record.get("initial_seed", 0)) >= MODULUS:
		return false
	if not _is_integer(record.get("consumption_count", -1)) or int(record.get("consumption_count", -1)) < 0 or int(record.get("consumption_count", -1)) > MAX_CONSUMPTION:
		return false
	return true


static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, floor(value)))
