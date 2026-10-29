extends Node3D
class_name Game

## Main scene controller: HUD binding, pause/capture, save/load, game over.

const SaveSystemScript = preload("res://src/systems/save_system.gd")
const SAVE_PATH := "user://savegame.json"

@onready var player: Node = $SubViewportContainer/PS2Viewport/World/Player
@onready var hud: Node = $HUD
@onready var world: Node3D = $SubViewportContainer/PS2Viewport/World


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if hud.has_method("bind_player"):
		hud.bind_player(player)
	if player.has_signal("died"):
		player.died.connect(_on_player_died)
	player.show_message("Trauma Village — prototyp. E: interakcja, LPM: strzał, PPM: celowanie.")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("save_game"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("load_game"):
		load_game()
		get_viewport().set_input_as_handled()


func save_game() -> bool:
	var enemies := {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("get_save_data"):
			enemies[enemy.name] = enemy.get_save_data()

	var interactables := {}
	for node in get_tree().get_nodes_in_group("interactable"):
		if node.has_method("get_save_data"):
			interactables[node.name] = node.get_save_data()

	var data := {
		"player": player.get_save_data(),
		"enemies": enemies,
		"interactables": interactables,
	}
	var ok: bool = SaveSystemScript.save_game(SAVE_PATH, data)
	player.show_message("Zapisano grę." if ok else "Błąd zapisu.")
	return ok


func load_game() -> bool:
	var data: Dictionary = SaveSystemScript.load_game(SAVE_PATH)
	if data.is_empty():
		player.show_message("Brak zapisu.")
		return false

	var player_data = data.get("player", {})
	if typeof(player_data) == TYPE_DICTIONARY:
		player.apply_save_data(player_data)

	var enemies = data.get("enemies", {})
	if typeof(enemies) == TYPE_DICTIONARY:
		for enemy_name in enemies.keys():
			var enemy := world.find_child(String(enemy_name), true, false)
			if enemy != null and enemy.has_method("apply_save_data"):
				enemy.apply_save_data(enemies[enemy_name])

	var interactables = data.get("interactables", {})
	if typeof(interactables) == TYPE_DICTIONARY:
		for node_name in interactables.keys():
			var node := world.find_child(String(node_name), true, false)
			if node != null and node.has_method("apply_save_data"):
				node.apply_save_data(interactables[node_name])

	player.show_message("Wczytano grę.")
	return true


func _on_player_died() -> void:
	player.show_message("Nie żyjesz...")
	await get_tree().create_timer(2.5).timeout
	get_tree().reload_current_scene()
