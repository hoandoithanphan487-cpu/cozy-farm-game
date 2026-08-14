## A deep-copied, immutable-at-the-boundary view captured at a SaveCoordinator stable point.
class_name GameSessionSnapshot
extends RefCounted

var scenario_id: StringName
var calendar: Dictionary
var player: Dictionary
var inventory: Array
var farm_cells: Dictionary
var economy: Dictionary
var quests: Array
var relationships: Dictionary
var community: Dictionary
var random_streams: Dictionary
var watershed: Dictionary
var world: Dictionary
var settings_snapshot: Dictionary


func _init(session: Variant) -> void:
	scenario_id = session.scenario_id
	calendar = _copy_value(session.calendar)
	player = _copy_value(session.player)
	inventory = _copy_value(session.inventory)
	farm_cells = _copy_value(session.farm_cells)
	economy = _copy_value(session.economy)
	quests = _copy_value(session.quests)
	relationships = _copy_value(session.relationships)
	community = _copy_value(session.community)
	random_streams = _copy_value(session.random_streams)
	watershed = _copy_value(session.watershed)
	world = _copy_value(session.world)
	settings_snapshot = _copy_value(session.settings_snapshot)


static func _copy_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[_copy_value(key)] = _copy_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_copy_value(entry))
		return result
	return value
