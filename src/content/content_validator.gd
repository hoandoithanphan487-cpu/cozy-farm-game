class_name ContentValidator
extends RefCounted

const ID_PATTERN := "^[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*$"
const VALID_GOSSIP_TRANSITIONS := {
	"offered": ["resolved_relay", "deferred", "investigating"],
	"investigating": ["verified"],
	"verified": ["resolved_corrected"],
}

var _registry: ContentRegistry
var _errors: Array[String] = []


static func is_stable_id(value: String) -> bool:
	var expression := RegEx.new()
	return expression.compile(ID_PATTERN) == OK and expression.search(value) != null


func validate(registry: ContentRegistry) -> Array[String]:
	_registry = registry
	_errors.clear()
	for definition: ContentDefinition in registry.definitions():
		_validate_definition(definition)
	return _errors.duplicate()


func _validate_definition(definition: ContentDefinition) -> void:
	_validate_id_category(definition)
	if definition is ItemDefinition:
		_validate_item(definition as ItemDefinition)
	elif definition is CropDefinition:
		_validate_crop(definition as CropDefinition)
	elif definition is NewGameScenarioDefinition:
		_validate_scenario(definition as NewGameScenarioDefinition)
	elif definition is RecipeDefinition:
		_validate_recipe(definition as RecipeDefinition)
	elif definition is ShopDefinition:
		_validate_shop(definition as ShopDefinition)
	elif definition is DialogueDefinition:
		_validate_dialogue(definition as DialogueDefinition)
	elif definition is ScheduleDefinition:
		_validate_schedule(definition as ScheduleDefinition)
	elif definition is GatherNodeDefinition:
		_validate_gather_node(definition as GatherNodeDefinition)
	elif definition is WatershedContributionDefinition:
		_validate_contribution(definition as WatershedContributionDefinition)
	elif definition is QuestDefinition:
		_validate_quest(definition as QuestDefinition)
	elif definition is NpcDefinition:
		_validate_npc(definition as NpcDefinition)
	elif definition is GossipEventDefinition:
		_validate_gossip_event(definition as GossipEventDefinition)
	elif definition is GossipClaimDefinition:
		_validate_gossip_claim(definition as GossipClaimDefinition)
	elif definition is GossipActionDefinition:
		_validate_gossip_action(definition as GossipActionDefinition)
	elif definition is ConditionGroupDefinition:
		_validate_condition_group(definition as ConditionGroupDefinition)
	elif definition is RelationshipEffectDefinition:
		_validate_relationship_effect(definition as RelationshipEffectDefinition)
	elif definition is WorldLocationDefinition:
		pass
	elif definition is WeatherDefinition:
		pass
	else:
		_error(definition, "resource", "unsupported content definition type")


func _validate_id_category(definition: ContentDefinition) -> void:
	var expected := ""
	if definition is ItemDefinition: expected = "item"
	elif definition is CropDefinition: expected = "crop"
	elif definition is NewGameScenarioDefinition: expected = "scenario"
	elif definition is RecipeDefinition: expected = "recipe"
	elif definition is ShopDefinition: expected = "shop"
	elif definition is DialogueDefinition: expected = "dialogue"
	elif definition is ScheduleDefinition: expected = "schedule"
	elif definition is GatherNodeDefinition: expected = "gather_node"
	elif definition is WeatherDefinition: expected = "weather"
	elif definition is WatershedContributionDefinition: expected = "watershed"
	elif definition is QuestDefinition: expected = "quest"
	elif definition is NpcDefinition: expected = "npc"
	elif definition is GossipEventDefinition: expected = "gossip_event"
	elif definition is GossipClaimDefinition: expected = "gossip_claim"
	elif definition is GossipActionDefinition: expected = "gossip_action"
	elif definition is ConditionGroupDefinition: expected = "condition_group"
	elif definition is RelationshipEffectDefinition: expected = "relationship_effect"
	elif definition is WorldLocationDefinition: expected = "map"
	var parts := String(definition.id).split(".")
	if not expected.is_empty() and (parts.size() != 3 or parts[1] != expected):
		_error(definition, "id", "expected category '%s' for this definition type" % expected)


func _validate_item(item: ItemDefinition) -> void:
	if item.stack_limit < 1 or item.stack_limit > 999:
		_error(item, "stack_limit", "must be between 1 and 999")
	if item.base_sell_price < 0:
		_error(item, "base_sell_price", "must be non-negative")


func _validate_crop(crop: CropDefinition) -> void:
	_expect(crop, "seed_item_id", crop.seed_item_id, ItemDefinition)
	_expect(crop, "harvest_item_id", crop.harvest_item_id, ItemDefinition)
	if crop.yield_max < crop.yield_min:
		_error(crop, "yield_max", "must be greater than or equal to yield_min")
	if crop.yield_min < 1:
		_error(crop, "yield_min", "must be at least 1")
	if crop.mature_stage_index < 0 or crop.mature_stage_index >= crop.stage_days.size():
		_error(crop, "mature_stage_index", "must reference an existing crop stage")


func _validate_scenario(scenario: NewGameScenarioDefinition) -> void:
	if scenario.starting_inventory_capacity < 1:
		_error(scenario, "starting_inventory_capacity", "must be positive")
	var used_slots := 0
	for index: int in scenario.starting_items.size():
		var stack := scenario.starting_items[index]
		var item := _expect(scenario, "starting_items[%d].item_id" % index, stack.item_id, ItemDefinition) as ItemDefinition
		if stack.quantity < 1:
			_error(scenario, "starting_items[%d].quantity" % index, "must be positive")
		elif item != null:
			used_slots += ceili(float(stack.quantity) / float(item.stack_limit))
	if used_slots > scenario.starting_inventory_capacity:
		_error(scenario, "starting_items", "requires %d slots but capacity is %d" % [used_slots, scenario.starting_inventory_capacity])
	var seen_cells := {}
	for index: int in scenario.starting_farm_cells.size():
		var cell := scenario.starting_farm_cells[index]
		var key := "%d,%d" % [cell.coordinates.x, cell.coordinates.y]
		if seen_cells.has(key):
			_error(scenario, "starting_farm_cells[%d].coordinates" % index, "duplicate tutorial cell coordinate %s" % key)
		seen_cells[key] = true
		var crop := _expect(scenario, "starting_farm_cells[%d].crop_id" % index, cell.crop_id, CropDefinition) as CropDefinition
		if crop != null and cell.stage_index != crop.mature_stage_index:
			_error(scenario, "starting_farm_cells[%d].stage_index" % index, "tutorial crop must use mature_stage_index %d" % crop.mature_stage_index)
	for index: int in scenario.starting_npc_spawns.size():
		var spawn := scenario.starting_npc_spawns[index]
		_expect(scenario, "starting_npc_spawns[%d].npc_id" % index, spawn.npc_id, NpcDefinition)
		_expect_map_spawn(scenario, "starting_npc_spawns[%d]" % index, spawn.map_id, spawn.spawn_point_id)
	for index: int in scenario.starting_recipe_ids.size():
		_expect(scenario, "starting_recipe_ids[%d]" % index, scenario.starting_recipe_ids[index], RecipeDefinition)
	for index: int in scenario.guaranteed_gather_node_ids.size():
		_expect(scenario, "guaranteed_gather_node_ids[%d]" % index, scenario.guaranteed_gather_node_ids[index], GatherNodeDefinition)
	for day: int in [1, 2, 3]:
		if not scenario.scripted_weather_by_day.has(day):
			_error(scenario, "scripted_weather_by_day", "must cover PRD game day %d" % day)
		else:
			_expect(scenario, "scripted_weather_by_day[%d]" % day, scenario.scripted_weather_by_day[day], WeatherDefinition)
	if not scenario.scripted_event_by_day.has(2):
		_error(scenario, "scripted_event_by_day", "must schedule the required day-2 community event")
	else:
		_expect(scenario, "scripted_event_by_day[2]", scenario.scripted_event_by_day[2], GossipEventDefinition)
	_validate_guaranteed_canal_materials(scenario)


func _validate_recipe(recipe: RecipeDefinition) -> void:
	for index: int in recipe.ingredients.size():
		var ingredient := recipe.ingredients[index]
		_expect(recipe, "ingredients[%d].item_id" % index, ingredient.item_id, ItemDefinition)
		if ingredient.quantity < 1:
			_error(recipe, "ingredients[%d].quantity" % index, "must be positive")
	_expect(recipe, "output_item_id", recipe.output_item_id, ItemDefinition)
	if recipe.output_quantity < 1:
		_error(recipe, "output_quantity", "must be positive")


func _validate_shop(shop: ShopDefinition) -> void:
	_expect(shop, "merchant_npc_id", shop.merchant_npc_id, NpcDefinition)
	for index: int in shop.listings.size():
		var listing := shop.listings[index]
		_expect(shop, "listings[%d].item_id" % index, listing.item_id, ItemDefinition)
		if listing.unit_price < 0:
			_error(shop, "listings[%d].unit_price" % index, "must be non-negative")


func _validate_dialogue(dialogue: DialogueDefinition) -> void:
	_expect(dialogue, "speaker_npc_id", dialogue.speaker_npc_id, NpcDefinition)
	if not dialogue.next_node_id.is_empty():
		_expect(dialogue, "next_node_id", dialogue.next_node_id, DialogueDefinition)
	for index: int in dialogue.action_ids.size():
		_expect(dialogue, "action_ids[%d]" % index, dialogue.action_ids[index], GossipActionDefinition)


func _validate_schedule(schedule: ScheduleDefinition) -> void:
	_expect(schedule, "npc_id", schedule.npc_id, NpcDefinition)
	var slots := schedule.slots.duplicate()
	slots.sort_custom(func(a: ScheduleSlotDefinition, b: ScheduleSlotDefinition) -> bool: return a.start_minute < b.start_minute)
	var previous_end := -1
	for index: int in slots.size():
		var slot: ScheduleSlotDefinition = slots[index]
		if slot.end_minute <= slot.start_minute:
			_error(schedule, "slots[%d]" % index, "end_minute must be after start_minute")
		if slot.start_minute < previous_end:
			_error(schedule, "slots[%d]" % index, "time period overlaps a previous schedule slot")
		previous_end = maxi(previous_end, slot.end_minute)
		_expect_map_spawn(schedule, "slots[%d]" % index, slot.map_id, slot.spawn_point_id)
	_expect_map_spawn(schedule, "fallback", schedule.fallback_map_id, schedule.fallback_spawn_point_id)


func _validate_gather_node(node: GatherNodeDefinition) -> void:
	_expect_map(node, "map_id", node.map_id)
	for index: int in node.guaranteed_outputs.size():
		var output := node.guaranteed_outputs[index]
		_expect(node, "guaranteed_outputs[%d].item_id" % index, output.item_id, ItemDefinition)
		if output.quantity < 1:
			_error(node, "guaranteed_outputs[%d].quantity" % index, "must be positive")


func _validate_contribution(contribution: WatershedContributionDefinition) -> void:
	if contribution.source_event_id.is_empty():
		_error(contribution, "source_event_id", "must not be empty")
	if contribution.points < 0:
		_error(contribution, "points", "must be non-negative")
	if not contribution.path_role.is_empty() and contribution.path_role != &"place_canal_segment" and contribution.path_role != &"deliver_canal_repair" and contribution.path_role != &"social_bonus":
		_error(contribution, "path_role", "must be place_canal_segment, deliver_canal_repair, or social_bonus")


func _validate_quest(quest: QuestDefinition) -> void:
	for index: int in quest.delivery_item_ids.size():
		_expect(quest, "delivery_item_ids[%d]" % index, quest.delivery_item_ids[index], ItemDefinition)
	if not quest.completion_contribution_id.is_empty():
		_expect(quest, "completion_contribution_id", quest.completion_contribution_id, WatershedContributionDefinition)
	if quest.is_watershed_mainline and quest.min_standing > 0:
		_error(quest, "min_standing", "watershed mainline critical path must not require standing")
	if quest.min_standing > 0:
		if quest.recovery_path_ids.is_empty():
			_error(quest, "recovery_path_ids", "optional standing gate requires an un-gated recovery path")
		for index: int in quest.recovery_path_ids.size():
			var recovery := _expect(quest, "recovery_path_ids[%d]" % index, quest.recovery_path_ids[index], QuestDefinition) as QuestDefinition
			if recovery != null and recovery.min_standing > 0:
				_error(quest, "recovery_path_ids[%d]" % index, "recovery path must not have a standing gate")


func _validate_npc(npc: NpcDefinition) -> void:
	if not npc.dialogue_pool_id.is_empty():
		_expect(npc, "dialogue_pool_id", npc.dialogue_pool_id, DialogueDefinition)
	if not npc.schedule_id.is_empty():
		_expect(npc, "schedule_id", npc.schedule_id, ScheduleDefinition)


func _validate_gossip_event(event: GossipEventDefinition) -> void:
	_expect(event, "claim_id", event.claim_id, GossipClaimDefinition)
	_expect(event, "trigger_npc_id", event.trigger_npc_id, NpcDefinition)
	if event.cooldown_days < 2 or event.cooldown_days > 3:
		_error(event, "cooldown_days", "must be between 2 and 3 days")
	if event.deadline_offset_days < 1 or event.deadline_offset_days > 7:
		_error(event, "deadline_offset_days", "must be between 1 and 7")
	if event.deadline_minute < 0 or event.deadline_minute > 1439:
		_error(event, "deadline_minute", "must be a valid game minute from 0 to 1439")
	for index: int in event.action_ids.size():
		_expect(event, "action_ids[%d]" % index, event.action_ids[index], GossipActionDefinition)


func _validate_gossip_claim(claim: GossipClaimDefinition) -> void:
	_expect(claim, "target_npc_id", claim.target_npc_id, NpcDefinition)
	_expect(claim, "relay_npc_id", claim.relay_npc_id, NpcDefinition)
	_expect(claim, "verification_rule_id", claim.verification_rule_id, ConditionGroupDefinition)


func _validate_gossip_action(action: GossipActionDefinition) -> void:
	if not VALID_GOSSIP_TRANSITIONS.has(String(action.required_event_status)) or not VALID_GOSSIP_TRANSITIONS[String(action.required_event_status)].has(String(action.next_status)):
		_error(action, "next_status", "illegal transition %s -> %s" % [action.required_event_status, action.next_status])
	if not action.fixed_npc_id.is_empty():
		_expect(action, "fixed_npc_id", action.fixed_npc_id, NpcDefinition)
	if action.interaction_selector != &"trigger_npc" and action.interaction_selector != &"fixed_npc":
		_error(action, "interaction_selector", "must be trigger_npc or fixed_npc")
	if action.reward_policy != &"apply_configured" and action.reward_policy != &"watershed_else_relationship":
		_error(action, "reward_policy", "must be apply_configured or watershed_else_relationship")
	if not action.condition_group_id.is_empty():
		_expect(action, "condition_group_id", action.condition_group_id, ConditionGroupDefinition)
	if not action.relationship_effect_id.is_empty():
		_expect(action, "relationship_effect_id", action.relationship_effect_id, RelationshipEffectDefinition)
	if not action.quest_effect_id.is_empty():
		_expect(action, "quest_effect_id", action.quest_effect_id, QuestDefinition)
	if not action.watershed_effect_id.is_empty():
		_expect(action, "watershed_effect_id", action.watershed_effect_id, WatershedContributionDefinition)
	if String(action.id).ends_with(".verify_with_c"):
		var group := _expect(action, "condition_group_id", action.condition_group_id, ConditionGroupDefinition) as ConditionGroupDefinition
		if group != null and group.condition_ids.is_empty():
			_error(action, "condition_group_id", "verify_with_c requires an evidence condition")
	if String(action.id).ends_with(".correct_d") and action.required_event_status != &"verified":
		_error(action, "required_event_status", "correct_d must require verified status")


func _validate_condition_group(group: ConditionGroupDefinition) -> void:
	if group.mode != &"all" and group.mode != &"any":
		_error(group, "mode", "must be all or any")
	if group.condition_ids.is_empty():
		_error(group, "condition_ids", "must not be empty")


func _validate_relationship_effect(effect: RelationshipEffectDefinition) -> void:
	if effect.first_talk_multiplier_bp < 0 or effect.first_talk_multiplier_bp > 20000:
		_error(effect, "first_talk_multiplier_bp", "must be between 0 and 20000 basis points")
	if effect.first_talk_start_offset_days < 0 or effect.first_talk_start_offset_days > 30 or effect.duration_days < 0 or effect.duration_days > 30:
		_error(effect, "duration_days", "start offset and duration must be between 0 and 30 days")
	if effect.stack_policy != &"replace" and effect.stack_policy != &"max" and effect.stack_policy != &"reject":
		_error(effect, "stack_policy", "must be replace, max, or reject")


func _validate_guaranteed_canal_materials(scenario: NewGameScenarioDefinition) -> void:
	var canal_recipe: RecipeDefinition
	for definition: ContentDefinition in _registry.definitions():
		if definition is RecipeDefinition and (definition as RecipeDefinition).is_canal_segment:
			canal_recipe = definition as RecipeDefinition
			break
	if canal_recipe == null:
		return
	var totals: Dictionary[StringName, int] = {}
	for node_id: StringName in scenario.guaranteed_gather_node_ids:
		var node := _registry.get_definition(node_id) as GatherNodeDefinition
		if node == null:
			continue
		for output: GatherOutputDefinition in node.guaranteed_outputs:
			totals[output.item_id] = totals.get(output.item_id, 0) + output.quantity
	for ingredient: RecipeIngredientDefinition in canal_recipe.ingredients:
		if totals.get(ingredient.item_id, 0) < ingredient.quantity:
			_error(scenario, "guaranteed_gather_node_ids", "guaranteed outputs provide %d of %s but canal recipe needs %d" % [totals.get(ingredient.item_id, 0), ingredient.item_id, ingredient.quantity])
	var contributions: Array[WatershedContributionDefinition] = []
	for definition: ContentDefinition in _registry.definitions():
		if definition is WatershedContributionDefinition:
			contributions.append(definition as WatershedContributionDefinition)
	var placement: WatershedContributionDefinition
	var repair: WatershedContributionDefinition
	for contribution: WatershedContributionDefinition in contributions:
		if contribution.path_role == &"place_canal_segment": placement = contribution
		if contribution.path_role == &"deliver_canal_repair": repair = contribution
	if placement == null or repair == null or placement.points != 12 or repair.points != 8 or not placement.one_time or not repair.one_time:
		_error(scenario, "watershed_contributions", "must define one-time place_canal_segment = 12 and deliver_canal_repair = 8 contributions")
		return
	var repair_quest: QuestDefinition
	for definition: ContentDefinition in _registry.definitions():
		if definition is QuestDefinition and (definition as QuestDefinition).completion_contribution_id == repair.id:
			repair_quest = definition as QuestDefinition
			break
	if repair_quest == null:
		_error(scenario, "watershed_contributions", "deliver_canal_repair must be completed by a quest")
	elif not repair_quest.delivery_item_ids.is_empty():
		_error(repair_quest, "delivery_item_ids", "canal repair delivery must not require extra items")
	for definition: ContentDefinition in _registry.definitions():
		if definition is GossipActionDefinition:
			var action := definition as GossipActionDefinition
			if action.watershed_effect_id == placement.id or action.watershed_effect_id == repair.id:
				_error(action, "watershed_effect_id", "social action cannot be required for the independent 12+8 watershed path")


func _expect(owner: ContentDefinition, field: String, id: StringName, expected_type: Variant) -> ContentDefinition:
	if id.is_empty():
		_error(owner, field, "reference ID must not be empty")
		return null
	var actual := _registry.get_definition(id)
	if actual == null:
		_error(owner, field, "unknown content ID: %s" % id)
		return null
	if not is_instance_of(actual, expected_type):
		_error(owner, field, "reference type does not match ID %s (actual %s)" % [id, actual.get_class()])
		return null
	return actual


func _expect_map(owner: ContentDefinition, field: String, map_id: StringName) -> WorldLocationDefinition:
	return _expect(owner, field, map_id, WorldLocationDefinition) as WorldLocationDefinition


func _expect_map_spawn(owner: ContentDefinition, field: String, map_id: StringName, spawn_id: StringName) -> void:
	var map := _expect_map(owner, "%s.map_id" % field, map_id)
	if map != null and not map.spawn_point_ids.has(spawn_id):
		_error(owner, "%s.spawn_point_id" % field, "unknown spawn point %s on map %s" % [spawn_id, map_id])


func _error(owner: ContentDefinition, field: String, reason: String) -> void:
	_errors.append("%s | %s | %s" % [_registry.path_for(owner.id), field, reason])
