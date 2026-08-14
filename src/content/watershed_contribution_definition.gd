class_name WatershedContributionDefinition
extends ContentDefinition

@export var source_event_id: StringName
@export var points: int = 0
@export var prerequisite_ids: Array[StringName] = []
@export var one_time: bool = true
@export var path_role: StringName
