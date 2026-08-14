## M0-001 startup composition root.
## This script deliberately does not construct gameplay, content, save, settings, or routing services.
extends Node

signal bootstrap_ready

const CONTENT_REGISTRY_SCRIPT := preload("res://src/content/content_registry.gd")

const REQUIRED_INPUT_ACTIONS: PackedStringArray = [
	"move_up",
	"move_down",
	"move_left",
	"move_right",
	"interact",
	"use_tool",
	"tool_next",
	"tool_previous",
	"quick_slot_1",
	"quick_slot_2",
	"quick_slot_3",
	"quick_slot_4",
	"quick_slot_5",
	"quick_slot_6",
	"quick_slot_7",
	"quick_slot_8",
	"inventory",
	"quest_log",
	"pause",
	"ui_accept",
	"ui_cancel",
]

const FUTURE_SERVICE_PORTS: PackedStringArray = [
	"ContentRegistry",
	"SettingsService",
	"SaveService",
	"SceneRouter",
]

@onready var _status_label: Label = $CanvasLayer/Margin/Layout/Status

var _content_registry: ContentRegistry


func _ready() -> void:
	GameLog.info(GameLog.Category.PERF, "Bootstrap startup.", {
		"engine_lock": ProjectSettings.get_setting("application/config/engine_version_lock", "unknown"),
		"scene": scene_file_path,
	})
	_content_registry = CONTENT_REGISTRY_SCRIPT.new()
	if not _content_registry.load_and_validate():
		_present_content_failure(_content_registry.validation_errors())
		return
	var missing_actions: PackedStringArray = _find_missing_input_actions()
	if missing_actions.is_empty():
		_status_label.text = "Bootstrap 已启动。内容验证与基础 InputMap 已就绪；请查看控制台中的日志。"
		GameLog.info(GameLog.Category.PERF, "Bootstrap ready.", {
			"input_actions": REQUIRED_INPUT_ACTIONS.size(),
			"service_ports": FUTURE_SERVICE_PORTS.size(),
		})
	else:
		_status_label.text = "Bootstrap 已启动，但基础 InputMap 缺失：%s" % ", ".join(missing_actions)
		GameLog.error(GameLog.Category.PERF, "Bootstrap input validation failed.", {
			"missing_actions": ",".join(missing_actions),
		})
		_log_future_service_boundary()
	bootstrap_ready.emit()


func has_future_service_port(port_name: StringName) -> bool:
	return port_name == &"ContentRegistry" and _content_registry != null


func _present_content_failure(errors: Array[String]) -> void:
	var summary := "\n".join(errors)
	GameLog.error(GameLog.Category.CONTENT, "Content validation failed; startup stopped.", {
		"error_count": errors.size(),
		"errors": summary,
	})
	if OS.is_debug_build():
		_status_label.text = "开发构建已停止：内容定义无效。\n%s" % summary
		get_tree().paused = true
	else:
		_status_label.text = "无法加载游戏内容。请返回标题页或重启游戏。\n%s" % summary


func _find_missing_input_actions() -> PackedStringArray:
	var missing_actions: PackedStringArray = []
	for action_name: String in REQUIRED_INPUT_ACTIONS:
		if not InputMap.has_action(action_name):
			missing_actions.append(action_name)
	return missing_actions


func _log_future_service_boundary() -> void:
	GameLog.info(GameLog.Category.PERF, "Future service ports intentionally remain unconfigured.", {
		"ports": ",".join(FUTURE_SERVICE_PORTS),
	})
