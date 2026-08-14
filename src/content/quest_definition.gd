class_name QuestDefinition
extends ContentDefinition

@export var text_key: StringName
@export var prerequisite_ids: Array[StringName] = []
@export var completion_event_id: StringName
@export var one_time: bool = true
@export var min_standing: int = 0
@export var is_watershed_mainline: bool = false
@export var recovery_path_ids: Array[StringName] = []
@export var delivery_item_ids: Array[StringName] = []
@export var completion_contribution_id: StringName
