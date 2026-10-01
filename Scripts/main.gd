extends Node3D

@export var player_scene: PackedScene = preload("res://Scenes/player.tscn")
@export var player_spawn_path: NodePath = NodePath("PlayerSpawn")

var player: CharacterBody3D


func _ready() -> void:
	spawn_player()
	HealthManager.died.connect(_on_player_died)


## Death sends the player back to the spawn point with full health and stamina. Enemies stay as they are.
func _on_player_died() -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.has_method(&"stop_shield_charge"):
		player.call(&"stop_shield_charge")
	player.velocity = Vector3.ZERO
	_place_player_at_spawn(player)
	player.reset_physics_interpolation()
	HealthManager.reset_health()
	StaminaManager.reset_stamina()


func spawn_player() -> void:
	if player != null and is_instance_valid(player):
		_place_player_at_spawn(player)
		return

	var existing_player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
	if existing_player != null:
		player = existing_player
		_place_player_at_spawn(player)
		return

	var spawned: Node = player_scene.instantiate()
	player = spawned as CharacterBody3D
	if player == null:
		push_error("Player scene root must be a CharacterBody3D.")
		spawned.queue_free()
		return

	add_child(player)
	player.name = "Player"
	_place_player_at_spawn(player)


func _place_player_at_spawn(player_body: CharacterBody3D) -> void:
	var spawn_node: Node3D = get_node_or_null(player_spawn_path) as Node3D
	var spawn_position: Vector3 = global_position
	var spawn_yaw: float = global_rotation.y

	if spawn_node != null:
		spawn_position = spawn_node.global_position
		spawn_yaw = spawn_node.global_transform.basis.orthonormalized().get_euler().y

	player_body.top_level = true
	player_body.scale = Vector3.ONE
	player_body.global_transform = Transform3D(
		Basis(Vector3.UP, spawn_yaw),
		spawn_position + Vector3.UP * WorldBasicRules.get_spawn_height_offset()
	)

	var head_node: Node = player_body.get_node_or_null("Head")
	if head_node != null and head_node.has_method(&"sync_with_player_rotation"):
		head_node.call(&"sync_with_player_rotation")
