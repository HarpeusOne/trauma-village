extends Node
class_name Inventory

## Six-slot inventory. Each slot is either null or {id, name, quantity}.

const MAX_SLOTS := 6

signal changed

var slots: Array = []


func _init() -> void:
	slots.resize(MAX_SLOTS)


func add_item(item_id: String, display_name: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	for slot in slots:
		if slot != null and slot.get("id", "") == item_id:
			slot["quantity"] = int(slot.get("quantity", 0)) + quantity
			changed.emit()
			return true
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = {"id": item_id, "name": display_name, "quantity": quantity}
			changed.emit()
			return true
	return false


func remove_item(item_id: String, quantity: int = 1) -> bool:
	for i in range(slots.size()):
		var slot = slots[i]
		if slot == null or slot.get("id", "") != item_id:
			continue
		var left: int = int(slot.get("quantity", 0)) - quantity
		if left > 0:
			slot["quantity"] = left
		else:
			slots[i] = null
		changed.emit()
		return true
	return false


func has_item(item_id: String) -> bool:
	for slot in slots:
		if slot != null and slot.get("id", "") == item_id:
			return true
	return false


func used_slots() -> int:
	var count := 0
	for slot in slots:
		if slot != null:
			count += 1
	return count


func is_full() -> bool:
	return used_slots() >= MAX_SLOTS


func display_text() -> String:
	var lines: PackedStringArray = []
	for i in range(slots.size()):
		var slot = slots[i]
		if slot == null:
			lines.append("%d. --" % (i + 1))
		else:
			lines.append("%d. %s x%d" % [i + 1, String(slot.get("name", slot.get("id", "?"))), int(slot.get("quantity", 1))])
	return "\n".join(lines)


func to_dict() -> Array:
	return slots.duplicate(true)


func apply_dict(data: Array) -> void:
	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = null
	for i in range(mini(data.size(), MAX_SLOTS)):
		var entry = data[i]
		if typeof(entry) == TYPE_DICTIONARY and entry.has("id"):
			slots[i] = {
				"id": String(entry.get("id", "")),
				"name": String(entry.get("name", entry.get("id", ""))),
				"quantity": maxi(1, int(entry.get("quantity", 1))),
			}
	changed.emit()
