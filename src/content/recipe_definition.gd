class_name RecipeDefinition
extends ContentDefinition

@export var ingredients: Array[RecipeIngredientDefinition] = []
@export var output_item_id: StringName
@export var output_quantity: int = 1
@export var workstation_tag: StringName
@export var is_canal_segment: bool = false
