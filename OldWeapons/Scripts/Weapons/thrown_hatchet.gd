extends Node3D

## A thrown hatchet (both hatchets). Created by hatchet.gd, which owns all the rules; this node only
## flies and reports. States:
## - FLYING: a spinning arc (gravity), raycasting its path. The first hittable thing is reported to
##   the hatchet (hit_target) and the hatchet then drops; the level makes it drop too. With a
##   homing target (S rank) it steers straight at that enemy's chest and ignores gravity until the
##   enemy dies.
## - DROPPING: falls under gravity, bouncing off walls, until it lands on a floor.
## - LYING: on the ground with a small light; the player walking within pickup_radius picks it up
##   (hatchet.collect()).
## - RETURNING: flies back to the player's camera (the returning hatchet after a kill), then
##   hatchet.on_returned().

enum State { FLYING, DROPPING, LYING, RETURNING }

const GROUP_ENEMIES: StringName = &"enemies"

var speed: float = 22.0
var gravity: float = 9.0
var return_speed: float = 30.0
var pickup_radius: float = 1.4
var spin_speed: float = 16.0
var collision_mask: int = 1
var light_color: Color = Color(1.0, 0.85, 0.5)

var velocity: Vector3 = Vector3.ZERO
var state: int = State.FLYING
var _hatchet: Node
var _target: Node3D
var _excluded: Array[RID] = []
var _visual: Node3D
var _light: OmniLight3D
var _age: float = 0.0
var _state_age: float = 0.0


## visual: a Node3D (copy of the weapon's meshes) to show; target: enemy to home in on, or null.
func launch(hatchet: Node, from: Vector3, direction: Vector3, visual: Node3D, target: Node3D, excluded: Array[RID]) -> void:
	_hatchet = hatchet
	_target = target
	_excluded = excluded.duplicate()
	_visual = visual
	add_child(_visual)
	global_position = from
	velocity = direction.normalized() * speed
	_face(velocity)
	reset_physics_interpolation()
	_light = OmniLight3D.new()
	_light.light_color = light_color
	_light.light_energy = 0.0
	_light.omni_range = 2.5
	add_child(_light)


func is_lying() -> bool:
	return state == State.LYING


func is_returning() -> bool:
	return state == State.RETURNING


## Called by the hatchet after a killing hit (returning hatchet only).
func start_return() -> void:
	state = State.RETURNING
	_state_age = 0.0


func _physics_process(delta: float) -> void:
	if _hatchet == null or not is_instance_valid(_hatchet):
		queue_free()
		return
	_age += delta
	_state_age += delta
	match state:
		State.FLYING:
			_fly(delta)
		State.DROPPING:
			_drop(delta)
		State.LYING:
			_lie(delta)
		State.RETURNING:
			_return(delta)


func _fly(delta: float) -> void:
	var homing: bool = _target != null and is_instance_valid(_target) and not (_target.has_method(&"is_dead") and bool(_target.call(&"is_dead")))
	if homing:
		var chest: Vector3 = _target.global_position + Vector3.UP * 1.0
		velocity = (chest - global_position).normalized() * maxf(velocity.length(), speed)
	else:
		_target = null
		velocity.y -= gravity * delta
	_spin(delta)
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var hit: Dictionary = _cast(from, to)
	if hit.is_empty():
		global_position = to
		# Lost: flew off for too long (out of the level).
		if _age > 6.0:
			_hatchet.call(&"on_returned", self)
		return
	var collider: Node3D = hit.get("collider") as Node3D
	global_position = Vector3(hit.get("position", to)) - velocity.normalized() * 0.15
	if collider != null and (collider.has_method(&"on_melee_hit") or collider is RigidBody3D):
		var killed: bool = bool(_hatchet.call(&"hit_target", self, collider, Vector3(hit.get("position", to)), velocity.normalized()))
		if killed and state == State.RETURNING:
			return
		# Bounce off the enemy and fall.
		velocity = -velocity.normalized() * 2.0 + Vector3.UP * 2.5
	else:
		_hatchet.call(&"on_world_hit", self)
		velocity = velocity.bounce(Vector3(hit.get("normal", Vector3.UP))) * 0.25
	state = State.DROPPING
	_state_age = 0.0


func _drop(delta: float) -> void:
	velocity.y -= 22.0 * delta
	_spin(delta * 0.5)
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var hit: Dictionary = _cast(from, to, true)
	if hit.is_empty():
		global_position = to
		if _state_age > 6.0:
			_hatchet.call(&"on_returned", self)
		return
	var normal: Vector3 = Vector3(hit.get("normal", Vector3.UP))
	if normal.y > 0.6:
		_land(Vector3(hit.get("position", to)), normal)
		return
	# A wall: slide down it.
	global_position = Vector3(hit.get("position", to)) + normal * 0.1
	velocity = velocity.bounce(normal) * 0.3


func _land(point: Vector3, normal: Vector3) -> void:
	state = State.LYING
	_state_age = 0.0
	velocity = Vector3.ZERO
	global_position = point + normal * 0.06
	# Lies on its side: handle flat on the floor, pointing a random way.
	var yaw: Basis = Basis(Vector3.UP, randf() * TAU)
	global_basis = yaw * Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.FORWARD, PI * 0.5)
	if _visual != null:
		_visual.basis = Basis.IDENTITY
	reset_physics_interpolation()


func _lie(_delta: float) -> void:
	_light.light_energy = 0.8 + 0.4 * sin(_state_age * 4.0)
	var player: Node3D = _hatchet.call(&"get_player") as Node3D
	if player == null:
		return
	var offset: Vector3 = player.global_position - global_position
	if absf(offset.y) < 2.0 and Vector2(offset.x, offset.z).length() <= pickup_radius:
		_hatchet.call(&"collect", self)
	# Fell out of the level somehow: give it back.
	if global_position.y < player.global_position.y - 40.0:
		_hatchet.call(&"on_returned", self)


func _return(delta: float) -> void:
	var camera: Node3D = _hatchet.call(&"get_camera") as Node3D
	if camera == null:
		_hatchet.call(&"on_returned", self)
		return
	var target: Vector3 = camera.global_position + Vector3.DOWN * 0.3
	var to_target: Vector3 = target - global_position
	_spin(delta)
	if to_target.length() <= return_speed * delta + 0.6 or _state_age > 4.0:
		_hatchet.call(&"on_returned", self)
		return
	velocity = to_target.normalized() * return_speed
	global_position += velocity * delta


func _spin(delta: float) -> void:
	if _visual != null:
		_visual.rotate_object_local(Vector3.RIGHT, -spin_speed * delta)


func _face(direction: Vector3) -> void:
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() > 0.0001:
		global_basis = Basis.looking_at(flat.normalized(), Vector3.UP)


func _cast(from: Vector3, to: Vector3, ignore_enemies: bool = false) -> Dictionary:
	var excluded: Array[RID] = _excluded.duplicate()
	for _attempt in range(4):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask, excluded)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return hit
		var collider: Node = hit.get("collider") as Node
		var dead: bool = collider != null and collider.has_method(&"is_dead") and bool(collider.call(&"is_dead"))
		if collider != null and (dead or (ignore_enemies and collider.is_in_group(GROUP_ENEMIES))):
			excluded.append(hit.get("rid"))
			continue
		return hit
	return {}
