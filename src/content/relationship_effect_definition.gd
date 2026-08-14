class_name RelationshipEffectDefinition
extends ContentDefinition

@export var target_selector: StringName
@export var zero_growth_today: bool = false
@export var first_talk_multiplier_bp: int = 10000
@export var first_talk_start_offset_days: int = 0
@export var duration_days: int = 0
@export var flat_bonus_subpoints: int = 0
@export var stack_policy: StringName = &"replace"
