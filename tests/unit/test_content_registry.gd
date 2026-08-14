extends RefCounted

const CONTENT_REGISTRY := preload("res://src/content/content_registry.gd")
const ITEM_DEFINITION := preload("res://src/content/item_definition.gd")


func run() -> Array[Dictionary]:
	return [
		_test_valid_tres_fixture_loads(),
		_test_missing_reference_fails_with_path_and_field(),
		_test_duplicate_id_fails(),
		_test_invalid_item_value_fails(),
		_test_invalid_scenario_fails(),
		_test_invalid_gossip_action_fails(),
	]


func _test_valid_tres_fixture_loads() -> Dictionary:
	var resource: Resource = ResourceLoader.load("res://tests/fixtures/content_valid/items/seed.tres")
	var registry: ContentRegistry = CONTENT_REGISTRY.new()
	var passed: bool = resource != null and resource.get_script() == ITEM_DEFINITION and registry.load_and_validate("res://tests/fixtures/content_valid") and registry.get_item(&"brookseed.item.mist_radish_seed") != null
	return _result("content registry loads a minimal .tres fixture", passed, "expected fixture item to load and index")


func _test_missing_reference_fails_with_path_and_field() -> Dictionary:
	var registry: ContentRegistry = CONTENT_REGISTRY.new()
	registry.load_and_validate("res://tests/fixtures/content_missing_reference")
	return _result("content registry reports missing references", _contains(registry.validation_errors(), "crops/broken_crop.tres", "seed_item_id", "unknown content ID"), str(registry.validation_errors()))


func _test_duplicate_id_fails() -> Dictionary:
	var registry: ContentRegistry = CONTENT_REGISTRY.new()
	registry.load_and_validate("res://tests/fixtures/content_duplicate_id")
	return _result("content registry rejects duplicate IDs", _contains(registry.validation_errors(), "duplicate or cross-type ID"), str(registry.validation_errors()))


func _test_invalid_item_value_fails() -> Dictionary:
	var registry: ContentRegistry = CONTENT_REGISTRY.new()
	registry.load_and_validate("res://tests/fixtures/content_invalid_item")
	return _result("content validator rejects illegal item values", _contains(registry.validation_errors(), "stack_limit", "between 1 and 999"), str(registry.validation_errors()))


func _test_invalid_scenario_fails() -> Dictionary:
	var registry: ContentRegistry = CONTENT_REGISTRY.new()
	registry.load_and_validate("res://tests/fixtures/content_invalid_scenario")
	return _result("content validator rejects invalid scenarios", _contains(registry.validation_errors(), "scripted_weather_by_day", "PRD game day"), str(registry.validation_errors()))


func _test_invalid_gossip_action_fails() -> Dictionary:
	var registry: ContentRegistry = CONTENT_REGISTRY.new()
	registry.load_and_validate("res://tests/fixtures/content_invalid_gossip")
	return _result("content validator rejects illegal gossip actions", _contains(registry.validation_errors(), "next_status", "illegal transition"), str(registry.validation_errors()))


func _contains(errors: Array[String], required_a: String, required_b: String = "", required_c: String = "") -> bool:
	var joined := "\n".join(errors)
	return joined.contains(required_a) and (required_b.is_empty() or joined.contains(required_b)) and (required_c.is_empty() or joined.contains(required_c))


func _result(name: String, ok: bool, message: String) -> Dictionary:
	return {"name": name, "ok": ok, "message": message}
