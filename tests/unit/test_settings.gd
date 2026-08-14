class_name TestSettings
extends RefCounted

const SettingsService = preload("res://src/core/settings_service.gd")

const SETTINGS_PATH: String = "user://m0_003_settings_tests/settings.cfg"


func run() -> Array[Dictionary]:
	return [_conflict_and_required_guard(), _persistence(), _corrupt_file_fallback()]


func _conflict_and_required_guard() -> Dictionary:
	var settings := SettingsService.new(SETTINGS_PATH)
	settings.restore_defaults()
	var conflict := settings.rebind(SettingsService.KEYBOARD_MOUSE, &"move_up", "Key:E")
	var guard := settings.remove_binding(SettingsService.KEYBOARD_MOUSE, &"interact", "Key:E")
	var restored: bool = settings.binding_set(SettingsService.KEYBOARD_MOUSE)["move_up"].has("Key:W")
	return _assert(not conflict.ok and conflict.get("conflict_action", StringName()) == &"interact" and not guard.ok and restored and InputMap.action_get_events(&"move_up").size() > 0, "input_conflict_required_guard_and_defaults", "input safety guard or InputMap sync failed")


func _persistence() -> Dictionary:
	var settings := SettingsService.new(SETTINGS_PATH)
	settings.restore_defaults()
	settings.set_ui_scale(150)
	settings.set_text_speed("fast")
	settings.set_volume("Music", 0.35)
	settings.mark_device_used(SettingsService.GAMEPAD)
	var saved := settings.save()
	var reloaded := SettingsService.new(SETTINGS_PATH)
	var loaded := reloaded.load()
	var view := reloaded.view_model()
	return _assert(saved.ok and loaded.ok and view.ui_scale == 150 and view.text_speed == "fast" and is_equal_approx(view.volumes.Music, 0.35) and view.last_used_device == SettingsService.GAMEPAD, "settings_restart_persistence", "settings did not persist")


func _corrupt_file_fallback() -> Dictionary:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return _assert(false, "corrupt_settings_fallback", "could not create corrupt settings fixture")
	file.store_string("this is not settings JSON")
	file.close()
	var settings := SettingsService.new(SETTINGS_PATH)
	var loaded := settings.load()
	var view := settings.view_model()
	return _assert(not loaded.ok and loaded.used_defaults and view.ui_scale == 100, "corrupt_settings_fallback", "corrupt settings did not restore defaults")


func _assert(condition: bool, name: String, message: String) -> Dictionary:
	return {"name": name, "ok": condition, "message": message}
