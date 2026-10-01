extends CanvasLayer

@export_group("Nodes")
## Permanent total loudness bar shown on the player HUD.
@export var total_loudness_bar_path: NodePath = NodePath("HudRoot/TotalLoudnessBar")
## Loudness bar shown on the player HUD.
@export var loudness_bar_path: NodePath = NodePath("HudRoot/LoudnessBar")
## Stamina bar shown on the player HUD.
@export var stamina_bar_path: NodePath = NodePath("HudRoot/StaminaBar")

var total_loudness_bar: Control
var loudness_bar: Control
var stamina_bar: Control


func _ready() -> void:
	total_loudness_bar = get_node_or_null(total_loudness_bar_path) as Control
	loudness_bar = get_node_or_null(loudness_bar_path) as Control
	stamina_bar = get_node_or_null(stamina_bar_path) as Control
	visible = true
