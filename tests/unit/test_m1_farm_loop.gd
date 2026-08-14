class_name TestM1FarmLoop
extends RefCounted

const ClockSystem = preload("res://src/domain/clock_system.gd")
const CropDefinitionScript = preload("res://src/content/crop_definition.gd")
const FarmActionService = preload("res://src/domain/farm_action_service.gd")
const GameSession = preload("res://src/core/game_session.gd")
const InventoryService = preload("res://src/domain/inventory_service.gd")
const SaveCodec = preload("res://src/core/save_codec.gd")


func run() -> Array[Dictionary]:
	return [_farming_loop(), _dry_crop_waits(), _stamina_failure_is_atomic(), _inventory_capacity_is_atomic(), _farm_state_persists(), _clock_uses_composable_pauses()]


func _farming_loop() -> Dictionary:
	var session := _session_with_seed()
	var farm := FarmActionService.new()
	var crops := _crops()
	var limits := _limits()
	var coordinate := Vector2i(2, 3)
	var tilled := farm.apply_action(session, coordinate, &"hoe", crops, limits)
	var planted := farm.apply_action(session, coordinate, &"seed", crops, limits)
	var watered_one := farm.apply_action(session, coordinate, &"water", crops, limits)
	farm.advance_day(session, crops)
	var watered_two := farm.apply_action(session, coordinate, &"water", crops, limits)
	farm.advance_day(session, crops)
	var harvested := farm.apply_action(session, coordinate, &"harvest", crops, limits)
	return _assert(tilled.ok and planted.ok and watered_one.ok and watered_two.ok and harvested.ok and InventoryService.count(session.inventory, &"brookseed.item.mist_radish") == 1, "m1_till_plant_water_grow_harvest", "the complete farm loop did not produce one harvest")


func _dry_crop_waits() -> Dictionary:
	var session := _session_with_seed()
	var farm := FarmActionService.new()
	var crops := _crops()
	var coordinate := Vector2i(1, 1)
	farm.apply_action(session, coordinate, &"hoe", crops, _limits())
	farm.apply_action(session, coordinate, &"seed", crops, _limits())
	farm.advance_day(session, crops)
	return _assert(session.farm_cells[coordinate].crop_stage == 0 and not session.farm_cells[coordinate].ready_to_harvest, "m1_dry_crop_does_not_grow", "unwatered crop advanced during day cycle")


func _stamina_failure_is_atomic() -> Dictionary:
	var session := _session_with_seed()
	session.player.stamina = 1
	var farm := FarmActionService.new()
	var result := farm.apply_action(session, Vector2i(4, 4), &"hoe", _crops(), _limits())
	return _assert(not result.ok and session.player.stamina == 1 and session.farm_cells.is_empty(), "m1_stamina_rejection_is_atomic", "failed labour action altered state")


func _inventory_capacity_is_atomic() -> Dictionary:
	var session := _session_with_seed()
	session.player.inventory_capacity = 1
	session.inventory = [{"item_id": &"brookseed.item.mist_radish_seed", "quantity": 8, "quality": &"normal"}]
	var added := InventoryService.try_add(session.inventory, 1, &"brookseed.item.mist_radish", 1, 99)
	return _assert(not added.ok and InventoryService.count(session.inventory, &"brookseed.item.mist_radish_seed") == 8, "m1_full_inventory_preserves_source", "full inventory operation mutated source state")


func _farm_state_persists() -> Dictionary:
	var session := _session_with_seed()
	var farm := FarmActionService.new()
	var coordinate := Vector2i(6, 2)
	farm.apply_action(session, coordinate, &"hoe", _crops(), _limits())
	farm.apply_action(session, coordinate, &"seed", _crops(), _limits())
	farm.apply_action(session, coordinate, &"water", _crops(), _limits())
	var codec := SaveCodec.new()
	var decoded := codec.decode_json(codec.encode_json(session.create_snapshot()).value)
	var restored: Dictionary = decoded.value.farm_cells[coordinate]
	return _assert(decoded.ok and restored.prepared and restored.watered_today and restored.planted_day == 1 and decoded.value.player.inventory_capacity == 16, "m1_farm_and_inventory_capacity_save_round_trip", "M1 state did not survive save/load")


func _clock_uses_composable_pauses() -> Dictionary:
	var clock := ClockSystem.new()
	var session := _session_with_seed()
	clock.add_pause_reason(&"MENU")
	clock.add_pause_reason(&"DIALOGUE")
	var while_paused := clock.advance(session, 3.0)
	clock.remove_pause_reason(&"MENU")
	var still_paused := clock.advance(session, 3.0)
	clock.remove_pause_reason(&"DIALOGUE")
	var running := clock.advance(session, 3.0)
	return _assert(while_paused == 0 and still_paused == 0 and running > 0, "m1_pause_reasons_compose", "removing one pause reason resumed time too early")


func _session_with_seed() -> GameSession:
	var session := GameSession.create_empty(&"brookseed.scenario.m1_farm")
	session.calendar.minute = 390
	session.player.inventory_capacity = 16
	session.inventory = [{"item_id": &"brookseed.item.mist_radish_seed", "quantity": 8, "quality": &"normal"}]
	return session


func _crops() -> Dictionary:
	var crop := CropDefinitionScript.new()
	crop.id = &"brookseed.crop.mist_radish"
	crop.seed_item_id = &"brookseed.item.mist_radish_seed"
	crop.harvest_item_id = &"brookseed.item.mist_radish"
	crop.stage_days = PackedInt32Array([1, 1, 1])
	crop.mature_stage_index = 2
	crop.yield_min = 1
	crop.yield_max = 1
	return {crop.id: crop}


func _limits() -> Dictionary:
	return {&"brookseed.item.mist_radish_seed": 99, &"brookseed.item.mist_radish": 99}


func _assert(condition: bool, name: String, message: String) -> Dictionary:
	return {"name": name, "ok": condition, "message": message}
