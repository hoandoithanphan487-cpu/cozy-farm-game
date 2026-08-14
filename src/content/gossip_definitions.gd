class_name GossipEventDefinition
extends ContentDefinition

@export var claim_id: StringName
@export var trigger_npc_id: StringName
@export var cooldown_days: int = 2
@export var deadline_offset_days: int = 1
@export_range(0, 1439) var deadline_minute: int = 1410
@export var prerequisite_ids: Array[StringName] = []
@export var action_ids: Array[StringName] = []

