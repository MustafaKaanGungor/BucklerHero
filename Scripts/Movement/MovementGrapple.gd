extends Node

## Grapple rules for the hook's hold move (autoload MovementGrapple). The player state lives in
## player.gd (_is_grappling); this holds the tunables and the velocity math.
## Zip: while attack is held the player is pulled straight at the anchor, without gravity, up to
## zip_speed. Reaching it ends the grapple; an anchor on a top surface (a platform edge or box top)
## also pops the player up so they land on it.
## Swing: while jump is held too, the rope locks at its current length and the player swings under
## the anchor as a pendulum, with a little air control. Letting go of jump goes back to zipping.
## Release (attack let go): the grapple ends and the velocity stays, so wall runs, climbs and edge
## help take over naturally.

@export_group("Activation")
## Enables the hook's grapple.
@export var enable_grapple: bool = true
## Longest grapple shot (m).
@export var grapple_range: float = 20.0
## The grapple breaks if the rope gets longer than this (m).
@export var max_rope_length: float = 25.0

@export_group("Zip")
## Top speed toward the anchor (m/s).
@export var zip_speed: float = 24.0
## How quickly the zip reaches its speed (m/s²).
@export var zip_acceleration: float = 70.0
## Sideways speed (across the pull) lost per second, so the zip goes straight at the anchor.
@export var zip_side_damping: float = 6.0
## The zip ends this close to the anchor (m).
@export var arrive_distance: float = 1.3
## Least upward speed given on arrival at a top surface (m/s); more if needed to clear the top,
## up to top_arrival_max_pop.
@export var top_arrival_pop: float = 6.5
@export var top_arrival_max_pop: float = 14.0
## A top-surface anchor counts as reached once the player is this close to it horizontally (m).
@export var top_arrival_flat_distance: float = 1.0
## Forward speed kept on arrival at a top surface (m/s).
@export var top_arrival_forward_speed: float = 4.0
## Anchors whose surface normal points up more than this count as top surfaces (0..1).
@export_range(0.0, 1.0) var top_surface_normal_y: float = 0.6
## Also counts as a top surface: an anchor within this distance below a ledge top (m).
@export var ledge_search_height: float = 1.2

## Ropes shorter than this aren't cut by things in between (they bend over edges) (m).
@export var min_line_of_sight_distance: float = 3.0

@export_group("Swing")
## Gravity multiplier while swinging.
@export var swing_gravity_multiplier: float = 1.0
## Air control acceleration while swinging (m/s²).
@export var swing_air_control: float = 8.0
## How hard the rope pulls back when it has stretched past its length.
@export var rope_correction_strength: float = 10.0

@export_group("Stamina")
## Stamina spent when the grapple latches.
@export var latch_stamina_cost: float = 12.0
## Stamina per second while zipping and while swinging.
@export var zip_stamina_per_second: float = 6.0
@export var swing_stamina_per_second: float = 10.0


## Velocity for one zip step: accelerate along the line to the anchor, damp the rest.
func get_zip_velocity(velocity: Vector3, to_anchor: Vector3, delta: float) -> Vector3:
	if to_anchor.length_squared() <= 0.0001:
		return velocity
	var direction: Vector3 = to_anchor.normalized()
	var along: float = velocity.dot(direction)
	var side: Vector3 = velocity - direction * along
	side *= exp(-maxf(zip_side_damping, 0.0) * delta)
	along = move_toward(maxf(along, 0.0), maxf(zip_speed, 0.0), maxf(zip_acceleration, 0.0) * delta)
	return direction * along + side


## Velocity for one swing step: gravity, air control along wish_direction, and the rope.
## from_anchor = player point - anchor.
func get_swing_velocity(velocity: Vector3, from_anchor: Vector3, rope_length: float, wish_direction: Vector3, gravity: float, delta: float) -> Vector3:
	var result: Vector3 = velocity
	result.y -= gravity * maxf(swing_gravity_multiplier, 0.0) * delta
	if wish_direction.length_squared() > 0.0001:
		result += Vector3(wish_direction.x, 0.0, wish_direction.z).normalized() * maxf(swing_air_control, 0.0) * delta
	var distance: float = from_anchor.length()
	if distance <= 0.001 or distance < rope_length:
		return result
	var radial: Vector3 = from_anchor / distance
	var outward: float = result.dot(radial)
	if outward > 0.0:
		result -= radial * outward
	# Pull back in when the rope has stretched (numerical drift, collisions).
	result -= radial * (distance - rope_length) * maxf(rope_correction_strength, 0.0)
	return result


## Upward speed that lifts the feet rise metres (with some margin), clamped to the pop range.
func get_top_arrival_pop(rise: float) -> float:
	var gravity: float = WorldBasicRules.get_gravity() * 1.4
	return clampf(sqrt(2.0 * gravity * maxf(rise, 0.0)), top_arrival_pop, top_arrival_max_pop)


func is_top_surface(normal: Vector3) -> bool:
	return normal.y >= top_surface_normal_y
