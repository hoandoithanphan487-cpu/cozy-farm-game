class_name TestSaveCoordinator
extends RefCounted

const DeterministicRandomStreams = preload("res://src/core/deterministic_random_streams.gd")
const GameSession = preload("res://src/core/game_session.gd")
const SaveCodec = preload("res://src/core/save_codec.gd")
const SaveCoordinator = preload("res://src/core/save_coordinator.gd")

const DIRECTORY: String = "user://m0_003_save_tests"


func run() -> Array[Dictionary]:
	return [_save_load(), _backup_recovery(), _unstable_save_queues(), _random_continues_after_save_load()]


func _save_load() -> Dictionary:
	var coordinator := SaveCoordinator.new(SaveCodec.new(), DIRECTORY)
	var session := GameSession.create_empty()
	session.economy.balance = 17
	var saved := coordinator.request_save(21, session)
	var loaded := coordinator.load_slot(21)
	return _assert(saved.ok and loaded.ok and loaded.value.economy.balance == 17, "coordinator_save_then_load", "save/load path failed")


func _backup_recovery() -> Dictionary:
	var coordinator := SaveCoordinator.new(SaveCodec.new(), DIRECTORY)
	var session := GameSession.create_empty()
	session.economy.balance = 5
	var first := coordinator.request_save(22, session)
	session.economy.balance = 9
	var second := coordinator.request_save(22, session)
	var path := "%s/slot_22.json" % DIRECTORY
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var recovered := coordinator.load_slot(22)
	return _assert(first.ok and second.ok and recovered.ok and recovered.value.economy.balance == 5, "primary_failure_recovers_backup", "backup was not selected after main corruption")


func _unstable_save_queues() -> Dictionary:
	var coordinator := SaveCoordinator.new(SaveCodec.new(), DIRECTORY)
	var session := GameSession.create_empty()
	coordinator.begin_transaction()
	var queued := coordinator.request_save(23, session)
	coordinator.end_transaction()
	var flushed := coordinator.flush_pending(session)
	return _assert(queued.get("queued", false) and flushed.size() == 1 and flushed[0].ok, "unstable_transaction_save_queues", "save was not safely queued")


func _random_continues_after_save_load() -> Dictionary:
	var coordinator := SaveCoordinator.new(SaveCodec.new(), DIRECTORY)
	var live_streams := DeterministicRandomStreams.create_default(9876)
	live_streams.next_int(&"weather")
	live_streams.next_int(&"quality")
	var session := GameSession.create_empty()
	session.random_streams = _records_to_map(live_streams.to_state_records())
	var saved := coordinator.request_save(24, session)
	var loaded := coordinator.load_slot(24)
	var restored_records: Array[Dictionary] = []
	for id_text: String in DeterministicRandomStreams.REQUIRED_STREAM_IDS:
		var state: Dictionary = loaded.value.random_streams[id_text]
		restored_records.append({"stream_id": id_text, "initial_seed": state.initial_seed, "consumption_count": state.consumption_count})
	var restored := DeterministicRandomStreams.from_state_records(restored_records).value as DeterministicRandomStreams
	return _assert(saved.ok and loaded.ok and live_streams.next_int(&"weather") == restored.next_int(&"weather") and live_streams.next_int(&"gossip") == restored.next_int(&"gossip"), "random_streams_continue_after_save_load", "random continuation diverged after loading")


func _records_to_map(records: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for record: Dictionary in records:
		result[record["stream_id"]] = {"initial_seed": record["initial_seed"], "consumption_count": record["consumption_count"]}
	return result


func _assert(condition: bool, name: String, message: String) -> Dictionary:
	return {"name": name, "ok": condition, "message": message}
