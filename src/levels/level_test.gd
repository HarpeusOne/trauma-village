extends Node3D
class_name TestLevel

## Minimal test level built from primitives. No NavMesh, no external assets.

const PS2_MATERIAL = preload("res://src/shaders/ps2_material.tres")
const EnemyScene = preload("res://scenes/enemy.tscn")
const DoorScene = preload("res://scenes/door.tscn")
const ItemScene = preload("res://scenes/item_pickup.tscn")

var _waypoint_markers: Array[Node3D] = []


func _ready() -> void:
	_build_geometry()
	_build_waypoints()
	_build_doors()
	_build_items()
	_build_enemies()


func _build_geometry() -> void:
	_add_box("Ground", Vector3(44, 1, 44), Vector3(0, -0.5, 0), Color(0.12, 0.13, 0.11))
	_add_box("WallNorth", Vector3(44, 5, 1), Vector3(0, 2.5, -22), Color(0.17, 0.18, 0.16))
	_add_box("WallSouth", Vector3(44, 5, 1), Vector3(0, 2.5, 22), Color(0.17, 0.18, 0.16))
	_add_box("WallEast", Vector3(1, 5, 44), Vector3(22, 2.5, 0), Color(0.17, 0.18, 0.16))
	_add_box("WallWest", Vector3(1, 5, 44), Vector3(-22, 2.5, 0), Color(0.17, 0.18, 0.16))

	# Small farmhouse shell with a door opening at z = -8.
	_add_box("HouseBack", Vector3(16, 5, 0.6), Vector3(0, 2.5, -18), Color(0.28, 0.24, 0.19))
	_add_box("HouseLeft", Vector3(0.6, 5, 10), Vector3(-8, 2.5, -13), Color(0.28, 0.24, 0.19))
	_add_box("HouseRight", Vector3(0.6, 5, 10), Vector3(8, 2.5, -13), Color(0.28, 0.24, 0.19))
	_add_box("HouseFrontLeft", Vector3(6.4, 5, 0.6), Vector3(-4.8, 2.5, -8), Color(0.28, 0.24, 0.19))
	_add_box("HouseFrontRight", Vector3(6.4, 5, 0.6), Vector3(4.8, 2.5, -8), Color(0.28, 0.24, 0.19))
	_add_box("HouseRoof", Vector3(17, 0.5, 11), Vector3(0, 5.1, -13), Color(0.14, 0.11, 0.09))

	# Props / cover.
	_add_box("CrateA", Vector3(1.2, 1.2, 1.2), Vector3(4.5, 0.6, 3.5), Color(0.33, 0.26, 0.17))
	_add_box("CrateB", Vector3(1.2, 1.2, 1.2), Vector3(5.4, 1.8, 3.5), Color(0.3, 0.23, 0.15))
	_add_box("CrateC", Vector3(1.2, 1.2, 1.2), Vector3(-6.5, 0.6, 1.5), Color(0.33, 0.26, 0.17))
	_add_box("Well", Vector3(2.2, 0.9, 2.2), Vector3(-10, 0.45, -6), Color(0.24, 0.24, 0.23))
	_add_box("FenceA", Vector3(0.25, 1.4, 8), Vector3(12, 0.7, 4), Color(0.26, 0.21, 0.15))
	_add_box("FenceB", Vector3(8, 1.4, 0.25), Vector3(16, 0.7, 8), Color(0.26, 0.21, 0.15))


func _build_waypoints() -> void:
	var points := [
		Vector3(-12, 0, -2),
		Vector3(-8, 0, -12),
		Vector3(2, 0, -14),
		Vector3(10, 0, -6),
		Vector3(12, 0, 4),
		Vector3(0, 0, 8),
		Vector3(-6, 0, 6),
	]
	for i in range(points.size()):
		var marker := Node3D.new()
		marker.name = "Waypoint%d" % i
		marker.position = points[i]
		marker.add_to_group("enemy_waypoint")
		add_child(marker)
		_waypoint_markers.append(marker)
		_add_box("WaypointPost%d" % i, Vector3(0.18, 0.9, 0.18), points[i] + Vector3(0, 0.45, 0), Color(0.4, 0.35, 0.2))


func _build_doors() -> void:
	var door_a = DoorScene.instantiate()
	door_a.name = "FrontDoor"
	door_a.position = Vector3(-0.9, 0, -8)
	add_child(door_a)

	var door_b = DoorScene.instantiate()
	door_b.name = "SideDoor"
	door_b.position = Vector3(8, 0, -10)
	door_b.rotation.y = deg_to_rad(90.0)
	add_child(door_b)


func _build_items() -> void:
	_add_item("BandagePickup", "bandage", "Bandaż", Vector3(3.2, 0.35, 1.8), Color(0.78, 0.72, 0.55))
	_add_item("AmmoPickup", "ammo_shells", "Naboje do strzelby", Vector3(-4.2, 0.35, -1.5), Color(0.55, 0.42, 0.2), 6)
	_add_item("KeyPickup", "house_key", "Klucz do domu", Vector3(0, 0.35, -14), Color(0.75, 0.68, 0.25))


func _add_item(node_name: String, item_id: String, display_name: String, pos: Vector3, tint: Color, quantity: int = 1) -> void:
	var item = ItemScene.instantiate()
	item.name = node_name
	item.item_id = item_id
	item.item_name = display_name
	item.tint = tint
	item.quantity = quantity
	item.position = pos
	add_child(item)


func _build_enemies() -> void:
	_spawn_enemy("walker", "EnemyWalker", Vector3(-11, 0, -3), [
		Vector3(-12, 0, -2), Vector3(-8, 0, -12), Vector3(-4, 0, -5),
	])
	_spawn_enemy("stalker", "EnemyStalker", Vector3(11, 0, -14), [
		Vector3(10, 0, -6), Vector3(12, 0, 4), Vector3(6, 0, 8),
	])
	_spawn_enemy("brute", "EnemyBrute", Vector3(0, 0, -15), [
		Vector3(2, 0, -14), Vector3(-4, 0, -13), Vector3(0, 0, -10),
	])


func _spawn_enemy(variant: String, node_name: String, pos: Vector3, points: Array) -> void:
	var enemy = EnemyScene.instantiate()
	enemy.name = node_name
	enemy.variant = variant
	var typed_points: Array[Vector3] = []
	for p in points:
		typed_points.append(p)
	enemy.waypoints = typed_points
	enemy.position = pos
	add_child(enemy)


func _add_box(node_name: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat: ShaderMaterial = PS2_MATERIAL.duplicate()
	mat.set_shader_parameter("tint", color)
	mesh.material_override = mat
	body.add_child(mesh)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	add_child(body)
	return body
