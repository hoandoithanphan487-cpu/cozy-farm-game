class_name NewGameScenarioDefinition
extends ContentDefinition

@export var start_day: int = 1
@export var start_minute: int = 390
@export var starting_currency: int = 0
@export var starting_inventory_capacity: int = 16
@export var starting_items: Array[InitialItemStack] = []
@export var starting_farm_cells: Array[InitialFarmCell] = []
@export var starting_npc_spawns: Array[InitialNpcSpawn] = []
@export var starting_recipe_ids: Array[StringName] = []
@export var guaranteed_gather_node_ids: Array[StringName] = []
@export var scripted_weather_by_day: Dictionary[int, StringName] = {}
@export var scripted_event_by_day: Dictionary[int, StringName] = {}
