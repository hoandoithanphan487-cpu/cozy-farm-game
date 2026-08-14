## UI receives copied values only; mutations remain on SettingsService.
class_name SettingsViewModel
extends RefCounted

const GameSessionSnapshotScript = preload("res://src/core/game_session_snapshot.gd")

var ui_scale: int
var vibration_enabled: bool
var reduce_flashing: bool
var text_speed: String
var volumes: Dictionary
var last_used_device: String


func _init(values: Dictionary) -> void:
	ui_scale = values.ui_scale
	vibration_enabled = values.vibration_enabled
	reduce_flashing = values.reduce_flashing
	text_speed = values.text_speed
	volumes = GameSessionSnapshotScript._copy_value(values.volumes)
	last_used_device = values.last_used_device
