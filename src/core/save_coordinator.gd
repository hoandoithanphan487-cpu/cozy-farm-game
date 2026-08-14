## Owns save stability and recoverable slot writes. It never serializes a live session
## after the snapshot boundary.
class_name SaveCoordinator
extends RefCounted

const GameLogScript = preload("res://src/core/game_log.gd")
const SaveCodecScript = preload("res://src/core/save_codec.gd")

signal save_completed(slot: int)
signal save_failed(slot: int, reason: String)

var _codec: Variant
var _save_directory: String
var _active_transactions: int = 0
var _is_loading: bool = false
var _is_community_commit: bool = false
var _is_day_settlement: bool = false
var _pending_slots: Array[int] = []


func _init(codec: Variant = null, save_directory: String = "user://saves") -> void:
	_codec = codec if codec != null else SaveCodecScript.new()
	_save_directory = save_directory


func begin_transaction() -> void:
	_active_transactions += 1


func end_transaction() -> void:
	_active_transactions = maxi(0, _active_transactions - 1)


func set_loading(active: bool) -> void:
	_is_loading = active


func set_community_commit(active: bool) -> void:
	_is_community_commit = active


func set_day_settlement(active: bool) -> void:
	_is_day_settlement = active


func request_save(slot: int, session: Variant) -> Dictionary:
	if slot < 0:
		return _fail(slot, "invalid slot")
	if not _is_stable():
		if not _pending_slots.has(slot):
			_pending_slots.append(slot)
		GameLogScript.info(GameLogScript.Category.SAVE, "Save request queued until stable point.", {"slot": slot})
		return {"ok": false, "queued": true, "reason": "unstable session"}
	return _write_snapshot(slot, session.create_snapshot())


func flush_pending(session: Variant) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not _is_stable():
		return results
	var slots: Array[int] = _pending_slots.duplicate()
	_pending_slots.clear()
	for slot: int in slots:
		results.append(_write_snapshot(slot, session.create_snapshot()))
	return results


func load_slot(slot: int) -> Dictionary:
	if slot < 0:
		return {"ok": false, "error": "invalid slot"}
	for path: String in [_main_path(slot), _backup_path(slot)]:
		if not FileAccess.file_exists(path):
			continue
		var decoded: Dictionary = _codec.decode_json(FileAccess.get_file_as_string(path))
		if decoded.ok:
			GameLogScript.info(GameLogScript.Category.SAVE, "Save loaded.", {"slot": slot, "source": path.get_file()})
			return decoded
		GameLogScript.warning(GameLogScript.Category.SAVE, "Save candidate rejected during load.", {"slot": slot, "source": path.get_file()})
	return {"ok": false, "error": "no valid save generation"}


func _write_snapshot(slot: int, snapshot: Variant) -> Dictionary:
	var encoded: Dictionary = _codec.encode_json(snapshot)
	if not encoded.ok:
		return _fail(slot, String(encoded.error))
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_save_directory))
	if directory_error != OK:
		return _fail(slot, "cannot create save directory")
	var temporary_path := _temporary_path(slot)
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _fail(slot, "cannot write temporary save")
	file.store_string(encoded.value)
	file.flush()
	file.close()
	var readback: Dictionary = _codec.decode_json(FileAccess.get_file_as_string(temporary_path))
	if not readback.ok:
		return _fail(slot, "temporary save verification failed")
	var main_path := _main_path(slot)
	if FileAccess.file_exists(main_path):
		var current: Dictionary = _codec.decode_json(FileAccess.get_file_as_string(main_path))
		if current.ok:
			var backup_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(main_path), ProjectSettings.globalize_path(_backup_path(slot)))
			if backup_error != OK:
				return _fail(slot, "cannot preserve backup")
		else:
			GameLogScript.warning(GameLogScript.Category.SAVE, "Existing main save is invalid; retaining it while replacement is attempted.", {"slot": slot})
	var replace_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(main_path))
	if replace_error != OK:
		return _fail(slot, "temporary save replacement failed")
	emit_signal("save_completed", slot)
	GameLogScript.info(GameLogScript.Category.SAVE, "Save completed.", {"slot": slot})
	return {"ok": true}


func _is_stable() -> bool:
	return _active_transactions == 0 and not _is_loading and not _is_community_commit and not _is_day_settlement


func _main_path(slot: int) -> String:
	return "%s/slot_%d.json" % [_save_directory, slot]


func _backup_path(slot: int) -> String:
	return "%s/slot_%d.backup" % [_save_directory, slot]


func _temporary_path(slot: int) -> String:
	return "%s/slot_%d.tmp" % [_save_directory, slot]


func _fail(slot: int, reason: String) -> Dictionary:
	emit_signal("save_failed", slot, reason)
	GameLogScript.error(GameLogScript.Category.SAVE, "Save failed.", {"slot": slot, "reason": reason})
	return {"ok": false, "error": reason}
