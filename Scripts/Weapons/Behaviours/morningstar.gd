extends "res://Scripts/Weapons/Behaviours/weapon_behaviour.gd"

## Morningstar: crowd scatterer. A slow, wide flail sweep whose hits knock enemies away hard
## (knockback_multiplier on the hit) and lift them a little, scattering a group.
## S rank: every enemy it hits becomes a projectile for thrown_damage_time seconds: other enemies it
## crashes into take thrown_damage (dummy_enemy.set_thrown_damage, reported as morningstar hits).
## The ball swings on its chain a little after each attack (ball_path).

@export_group("Knockback")
## Multiplies the hit enemy's knockback speed.
@export var knockback_multiplier: float = 3.0
## Upward speed given to light enemies it hits, so they fly instead of sliding (m/s).
@export var launch_speed: float = 3.5

@export_group("Thrown Enemies (S Rank)")
## Damage a thrown enemy deals to each enemy it crashes into.
@export var thrown_damage: float = 2.0
## Seconds a hit enemy keeps hurting what it crashes into.
@export var thrown_damage_time: float = 0.8

@export_group("Ball")
## Node of the chain and ball, swung around by the attack.
@export var ball_path: NodePath = NodePath("Chain")
## How far the ball swings out (degrees) and how fast it settles.
@export var ball_swing_degrees: float = 70.0
@export var ball_settle_speed: float = 6.0

var _ball: Node3D
var _ball_rest: Basis
var _ball_angle: float = 0.0
var _ball_velocity: float = 0.0


func setup(owner_weapons: Node) -> void:
	super.setup(owner_weapons)
	_ball = get_node_or_null(ball_path) as Node3D
	if _ball != null:
		_ball_rest = _ball.basis
	weapons.connect(&"attack_started", _on_attack_started)


func _on_attack_started(started_weapon: StringName) -> void:
	if started_weapon == weapon_id:
		_ball_velocity = -deg_to_rad(ball_swing_degrees) * 6.0


func modify_hit(hit_info: Dictionary, _target: Node3D) -> Dictionary:
	hit_info["knockback_multiplier"] = knockback_multiplier
	return hit_info


func on_hit_landed(target: Node3D, _hit_info: Dictionary, killed: bool) -> void:
	if killed or target == null or not is_instance_valid(target):
		return
	var heavy: bool = target.has_method(&"is_shield_charge_blocker") and bool(target.call(&"is_shield_charge_blocker"))
	if not heavy and target.has_method(&"apply_launch"):
		target.call(&"apply_launch", launch_speed)
	if bool(weapons.call(&"is_attack_empowered")) and target.has_method(&"set_thrown_damage"):
		target.call(&"set_thrown_damage", thrown_damage, thrown_damage_time, weapons)


func _process(delta: float) -> void:
	if _ball == null:
		return
	# A damped spring: the attack kicks it, it swings back and settles.
	_ball_velocity += -_ball_angle * 60.0 * delta
	_ball_velocity *= exp(-maxf(ball_settle_speed, 0.0) * delta)
	_ball_angle += _ball_velocity * delta
	_ball.basis = Basis(Vector3.FORWARD, _ball_angle) * _ball_rest
