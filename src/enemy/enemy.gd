extends CharacterBody3D
class_name Enemy

## One enemy type, three variants. Waypoint patrol + vision/hearing + chase +
## melee attack + stagger + death. No NavMesh; movement is direct with raycasts.

signal died(enemy)

enum State { PATROL, CHASE, ATTACK, STAGGER, DEAD }

const PS2_MATERIAL = preload("res://src/shaders/ps2_material.tres")

@export_enum("walker", "stalker", "brute") var variant := "walker"
@export var patrol_speed := 1.2
@export var chase_speed := 2.4
@export var attack_damage := 10.0
@export var max_health := 60.0
@export var attack_range := 1.9
@export var attack_cooldown_time := 1.25
@export var vision_range := 15.0
@export var vision_angle_deg := 110.0
@export var hearing_range := 10.0
@export var gravity := 24.0

var state: State = State.PATROL
var health := 60.0
var waypoints: Array[Vector3] = []

var _waypoint_index := 0
var _player: Node3D = null
var _attack_cooldown := 0.0
var _stagger_timer := 0.0
var _lost_timer := 0.0
var _last_known := Vector3.ZERO
var _configured := false

@onready var body_mesh: MeshInstance3D = $Body
@onready var collision: CollisionShape3D = $Collision


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_configure_variant()
	_find_player()


func _configure_variant() -> void:
	if _configured:
		return
	_configured = true
	var tint := Color(0.36, 0.33, 0.28)
	match variant:
		"stalker":
			max_health = 40.0
			chase_speed = 3.7
			patrol_speed = 1.6
			attack_damage = 8.0
			vision_range = 19.0
			hearing_range = 13.0
			tint = Color(0.16, 0.15, 0.14)
			scale = Vector3(0.92, 1.05, 0.92)
		"brute":
			max_health = 150.0
			chase_speed = 1.7
			patrol_speed = 0.9
			attack_damage = 24.0
			attack_range = 2.3
			vision_range = 13.0
			hearing_range = 8.0
			tint = Color(0.34, 0.16, 0.13)
			scale = Vector3(1.3, 1.3, 1.3)
		_:
			variant = "walker"
	health = max_health
	_apply_material(tint)


func _apply_material(tint: Color) -> void:
	if body_mesh == null:
		return
	var mat = PS2_MATERIAL.duplicate()
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("fog_start", 7.0)
	body_mesh.material_override = mat


func _find_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_find_player()
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.2

	match state:
		State.STAGGER:
			_update_stagger(delta)
		_:
			_update_senses(delta)
			match state:
				State.ATTACK:
					_update_attack(delta)
				State.CHASE:
					_update_chase(delta)
				_:
					_update_patrol(delta)

	move_and_slide()


func _update_senses(delta: float) -> void:
	if _player == null or bool(_player.get("dead")):
		if state != State.PATROL:
			state = State.PATROL
		return

	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	var can_see := _can_see_player(distance)
	var can_hear := _can_hear_player(distance)

	if can_see or can_hear:
		_last_known = _player.global_position
		_lost_timer = 2.5
		if can_see and distance <= attack_range:
			state = State.ATTACK
		else:
			state = State.CHASE
	elif _lost_timer > 0.0:
		_lost_timer -= delta
		state = State.CHASE
	else:
		state = State.PATROL


func _can_see_player(distance: float) -> bool:
	if distance > vision_range:
		return false
	var forward := -global_transform.basis.z
	var to_player := (_player.global_position - global_position)
	to_player.y = 0.0
	if to_player.length_squared() < 0.001:
		return true
	to_player = to_player.normalized()
	var cone := cos(deg_to_rad(vision_angle_deg * 0.5))
	if forward.dot(to_player) < cone:
		return false
	return _has_line_of_sight()


func _can_hear_player(distance: float) -> bool:
	if _player == null:
		return false
	if distance <= hearing_range * 0.45:
		return true
	var sprinting := bool(_player.get("is_sprinting"))
	var shot_recently := Time.get_ticks_msec() - int(_player.get("last_shot_ms")) < 1800
	return distance <= hearing_range and (sprinting or shot_recently)


func _has_line_of_sight() -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector3.UP * 1.35
	var to := _player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit.get("collider") == _player


func _update_patrol(delta: float) -> void:
	if waypoints.is_empty():
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		return
	var target := waypoints[_waypoint_index]
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.9:
		_waypoint_index = (_waypoint_index + 1) % waypoints.size()
		return
	_move_towards(to_target.normalized(), patrol_speed, delta)


func _update_chase(delta: float) -> void:
	var target := _last_known
	if _player != null and _lost_timer > 0.0:
		target = _player.global_position
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() <= attack_range and _lost_timer > 0.0:
		state = State.ATTACK
		return
	_move_towards(to_target.normalized(), chase_speed, delta)


func _update_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	if _player == null:
		state = State.PATROL
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > attack_range * 1.15:
		state = State.CHASE
		return
	if to_player.length_squared() > 0.001:
		_face_direction(to_player.normalized(), delta)
	if _attack_cooldown <= 0.0 and _has_line_of_sight():
		_attack_cooldown = attack_cooldown_time
		if _player.has_method("take_damage"):
			_player.take_damage(attack_damage, to_player.normalized())


func _update_stagger(delta: float) -> void:
	_stagger_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	if _stagger_timer <= 0.0:
		state = State.CHASE if _player != null else State.PATROL


func _move_towards(direction: Vector3, speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, direction.x * speed, 10.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 10.0 * delta)
	_face_direction(direction, delta)


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 8.0, 0.0, 1.0))


func take_damage(amount: float, hit_dir: Vector3 = Vector3.ZERO) -> void:
	if state == State.DEAD:
		return
	health -= amount
	if health <= 0.0:
		_die()
		return
	state = State.STAGGER
	_stagger_timer = 0.32
	if hit_dir.length_squared() > 0.001:
		velocity = hit_dir.normalized() * 3.5


func _die() -> void:
	state = State.DEAD
	health = 0.0
	velocity = Vector3.ZERO
	if collision != null:
		collision.set_deferred("disabled", true)
	if body_mesh != null:
		body_mesh.rotation_degrees = Vector3(-85.0, 0.0, 0.0)
		body_mesh.position.y = 0.25
	died.emit(self)


func get_save_data() -> Dictionary:
	return {
		"name": name,
		"variant": variant,
		"position": [global_position.x, global_position.y, global_position.z],
		"health": health,
		"state": int(state),
		"waypoint_index": _waypoint_index,
	}


func apply_save_data(data: Dictionary) -> void:
	var pos = data.get("position", [global_position.x, global_position.y, global_position.z])
	if typeof(pos) == TYPE_ARRAY and pos.size() >= 3:
		global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	health = clampf(float(data.get("health", max_health)), 0.0, max_health)
	_waypoint_index = int(data.get("waypoint_index", 0))
	var saved_state := int(data.get("state", State.PATROL))
	if saved_state == int(State.DEAD) or health <= 0.0:
		_die()
	elif saved_state == int(State.STAGGER):
		state = State.PATROL
	else:
		state = saved_state
