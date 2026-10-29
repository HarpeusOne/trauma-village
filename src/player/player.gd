extends CharacterBody3D
class_name Player

## Over-the-shoulder player controller: movement, sprint, aim, hitscan shooting,
## reload, interaction, six-slot inventory and versioned save data.

signal health_changed(current: float, maximum: float)
signal ammo_changed(weapon_name: String, ammo: int, reserve: int)
signal prompt_changed(text: String)
signal message_shown(text: String)
signal died

const WeaponDataScript = preload("res://src/systems/weapon.gd")
const InventoryScript = preload("res://src/systems/inventory.gd")
const PS2_MATERIAL = preload("res://src/shaders/ps2_material.tres")

@export var walk_speed := 4.2
@export var sprint_speed := 6.8
@export var aim_speed := 2.1
@export var acceleration := 12.0
@export var gravity := 24.0
@export var mouse_sensitivity := 0.0024
@export var pad_look_speed := 2.4
@export var max_health := 100.0
@export var camera_height := 1.55
@export var shoulder_offset := Vector3(0.55, 0.12, 0.0)
@export var hip_spring_length := 2.8
@export var aim_spring_length := 1.55
@export var hip_fov := 76.0
@export var aim_fov := 52.0

@onready var body_mesh: MeshInstance3D = $Body
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var laser: MeshInstance3D = $CameraPivot/SpringArm3D/Camera3D/Laser
@onready var interact_ray: RayCast3D = $InteractRay

var health := 100.0
var inventory: Node
var weapons: Array = []
var current_weapon := 0
var is_aiming := false
var is_sprinting := false
var current_prompt := ""
var last_message := ""
var message_time_left := 0.0
var last_shot_ms := -10000
var dead := false

var _yaw := 0.0
var _pitch := -0.08
var _fire_cooldown := 0.0
var _reload_timer := 0.0
var _interact_target: Object = null
var _last_hud_weapon := -1


func _ready() -> void:
	add_to_group("player")
	health = max_health
	inventory = InventoryScript.new()
	inventory.name = "Inventory"
	add_child(inventory)
	_build_weapons()
	current_weapon = 0
	camera_pivot.position.y = camera_height
	spring_arm.position = shoulder_offset
	spring_arm.spring_length = hip_spring_length
	camera.fov = hip_fov
	_pitch = spring_arm.rotation.x
	_yaw = rotation.y
	laser.visible = false
	if body_mesh != null:
		var mat = PS2_MATERIAL.duplicate()
		mat.set_shader_parameter("tint", Color(0.2, 0.23, 0.19))
		body_mesh.material_override = mat
	_emit_weapon_hud()


func _build_weapons() -> void:
	var pistol = WeaponDataScript.new()
	pistol.id = "pistol"
	pistol.display_name = "Pistolet"
	pistol.damage = 26.0
	pistol.pellets = 1
	pistol.spread_deg = 0.6
	pistol.mag_size = 8
	pistol.fire_interval = 0.32
	pistol.reload_time = 1.2
	pistol.range_m = 55.0
	pistol.ammo = 8
	pistol.reserve = 40

	var shotgun = WeaponDataScript.new()
	shotgun.id = "shotgun"
	shotgun.display_name = "Strzelba"
	shotgun.damage = 11.0
	shotgun.pellets = 7
	shotgun.spread_deg = 5.5
	shotgun.mag_size = 6
	shotgun.fire_interval = 0.85
	shotgun.reload_time = 1.9
	shotgun.range_m = 24.0
	shotgun.ammo = 6
	shotgun.reserve = 18

	weapons = [pistol, shotgun]


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, -1.15, 0.55)


func _process(delta: float) -> void:
	if dead:
		return

	_apply_pad_look(delta)
	_apply_look()
	_update_aim(delta)
	_update_laser()

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	message_time_left = maxf(0.0, message_time_left - delta)

	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			var weapon = get_current_weapon()
			if weapon.reload():
				show_message("Przeładowano: %s" % weapon.display_name)
			_emit_weapon_hud()

	if Input.is_action_just_pressed("switch_weapon") and _reload_timer <= 0.0:
		current_weapon = (current_weapon + 1) % weapons.size()
		_emit_weapon_hud()
		show_message(get_current_weapon().display_name)

	if Input.is_action_just_pressed("reload"):
		start_reload()

	if Input.is_action_just_pressed("shoot") and _reload_timer <= 0.0:
		try_shoot()

	_update_interaction()
	if Input.is_action_just_pressed("interact") and _interact_target != null:
		_interact_target.interact(self)


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	move_dir.y = 0.0
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()

	is_sprinting = Input.is_action_pressed("sprint") and not is_aiming and move_dir.length_squared() > 0.01

	var target_speed := walk_speed
	if is_sprinting:
		target_speed = sprint_speed
	elif is_aiming:
		target_speed = aim_speed

	var target_velocity := move_dir * target_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta * target_speed)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta * target_speed)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.2

	move_and_slide()


func _apply_pad_look(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length_squared() < 0.01:
		return
	_yaw -= look.x * pad_look_speed * delta
	_pitch -= look.y * pad_look_speed * delta
	_pitch = clampf(_pitch, -1.15, 0.55)


func _apply_look() -> void:
	rotation.y = _yaw
	spring_arm.rotation.x = _pitch


func _update_aim(delta: float) -> void:
	var want_aim := Input.is_action_pressed("aim") and not dead and _reload_timer <= 0.0
	is_aiming = want_aim
	var target_spring := aim_spring_length if is_aiming else hip_spring_length
	var target_fov := aim_fov if is_aiming else hip_fov
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_spring, clampf(delta * 12.0, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 12.0, 0.0, 1.0))


func _update_laser() -> void:
	laser.visible = is_aiming and not dead
	if not laser.visible:
		return
	var weapon = get_current_weapon()
	var from := camera.global_position
	var forward := -camera.global_transform.basis.z
	var to: Vector3 = from + forward * float(weapon.range_m)
	var hit: Dictionary = _raycast(from, to)
	var distance: float = float(weapon.range_m)
	if not hit.is_empty():
		distance = from.distance_to(hit.get("position", to))
	laser.position = Vector3(0.0, 0.0, -distance * 0.5)
	laser.scale = Vector3(1.0, 1.0, maxf(distance, 0.01))


func _update_interaction() -> void:
	interact_ray.force_raycast_update()
	var target: Object = null
	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if collider != null and collider.has_method("interact"):
			target = collider
	_interact_target = target
	var new_prompt := ""
	if _interact_target != null and _interact_target.has_method("get_prompt"):
		new_prompt = String(_interact_target.get_prompt())
	if new_prompt != current_prompt:
		current_prompt = new_prompt
		prompt_changed.emit(current_prompt)


func get_current_weapon():
	return weapons[current_weapon]


func _emit_weapon_hud() -> void:
	var weapon = get_current_weapon()
	ammo_changed.emit(weapon.display_name, weapon.ammo, weapon.reserve)
	_last_hud_weapon = current_weapon


func start_reload() -> bool:
	var weapon = get_current_weapon()
	if _reload_timer > 0.0 or dead:
		return false
	if weapon.is_full():
		show_message("Magazynek pełny")
		return false
	if weapon.reserve <= 0:
		show_message("Brak amunicji")
		return false
	_reload_timer = weapon.reload_time
	show_message("Przeładowywanie...")
	return true


func try_shoot() -> Dictionary:
	var result := {"fired": false, "hits": [], "weapon": ""}
	if dead or _reload_timer > 0.0 or _fire_cooldown > 0.0:
		return result
	var weapon = get_current_weapon()
	if not weapon.consume_round():
		show_message("Klik. Brak amunicji.")
		start_reload()
		return result

	_fire_cooldown = weapon.fire_interval
	last_shot_ms = Time.get_ticks_msec()
	result["fired"] = true
	result["weapon"] = weapon.id
	_emit_weapon_hud()

	var from := camera.global_position
	var forward := -camera.global_transform.basis.z
	for i in range(weapon.pellets):
		var direction := _spread_direction(forward, weapon.spread_deg)
		var hit := _raycast(from, from + direction * weapon.range_m)
		if hit.is_empty():
			continue
		var collider = hit.get("collider")
		result["hits"].append(collider)
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(weapon.damage, direction)
	return result


func _spread_direction(forward: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.001:
		return forward
	var basis := Basis.looking_at(forward, Vector3.UP)
	var yaw := deg_to_rad(randf_range(-spread_deg, spread_deg))
	var pitch := deg_to_rad(randf_range(-spread_deg, spread_deg))
	var dir := basis * Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	return dir.normalized()


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	return space.intersect_ray(query)


func take_damage(amount: float, _hit_dir: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	show_message("Otrzymano obrażenia: -%d" % int(amount))
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if dead:
		return
	health = clampf(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)


func _die() -> void:
	dead = true
	is_aiming = false
	laser.visible = false
	died.emit()


func show_message(text: String) -> void:
	last_message = text
	message_time_left = 2.4
	message_shown.emit(text)


func add_item(item_id: String, display_name: String, quantity: int = 1) -> bool:
	if inventory.add_item(item_id, display_name, quantity):
		show_message("Zabrano: %s" % display_name)
		return true
	show_message("Ekwipunek pełny")
	return false


func get_hud_state() -> Dictionary:
	var weapon = get_current_weapon()
	return {
		"health": health,
		"max_health": max_health,
		"weapon_name": weapon.display_name,
		"ammo": weapon.ammo,
		"reserve": weapon.reserve,
		"weapon_index": current_weapon + 1,
		"weapon_count": weapons.size(),
		"reloading": _reload_timer > 0.0,
		"aiming": is_aiming,
		"sprinting": is_sprinting,
		"prompt": current_prompt,
		"inventory": inventory.display_text(),
		"message": last_message if message_time_left > 0.0 else "",
		"dead": dead,
	}


func get_save_data() -> Dictionary:
	var weapon_data: Array = []
	for weapon in weapons:
		weapon_data.append(weapon.to_dict())
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y,
		"pitch": _pitch,
		"health": health,
		"current_weapon": current_weapon,
		"weapons": weapon_data,
		"inventory": inventory.to_dict(),
		"dead": dead,
	}


func apply_save_data(data: Dictionary) -> void:
	var pos = data.get("position", [global_position.x, global_position.y, global_position.z])
	if typeof(pos) == TYPE_ARRAY and pos.size() >= 3:
		global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	rotation.y = float(data.get("rotation_y", rotation.y))
	_yaw = rotation.y
	_pitch = float(data.get("pitch", _pitch))
	spring_arm.rotation.x = _pitch
	health = clampf(float(data.get("health", max_health)), 0.0, max_health)
	dead = bool(data.get("dead", false))
	var saved_weapons = data.get("weapons", [])
	if typeof(saved_weapons) == TYPE_ARRAY:
		for i in range(mini(saved_weapons.size(), weapons.size())):
			if typeof(saved_weapons[i]) == TYPE_DICTIONARY:
				weapons[i].apply_dict(saved_weapons[i])
	current_weapon = clampi(int(data.get("current_weapon", 0)), 0, weapons.size() - 1)
	var saved_inventory = data.get("inventory", [])
	if typeof(saved_inventory) == TYPE_ARRAY:
		inventory.apply_dict(saved_inventory)
	health_changed.emit(health, max_health)
	_emit_weapon_hud()
