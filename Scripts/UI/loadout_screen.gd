extends Control

## Loadout screen shown before a run starts (when the scene starts, and again after the level
## generator's run_restarted, i.e. after the death or victory screen). The game is paused and the
## mouse is free while it is open.
## Click weapon cards to pick any number of the weapons melee_weapons.gd has (at least one; capped by
## max_weapons when it is above 0); the order they are picked in is their slot (keys 1-9, cycling,
## the selector wheel). Click a picked card
## again to drop it. START (or Enter / Space) calls melee_weapons.set_loadout(), takes out the first
## pick, captures the mouse and unpauses. The last loadout is remembered for the next run.
## Builds its own nodes; runs while the tree is paused.

signal loadout_confirmed(weapon_ids: Array[StringName])

const GROUP_PLAYER_MELEE: StringName = &"player_melee"
const GROUP_LEVEL_NAVIGATION: StringName = &"level_navigation"
const SIGNAL_RUN_RESTARTED: StringName = &"run_restarted"
const SoundSynth = preload("res://Scripts/Audio/sound_synth.gd")

@export_group("Rules")
## Most weapons in a loadout. 0 = no limit. Number keys 1-9 reach the first nine slots; the rest are
## reached by cycling (Q / mouse wheel) or the selector wheel.
@export var max_weapons: int = 0
## Open the screen when the scene starts.
@export var show_on_start: bool = true

@export_group("Weapons")
## Shown name, role and description per weapon id. Weapons missing here use their id.
@export var weapon_info: Dictionary = {
	&"broadsword": ["BROADSWORD", "Crowd cutter", "Wide right-to-left sweep, 3.3 m reach.\nHits everyone in the arc, freezing on each.\nS rank: every swing throws a slash wave."],
	&"halberd": ["HALBERD", "Long reach, lunge", "Long thrust with a forward lunge.\n2 damage, pierces a line of enemies.\nS rank: a 10 m lunge through them, double damage."],
	&"shield": ["SHIELD", "Defence, crowd control", "Blocks hits from the front while held.\nClick: bash. Hold: charge, carry and crush enemies.\nS rank: the charge crushes everything it touches."],
	&"crossbow": ["CROSSBOW", "Combo spender", "Needs combo to fire; each shot spends all of it.\nDamage by rank: D 2, C 3, B 5, A 8, S 12.\nAt S the bolt explodes: 6 m blast."],
}

@export_group("Look")
## Card size in pixels.
@export var card_size: Vector2 = Vector2(360.0, 300.0)
@export var accent_color: Color = Color(1.0, 0.6, 0.2)
@export var card_color: Color = Color(0.08, 0.08, 0.1, 0.92)
@export var card_selected_color: Color = Color(0.22, 0.13, 0.06, 0.95)

var _is_open: bool = false
var _selection: Array[StringName] = []
var _has_previous: bool = false
var _cards: Dictionary = {}
var _badges: Dictionary = {}
var _cards_row: HFlowContainer
var _start_button: Button
var _hint: Label
var _connected_level: Node
var _click_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false
	if show_on_start:
		open.call_deferred()


func is_open() -> bool:
	return _is_open


## Shows the screen and pauses the game. Builds the cards from the weapons the player has.
func open() -> void:
	var weapons: Node = _get_weapons()
	if weapons == null or _is_open:
		return
	_is_open = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var all: Array[StringName] = []
	all.assign(weapons.call(&"get_all_weapons"))
	if not _has_previous:
		_selection = all.slice(0, all.size() if max_weapons <= 0 else mini(max_weapons, all.size()))
	_rebuild_cards(all)
	_refresh()


func _process(_delta: float) -> void:
	_connect_level()


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		_confirm()


func _toggle(weapon_id: StringName) -> void:
	if _selection.has(weapon_id):
		_selection.erase(weapon_id)
	elif max_weapons <= 0 or _selection.size() < max_weapons:
		_selection.append(weapon_id)
	_click_player.play()
	_refresh()


func _confirm() -> void:
	if _selection.is_empty():
		return
	var weapons: Node = _get_weapons()
	if weapons != null:
		weapons.call(&"set_loadout", _selection)
		weapons.call(&"equip", _selection[0])
	_has_previous = true
	_is_open = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	loadout_confirmed.emit(_selection.duplicate())


func _refresh() -> void:
	for weapon_id in _cards.keys():
		var slot: int = _selection.find(weapon_id)
		var card: Button = _cards[weapon_id]
		card.button_pressed = slot >= 0
		var badge: Label = _badges[weapon_id]
		badge.text = "KEY %d" % (slot + 1) if slot >= 0 else ""
	_start_button.disabled = _selection.is_empty()
	if _selection.is_empty():
		_hint.text = "Pick at least one weapon."
	elif max_weapons > 0 and _selection.size() >= max_weapons:
		_hint.text = "Loadout full. Click a weapon to drop it."
	elif max_weapons > 0:
		_hint.text = "Pick up to %d. The order you pick is their key (1, 2, 3, …)." % max_weapons
	else:
		_hint.text = "Pick as many as you like. The order you pick is their key (1, 2, 3, …)."


## The level generator joins its group after the HUD is ready, so the restart hook connects late.
func _connect_level() -> void:
	if _connected_level != null and is_instance_valid(_connected_level):
		return
	var level: Node = get_tree().get_first_node_in_group(GROUP_LEVEL_NAVIGATION)
	if level == null or not level.has_signal(SIGNAL_RUN_RESTARTED):
		return
	level.connect(SIGNAL_RUN_RESTARTED, open)
	_connected_level = level


func _get_weapons() -> Node:
	return get_tree().get_first_node_in_group(GROUP_PLAYER_MELEE)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 22)
	add_child(column)

	column.add_child(_make_label("CHOOSE YOUR WEAPONS", 64, accent_color, 12))
	_hint = _make_label("", 24, Color(0.85, 0.85, 0.85), 6)
	column.add_child(_hint)

	# Wraps onto more rows once there are more weapons than fit across the screen.
	_cards_row = HFlowContainer.new()
	_cards_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_cards_row.custom_minimum_size = Vector2(1600.0, 0.0)
	_cards_row.add_theme_constant_override(&"h_separation", 24)
	_cards_row.add_theme_constant_override(&"v_separation", 24)
	column.add_child(_cards_row)

	column.add_child(_make_label("Switching weapons is the combo: each attack with a different weapon resets the others' recovery.", 20, Color(0.7, 0.7, 0.7), 4))

	_start_button = Button.new()
	_start_button.text = "START"
	_start_button.custom_minimum_size = Vector2(260.0, 64.0)
	_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start_button.add_theme_font_size_override(&"font_size", 32)
	_start_button.add_theme_stylebox_override(&"normal", _make_style(Color(accent_color, 0.85), accent_color))
	_start_button.add_theme_stylebox_override(&"hover", _make_style(accent_color.lightened(0.15), Color.WHITE))
	_start_button.add_theme_stylebox_override(&"pressed", _make_style(accent_color.darkened(0.2), Color.WHITE))
	_start_button.add_theme_stylebox_override(&"disabled", _make_style(Color(0.25, 0.25, 0.25, 0.8), Color(0.4, 0.4, 0.4)))
	_start_button.add_theme_color_override(&"font_color", Color(0.08, 0.05, 0.02))
	_start_button.add_theme_color_override(&"font_hover_color", Color(0.08, 0.05, 0.02))
	_start_button.pressed.connect(_confirm)
	column.add_child(_start_button)
	column.add_child(_make_label("Enter / Space to start", 18, Color(0.6, 0.6, 0.6), 4))

	_click_player = AudioStreamPlayer.new()
	_click_player.stream = SoundSynth.make_wav(SoundSynth.normalize(SoundSynth.thud(0.06, 1500.0, 900.0, 70.0, 0.6, 110.0, 0.9, 601)))
	_click_player.volume_db = -12.0
	add_child(_click_player)


func _rebuild_cards(all: Array[StringName]) -> void:
	for child in _cards_row.get_children():
		child.queue_free()
	_cards.clear()
	_badges.clear()
	for weapon_id in all:
		var info: Array = weapon_info.get(weapon_id, [String(weapon_id).to_upper(), "", ""])
		var card: Button = Button.new()
		card.toggle_mode = true
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = card_size
		card.add_theme_stylebox_override(&"normal", _make_style(card_color, Color(0.3, 0.3, 0.35)))
		card.add_theme_stylebox_override(&"hover", _make_style(card_color.lightened(0.08), Color(0.6, 0.6, 0.65)))
		card.add_theme_stylebox_override(&"pressed", _make_style(card_selected_color, accent_color))
		card.add_theme_stylebox_override(&"hover_pressed", _make_style(card_selected_color.lightened(0.05), accent_color.lightened(0.2)))
		card.pressed.connect(_toggle.bind(weapon_id))

		var inside: VBoxContainer = VBoxContainer.new()
		inside.set_anchors_preset(Control.PRESET_FULL_RECT)
		inside.offset_left = 18.0
		inside.offset_top = 16.0
		inside.offset_right = -18.0
		inside.offset_bottom = -16.0
		inside.add_theme_constant_override(&"separation", 8)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inside)
		inside.add_child(_make_label(String(info[0]), 34, Color.WHITE, 6))
		inside.add_child(_make_label(String(info[1]), 20, accent_color, 4))
		var description: Label = _make_label(String(info[2]), 18, Color(0.82, 0.82, 0.82), 3)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inside.add_child(description)
		var badge: Label = _make_label("", 26, accent_color, 6)
		inside.add_child(badge)

		_cards_row.add_child(card)
		_cards[weapon_id] = card
		_badges[weapon_id] = badge


func _make_label(text: String, font_size: int, color: Color, outline: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override(&"outline_size", outline)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	return style
