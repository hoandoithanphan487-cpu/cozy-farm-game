## Atomic inventory helpers. UI and scenes must request changes through this boundary.
class_name InventoryService
extends RefCounted


static func try_add(inventory: Array, capacity: int, item_id: StringName, quantity: int, stack_limit: int, quality: StringName = &"normal") -> Dictionary:
	if quantity < 1 or capacity < 1 or stack_limit < 1:
		return {"ok": false, "reason": "背包变更参数无效。"}
	var next: Array = inventory.duplicate(true)
	var remaining := quantity
	for index: int in next.size():
		var stack: Dictionary = next[index]
		if StringName(stack.get("item_id", "")) != item_id or StringName(stack.get("quality", "normal")) != quality:
			continue
		var free_space := stack_limit - int(stack.get("quantity", 0))
		if free_space <= 0:
			continue
		var moved := mini(free_space, remaining)
		stack["quantity"] = int(stack.get("quantity", 0)) + moved
		next[index] = stack
		remaining -= moved
		if remaining == 0:
			return {"ok": true, "inventory": next}
	while remaining > 0 and next.size() < capacity:
		var moved := mini(stack_limit, remaining)
		next.append({"item_id": item_id, "quantity": moved, "quality": quality})
		remaining -= moved
	if remaining > 0:
		return {"ok": false, "reason": "背包已满，物品留在原处。"}
	return {"ok": true, "inventory": next}


static func try_remove(inventory: Array, item_id: StringName, quantity: int, quality: StringName = &"normal") -> Dictionary:
	if quantity < 1:
		return {"ok": false, "reason": "移除数量必须为正数。"}
	var available := 0
	for stack: Dictionary in inventory:
		if StringName(stack.get("item_id", "")) == item_id and StringName(stack.get("quality", "normal")) == quality:
			available += int(stack.get("quantity", 0))
	if available < quantity:
		return {"ok": false, "reason": "所需物品不足。"}
	var next: Array = []
	var remaining := quantity
	for source: Dictionary in inventory:
		var stack: Dictionary = source.duplicate(true)
		if remaining > 0 and StringName(stack.get("item_id", "")) == item_id and StringName(stack.get("quality", "normal")) == quality:
			var removed := mini(int(stack.get("quantity", 0)), remaining)
			stack["quantity"] = int(stack.get("quantity", 0)) - removed
			remaining -= removed
		if int(stack.get("quantity", 0)) > 0:
			next.append(stack)
	return {"ok": true, "inventory": next}


static func count(inventory: Array, item_id: StringName, quality: StringName = &"normal") -> int:
	var total := 0
	for stack: Dictionary in inventory:
		if StringName(stack.get("item_id", "")) == item_id and StringName(stack.get("quality", "normal")) == quality:
			total += int(stack.get("quantity", 0))
	return total
