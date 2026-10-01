extends Node3D

## Health pickup placed by level_generator.gd. Walk into it to heal.
## It is only taken when the player is missing health, so it can't be wasted at full health.
## Builds its own look (a glowing box with a white cross) and bobs and spins in place.
## reset_pack() puts it back; level sections call it when the player dies and the section restarts.

signal picked_up(heal_amount: float)

const GROUP_PLAYER: StringName = &"player"

@export_group("Pickup")
## Health given back. The player has 100.
@export var heal_amount: float = 35.0
## Horizontal distance from the player at which it is picked up.
@export var pickup_radius: float = 1.3
## Height difference at which it can still be picked up.
@export var pickup_height: float = 2.0

@export_group("Sound")
## Volume of the pickup chime in decibels.
@export var pickup_volume_db: float = -8.0
## Random pitch change per pickup, so repeated pickups don't sound identical.
@export_range(0.0, 0.5) var pickup_pitch_variation: float = 0.04

@export_group("Look")
## Colour of the box.
@export var pack_color: Color = Color(0.2, 0.9, 0.35)
## Height the pack floats at.
@export var float_height: float = 0.7
## How far it bobs up and down.
@export var bob_amount: float = 0.12
## Bobs per second.
@export var bob_speed: float = 1.6
## Spin in degrees per second.
@export var spin_degrees: float = 90.0

## The project has no audio files, so the chime is synthesized once and shared by every pack.
static var _pickup_sound: AudioStreamWAV

var _visual: Node3D
var _light: OmniLight3D
var _sound_player: AudioStreamPlayer
var _is_taken: bool = false
var _time: float = 0.0
var _player: Node3D


func _ready() -> void:
	_build_visual()
	_sound_player = AudioStreamPlayer.new()
	_sound_player.stream = _get_pickup_sound()
	_sound_player.volume_db = pickup_volume_db
	add_child(_sound_player)


func is_taken() -> bool:
	return _is_taken


func reset_pack() -> void:
	_is_taken = false
	if _visual != null:
		_visual.show()


func _physics_process(_delta: float) -> void:
	if _is_taken:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(GROUP_PLAYER) as Node3D
	if _player == null or HealthManager.is_dead():
		return
	if HealthManager.get_health() >= HealthManager.get_max_health():
		return

	var offset: Vector3 = _player.global_position - global_position
	if absf(offset.y) > pickup_height:
		return
	if Vector2(offset.x, offset.z).length() > pickup_radius:
		return

	_is_taken = true
	HealthManager.heal(heal_amount)
	if _visual != null:
		_visual.hide()
	_sound_player.pitch_scale = 1.0 + randf_range(-pickup_pitch_variation, pickup_pitch_variation)
	_sound_player.play()
	picked_up.emit(heal_amount)


func _process(delta: float) -> void:
	if _visual == null or _is_taken:
		return
	_time += delta
	_visual.position.y = float_height + sin(_time * TAU * bob_speed) * bob_amount
	_visual.rotation.y = wrapf(_visual.rotation.y + deg_to_rad(spin_degrees) * delta, -PI, PI)


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var box_material: StandardMaterial3D = StandardMaterial3D.new()
	box_material.albedo_color = pack_color
	box_material.emission_enabled = true
	box_material.emission = pack_color
	box_material.emission_energy_multiplier = 1.2
	_add_mesh(Vector3(0.5, 0.5, 0.5), Vector3.ZERO, box_material)

	var cross_material: StandardMaterial3D = StandardMaterial3D.new()
	cross_material.albedo_color = Color.WHITE
	cross_material.emission_enabled = true
	cross_material.emission = Color.WHITE
	cross_material.emission_energy_multiplier = 1.5
	# A cross on each of the four sides.
	for side in range(4):
		var holder: Node3D = Node3D.new()
		holder.rotation.y = float(side) * PI * 0.5
		_visual.add_child(holder)
		_add_mesh(Vector3(0.3, 0.09, 0.02), Vector3(0.0, 0.0, 0.255), cross_material, holder)
		_add_mesh(Vector3(0.09, 0.3, 0.02), Vector3(0.0, 0.0, 0.255), cross_material, holder)

	_light = OmniLight3D.new()
	_light.light_color = pack_color
	_light.light_energy = 1.5
	_light.omni_range = 3.0
	_visual.add_child(_light)
	_visual.position.y = float_height


## A short, soft rising chime: three quick sine notes (E5, G#5, B5) that ring into each other.
static func _get_pickup_sound() -> AudioStreamWAV:
	if _pickup_sound != null:
		return _pickup_sound

	var mix_rate: int = 44100
	var length: float = 0.55
	var notes: Array[float] = [659.25, 830.61, 987.77]
	var note_spacing: float = 0.065
	var sample_count: int = int(length * float(mix_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for sample in range(sample_count):
		var time: float = float(sample) / float(mix_rate)
		var value: float = 0.0
		for note_index in range(notes.size()):
			var note_time: float = time - float(note_index) * note_spacing
			if note_time < 0.0:
				continue
			var frequency: float = notes[note_index]
			# Quick fade-in to avoid a click, then an exponential ring-out.
			var envelope: float = minf(note_time / 0.006, 1.0) * exp(-note_time * 9.0)
			var tone: float = sin(TAU * frequency * note_time) + 0.25 * sin(TAU * frequency * 2.0 * note_time)
			value += tone * envelope * 0.32
		# Fade the tail so the sample ends on silence.
		value *= clampf((length - time) / 0.05, 0.0, 1.0)
		data.encode_s16(sample * 2, int(clampf(value, -1.0, 1.0) * 32767.0))

	_pickup_sound = AudioStreamWAV.new()
	_pickup_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_pickup_sound.mix_rate = mix_rate
	_pickup_sound.stereo = false
	_pickup_sound.data = data
	return _pickup_sound


func _add_mesh(size: Vector3, offset: Vector3, material: StandardMaterial3D, parent: Node3D = null) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _visual).add_child(instance)
