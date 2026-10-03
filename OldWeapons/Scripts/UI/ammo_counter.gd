extends Label

## Shows the player's magazine ammo, e.g. "12 / ∞", or RELOADING during a reload.
## Finds the weapon through the "player_weapons" group, because the player is spawned
## after the HUD is ready.

const GROUP_PLAYER_WEAPONS: StringName = &"player_weapons"

@export_group("Text")
## Shown after the magazine count. Reserve ammo is unlimited.
@export var reserve_text: String = "∞"
@export var reloading_text: String = "RELOADING"

@export_group("Colors")
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 0.95)
## Color when the magazine is at or below low_ammo_count.
@export var low_color: Color = Color(0.95, 0.72, 0.18, 1.0)
@export var empty_color: Color = Color(0.95, 0.18, 0.13, 1.0)
@export var reloading_color: Color = Color(0.75, 0.8, 0.85, 0.9)
@export var low_ammo_count: int = 3

var _weapon: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = ""


func _process(_delta: float) -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		_connect_weapon()


func _connect_weapon() -> void:
	_weapon = get_tree().get_first_node_in_group(GROUP_PLAYER_WEAPONS)
	if _weapon == null:
		text = ""
		return

	var ammo_changed_callback: Callable = Callable(self, "_on_ammo_changed")
	if not _weapon.is_connected(&"ammo_changed", ammo_changed_callback):
		_weapon.connect(&"ammo_changed", ammo_changed_callback)
	_on_ammo_changed(
		int(_weapon.call(&"get_ammo")),
		int(_weapon.call(&"get_magazine_size")),
		bool(_weapon.call(&"is_reloading"))
	)


func _on_ammo_changed(current_ammo: int, _magazine_size: int, is_reloading: bool) -> void:
	if is_reloading:
		text = reloading_text
		add_theme_color_override(&"font_color", reloading_color)
		return

	text = "%d / %s" % [current_ammo, reserve_text]
	var ammo_color: Color = normal_color
	if current_ammo <= 0:
		ammo_color = empty_color
	elif current_ammo <= low_ammo_count:
		ammo_color = low_color
	add_theme_color_override(&"font_color", ammo_color)
