## Session-scoped clock. It advances from accumulated time and supports composable pauses.
class_name ClockSystem
extends RefCounted

const DAY_START_MINUTE := 390 # 06:30
const DAY_END_MINUTE := 1410 # 23:30
const GAME_MINUTES_PER_REAL_SECOND := 1.3

var _accumulated_minutes := 0.0
var _pause_reasons: Dictionary = {}


func add_pause_reason(reason: StringName) -> void:
	_pause_reasons[reason] = true


func remove_pause_reason(reason: StringName) -> void:
	_pause_reasons.erase(reason)


func is_paused() -> bool:
	return not _pause_reasons.is_empty()


func pause_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	for reason: Variant in _pause_reasons:
		reasons.append(StringName(reason))
	return reasons


func advance(session: Variant, delta_seconds: float) -> int:
	if is_paused() or delta_seconds <= 0.0:
		return 0
	_accumulated_minutes += delta_seconds * GAME_MINUTES_PER_REAL_SECOND
	var whole_minutes := floori(_accumulated_minutes)
	if whole_minutes <= 0:
		return 0
	_accumulated_minutes -= whole_minutes
	var current_minute := int(session.calendar.get("minute", DAY_START_MINUTE))
	var advanced := mini(whole_minutes, DAY_END_MINUTE - current_minute)
	session.calendar["minute"] = current_minute + advanced
	return advanced


func begin_next_day(session: Variant) -> void:
	session.calendar["day"] = int(session.calendar.get("day", 1)) + 1
	session.calendar["minute"] = DAY_START_MINUTE
	_accumulated_minutes = 0.0
