class_name MeleeAttackData
extends Resource

## Tunables for one melee attack: timing, hit area, effect on targets and viewmodel animation.
## melee_weapons.gd holds one of these per weapon; the values live in melee_weapons.tscn.
## All positions and directions are in camera space: +X right, +Y up, -Z forward.

enum HitArea {
	## Wide horizontal fan in front of the camera (sword sweep).
	ARC,
	## Box that starts at the camera and reaches forward (halberd thrust, shield bash).
	BOX,
}

@export_group("Timing")
## Seconds the weapon takes to pull back before the strike.
@export var windup_time: float = 0.14
## Seconds of the strike itself. Hits only land during this part.
@export var strike_time: float = 0.2
## Seconds the weapon takes to return to idle after the strike. This weapon can't attack again
## until it is over, unless an attack with a different weapon resets it.
@export var recover_time: float = 1.0

@export_group("Hit Area")
@export var hit_area: HitArea = HitArea.ARC
## How far the attack reaches from the camera, in meters.
@export var reach: float = 2.5
## ARC: total horizontal angle covered, centered on where the camera looks.
@export_range(1.0, 360.0) var arc_degrees: float = 140.0
## ARC: how far above and below the view line the fan reaches at full reach, in meters.
@export var arc_height: float = 1.0
## ARC: angle between neighboring hit rays. Smaller catches thinner targets.
@export var ray_spacing_degrees: float = 5.0
## ARC: hits land as the swing passes each target, starting on the right and ending on the left.
@export var sweep_right_to_left: bool = true
## BOX: width and height of the hit box in meters. Its length is the reach.
@export var box_size: Vector2 = Vector2(0.6, 0.6)
## BOX: moves the hit box away from the camera's view line, for example down to cover the body.
@export var box_offset: Vector3 = Vector3.ZERO
## Hit rays per side: ARC stacks this many rows, BOX uses a grid of this many rows and columns.
@export var ray_rows: int = 3

@export_group("Effect")
## Damage passed to objects that implement on_melee_hit(hit_info).
@export var damage: float = 1.0
## Impulse applied to RigidBody3D objects that get hit.
@export var physics_impulse: float = 6.0
## Direction hit objects are pushed in, in camera space.
@export var impulse_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
## Meters the player dashes forward when the strike starts. 0 disables the dash.
## The distance is the same on the ground and in the air.
@export var dash_distance: float = 0.0
## Seconds the dash takes. It starts fast and eases out.
@export var dash_duration: float = 0.2
## Seconds the swing and the enemy it hits freeze when the hit lands (hit-stop). 0 disables it.
@export var hit_stop_time: float = 0.07
## Freeze again for every enemy hit, one after another (sword sweep).
## Off: the swing freezes only on its first hit; every enemy hit still freezes.
@export var hit_stop_every_hit: bool = false
## Screen shake when the attack hits, from 0 (none) to 1 (strongest). Follows hit_stop_every_hit:
## with it on every enemy hit shakes again (sword sweep), otherwise only the first hit shakes.
@export_range(0.0, 1.0) var hit_screen_shake: float = 0.0
## Loudness added to the stealth meter when the swing starts.
@export var swing_loudness: float = 6.0
## Loudness added to the stealth meter for a swing that hits something.
@export var hit_loudness: float = 22.0

@export_group("Animation")
## Offset from the idle pose at the end of the windup.
@export var windup_position: Vector3 = Vector3.ZERO
## Rotation added to the idle pose at the end of the windup. -X tips the weapon forward, +Y turns it left.
@export var windup_rotation_degrees: Vector3 = Vector3.ZERO
## Offset from the idle pose at the end of the strike.
@export var strike_position: Vector3 = Vector3.ZERO
## Rotation added to the idle pose at the end of the strike.
@export var strike_rotation_degrees: Vector3 = Vector3.ZERO
## Camera kick when the strike starts. It springs back on its own.
@export var camera_kick_rotation_degrees: Vector3 = Vector3.ZERO


## Seconds the whole attack takes, from the first frame of windup until the weapon is idle again.
func get_duration() -> float:
	return maxf(maxf(windup_time, 0.0) + maxf(strike_time, 0.0) + maxf(recover_time, 0.0), 0.001)


func get_half_arc_degrees() -> float:
	return clampf(arc_degrees, 1.0, 360.0) * 0.5


## Point in the attack (0-1) where the windup ends and the strike starts.
func get_windup_end() -> float:
	return clampf(maxf(windup_time, 0.0) / get_duration(), 0.0, 0.98)


## Point in the attack (0-1) where the strike ends and the recover starts.
func get_strike_end() -> float:
	var strike_end: float = (maxf(windup_time, 0.0) + maxf(strike_time, 0.0)) / get_duration()
	return clampf(strike_end, get_windup_end() + 0.001, 1.0)


## 0 before the strike, 1 once it has finished.
func get_strike_progress(attack_progress: float) -> float:
	var strike_start: float = get_windup_end()
	return clampf((attack_progress - strike_start) / maxf(get_strike_end() - strike_start, 0.001), 0.0, 1.0)


func is_strike_active(attack_progress: float) -> bool:
	return attack_progress >= get_windup_end() and attack_progress <= get_strike_end()
