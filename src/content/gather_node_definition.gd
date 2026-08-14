class_name GatherNodeDefinition
extends ContentDefinition

@export var map_id: StringName
@export var coordinates: Vector2i
@export var required_tool_tag: StringName
@export var guaranteed_outputs: Array[GatherOutputDefinition] = []
@export var refresh_days: int = 0
@export var one_time: bool = false
