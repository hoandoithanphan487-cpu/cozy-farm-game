class_name ItemDefinition
extends ContentDefinition

@export var name_key: StringName
@export var category: StringName
@export_range(1, 999) var stack_limit: int = 1
@export_range(0, 2147483647) var base_sell_price: int = 0
@export var tags: Array[StringName] = []

