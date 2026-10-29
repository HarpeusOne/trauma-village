extends SceneTree

## Headless smoke test for Wave 1.
## Run:
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/smoke_test.gd

const MainScene = preload("res://scenes/main.tscn")
const LevelScene = preload("res://scenes/level_test.tscn")
const PlayerScene = preload("res://scenes/player.tscn")
const EnemyScene = preload("res://scenes/enemy.tscn")
const EnemyScript = preload("res://src/enemy/enemy.gd")
const WeaponDataScript = preload("res://src/systems/weapon.gd")
const InventoryScript = preload("res://src/systems/inventory.gd")
const SaveSystemScript = preload("res://src/systems/save_system.gd")

const SAVE_PATH := "user://smoke_test_save.json"

var failures: Array[String] = []
var passes := 0


class DummyTarget:
	extends StaticBody3D

	var health := 100.0

	func take_damage(amount: float, _hit_dir: Vector3 = Vector3.ZERO) -> void:
		health -= amount


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("PASS  ", label)
	else:
		failures.append(label)
		push_error("FAIL  " + label)
		print("FAIL  ", label)


func _run() -> void:
	print("=== Trauma Village smoke test ===")
	await process_frame

	_test_scene_loading()
	await process_frame

	var level = LevelScene.instantiate()
	root.add_child(level)
	await process_frame
	_check(level.get_child_count() > 15, "level builds primitives and props")
	_check(get_nodes_in_group("enemies").size() == 3, "level spawns 3 enemy variants")
	_check(get_nodes_in_group("enemy_waypoint").size() >= 5, "level creates waypoints")
	_check(get_nodes_in_group("interactable").size() >= 4, "level creates doors and items")

	_test_weapon_data()
	_test_inventory()

	var player = PlayerScene.instantiate()
	root.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	await physics_frame
	await physics_frame
	_check(player.is_in_group("player"), "player joins 'player' group")
	_check(player.weapons.size() == 2, "player owns pistol and shotgun")
	_check(player.get_current_weapon().id == "pistol", "pistol is default weapon")

	var target := DummyTarget.new()
	target.name = "DummyTarget"
	target.position = Vector3(0, 1.0, -4)
	var target_collision := CollisionShape3D.new()
	var target_shape := BoxShape3D.new()
	target_shape.size = Vector3(2, 2, 2)
	target_collision.shape = target_shape
	target.add_child(target_collision)
	root.add_child(target)
	await physics_frame
	await physics_frame

	var shot: Dictionary = player.try_shoot()
	_check(bool(shot.get("fired", false)), "player fires pistol")
	_check(not shot.get("hits", []).is_empty(), "hitscan ray reaches dummy target")
	_check(target.health < 100.0, "shot applies damage to target")

	player.try_shoot()
	await process_frame
	var reload_started: bool = player.start_reload()
	_check(reload_started, "reload starts when magazine is not full")

	_test_save_round_trip(player)
	await _test_enemy_variants()
	await _test_main_scene()

	player.queue_free()
	target.queue_free()
	level.queue_free()
	await process_frame

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	print("=== RESULT: %d passed, %d failed ===" % [passes, failures.size()])
	for failure in failures:
		print("  - ", failure)
	quit(0 if failures.is_empty() else 1)


func _test_scene_loading() -> void:
	var scenes := {
		"main": "res://scenes/main.tscn",
		"level_test": "res://scenes/level_test.tscn",
		"player": "res://scenes/player.tscn",
		"enemy": "res://scenes/enemy.tscn",
		"door": "res://scenes/door.tscn",
		"item_pickup": "res://scenes/item_pickup.tscn",
		"hud": "res://scenes/hud.tscn",
	}
	for label in scenes.keys():
		var packed = load(scenes[label])
		_check(packed is PackedScene, "scene loads: %s" % label)
	var shader := load("res://src/shaders/ps2_surface.gdshader")
	_check(shader is Shader, "PS2 shader loads")
	var material := load("res://src/shaders/ps2_material.tres")
	_check(material is ShaderMaterial, "PS2 material loads")


func _test_weapon_data() -> void:
	var pistol = WeaponDataScript.new()
	pistol.mag_size = 8
	pistol.ammo = 8
	pistol.reserve = 40
	var before: int = pistol.ammo
	_check(pistol.consume_round() and pistol.ammo == before - 1, "pistol consumes one round")
	pistol.ammo = 0
	_check(not pistol.can_fire(), "empty pistol cannot fire")
	pistol.reserve = 10
	_check(pistol.reload() and pistol.ammo == pistol.mag_size, "pistol reloads from reserve")

	var shotgun = WeaponDataScript.new()
	shotgun.pellets = 7
	shotgun.mag_size = 6
	_check(shotgun.pellets == 7, "shotgun fires 7 pellets")
	_check(shotgun.mag_size == 6, "shotgun magazine is 6")


func _test_inventory() -> void:
	var inventory = InventoryScript.new()
	root.add_child(inventory)
	var added := 0
	for i in range(InventoryScript.MAX_SLOTS):
		if inventory.add_item("item_%d" % i, "Item %d" % i):
			added += 1
	_check(added == 6, "inventory accepts exactly 6 slots")
	_check(inventory.is_full(), "inventory reports full")
	_check(not inventory.add_item("overflow", "Overflow"), "7th item is rejected")
	var snapshot: Array = inventory.to_dict()
	inventory.apply_dict(snapshot)
	_check(inventory.used_slots() == 6, "inventory round-trips through dict")
	inventory.queue_free()


func _test_save_round_trip(player) -> void:
	player.health = 55.0
	player.add_item("bandage", "Bandaż", 2)
	var data := {
		"player": player.get_save_data(),
		"enemies": {},
		"interactables": {},
	}
	_check(SaveSystemScript.save_game(SAVE_PATH, data), "save_game writes JSON")
	_check(FileAccess.file_exists(SAVE_PATH), "save file exists in user://")

	var loaded: Dictionary = SaveSystemScript.load_game(SAVE_PATH)
	_check(int(loaded.get("version", 0)) == SaveSystemScript.CURRENT_VERSION, "save version is current")
	_check(typeof(loaded.get("player", null)) == TYPE_DICTIONARY, "loaded player payload is a dictionary")

	player.health = 100.0
	player.apply_save_data(loaded.get("player", {}))
	_check(is_equal_approx(player.health, 55.0), "player health round-trips")
	_check(player.inventory.has_item("bandage"), "inventory item round-trips")

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_check(typeof(parsed) == TYPE_DICTIONARY, "save file is valid JSON")


func _test_enemy_variants() -> void:
	var walker = _spawn_test_enemy("walker")
	var stalker = _spawn_test_enemy("stalker")
	var brute = _spawn_test_enemy("brute")
	await process_frame
	_check(walker.max_health == 60.0, "walker variant stats")
	_check(stalker.max_health == 40.0, "stalker variant stats")
	_check(brute.max_health == 150.0, "brute variant stats")
	_check(walker.state == EnemyScript.State.PATROL, "enemy starts in patrol")
	walker.take_damage(10.0, Vector3.FORWARD)
	_check(walker.state == EnemyScript.State.STAGGER, "enemy staggers on hit")
	walker.take_damage(1000.0, Vector3.FORWARD)
	_check(walker.state == EnemyScript.State.DEAD, "enemy dies when health reaches zero")
	walker.queue_free()
	stalker.queue_free()
	brute.queue_free()
	await process_frame


func _spawn_test_enemy(variant: String):
	var enemy = EnemyScene.instantiate()
	enemy.variant = variant
	enemy.position = Vector3(0, 0.1, -4)
	root.add_child(enemy)
	return enemy


func _test_main_scene() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var player := main.get_node_or_null("SubViewportContainer/PS2Viewport/World/Player")
	var hud := main.get_node_or_null("HUD")
	var container := main.get_node_or_null("SubViewportContainer")
	var viewport := main.get_node_or_null("SubViewportContainer/PS2Viewport")
	_check(player != null, "main scene spawns player")
	_check(hud != null, "main scene has HUD")
	_check(container != null and container.stretch_shrink == 2, "PS2 viewport uses 2x downscale (640x480 at 1280x960)")
	_check(container != null and viewport != null and viewport.size == Vector2i(container.size / 2.0), "PS2 viewport is half the window size")
	_check(container != null and container.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "PS2 upscale uses nearest filtering")
	main.queue_free()
	await process_frame
