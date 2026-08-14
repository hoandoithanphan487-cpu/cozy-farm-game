class_name ContentRegistry
extends RefCounted

## Read-only index of authored resources. Runtime state belongs in GameSession, never here.
var _definitions_by_id: Dictionary[StringName, ContentDefinition] = {}
var _paths_by_id: Dictionary[StringName, String] = {}
var _validation_errors: Array[String] = []


func load_and_validate(root_path: String = "res://content") -> bool:
	_definitions_by_id.clear()
	_paths_by_id.clear()
	_validation_errors.clear()
	for path: String in _find_tres_paths(root_path):
		var resource: Resource = ResourceLoader.load(path)
		if resource == null:
			_add_error(path, "resource", "failed to load .tres")
			continue
		if not resource is ContentDefinition:
			_add_error(path, "resource", "expected a ContentDefinition resource")
			continue
		var definition := resource as ContentDefinition
		_register(definition, path)
	_validation_errors.append_array(ContentValidator.new().validate(self))
	return _validation_errors.is_empty()


func has(id: StringName) -> bool:
	return _definitions_by_id.has(id)


func get_definition(id: StringName) -> ContentDefinition:
	return _definitions_by_id.get(id) as ContentDefinition


func get_item(id: StringName) -> ItemDefinition:
	return get_definition(id) as ItemDefinition


func get_crop(id: StringName) -> CropDefinition:
	return get_definition(id) as CropDefinition


func get_scenario(id: StringName) -> NewGameScenarioDefinition:
	return get_definition(id) as NewGameScenarioDefinition


func get_recipe(id: StringName) -> RecipeDefinition:
	return get_definition(id) as RecipeDefinition


func get_npc(id: StringName) -> NpcDefinition:
	return get_definition(id) as NpcDefinition


func definitions() -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	for definition: ContentDefinition in _definitions_by_id.values():
		result.append(definition)
	return result


func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func path_for(id: StringName) -> String:
	return _paths_by_id.get(id, "<unregistered>") as String


func add_validation_error(path: String, field: String, reason: String) -> void:
	_add_error(path, field, reason)


func _register(definition: ContentDefinition, path: String) -> void:
	var text_id := String(definition.id)
	if text_id.is_empty():
		_add_error(path, "id", "stable ID must not be empty")
		return
	if not ContentValidator.is_stable_id(text_id):
		_add_error(path, "id", "invalid stable ID '%s'; expected namespace.category.name" % text_id)
		return
	if _definitions_by_id.has(definition.id):
		_add_error(path, "id", "duplicate or cross-type ID '%s'; already declared at %s" % [text_id, path_for(definition.id)])
		return
	_definitions_by_id[definition.id] = definition
	_paths_by_id[definition.id] = path


func _add_error(path: String, field: String, reason: String) -> void:
	_validation_errors.append("%s | %s | %s" % [path, field, reason])


func _find_tres_paths(root_path: String) -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		_add_error(root_path, "directory", "content root cannot be opened")
		return paths
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not name.begins_with("."):
			var child_path := root_path.path_join(name)
			if directory.current_is_dir():
				paths.append_array(_find_tres_paths(child_path))
			elif name.ends_with(".tres"):
				paths.append(child_path)
		name = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths
