## Small, dependency-free logging boundary for the M0 skeleton.
## Domain services may use these stable categories without depending on a scene.
class_name GameLog
extends RefCounted

enum Category {
	CONTENT,
	SAVE,
	FARM,
	INVENTORY,
	ECONOMY,
	QUEST,
	WORLD,
	COMMUNITY,
	PERF,
}

const CATEGORY_NAMES: PackedStringArray = [
	"CONTENT",
	"SAVE",
	"FARM",
	"INVENTORY",
	"ECONOMY",
	"QUEST",
	"WORLD",
	"COMMUNITY",
	"PERF",
]

static var _sequence: int = 0


static func info(category: Category, message: String, context: Dictionary = {}) -> void:
	_emit("INFO", category, message, context)


static func warning(category: Category, message: String, context: Dictionary = {}) -> void:
	_emit("WARN", category, message, context)


static func error(category: Category, message: String, context: Dictionary = {}) -> void:
	_emit("ERROR", category, message, context)


static func _emit(level: String, category: Category, message: String, context: Dictionary) -> void:
	_sequence += 1
	var fields: Array[String] = []
	var keys: Array = context.keys()
	keys.sort()
	for key: Variant in keys:
		fields.append("%s=%s" % [str(key), str(context[key])])
	var context_suffix: String = "" if fields.is_empty() else " " + ", ".join(fields)
	var timestamp: String = Time.get_datetime_string_from_system(true, true)
	print("[%s][%04d][%s][%s] %s%s" % [timestamp, _sequence, level, CATEGORY_NAMES[category], message, context_suffix])
