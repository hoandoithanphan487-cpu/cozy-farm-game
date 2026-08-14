## M1 playable placeholder presentation. Domain state lives in GameSession and services.
class_name FarmSlice
extends Node2D

const ContentRegistryScript := preload("res://src/content/content_registry.gd")
const GameSessionScript := preload("res://src/core/game_session.gd")
const ClockSystemScript := preload("res://src/domain/clock_system.gd")
const FarmActionServiceScript := preload("res://src/domain/farm_action_service.gd")
const InventoryServiceScript := preload("res://src/domain/inventory_service.gd")

const CELL_SIZE := 24.0
const FARM_ORIGIN := Vector2(96.0, 72.0)
const FARM_SIZE := Vector2i(12, 7)
const CABIN_TILE := Vector2i(0, 0)
const TOOLS: Array[StringName] = [&"hoe", &"seed", &"water", &"harvest"]

var _registry: ContentRegistry
var _session: GameSession
var _clock: ClockSystem
var _farm: FarmActionService
var _crops: Dictionary = {}
var _stack_limits: Dictionary = {}
var _player_pixels := Vector2.ZERO
var _facing := Vector2i.DOWN
var _tool_index := 0
var _feedback := "用 Q / R 切换工具，左键使用；靠近小屋按 E 睡眠。"
var _hud: Label
var _message: Label


func _ready() -> void:
	_registry = ContentRegistryScript.new()
	if not _registry.load_and_validate():
		_feedback = "内容验证失败：%s" % "\n".join(_registry.validation_errors())
		_create_ui()
		queue_redraw()
		return
	var crop := _registry.get_crop(&"brookseed.crop.mist_radish")
	var seed := _registry.get_item(&"brookseed.item.mist_radish_seed")
	var harvest := _registry.get_item(&"brookseed.item.mist_radish")
	if crop == null or seed == null or harvest == null:
		_feedback = "M1 占位内容缺失，无法开始农耕切片。"
		_create_ui()
		queue_redraw()
		return
	_crops[crop.id] = crop
	_stack_limits[seed.id] = seed.stack_limit
	_stack_limits[harvest.id] = harvest.stack_limit
	_session = GameSessionScript.create_empty(&"brookseed.scenario.m1_farm")
	_session.calendar = {"day": 1, "minute": 390, "season": "spring", "weather": "clear"}
	_session.player["position"] = Vector2i(5, 4)
	_session.player["inventory_capacity"] = 16
	_session.inventory = [{"item_id": seed.id, "quantity": 8, "quality": &"normal"}]
	_clock = ClockSystemScript.new()
	_farm = FarmActionServiceScript.new()
	_player_pixels = _cell_center(_session.player.position)
	_create_ui()
	_update_ui()
	queue_redraw()


func _process(delta: float) -> void:
	if _session == null:
		return
	_clock.advance(_session, delta)
	var movement := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if not _clock.is_paused() and movement.length() > 0.0:
		_player_pixels += movement.normalized() * 80.0 * delta
		_player_pixels.x = clampf(_player_pixels.x, FARM_ORIGIN.x + 8.0, FARM_ORIGIN.x + FARM_SIZE.x * CELL_SIZE - 8.0)
		_player_pixels.y = clampf(_player_pixels.y, FARM_ORIGIN.y + 8.0, FARM_ORIGIN.y + FARM_SIZE.y * CELL_SIZE - 8.0)
		_session.player["position"] = _player_grid()
		_facing = Vector2i(int(sign(movement.x)), int(sign(movement.y)))
		if _facing == Vector2i.ZERO:
			_facing = Vector2i.DOWN
	_update_ui()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _session == null:
		return
	if event.is_action_pressed(&"tool_next"):
		_tool_index = posmod(_tool_index + 1, TOOLS.size())
		_feedback = "当前工具：%s" % _tool_name()
	elif event.is_action_pressed(&"tool_previous"):
		_tool_index = posmod(_tool_index - 1, TOOLS.size())
		_feedback = "当前工具：%s" % _tool_name()
	elif event.is_action_pressed(&"use_tool"):
		_apply_current_tool()
	elif event.is_action_pressed(&"interact"):
		_try_sleep()
	_update_ui()
	queue_redraw()


func _apply_current_tool() -> void:
	var target := _target_grid()
	var result := _farm.apply_action(_session, target, TOOLS[_tool_index], _crops, _stack_limits)
	_feedback = String(result.reason)


func _try_sleep() -> void:
	var player_grid := _player_grid()
	if absi(player_grid.x - CABIN_TILE.x) > 1 or absi(player_grid.y - CABIN_TILE.y) > 1:
		_feedback = "靠近左上角的小屋后按 E，可以结束今天。"
		return
	_clock.add_pause_reason(&"SLEEP")
	_farm.advance_day(_session, _crops)
	_clock.begin_next_day(_session)
	_clock.remove_pause_reason(&"SLEEP")
	_feedback = "新的一天开始了；已浇水的作物推进了一天。"


func _target_grid() -> Vector2i:
	var result := _player_grid() + _facing
	result.x = clampi(result.x, 0, FARM_SIZE.x - 1)
	result.y = clampi(result.y, 0, FARM_SIZE.y - 1)
	return result


func _player_grid() -> Vector2i:
	return Vector2i(
		clampi(floori((_player_pixels.x - FARM_ORIGIN.x) / CELL_SIZE), 0, FARM_SIZE.x - 1),
		clampi(floori((_player_pixels.y - FARM_ORIGIN.y) / CELL_SIZE), 0, FARM_SIZE.y - 1)
	)


func _cell_center(cell: Vector2i) -> Vector2:
	return FARM_ORIGIN + Vector2(cell) * CELL_SIZE + Vector2.ONE * (CELL_SIZE * 0.5)


func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var title := Label.new()
	title.position = Vector2(12, 10)
	title.text = "溪谷新芽 · M1 农耕闭环"
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color("d8f1b5")
	canvas.add_child(title)
	_hud = Label.new()
	_hud.position = Vector2(12, 36)
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.modulate = Color("d8ebe4")
	canvas.add_child(_hud)
	_message = Label.new()
	_message.position = Vector2(12, 246)
	_message.size = Vector2(456, 18)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size", 12)
	_message.modulate = Color("b9d9d1")
	canvas.add_child(_message)


func _update_ui() -> void:
	if _session == null or _hud == null:
		return
	var minute := int(_session.calendar.get("minute", 390))
	var time_text := "%02d:%02d" % [minute / 60, minute % 60]
	var target := _target_grid()
	var preview := _farm.preview_action(_session, target, TOOLS[_tool_index], _crops, _stack_limits)
	var seed_count := InventoryServiceScript.count(_session.inventory, &"brookseed.item.mist_radish_seed")
	var harvest_count := InventoryServiceScript.count(_session.inventory, &"brookseed.item.mist_radish")
	_hud.text = "第 %d 天 · %s · 晴 · 体力 %d/100 · 溪票 %d\n工具：%s  | 目标格 (%d, %d) %s\n种子 %d  收获 %d  |  Q/R 切换 · 左键使用 · E 小屋睡眠" % [
		int(_session.calendar.get("day", 1)), time_text, int(_session.player.get("stamina", 0)), int(_session.economy.get("balance", 0)), _tool_name(),
		target.x, target.y, "可操作" if preview.ok else "不可：%s" % String(preview.reason),
		seed_count, harvest_count,
	]
	_message.text = _feedback


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color("102724"))
	if _session == null:
		return
	for y: int in FARM_SIZE.y:
		for x: int in FARM_SIZE.x:
			var coordinate := Vector2i(x, y)
			var rect := Rect2(FARM_ORIGIN + Vector2(coordinate) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			var cell: Dictionary = _session.farm_cells.get(coordinate, {})
			var color := Color("36594a")
			if bool(cell.get("prepared", false)):
				color = Color("77513c")
			if not StringName(cell.get("crop_id", "")).is_empty():
				color = Color("5b9a59") if not bool(cell.get("ready_to_harvest", false)) else Color("d1b957")
			draw_rect(rect.grow(-1.0), color)
			if bool(cell.get("watered_today", false)):
				draw_rect(rect.grow(-4.0), Color("78c7d5"), false, 1.5)
	draw_rect(Rect2(FARM_ORIGIN, Vector2(CELL_SIZE * 2.0, CELL_SIZE * 2.0)), Color("8c6f58"))
	draw_rect(Rect2(FARM_ORIGIN, Vector2(CELL_SIZE * 2.0, CELL_SIZE * 2.0)), Color("c9d7c7"), false, 1.5)
	var target_rect := Rect2(FARM_ORIGIN + Vector2(_target_grid()) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
	draw_rect(target_rect.grow(-2.0), Color("e0e9bb"), false, 2.0)
	draw_circle(_player_pixels, 7.0, Color("e4a975"))
	draw_circle(_player_pixels, 3.0, Color("fff1ce"))


func _tool_name() -> String:
	match TOOLS[_tool_index]:
		&"hoe": return "锄头"
		&"seed": return "种子"
		&"water": return "水壶"
		&"harvest": return "收获"
	return "未知"
