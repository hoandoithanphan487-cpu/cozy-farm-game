extends SceneTree

const UNIT_SAVE_CODEC := preload("res://tests/unit/test_save_codec.gd")
const UNIT_SETTINGS := preload("res://tests/unit/test_settings.gd")
const INTEGRATION_SAVE := preload("res://tests/integration/test_save_coordinator.gd")
const UNIT_CONTENT := preload("res://tests/unit/test_content_registry.gd")
const UNIT_M1_FARM := preload("res://tests/unit/test_m1_farm_loop.gd")


func _init() -> void:
	var suites: Array = [UNIT_SAVE_CODEC.new(), UNIT_SETTINGS.new(), UNIT_CONTENT.new(), INTEGRATION_SAVE.new(), UNIT_M1_FARM.new()]
	var failures: Array[String] = []
	var count: int = 0
	for suite: RefCounted in suites:
		for result: Dictionary in suite.run():
			count += 1
			if result.get("ok", false):
				print("PASS  %s" % result.get("name", "unnamed"))
			else:
				var line := "FAIL  %s — %s" % [result.get("name", "unnamed"), result.get("message", "no assertion result")]
				print(line)
				failures.append(line)
	print("\nTest summary: %d run, %d failed." % [count, failures.size()])
	quit(0 if failures.is_empty() else 1)
