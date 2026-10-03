extends Control

## Weapon selector: hold middle mouse (action weapon_wheel) to open a radial menu of the weapons in
## melee_weapons.weapon_order, move the mouse toward one and let go to equip it.
## While it is open the game runs in slow motion (Engine.time_scale), the mouse moves a pointer
## instead of turning the camera, and no new attacks start. Weapons still recovering are dimmed.
## Full-screen Control in the HUD; draws itself in _draw(). Joins group weapon_wheel.

signal opened
signal closed(weapon_id: StringName)

const SoundSynth = preload("res://Scripts/Audio/sound_synth.gd")
const GROUP_WEAPON_WHEEL: StringName = &"weapon_wheel"
const GROUP_PLAYER_MELEE: StringName = &"player_melee"

@export_group("Slow Motion")
## Game speed while the selector is open (1 = normal).
@export_range(0.05, 1.0) var wheel_time_scale: float = 0.25
## Real-time seconds the slow-down and speed-up take.
@export var time_scale_blend_time: float = 0.08

@export_group("Pointer")
## Pointer travel per pixel of mouse motion.
@export var pointer_sensitivity: float = 1.0
## The pointer must be this far from the centre (pixels) before a slice is picked.
@export var select_deadzone: float = 40.0

@export_group("Look")
## Outer and inner radius of the ring, in pixels.
@export var outer_radius: float = 230.0
@export var inner_radius: float = 80.0
## Ring colour, highlighted slice colour, and the colour of the weapon already in hand.
@export var ring_color: Color = Color(0.05, 0.05, 0.07, 0.72)
@export var highlight_color: Color = Color(1.0, 0.55, 0.2, 0.85)
@export var equipped_color: Color = Color(1.0, 1.0, 1.0, 0.18)
## Label size.
@export var font_size: int = 28
## Display names, in the same order as weapon_order.
@export var weapon_names: Dictionary = {
	&"broadsword": "BROADSWORD",
	&"halberd": "HALBERD",
	&"shield": "SHIELD",
	&"crossbow": "CROSSBOW",
	&"war_hammer": "WAR HAMMER",
	&"sickle_dagger": "SICKLE & DAGGER",
	&"morningstar": "MORNINGSTAR",
	&"war_axe": "WAR AXE",
	&"hatchet": "HATCHET",
	&"returning_hatchet": "RETURNING HATCHET",
	&"hook": "HOOK",
	&"talons": "TALONS",
}
## Seconds (real time) the ring takes to fade in or out.
@export var fade_time: float = 0.08

@export_group("Sound")
## Volume of the open / close / highlight ticks, in decibels.
@export var tick_volume_db: float = -14.0

var _is_open: bool = false
var _is_restoring_time: bool = false
var _pointer: Vector2 = Vector2.ZERO
var _highlighted: int = -1
var _alpha: float = 0.0
var _weapons: Node
var _tick_player: AudioStreamPlayer
var _open_player: AudioStreamPlayer


func _ready() -> void:
	add_to_group(GROUP_WEAPON_WHEEL)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate.a = 0.0
	_tick_player = _make_player(SoundSynth.thud(0.05, 1800.0, 1200.0, 80.0, 0.6, 120.0, 0.9, 401), tick_volume_db)
	_open_player = _make_player(SoundSynth.whoosh(0.18, 600.0, 1800.0, 900.0, 0.4, 1.5, 402), tick_volume_db + 2.0)
	HealthManager.died.connect(_close.bind(false))


func _exit_tree() -> void:
	# Never leave the game in slow motion.
	Engine.time_scale = 1.0


func is_open() -> bool:
	return _is_open


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	# The pointer gets the mouse; the camera doesn't turn while choosing.
	_pointer += motion.relative * pointer_sensitivity
	if _pointer.length() > outer_radius:
		_pointer = _pointer.normalized() * outer_radius
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Real time, so the ring and the slow-down don't slow themselves.
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	var wants_open: bool = InputManager.is_weapon_wheel_pressed() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and not HealthManager.is_dead()
	if wants_open and not _is_open:
		_open()
	elif not wants_open and _is_open:
		_close(true)

	# Only touch the game speed while open or easing back afterwards, so other slow-motion
	# (the death screen) isn't fought every frame.
	if _is_open or _is_restoring_time:
		var target_scale: float = wheel_time_scale if _is_open else 1.0
		Engine.time_scale = move_toward(Engine.time_scale, target_scale, real_delta / maxf(time_scale_blend_time, 0.001))
		if not _is_open and is_equal_approx(Engine.time_scale, 1.0):
			_is_restoring_time = false
	_alpha = move_toward(_alpha, 1.0 if _is_open else 0.0, real_delta / maxf(fade_time, 0.001))
	modulate.a = _alpha

	if _is_open:
		var highlighted: int = _get_slice_under_pointer()
		if highlighted != _highlighted:
			_highlighted = highlighted
			if highlighted >= 0:
				_tick_player.play()
	if _alpha > 0.0:
		queue_redraw()


func _open() -> void:
	_is_open = true
	_pointer = Vector2.ZERO
	_highlighted = -1
	_open_player.play()
	opened.emit()


## equip: pick the highlighted weapon (false when closing because the player died).
func _close(equip: bool) -> void:
	if not _is_open:
		return
	_is_open = false
	var picked: StringName = &""
	var order: Array[StringName] = _get_order()
	if equip and _highlighted >= 0 and _highlighted < order.size():
		picked = order[_highlighted]
		var weapons: Node = _get_weapons()
		if weapons != null:
			weapons.call(&"equip", picked)
	_highlighted = -1
	if equip:
		_is_restoring_time = true
	else:
		# Closed by death: hand the game speed straight back (the death screen takes over).
		_is_restoring_time = false
		Engine.time_scale = 1.0
	closed.emit(picked)


func _get_slice_under_pointer() -> int:
	var count: int = _get_order().size()
	if count == 0 or _pointer.length() < select_deadzone:
		return -1
	# Slice 0 is centred straight up, the rest follow clockwise.
	var angle: float = fposmod(_pointer.angle() + PI * 0.5 + PI / float(count), TAU)
	return int(angle / (TAU / float(count))) % count


func _draw() -> void:
	var order: Array[StringName] = _get_order()
	var count: int = order.size()
	if count == 0:
		return
	var centre: Vector2 = size * 0.5
	var slice: float = TAU / float(count)
	var weapons: Node = _get_weapons()
	var equipped: StringName = weapons.call(&"get_equipped_weapon") if weapons != null else &""
	var font: Font = get_theme_default_font()

	for index in range(count):
		var start_angle: float = -PI * 0.5 - slice * 0.5 + slice * float(index)
		var color: Color = ring_color
		if index == _highlighted:
			color = highlight_color
		elif order[index] == equipped:
			color = ring_color.blend(equipped_color)
		_draw_ring_slice(centre, start_angle + 0.03, start_angle + slice - 0.03, color)

		var middle_angle: float = start_angle + slice * 0.5
		var label_position: Vector2 = centre + Vector2.from_angle(middle_angle) * (inner_radius + outer_radius) * 0.5
		var label: String = String(weapon_names.get(order[index], String(order[index]).to_upper()))
		var recovering: bool = weapons != null and bool(weapons.call(&"is_recovering", order[index]))
		# A thrown hatchet can't be picked here until it is collected.
		var available: bool = weapons == null or bool(weapons.call(&"is_weapon_available", order[index]))
		var text_color: Color = Color(1.0, 1.0, 1.0, 0.45 if recovering else 1.0)
		if not available:
			text_color = Color(1.0, 1.0, 1.0, 0.2)
			label += " (THROWN)"
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string_outline(font, label_position + Vector2(-text_size.x * 0.5, font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.8))
		draw_string(font, label_position + Vector2(-text_size.x * 0.5, font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		var key_hint: String = str(index + 1)
		var hint_size: int = int(font_size * 0.6)
		draw_string(font, label_position + Vector2(-hint_size * 0.3, font_size * 1.3), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(1, 1, 1, 0.5))

	draw_circle(centre + _pointer, 6.0, Color(1.0, 1.0, 1.0, 0.9))


func _draw_ring_slice(centre: Vector2, from_angle: float, to_angle: float, color: Color) -> void:
	var steps: int = 24
	var points: PackedVector2Array = PackedVector2Array()
	for step in range(steps + 1):
		points.append(centre + Vector2.from_angle(lerpf(from_angle, to_angle, float(step) / float(steps))) * outer_radius)
	for step in range(steps, -1, -1):
		points.append(centre + Vector2.from_angle(lerpf(from_angle, to_angle, float(step) / float(steps))) * inner_radius)
	draw_colored_polygon(points, color)


func _get_weapons() -> Node:
	if _weapons == null or not is_instance_valid(_weapons):
		_weapons = get_tree().get_first_node_in_group(GROUP_PLAYER_MELEE)
	return _weapons


func _get_order() -> Array[StringName]:
	var order: Array[StringName] = []
	var weapons: Node = _get_weapons()
	if weapons != null:
		order.assign(weapons.get(&"weapon_order"))
	return order


func _make_player(samples: PackedFloat32Array, volume_db: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = SoundSynth.make_wav(SoundSynth.normalize(samples))
	player.volume_db = volume_db
	add_child(player)
	return player
