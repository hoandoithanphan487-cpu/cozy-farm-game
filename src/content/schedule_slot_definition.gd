class_name ScheduleSlotDefinition
extends Resource

@export_range(0, 1439) var start_minute: int = 0
@export_range(1, 1440) var end_minute: int = 1
@export var map_id: StringName
@export var spawn_point_id: StringName

