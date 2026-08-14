## JSON-safe transport object. Its dictionary is never allowed to contain engine objects.
class_name SaveGameDto
extends RefCounted

const GameSessionSnapshotScript = preload("res://src/core/game_session_snapshot.gd")

var fields: Dictionary


func _init(value: Dictionary = {}) -> void:
	fields = GameSessionSnapshotScript._copy_value(value)


func to_dictionary() -> Dictionary:
	return GameSessionSnapshotScript._copy_value(fields)
