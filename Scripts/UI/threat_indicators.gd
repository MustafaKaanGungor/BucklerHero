extends Control

## Arrows around the crosshair pointing at enemies that are winding up an attack you can't see
## (outside the view or behind you). Each arrow sits on a ring at the enemy's direction (top =
## ahead, bottom = behind), fills up and turns from orange to red as the windup runs out, and
## flashes white when the attack comes out. Closer enemies get bigger arrows.
## Reads enemies (group enemies) through get_attack_telegraph() / is_striking() from
## melee_enemy.gd. Full-screen Control in the HUD that draws itself.

const GROUP_ENEMIES: StringName = &"enemies"
const METHOD_GET_ATTACK_TELEGRAPH: StringName = &"get_attack_telegraph"
const METHOD_IS_STRIKING: StringName = &"is_striking"

@export_group("Placement")
## Radius of the ring the arrows sit on, in pixels.
@export var ring_radius: float = 250.0
## An enemy whose chest projects inside the screen shrunk by this share on every side counts as
## seen, and gets no arrow (its own glow is visible).
@export_range(0.0, 0.4) var on_screen_margin: float = 0.06
## Height above the enemy's feet that is checked and pointed at.
@export var aim_height: float = 1.2
## Enemies further away than this get no arrow.
@export var max_distance: float = 40.0

@export_group("Look")
## Arrow length and width at full size, in pixels.
@export var arrow_length: float = 46.0
@export var arrow_width: float = 52.0
## Arrow size for an enemy at near_distance and at far_distance (metres); in between it blends.
@export var near_distance: float = 3.0
@export var far_distance: float = 25.0
@export var near_scale: float = 1.3
@export var far_scale: float = 0.7
## Colour early in the windup, just before the strike, and on the strike itself.
@export var start_color: Color = Color(1.0, 0.6, 0.1, 0.9)
@export var end_color: Color = Color(1.0, 0.1, 0.05, 1.0)
@export var strike_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Opacity of the empty part of an arrow.
@export_range(0.0, 1.0) var empty_alpha: float = 0.3

var _threats: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Arrows currently shown: Dictionaries with angle (radians, 0 = ahead, clockwise), progress (0..1),
## striking (bool) and distance (m). For tests and other HUD pieces.
func get_threats() -> Array[Dictionary]:
	return _threats


func _process(_delta: float) -> void:
	_threats.clear()
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var view_size: Vector2 = get_viewport_rect().size
		var margin: Vector2 = view_size * on_screen_margin
		var inner: Rect2 = Rect2(margin, view_size - margin * 2.0)
		var camera_basis: Basis = camera.global_transform.basis.orthonormalized()
		for node in get_tree().get_nodes_in_group(GROUP_ENEMIES):
			var enemy: Node3D = node as Node3D
			if enemy == null or not enemy.has_method(METHOD_GET_ATTACK_TELEGRAPH):
				continue
			var progress: float = float(enemy.call(METHOD_GET_ATTACK_TELEGRAPH))
			var striking: bool = enemy.has_method(METHOD_IS_STRIKING) and bool(enemy.call(METHOD_IS_STRIKING))
			if progress < 0.0 and not striking:
				continue
			var point: Vector3 = enemy.global_position + Vector3.UP * aim_height
			var offset: Vector3 = point - camera.global_position
			var distance: float = offset.length()
			if distance > max_distance:
				continue
			if not camera.is_position_behind(point) and inner.has_point(camera.unproject_position(point)):
				continue
			var local: Vector3 = camera_basis.inverse() * offset
			_threats.append({
				"angle": atan2(local.x, -local.z),
				"progress": 1.0 if striking else progress,
				"striking": striking,
				"distance": distance,
			})
	queue_redraw()


func _draw() -> void:
	var centre: Vector2 = size * 0.5
	for threat in _threats:
		var angle: float = float(threat["angle"])
		var progress: float = clampf(float(threat["progress"]), 0.0, 1.0)
		var distance_ratio: float = clampf((float(threat["distance"]) - near_distance) / maxf(far_distance - near_distance, 0.001), 0.0, 1.0)
		var arrow_scale: float = lerpf(near_scale, far_scale, distance_ratio)
		var outward: Vector2 = Vector2(sin(angle), -cos(angle))
		var side: Vector2 = Vector2(-outward.y, outward.x)
		var base: Vector2 = centre + outward * ring_radius
		var length: float = arrow_length * arrow_scale
		var half_width: float = arrow_width * 0.5 * arrow_scale
		var tip: Vector2 = base + outward * length
		var left: Vector2 = base + side * half_width
		var right: Vector2 = base - side * half_width

		var color: Color = strike_color if bool(threat["striking"]) else start_color.lerp(end_color, progress)
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(color, color.a * empty_alpha))
		# Fill from the base toward the tip as the windup runs out.
		var fill: float = 1.0 if bool(threat["striking"]) else progress
		if fill > 0.01:
			draw_colored_polygon(_fill_polygon(tip, left, right, fill), color)
		draw_polyline(PackedVector2Array([tip, left, right, tip]), Color(0.0, 0.0, 0.0, 0.7 * color.a), 2.0, true)


## The part of the arrow triangle from its base up to fill (0..1) of the way to the tip.
func _fill_polygon(tip: Vector2, left: Vector2, right: Vector2, fill: float) -> PackedVector2Array:
	if fill >= 1.0:
		return PackedVector2Array([tip, left, right])
	var top_left: Vector2 = left.lerp(tip, fill)
	var top_right: Vector2 = right.lerp(tip, fill)
	return PackedVector2Array([top_left, left, right, top_right])
