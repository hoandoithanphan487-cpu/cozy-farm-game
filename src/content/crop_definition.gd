class_name CropDefinition
extends ContentDefinition

@export var seed_item_id: StringName
@export var harvest_item_id: StringName
@export var stage_days: PackedInt32Array = []
@export var valid_seasons: Array[StringName] = []
@export var yield_min: int = 1
@export var yield_max: int = 1
@export var regrow_days: int = 0
@export_range(0, 1) var water_need: int = 1
@export var mature_stage_index: int = 0

