## Machine settings and protected input binding service. Save-game settings snapshots are
## deliberately separate from this machine file.
class_name SettingsService
extends RefCounted

const GameLogScript = preload("res://src/core/game_log.gd")
const GameSessionSnapshotScript = preload("res://src/core/game_session_snapshot.gd")
const SettingsViewModelScript = preload("res://src/core/settings_view_model.gd")

const KEYBOARD_MOUSE: String = "keyboard_mouse"
const GAMEPAD: String = "gamepad"
const REQUIRED_ACTIONS: PackedStringArray = ["move_up", "move_down", "move_left", "move_right", "interact", "use_tool", "pause", "ui_accept", "ui_cancel"]
const UI_ACTIONS: PackedStringArray = ["ui_accept", "ui_cancel"]
const VALID_SCALES: PackedInt32Array = [100, 125, 150]
const VALID_TEXT_SPEEDS: PackedStringArray = ["slow", "standard", "fast", "instant"]
const VOLUME_BUSES: PackedStringArray = ["Master", "Music", "Ambience", "SFX", "UI"]

var _settings_path: String
var _values: Dictionary


func _init(settings_path: String = "user://settings.cfg") -> void:
	_settings_path = settings_path
	_values = _default_values()


func load() -> Dictionary:
	if not FileAccess.file_exists(_settings_path):
		apply_to_input_map()
		return {"ok": true, "used_defaults": true}
	var json := JSON.new()
	var source := FileAccess.get_file_as_string(_settings_path)
	if json.parse(source) != OK or not json.data is Dictionary or not _validate_values(json.data):
		_preserve_corrupt_file()
		_values = _default_values()
		apply_to_input_map()
		GameLogScript.warning(GameLogScript.Category.SAVE, "Settings file rejected; defaults restored.", {"path": _settings_path.get_file()})
		return {"ok": false, "used_defaults": true, "error": "invalid settings file"}
	_values = GameSessionSnapshotScript._copy_value(json.data)
	apply_to_input_map()
	return {"ok": true, "used_defaults": false}


func save() -> Dictionary:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_settings_path.get_base_dir()))
	if directory_error != OK:
		return {"ok": false, "error": "cannot create settings directory"}
	var temporary_path := _settings_path.get_base_dir().path_join("settings.tmp")
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "cannot write temporary settings"}
	file.store_string(JSON.stringify(_values, "\t", false))
	file.flush()
	file.close()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(temporary_path)) != OK or not json.data is Dictionary or not _validate_values(json.data):
		return {"ok": false, "error": "temporary settings verification failed"}
	var replace_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(_settings_path))
	if replace_error != OK:
		return {"ok": false, "error": "settings replacement failed"}
	return {"ok": true}


func view_model() -> RefCounted:
	return SettingsViewModelScript.new(_values)


func save_game_snapshot() -> Dictionary:
	## Only gameplay/accessibility choices travel with a save; hardware mappings stay machine-local.
	return {"ui_scale": _values.ui_scale, "vibration_enabled": _values.vibration_enabled, "reduce_flashing": _values.reduce_flashing, "text_speed": _values.text_speed}


func restore_defaults() -> void:
	_values = _default_values()
	apply_to_input_map()


func set_ui_scale(value: int) -> bool:
	if not VALID_SCALES.has(value):
		return false
	_values.ui_scale = value
	return true


func set_vibration_enabled(value: bool) -> void:
	_values.vibration_enabled = value


func set_reduce_flashing(value: bool) -> void:
	_values.reduce_flashing = value


func set_text_speed(value: String) -> bool:
	if not VALID_TEXT_SPEEDS.has(value):
		return false
	_values.text_speed = value
	return true


func set_volume(bus: String, value: float) -> bool:
	if not VOLUME_BUSES.has(bus) or value < 0.0 or value > 1.0:
		return false
	_values.volumes[bus] = value
	return true


func mark_device_used(device: String) -> bool:
	if device != KEYBOARD_MOUSE and device != GAMEPAD:
		return false
	_values.last_used_device = device
	return true


func rebind(device: String, action: StringName, binding: String) -> Dictionary:
	var action_key := str(action)
	if not _is_valid_device(device) or not _values.bindings[device].has(action_key) or binding.is_empty():
		return {"ok": false, "error": "invalid binding request"}
	var context := _context_for(action)
	for candidate: Variant in _values.bindings[device]:
		if candidate != action_key and _context_for(StringName(candidate)) == context and _values.bindings[device][candidate].has(binding):
			return {"ok": false, "conflict_action": StringName(candidate), "error": "binding conflict"}
	_values.bindings[device][action_key] = [binding]
	apply_to_input_map()
	return {"ok": true}


func remove_binding(device: String, action: StringName, binding: String) -> Dictionary:
	var action_key := str(action)
	if not _is_valid_device(device) or not _values.bindings[device].has(action_key):
		return {"ok": false, "error": "invalid binding request"}
	var bindings: Array = _values.bindings[device][action_key]
	if not bindings.has(binding):
		return {"ok": false, "error": "binding not found"}
	if REQUIRED_ACTIONS.has(str(action)) and bindings.size() == 1:
		return {"ok": false, "error": "required action must retain a binding"}
	bindings.erase(binding)
	_values.bindings[device][action_key] = bindings
	apply_to_input_map()
	return {"ok": true}


func binding_set(device: String) -> Dictionary:
	return GameSessionSnapshotScript._copy_value(_values.bindings.get(device, {}))


func apply_to_input_map() -> void:
	for action_name: Variant in _all_actions():
		var action := StringName(action_name)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for device: String in [KEYBOARD_MOUSE, GAMEPAD]:
			for binding: String in _values.bindings[device][str(action)]:
				var event := _event_from_binding(binding)
				if event != null:
					InputMap.action_add_event(action, event)


func _default_values() -> Dictionary:
	var keyboard: Dictionary = {}
	var gamepad: Dictionary = {}
	for action_name: String in _all_actions():
		var action := StringName(action_name)
		keyboard[action_name] = ["Key:%s" % action.to_upper()]
		gamepad[action_name] = ["Joypad:%s" % action.to_upper()]
	keyboard["move_up"] = ["Key:W"]
	keyboard["move_down"] = ["Key:S"]
	keyboard["move_left"] = ["Key:A"]
	keyboard["move_right"] = ["Key:D"]
	keyboard["interact"] = ["Key:E"]
	keyboard["use_tool"] = ["Mouse:Left"]
	keyboard["pause"] = ["Key:Escape"]
	keyboard["ui_accept"] = ["Key:Enter"]
	keyboard["ui_cancel"] = ["Mouse:Right"]
	gamepad["interact"] = ["Joypad:A"]
	gamepad["use_tool"] = ["Joypad:X"]
	gamepad["move_up"] = ["Joypad:DpadUp"]
	gamepad["move_down"] = ["Joypad:DpadDown"]
	gamepad["move_left"] = ["Joypad:DpadLeft"]
	gamepad["move_right"] = ["Joypad:DpadRight"]
	gamepad["pause"] = ["Joypad:Start"]
	gamepad["ui_accept"] = ["Joypad:A"]
	gamepad["ui_cancel"] = ["Joypad:B"]
	return {"ui_scale": 100, "vibration_enabled": true, "reduce_flashing": false, "text_speed": "standard", "volumes": {"Master": 1.0, "Music": 1.0, "Ambience": 1.0, "SFX": 1.0, "UI": 1.0}, "last_used_device": KEYBOARD_MOUSE, "bindings": {KEYBOARD_MOUSE: keyboard, GAMEPAD: gamepad}}


func _all_actions() -> PackedStringArray:
	return ["move_up", "move_down", "move_left", "move_right", "interact", "use_tool", "tool_next", "tool_previous", "quick_slot_1", "quick_slot_2", "quick_slot_3", "quick_slot_4", "quick_slot_5", "quick_slot_6", "quick_slot_7", "quick_slot_8", "inventory", "quest_log", "pause", "ui_accept", "ui_cancel"]


func _context_for(action: StringName) -> String:
	return "ui" if UI_ACTIONS.has(str(action)) else "gameplay"


func _event_from_binding(binding: String) -> InputEvent:
	var parts := binding.split(":", false, 1)
	if parts.size() != 2:
		return null
	if parts[0] == "Key":
		var event := InputEventKey.new()
		event.physical_keycode = OS.find_keycode_from_string(parts[1])
		return event if event.physical_keycode != KEY_NONE else null
	if parts[0] == "Mouse":
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if parts[1] == "Left" else MOUSE_BUTTON_RIGHT if parts[1] == "Right" else MOUSE_BUTTON_NONE
		return event if event.button_index != MOUSE_BUTTON_NONE else null
	if parts[0] == "Joypad":
		var event := InputEventJoypadButton.new()
		var buttons := {"A": JOY_BUTTON_A, "B": JOY_BUTTON_B, "X": JOY_BUTTON_X, "Start": JOY_BUTTON_START, "DpadUp": JOY_BUTTON_DPAD_UP, "DpadDown": JOY_BUTTON_DPAD_DOWN, "DpadLeft": JOY_BUTTON_DPAD_LEFT, "DpadRight": JOY_BUTTON_DPAD_RIGHT}
		if not buttons.has(parts[1]):
			return null
		event.button_index = buttons[parts[1]]
		return event
	return null


func _validate_values(value: Dictionary) -> bool:
	if not VALID_SCALES.has(value.get("ui_scale", -1)) or not value.get("vibration_enabled", null) is bool or not value.get("reduce_flashing", null) is bool or not VALID_TEXT_SPEEDS.has(value.get("text_speed", "")) or not _is_valid_device(value.get("last_used_device", "")) or not value.get("volumes", null) is Dictionary or not value.get("bindings", null) is Dictionary:
		return false
	for bus: String in VOLUME_BUSES:
		if not value.volumes.get(bus, null) is float and not value.volumes.get(bus, null) is int:
			return false
		if float(value.volumes[bus]) < 0.0 or float(value.volumes[bus]) > 1.0:
			return false
	for device: String in [KEYBOARD_MOUSE, GAMEPAD]:
		if not value.bindings.get(device, null) is Dictionary:
			return false
		for action_text: String in _all_actions():
			if not value.bindings[device].get(action_text, null) is Array or value.bindings[device][action_text].is_empty():
				return false
	return true


func _preserve_corrupt_file() -> void:
	var diagnostic_path := "%s.corrupt.%d" % [_settings_path, Time.get_unix_time_from_system()]
	DirAccess.copy_absolute(ProjectSettings.globalize_path(_settings_path), ProjectSettings.globalize_path(diagnostic_path))


func _is_valid_device(device: String) -> bool:
	return device == KEYBOARD_MOUSE or device == GAMEPAD
