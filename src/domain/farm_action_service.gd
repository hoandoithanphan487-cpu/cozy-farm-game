## Validates and atomically commits M1 farm actions against GameSession state.
class_name FarmActionService
extends RefCounted

const InventoryServiceScript := preload("res://src/domain/inventory_service.gd")

const TOOL_STAMINA_COSTS := {
	&"hoe": 2,
	&"seed": 2,
	&"water": 2,
	&"harvest": 2,
}


func preview_action(session: Variant, target: Vector2i, tool: StringName, crops: Dictionary, stack_limits: Dictionary) -> Dictionary:
	return _prepare_action(session, target, tool, crops, stack_limits)


func apply_action(session: Variant, target: Vector2i, tool: StringName, crops: Dictionary, stack_limits: Dictionary) -> Dictionary:
	var prepared := _prepare_action(session, target, tool, crops, stack_limits)
	if not prepared.ok:
		return prepared
	session.player["stamina"] = prepared.stamina
	session.inventory = prepared.inventory
	session.farm_cells[target] = prepared.cell
	return {"ok": true, "reason": prepared.reason, "event": prepared.event}


func advance_day(session: Variant, crops: Dictionary) -> void:
	for coordinate: Variant in session.farm_cells.keys():
		var cell: Dictionary = (session.farm_cells[coordinate] as Dictionary).duplicate(true)
		var crop_id := StringName(cell.get("crop_id", ""))
		if crop_id.is_empty() or not crops.has(crop_id):
			cell["watered_today"] = false
			session.farm_cells[coordinate] = cell
			continue
		var crop: CropDefinition = crops[crop_id]
		if bool(cell.get("watered_today", false)) and not bool(cell.get("ready_to_harvest", false)):
			cell["stage_progress_days"] = int(cell.get("stage_progress_days", 0)) + 1
			cell["crop_stage"] = _stage_for_progress(crop, int(cell.stage_progress_days))
			cell["ready_to_harvest"] = int(cell.crop_stage) >= crop.mature_stage_index
		cell["watered_today"] = false
		session.farm_cells[coordinate] = cell


func _prepare_action(session: Variant, target: Vector2i, tool: StringName, crops: Dictionary, stack_limits: Dictionary) -> Dictionary:
	if not TOOL_STAMINA_COSTS.has(tool):
		return _invalid("未知工具。")
	var stamina_cost := int(TOOL_STAMINA_COSTS[tool])
	var stamina := int(session.player.get("stamina", 0))
	if stamina < stamina_cost:
		return _invalid("体力不足，不能继续劳动。")
	var cell := _cell_for(session, target)
	var inventory: Array = session.inventory.duplicate(true)
	match tool:
		&"hoe":
			if bool(cell.prepared) or not StringName(cell.crop_id).is_empty():
				return _invalid("这块地已经处理过了。")
			cell.prepared = true
			return _ready(cell, inventory, stamina - stamina_cost, "翻土完成。", &"tilled")
		&"seed":
			if not bool(cell.prepared) or not StringName(cell.crop_id).is_empty():
				return _invalid("只能在空的已翻土地块播种。")
			var crop := _first_crop_for_seed(crops, &"brookseed.item.mist_radish_seed")
			if crop == null:
				return _invalid("没有可用的种子定义。")
			var removed := InventoryServiceScript.try_remove(inventory, crop.seed_item_id, 1)
			if not removed.ok:
				return _invalid(String(removed.reason))
			cell.crop_id = crop.id
			cell.crop_stage = 0
			cell.stage_progress_days = 0
			cell.planted_day = int(session.calendar.get("day", 1))
			cell.ready_to_harvest = false
			return _ready(cell, removed.inventory, stamina - stamina_cost, "播种完成。", &"planted")
		&"water":
			if StringName(cell.crop_id).is_empty() or bool(cell.watered_today):
				return _invalid("这里没有需要浇水的作物。")
			cell.watered_today = true
			return _ready(cell, inventory, stamina - stamina_cost, "浇水完成。", &"watered")
		&"harvest":
			var crop_id := StringName(cell.crop_id)
			if crop_id.is_empty() or not bool(cell.ready_to_harvest) or not crops.has(crop_id):
				return _invalid("作物尚未成熟。")
			var crop: CropDefinition = crops[crop_id]
			var stack_limit := int(stack_limits.get(crop.harvest_item_id, 99))
			var added := InventoryServiceScript.try_add(inventory, int(session.player.get("inventory_capacity", 16)), crop.harvest_item_id, crop.yield_min, stack_limit)
			if not added.ok:
				return _invalid(String(added.reason))
			cell.crop_id = StringName()
			cell.crop_stage = 0
			cell.stage_progress_days = 0
			cell.planted_day = 0
			cell.ready_to_harvest = false
			cell.watered_today = false
			return _ready(cell, added.inventory, stamina - stamina_cost, "收获完成，已放入背包。", &"harvested")
	return _invalid("此工具暂不可用。")


func _cell_for(session: Variant, target: Vector2i) -> Dictionary:
	if session.farm_cells.has(target):
		return (session.farm_cells[target] as Dictionary).duplicate(true)
	return {
		"prepared": false,
		"watered_today": false,
		"fertility": 0,
		"crop_id": StringName(),
		"crop_stage": 0,
		"stage_progress_days": 0,
		"planted_day": 0,
		"ready_to_harvest": false,
	}


func _first_crop_for_seed(crops: Dictionary, seed_item_id: StringName) -> CropDefinition:
	for candidate: Variant in crops.values():
		var crop := candidate as CropDefinition
		if crop != null and crop.seed_item_id == seed_item_id:
			return crop
	return null


func _stage_for_progress(crop: CropDefinition, watered_days: int) -> int:
	var stage := 0
	var cumulative_days := 0
	for index: int in crop.stage_days.size():
		cumulative_days += crop.stage_days[index]
		if watered_days >= cumulative_days:
			stage = mini(index + 1, crop.mature_stage_index)
	return stage


func _ready(cell: Dictionary, inventory: Array, stamina: int, reason: String, event_name: StringName) -> Dictionary:
	return {"ok": true, "cell": cell, "inventory": inventory, "stamina": stamina, "reason": reason, "event": event_name}


func _invalid(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
