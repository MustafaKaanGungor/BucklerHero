extends "res://Scripts/Enemies/melee_enemy.gd"

## Ranged enemy that throws enemy_projectile scenes at the player.
## Two styles:
## - direct (lob_throw off): a fast, almost straight throw at the player's chest. Dodge by moving sideways.
## - lob (lob_throw on): a high, slow arc that lands where the player's feet were when it was thrown,
##   usually with an explosion_radius so it hurts everything around the landing spot. Dodge by moving away.
## It keeps its distance (see the Positioning exports) and only throws with a clear line of sight.

@export_group("Projectile")
## Scene thrown at the player. Must have launch(from, velocity, thrower).
@export var projectile_scene: PackedScene = preload("res://Scenes/Enemies/enemy_projectile.tscn")
## Throw in a high arc that lands at the player's feet instead of straight at their chest.
@export var lob_throw: bool = false
## Direct throws: speed of the projectile.
@export var projectile_speed: float = 20.0
## Lobbed throws: seconds from throw to landing.
@export var lob_flight_time: float = 1.3
## Downward acceleration of the projectile. The throw is aimed to make up for it.
@export var projectile_gravity: float = 6.0
## Direct throws aim this far above the player's feet.
@export var aim_height: float = 1.1
## Random sideways error of each throw, in degrees.
@export var aim_spread_degrees: float = 0.8
## Height above the enemy's feet the projectile is thrown from.
@export var throw_height: float = 1.5
## How far in front of the body the projectile is thrown from.
@export var throw_forward_offset: float = 0.5
## Explosion radius given to the projectile. 0 keeps it a direct-hit projectile.
@export var explosion_radius: float = 0.0
## Share of the damage dealt at the edge of the explosion.
@export_range(0.0, 1.0) var explosion_edge_damage_ratio: float = 0.4


## Throws at where the player is right now. attack_damage is the projectile's damage.
func _strike() -> void:
	if not _has_living_target() or projectile_scene == null:
		return

	var origin: Vector3 = _get_attack_origin(throw_height, throw_forward_offset)
	var target_point: Vector3 = _target.global_position
	var launch_velocity: Vector3 = Vector3.ZERO
	var gravity_amount: float = maxf(projectile_gravity, 0.0)
	if lob_throw:
		# Lands exactly on target_point after lob_flight_time, if the player stands still.
		var flight_time: float = maxf(lob_flight_time, 0.05)
		launch_velocity = (target_point - origin) / flight_time
		launch_velocity.y += 0.5 * gravity_amount * flight_time
	else:
		target_point += Vector3.UP * aim_height
		var to_target: Vector3 = target_point - origin
		var flight_time: float = to_target.length() / maxf(projectile_speed, 0.1)
		launch_velocity = to_target.normalized() * maxf(projectile_speed, 0.1)
		launch_velocity.y += 0.5 * gravity_amount * flight_time

	var spread: float = deg_to_rad(randf_range(-aim_spread_degrees, aim_spread_degrees))
	launch_velocity = launch_velocity.rotated(Vector3.UP, spread)

	var projectile: Node3D = projectile_scene.instantiate() as Node3D
	if projectile == null:
		return
	projectile.set(&"damage", attack_damage)
	projectile.set(&"gravity", gravity_amount)
	projectile.set(&"explosion_radius", explosion_radius)
	projectile.set(&"explosion_edge_damage_ratio", explosion_edge_damage_ratio)
	var projectile_parent: Node = get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_parent()
	projectile_parent.add_child(projectile)
	projectile.call(&"launch", origin, launch_velocity, self)
	if lob_throw and projectile.has_method(&"set_landing_marker"):
		projectile.call(&"set_landing_marker", _target.global_position)
	attack_landed.emit(attack_damage)
