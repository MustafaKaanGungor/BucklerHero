extends Label

## Top-of-screen line for generated levels: section, wave and enemies left.
## Reads get_hud_text() from the level generator (group level_navigation); hidden when there is none.

const GROUP_LEVEL_NAVIGATION: StringName = &"level_navigation"
const METHOD_GET_HUD_TEXT: StringName = &"get_hud_text"

var _level: Node


func _process(_delta: float) -> void:
	if _level == null or not is_instance_valid(_level):
		_level = get_tree().get_first_node_in_group(GROUP_LEVEL_NAVIGATION)
	if _level == null or not _level.has_method(METHOD_GET_HUD_TEXT):
		visible = false
		return

	var hud_text: String = String(_level.call(METHOD_GET_HUD_TEXT))
	visible = not hud_text.is_empty()
	text = hud_text
