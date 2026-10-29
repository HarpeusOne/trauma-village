extends StaticBody3D
class_name ItemPickup

## Interactable world item. Adds one item to the player's six-slot inventory.
## Picked items stay in the scene (hidden) so save/load can restore their state.

const PS2_MATERIAL = preload("res://src/shaders/ps2_material.tres")

@export var item_id := "bandage"
@export var item_name := "Bandaż"
@export var quantity := 1
@export var tint := Color(0.72, 0.66, 0.42)
@export var spin_speed := 1.6

var picked := false

var _base_y := 0.0
var _time := 0.0

@onready var item_mesh: MeshInstance3D = $Mesh
@onready var item_collision: CollisionShape3D = $Collision


func _ready() -> void:
	add_to_group("interactable")
	_base_y = position.y
	if item_mesh != null:
		var mat = PS2_MATERIAL.duplicate()
		mat.set_shader_parameter("tint", tint)
		mat.set_shader_parameter("fog_start", 30.0)
		item_mesh.material_override = mat


func _process(delta: float) -> void:
	if picked:
		return
	_time += delta
	rotation.y += spin_speed * delta
	position.y = _base_y + sin(_time * 2.2) * 0.08


func get_prompt() -> String:
	return "" if picked else "Podnieś: %s" % item_name


func interact(actor: Node) -> void:
	if picked or actor == null or not actor.has_method("add_item"):
		return
	if actor.add_item(item_id, item_name, quantity):
		_set_picked(true)


func _set_picked(value: bool) -> void:
	picked = value
	visible = not picked
	if item_collision != null:
		item_collision.set_deferred("disabled", picked)


func get_save_data() -> Dictionary:
	return {"name": name, "picked": picked}


func apply_save_data(data: Dictionary) -> void:
	_set_picked(bool(data.get("picked", false)))
