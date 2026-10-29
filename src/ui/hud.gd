extends CanvasLayer
class_name Hud

## Minimal PS2-style HUD built in code: health, ammo, weapon, prompt,
## six-slot inventory, crosshair and message line.

var player: Node = null

var _ammo_label: Label
var _health_label: Label
var _health_bar: ProgressBar
var _inventory_label: Label
var _prompt_label: Label
var _message_label: Label
var _crosshair: Control
var _dead_label: Label


func _ready() -> void:
	layer = 10
	_build()


func bind_player(value: Node) -> void:
	player = value
	if player != null:
		_update()


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_crosshair = Control.new()
	_crosshair.name = "Crosshair"
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)
	_add_crosshair_bar(_crosshair, Vector2(-9, -1), Vector2(9, 1))
	_add_crosshair_bar(_crosshair, Vector2(-1, -9), Vector2(1, 9))

	_health_label = _make_label(root, Control.PRESET_BOTTOM_LEFT, Vector2(24, -64), Vector2(280, -32), HORIZONTAL_ALIGNMENT_LEFT, 20)
	_health_bar = ProgressBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health_bar.offset_left = 24
	_health_bar.offset_top = -34
	_health_bar.offset_right = 284
	_health_bar.offset_bottom = -18
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_health_bar)

	_ammo_label = _make_label(root, Control.PRESET_BOTTOM_RIGHT, Vector2(-380, -68), Vector2(-24, -30), HORIZONTAL_ALIGNMENT_RIGHT, 26)

	_inventory_label = _make_label(root, Control.PRESET_TOP_LEFT, Vector2(24, 20), Vector2(320, 190), HORIZONTAL_ALIGNMENT_LEFT, 16)
	_inventory_label.modulate = Color(0.82, 0.86, 0.8, 0.85)

	_prompt_label = _make_label(root, Control.PRESET_CENTER_BOTTOM, Vector2(-260, -128), Vector2(260, -96), HORIZONTAL_ALIGNMENT_CENTER, 18)
	_prompt_label.modulate = Color(0.95, 0.88, 0.55)

	_message_label = _make_label(root, Control.PRESET_CENTER_TOP, Vector2(-320, 28), Vector2(320, 64), HORIZONTAL_ALIGNMENT_CENTER, 20)
	_message_label.modulate = Color(0.92, 0.9, 0.82)

	_dead_label = _make_label(root, Control.PRESET_CENTER, Vector2(-300, -40), Vector2(300, 40), HORIZONTAL_ALIGNMENT_CENTER, 42)
	_dead_label.text = "NIE ŻYJESZ"
	_dead_label.modulate = Color(0.7, 0.05, 0.05)
	_dead_label.visible = false


func _add_crosshair_bar(parent: Control, top_left: Vector2, bottom_right: Vector2) -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.92, 0.94, 0.88, 0.8)
	bar.anchor_left = 0.5
	bar.anchor_top = 0.5
	bar.anchor_right = 0.5
	bar.anchor_bottom = 0.5
	bar.offset_left = top_left.x
	bar.offset_top = top_left.y
	bar.offset_right = bottom_right.x
	bar.offset_bottom = bottom_right.y
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)


func _make_label(parent: Control, preset: int, top_left: Vector2, bottom_right: Vector2, alignment: int, font_size: int) -> Label:
	var label := Label.new()
	label.set_anchors_preset(preset)
	label.offset_left = top_left.x
	label.offset_top = top_left.y
	label.offset_right = bottom_right.x
	label.offset_bottom = bottom_right.y
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.84))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _process(_delta: float) -> void:
	if player != null:
		_update()


func _update() -> void:
	var state: Dictionary = player.get_hud_state()
	_health_label.text = "HP %d / %d" % [int(state["health"]), int(state["max_health"])]
	_health_bar.max_value = float(state["max_health"])
	_health_bar.value = float(state["health"])

	var suffix := "  [PRZEŁADOWANIE]" if bool(state["reloading"]) else ""
	_ammo_label.text = "%s  %d / %d%s" % [
		String(state["weapon_name"]).to_upper(),
		int(state["ammo"]),
		int(state["reserve"]),
		suffix,
	]
	_inventory_label.text = "EKWIPUNEK (%d/%d)\n%s" % [
		_count_inventory(String(state["inventory"])),
		6,
		String(state["inventory"]),
	]
	_prompt_label.text = String(state["prompt"])
	_message_label.text = String(state["message"])
	_dead_label.visible = bool(state["dead"])
	_crosshair.modulate = Color(1, 1, 1, 1) if bool(state["aiming"]) else Color(1, 1, 1, 0.55)


func _count_inventory(text: String) -> int:
	var count := 0
	for line in text.split("\n"):
		if not line.contains("--"):
			count += 1
	return count
