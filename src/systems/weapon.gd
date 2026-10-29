extends Resource
class_name WeaponData

## Pure data + ammo state for one weapon. No nodes, so it is headless-testable.

@export var id: String = "pistol"
@export var display_name: String = "Pistolet"
@export var damage: float = 25.0
@export var pellets: int = 1
@export var spread_deg: float = 0.8
@export var mag_size: int = 8
@export var fire_interval: float = 0.35
@export var reload_time: float = 1.3
@export var range_m: float = 60.0

var ammo: int = 8
var reserve: int = 40


func can_fire() -> bool:
	return ammo > 0


func consume_round() -> bool:
	if ammo <= 0:
		return false
	ammo -= 1
	return true


func reload() -> bool:
	if ammo >= mag_size or reserve <= 0:
		return false
	var needed: int = mag_size - ammo
	var taken: int = mini(needed, reserve)
	ammo += taken
	reserve -= taken
	return true


func is_full() -> bool:
	return ammo >= mag_size


func to_dict() -> Dictionary:
	return {
		"id": id,
		"ammo": ammo,
		"reserve": reserve,
	}


func apply_dict(data: Dictionary) -> void:
	ammo = clampi(int(data.get("ammo", mag_size)), 0, mag_size)
	reserve = maxi(0, int(data.get("reserve", reserve)))

