extends StaticBody3D
class_name Door

## Interactable hinged door. Rotates around its local origin (hinge at x=0).

const PS2_MATERIAL = preload("res://src/shaders/ps2_material.tres")

@export var open_angle_deg := 95.0
@export var open_time := 0.45
@export var tint := Color(0.34, 0.25, 0.17)

var is_open := false
var _busy := false
var _tween: Tween = null

@onready var panel_mesh: MeshInstance3D = $Panel
@onready var panel_collision: CollisionShape3D = $PanelCollision


func _ready() -> void:
	add_to_group("interactable")
	if panel_mesh != null:
		var mat = PS2_MATERIAL.duplicate()
		mat.set_shader_parameter("tint", tint)
		panel_mesh.material_override = mat


func get_prompt() -> String:
	if _busy:
		return ""
	return "Zamknij drzwi" if is_open else "Otwórz drzwi"


func interact(_actor: Node) -> void:
	if _busy:
		return
	is_open = not is_open
	_busy = true
	var target_yaw := deg_to_rad(-open_angle_deg) if is_open else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "rotation:y", target_yaw, open_time)
	_tween.tween_callback(_on_tween_finished)


func _on_tween_finished() -> void:
	_busy = false


func get_save_data() -> Dictionary:
	return {"name": name, "open": is_open}


func apply_save_data(data: Dictionary) -> void:
	is_open = bool(data.get("open", false))
	rotation.y = deg_to_rad(-open_angle_deg) if is_open else 0.0
