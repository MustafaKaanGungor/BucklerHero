# Old weapons

The game now revolves around the **shield**. Every other weapon was taken out of the live game and parked in `OldWeapons/` so its mechanics can be reused later. This file explains what each one did in play and how its code worked.

- `OldWeapons/` has a `.gdignore`, so Godot skips it entirely. Nothing in it is loaded, parsed or shown in the editor's FileSystem dock, so errors in these files can't break the game.
- The last commit with every weapon working is **`52e9f9a`** ("added porject"). `git checkout 52e9f9a` gives the full playable version; `git show 52e9f9a:<path>` shows any single file as it was.

## What's in the folder

| Path | What it is |
|---|---|
| `OldWeapons/Scripts/Weapons/Behaviours/` | The behaviour weapons: `war_hammer.gd`, `sickle_dagger.gd`, `morningstar.gd`, `war_axe.gd`, `hatchet.gd` (both hatchets), `hook.gd`, `talons.gd` |
| `OldWeapons/Scripts/Weapons/` | Helpers they spawned: `sword_wave.gd` (broadsword S rank), `crossbow_bolt.gd` (crossbow and thrown daggers), `thrown_hatchet.gd`, `hammer_quake.gd`, `hook_rope.gd`; and the dormant pistol: `pistol.gd`, `projectile.gd`, `impact_decal.gd` |
| `OldWeapons/Scripts/Movement/MovementGrapple.gd` | The hook's grapple autoload (tunables and math) |
| `OldWeapons/Scenes/Weapons/` | `pistol.tscn`, `projectile.tscn`, `impact_decal.tscn` |
| `OldWeapons/Scripts/UI/ammo_counter.gd` | The pistol's HUD ammo counter (was `HudRoot/AmmoCounter` in `ui.tscn`) |
| `OldWeapons/SharedFilesSnapshot/` | Copies of every shared file **before** the old-weapon code was cut out of it (same relative paths). Use these to see or copy the stripped parts. |

The `.uid` files moved with their scripts. Paths inside the parked scripts still point at their old locations (for example `res://Scripts/Weapons/hammer_quake.gd`), so put files back where they were, or fix the paths, before using them.

### What was cut from shared files (see the snapshot copies)

| Live file | What was removed |
|---|---|
| `Scripts/Weapons/melee_weapons.gd` | Broadsword, halberd, crossbow and pistol: constants, `*_path` / `*_attack` exports, the `Empowered (S Rank)` sword/halberd exports, the `Crossbow` export group, registration, sword wave (`_launch_sword_wave`, `on_sword_wave_hit`), halberd empowered dash (`_empowered_dash_timer`, `_pass_through`, `_update_dash_pass_through`, `_get_damage_multiplier`), crossbow (`attack()` dry-fire / `spend_all`, `_fire_crossbow_bolt`, `on_crossbow_bolt_hit`, `on_crossbow_bolt_explosion`, signals `crossbow_fired` / `crossbow_dry_fired` / `crossbow_explosion`), pistol holstering, `on_weapon_projectile_hit`, the `WEAPON_*` ids of the behaviour weapons. |
| `Scenes/Weapons/melee_weapons.tscn` | Nodes `Broadsword`, `Halberd`, `Crossbow`, `WarHammer`, `SickleDagger`, `Morningstar`, `WarAxe`, `Hatchet`, `ReturningHatchet`, `Hook`, `Talons`, their `MeleeAttackData` sub-resources and all their `BoxMesh` / material sub-resources, and the sword model ext_resource. |
| `Scripts/Audio/melee_audio.gd` | Every sound except the shield's (all synthesized, see each weapon below). |
| `Scripts/player.gd` | Grapple state and API, pounce state and API, `_sync_talon_bonus`, `WEAPON_TALONS`, `set_vertical_velocity`, `get_airborne_highest_y`. |
| `Scripts/Movement/MovementWallRun.gd`, `MovementClimb.gd` | The `Talons` export groups and `set_talon_bonus()`. |
| `StaminaManager.gd` | `spend_grapple()`, `drain_grapple()`. |
| `project.godot` | The `MovementGrapple` autoload. |
| `Scripts/Enemies/dummy_enemy.gd`, `melee_enemy.gd` | `apply_launch()`, `on_hook_pull()` (and the timed pull), `set_thrown_damage()` / `_update_thrown_damage()`. |
| `Scripts/DataScripts/ComboMeter.gd` | `unscored_weapons` emptied (was `[crossbow, thrown_dagger]`). |
| `Scripts/UI/loadout_screen.gd`, `weapon_wheel.gd`, `combo_meter_hud.gd` | Card texts / colours and wheel names of the old weapons; the HUD's "NEED COMBO" hook-up to `crossbow_dry_fired`. |

### What stayed live (shared machinery, usable by future weapons)

- **Switching and loadout:** keys 1–9, Q / mouse wheel, middle-mouse selector wheel, loadout screen. They list only the shield for now.
- **Behaviour-weapon framework:** `Scripts/Weapons/Behaviours/weapon_behaviour.gd` and its hooks in `melee_weapons.gd`: press modes (`PRESS`, `CLICK_OR_HOLD`, `HOLD_ONLY`, `HOLD_WHEN_EMPOWERED`), `repeat_while_held`, availability, `holster_all`, `switch_away_from`, and the services `deliver_hit`, `find_aimed_enemy`, `register_custom_attack`, `set_attack_data`, `set_recover`, `spawn_in_world`, `add_screen_shake`, `add_camera_kick`, `reset_behaviours`.
- **Other pieces:**
  - the player's weapon speed multiplier (`get_move_speed_multiplier`);
  - `ComboMeter.spend_all()`;
  - the enemies' `is_staggered()` and `hit_info["knockback_multiplier"]`;
  - the F1 S-rank cheat.

**Combo meter change:** the shield-only game turns off the same-weapon cap (`ComboMeter.enable_same_weapon_cap = false`). Repeated shield bashes now score like weapon switches: 70 for the first hit of an attack and 30 for each further hit. Set it to `true` to bring back the old rule, where only switching weapons got you past D.

---

## How the weapon system worked (all weapons)

- **Combo rule:** each attack has a long recover (about 1 s) before the same weapon can attack again. Attacking with a *different* weapon resets every other weapon's recover, so alternating weapons is fast. The combo meter rewarded this: 70 for the first hit of a switch attack, 30 for further hits, and same-weapon hits only 20 and only up to 99, so one weapon alone stayed at D.
- **S rank (empowered):** at rank S an attack was "empowered". Each weapon had its own S-rank effect, signalled by `empowered_attack_started(weapon_id)`, and every weapon model got a pulsing orange overlay.
- **Hit detection:** raycasts from the camera, a fan for `ARC` attacks and a grid for `BOX` attacks. Hits call `on_melee_hit(hit_info)` on enemies and push `RigidBody3D` props. Hits freeze both the enemy and the swing (hit-stop) and shake the screen.
- **Sounds:** synthesized in `melee_audio.gd` as `swing_<id>`, `hit_<id>` and `empowered_<id>`.
- **Models:** greybox `BoxMesh` parts, except the broadsword, which used Kenney's `weapon-sword.glb`, stretched.
- **Behaviour weapons:** the hammer, sickle and dagger, morningstar, axe, hatchets, hook and talons were child nodes of `MeleeWeapons` with a script extending `weapon_behaviour.gd`. `melee_weapons._register_behaviour_weapons()` found them by their `get_press_mode` method and registered them using their `weapon_id` and `attack_data` exports, so adding one needed no edits in `melee_weapons.gd`.

---

## Broadsword

**In game:** wide crowd cutter.
- **Attack:** a 150° sweep, right to left, 3.3 m reach, 1 damage. It freezes 0.1 s on *every* enemy it passes, so a sweep through three enemies stutters three times in order. Recover 0.9 s.
- **S rank:** every swing also throws a glowing crescent **slash wave**: 28 m/s, 22 m range, 3.2 m wide, 3 damage to each enemy it passes through.

**Code:**
- **Attack data** (`Resource_broadsword_attack`): `ARC`, `arc_degrees` 150, `sweep_right_to_left`, `hit_stop_every_hit`, shake 0.3.
- **Sweep:** `_cast_arc_rays` (still live) only casts the columns the swing has passed since the last tick, which gives the right-to-left order.
- **Slash wave:** `_launch_sword_wave()` (snapshot of `melee_weapons.gd`) spawns `sword_wave.gd` 1.2 m ahead and 0.45 m below the camera, with pitch clamped to −12°..30°.
  - It is a translucent ribbon mesh built in code that raycasts a 5 × 3 grid over its motion each tick, bowed like the crescent.
  - It passes through hittable things, dies against the level with a flare, and fades over the last 30 % of its range.
  - Its hits go to `on_sword_wave_hit()`, which emits `attack_hit` (sound and combo) with no hit-stop.

## Halberd

**In game:** long reach and lunge.
- **Attack:** a 4.2 m thrust (box 0.55 × 0.55) for 2 damage that pierces a line of enemies, with a 2.6 m forward dash over 0.2 s.
- **S rank:** the lunge is 4× as long (10.4 m over 0.4 s). It keeps hitting for the whole dash at double damage and passes *through* the enemies it hits.

**Code:**
- **Attack data:** `BOX` with `dash_distance` / `dash_duration`. `_start_strike` calls `player.start_dash()`; the dash itself is still live in `player.gd`.
- **Empowered lunge:** `_empowered_dash_timer` keeps `_update_attack_hits(…, 1.0)` running through the dash, and `_get_damage_multiplier` doubles the damage.
- **Passing through:** `_pass_through` adds mutual collision exceptions between the player and each enemy hit. `_update_dash_pass_through` removes them 0.3 s after the dash, checking `is_instance_valid` first because killed enemies are freed.

## Crossbow

**In game:** a combo spender.
- **Empty meter:** it can't fire; you get a dry click and a red "NEED COMBO" message.
- **Firing:** each shot spends the **whole** meter. Damage depends on the rank it was fired at: D 2, C 3, B 5, A 8, S 12.
- **S rank:** the bolt is explosive: 6 m blast, 10 damage at the centre falling to 40 % at the edge, only enemies with a clear line from the blast, and props get shoved.
- **Combo:** bolt hits never score.

**Code:**
- **Firing:** in `melee_weapons.gd`, `attack()` checks `ComboMeter.get_rank() < 0` (dry fire, `crossbow_dry_fired`, 0.3 s cooldown), otherwise `_crossbow_rank = ComboMeter.spend_all()`. `_start_strike` calls `_fire_crossbow_bolt(rank)`, which aims at what the screen centre points at (a 200 m ray).
- **The bolt:** `crossbow_bolt.gd` flies at 80 m/s with gravity 2 and raycasts each tick. The first hittable thing it meets is reported to `report_method` (default `on_crossbow_bolt_hit`). The level stops it and it stays stuck 3 s.
- **Explosion:** `_explode()` loops over group `enemies` with line-of-sight rays, then sphere-queries props. It also has `stick_in_world`, `shaft_length` and `weapon_id` settings, used for the daggers.
- **Combo:** `ComboMeter.unscored_weapons` had `crossbow`. Sounds: `swing_crossbow` twang, `hit_crossbow`, `empowered_crossbow` whine, `dry_crossbow` click.

## War hammer (`war_hammer.gd`, `HOLD_ONLY`)

**In game:** heavy breaker with no click attack.
- **Charging:** hold to raise and charge while walking slowly at 0.55× speed, with no sprint. A full charge (1.2 s) can be held forever.
- **Slam:** releasing after 0.35 s slams 1.6 m ahead.
  - The shockwave grows from 1.5 to 4 m and does 3 → 6 damage, 70 % at the edge.
  - It launches light enemies upward at 4 → 8 m/s.
  - A full charge staggers brutes and mortars and gives 40 combo points.
- **Plunge:** releasing in the air drives you down at 22 m/s and slams on landing. It gets +0.5 damage and +0.35 m radius per metre fallen from the top of the jump (capped at +3 and +2).
- **S rank:** a **quake line** rolls forward: 8 bursts, 1.4 m apart, every 0.06 s, each 1.5 m wide for 2 damage plus a launch. A wall stops it.

**Code:**
- **Charge:** `on_hold_started` / `on_hold_updated` count the charge. `get_move_speed_multiplier` slows the player through the live weapon speed multiplier. `get_pose_offset` raises the model, with a tremble at full charge.
- **Release:** `on_hold_released` calls `start_attack()`, or, in the air, sets `player.set_vertical_velocity(-22)` (removed from the player) and waits for `is_on_floor` in `behaviour_physics_process`.
- **Slam:** `on_strike_started` → `_slam()` → `burst()`, which loops over enemies with line of sight, `deliver_hit`, `apply_launch` (removed from enemies) and `on_shield_charge_impact` for heavies; then `_push_props` and a ring visual (`spawn_ring`, a `TorusMesh`).
- **Quake:** `hammer_quake.gd` walks along the floor with wall and floor rays and calls `hammer.burst()` per pulse, with a rock spike visual.
- **Sounds:** the hammer synthesizes its own charge rumble, full-charge ping and slam boom.

## Sickle and dagger (`sickle_dagger.gd`, `HOLD_WHEN_EMPOWERED`, `repeat_while_held`)

**In game:** fast duelist.
- **Cuts:** quick alternating cuts, sickle right-to-left and dagger left-to-right: 0.6 damage, 0.42 s per cut, 2.6 m, 100°. Holding the button keeps cutting.
- **Execute:** triple damage on staggered enemies (any weapon's stagger counts).
- **S rank:** holding the button throws daggers like a machine gun: one every 0.08 s with 1.5° spread, 1.5 damage, 70 m/s, alternating hands. Dagger hits don't score, so the stream can't keep S going on its own.

**Code:**
- **Alternating hands:** the `Right` and `Left` child nodes are animated by the script; the attack data poses are zero. Each `attack_started` swaps `attack_data` and `left_attack_data` through `set_attack_data`.
- **Execute:** `modify_hit` multiplies damage when `target.is_staggered()`.
- **Dagger stream:** `on_hold_started` refuses below S. `on_hold_updated` throws `crossbow_bolt.gd` instances with `weapon_id` `thrown_dagger`, `stick_in_world` false, no gravity and `report_method` `on_weapon_projectile_hit` (removed from melee_weapons), and stops when the rank drops.

## Morningstar (`morningstar.gd`)

**In game:** crowd scatterer.
- **Attack:** a slow, wide flail swing: 160°, 3 m, 2 damage, recover 1.0 s. It knocks enemies about 3 m away (3× knockback plus a 3.5 m/s lift).
- **S rank:** enemies it hits become projectiles for 0.8 s and deal 2 damage to every enemy they crash into.

**Code:**
- **Knockback:** `modify_hit` sets `knockback_multiplier` 3, which is still live in `dummy_enemy.on_melee_hit`. `on_hit_landed` calls `apply_launch(3.5)`.
- **S rank:** `on_hit_landed` also calls `set_thrown_damage(2, 0.8, weapons)`. In `dummy_enemy` (removed), `_update_thrown_damage` checked slide collisions with other enemies and called `deliver_hit(&"morningstar", …)` on each one, once.
- **Model:** the `Chain` child swings on a spring after each attack.

## War axe (`war_axe.gd`)

**In game:** cleaver.
- **Attack:** a heavy diagonal cleave, 2 damage, scaled by how hurt the enemy already is: ×(1 + missing health share), so 3.5 against an enemy at 25 % health.
- **S rank:** ×1.5 damage, and every axe kill heals 10.

**Code:**
- **Damage:** `modify_hit` reads `get_health()` and `max_health`.
- **Healing:** `on_hit_landed(…, killed)` calls `HealthManager.heal(10)` when the attack was empowered. "Killed" comes from melee_weapons comparing alive-before with dead-or-freed-after, which is still live.

## Hatchet and returning hatchet (`hatchet.gd`, `thrown_hatchet.gd`)

**In game:** throwing weapons.
- **Throw:** thrown in an arc (22 m/s, gravity 9) that comes down where the crosshair points. The hatchet does 4 damage; the returning hatchet 2.5.
- **While it's out:** the weapon can't be selected by keys, Q or the wheel, and you switch to the weapon you used before (or to empty hands if it was your only one).
- **Pickup:** it drops where it hits. Walking over it picks it up and puts it in your hand.
- **Returning hatchet:** a kill sends it flying back. It goes into your hand if you haven't switched since the throw; otherwise it just becomes available again.
- **S rank:** homes in on the enemy nearest the crosshair (within 8° and 40 m).
- **Telling them apart:** the plain hatchet has a steel head and dark handle; the returning one has a glowing blue head and a light handle. The loadout cards had matching colour strips.

**Code:**
- **Throw:** `hatchet.gd` sets `returns_on_kill` per node. `on_strike_started` aims with `_get_throw_direction`: the line to the aim point, tilted up by the angle that makes up for the drop. It spawns `thrown_hatchet.gd` with a copy of the node's meshes, then calls `switch_away_from` deferred.
- **Availability:** `is_available()` is false while a projectile exists.
- **Projectile states:**
  - FLYING: raycasts; a hit calls `hatchet.hit_target` → `deliver_hit`, then it bounces off and falls.
  - DROPPING: falls and slides down walls.
  - LYING: shows a small light, and a 1.4 m distance check triggers `collect` → equip.
  - RETURNING: after a kill, flies to the camera at 30 m/s → `on_returned`.
- **Homing:** `find_aimed_enemy(8, 40)` (still live) picks the target, and the projectile steers at its chest each tick.
- **Resets:** a hatchet lost in flight for 6 s comes back on its own. `reset_behaviour` (on run restart or a new level) frees a thrown one.

## Hook (`hook.gd`, `CLICK_OR_HOLD`) and grapple (`MovementGrapple.gd`)

**In game:** mobility and control, with no S-rank version.
- **Click (yank):** 9 m reach. A light enemy is dragged to 1.5 m in front of you over 0.25 s, staggered for 0.6 s and takes 1 damage. With a brute or mortar, *you* are pulled to 1.8 m short of it instead, and it is staggered.
- **Hold (grapple):** 20 m range.
  - **Zip:** while attack is held, accelerates at 70 m/s² straight at the anchor, up to 24 m/s, with no gravity.
  - **Platform edges:** an anchor just under a ledge top is moved onto the top, so zipping to a platform edge pops you up onto it.
  - **Swing:** hold jump to lock the rope length and swing as a pendulum.
  - **Release:** letting go keeps your momentum.
  - **Ends when:** the rope is longer than 25 m, something cuts a rope longer than 3 m, or stamina runs out (12 to latch, 6/s zipping, 10/s swinging).

**Code:**
- **Yank:** `hook.gd` `_catch` uses `deliver_hit` with `knockback_multiplier` 0. Light enemies get `on_hook_pull({pull_to, pull_time, lift, stagger_time})`; `dummy_enemy` (removed) dragged itself to the spot each tick. Heavy enemies: `player.start_dash` toward them.
- **Grapple start:** `on_hold_started` casts the grapple ray. An enemy gets the yank; the level gets `_find_ledge_top`, then `player.start_grapple(anchor, normal)`.
- **Rope visual:** `hook_rope.gd` is a stretched thin box plus a head.
- **Player side (removed):** the state `_is_grappling` sat between the shield charge and the slide in the movement priority, with no vertical motion while grappling. `_apply_grapple_movement` used `MovementGrapple.get_zip_velocity` / `get_swing_velocity`; `_finish_grapple_zip` handled the arrival pop (`get_top_arrival_pop`); `_has_grapple_line_of_sight` checked the rope. API: `start_grapple`, `release_grapple`, `is_grappling`, `is_grapple_swinging`, `get_grapple_anchor`.

## Talons (`talons.gd`, `CLICK_OR_HOLD`)

**In game:** parkour predator.
- **Rakes:** fast rakes (0.8 damage, 0.4 s recover); every third rake in a row is a heavier rend (2.5 damage, longer freeze).
- **Passive while in hand:**
  - wall runs last 1.5× longer (2.05 → 3.07 s);
  - climbs go 1.3× faster;
  - any wall can be grabbed mid-air without holding jump.
- **Hold (pounce):** leap onto the enemy nearest the crosshair (within 12° and 12 m) along an arc, for 3 damage on contact.
- **S rank:** the pounce chains to the nearest other visible enemy within 10 m, up to 2 more times.

**Code:**
- **Rend:** counted on `attack_started`, which swaps in `rend_attack_data` through `set_attack_data`.
- **Passive:** `player._sync_talon_bonus()` (removed) pushed "talons in hand" every tick to `MovementWallRun.set_talon_bonus()` and `MovementClimb.set_talon_bonus()` (removed), which scaled the wall-run time limit and climb speed and skipped the climb's jump and timing requirements.
- **Pounce:** `player.start_pounce(end, duration, arc)` (removed) followed a parabola with `velocity = (point - position) / delta`, so walls still stop it. `talons.gd` updates the end point as the target moves (`set_pounce_end`), lands the hit within 1.6 m, then chains via `_find_chain_target`. `is_busy()` blocks attacks while pouncing.

## Pistol (dormant before this move)

**In game:** not in the player scene for a while already.
- **Firing:** semi-automatic, 12 rounds, 1.2 s reload (R), 0.14 s between shots.
- **Projectile:** a raycast tracer at 180 m/s that leaves bullet-hole decals.

**Code:**
- `pistol.gd` sat under `Head/Camera3D`, joined group `player_weapons` and emitted `fired` / `ammo_changed`. `melee_weapons.gd` holstered it while a melee weapon was out (removed).
- **Projectile:** `projectile.gd` raycasts each tick (no tunnelling at 180 m/s) and joins group `projectiles`. It has `time_scale`, `stop()`, `resume()` and `redirect()`, meant for future abilities. On a hit it spawns a decal, calls `on_projectile_hit(hit)` on the target, pushes rigid bodies and emits `hit_something`.
- **Decals:** `impact_decal.gd` is parented to the body it hit, keeps at most 64 holes and fades them after 20 s; bodies in group `no_impact_decals` get none.
- **Ammo counter:** `ammo_counter.gd` was a label at the bottom right of the HUD (`HudRoot/AmmoCounter` in `ui.tscn`, font 40, "12 / ∞"). It found the pistol through group `player_weapons`, listened to `ammo_changed` and coloured itself when the magazine was low or empty. It is now in `OldWeapons/Scripts/UI/`, and its node was removed from `ui.tscn`.
- **Still live:** `shootable_target.gd` still implements `on_projectile_hit`; the `shoot` and `reload` input actions still exist but nothing reads them.

---

## Bringing a weapon back

1. **Behaviour weapons** (hammer, sickle and dagger, morningstar, axe, hatchets, hook, talons):
   - Move the script (and its helper scripts) back to `Scripts/Weapons/Behaviours/` and `Scripts/Weapons/`.
   - Copy its node, `MeleeAttackData` and mesh sub-resources from `OldWeapons/SharedFilesSnapshot/Scenes/Weapons/melee_weapons.tscn` into the live scene; ext_resource ids may need renumbering.
   - Copy its sounds from the snapshot `melee_audio.gd`, and its card text from the snapshot `loadout_screen.gd`.
   - The framework is still live, so no `melee_weapons.gd` edits are needed, except where the weapon needs a removed API:
     - hammer: `player.set_vertical_velocity`, `get_airborne_highest_y`, enemy `apply_launch`;
     - morningstar: `apply_launch`, `set_thrown_damage`;
     - sickle and dagger: `on_weapon_projectile_hit`, `crossbow_bolt.gd`;
     - hook: grapple player state, `MovementGrapple` autoload, stamina functions, enemy `on_hook_pull`;
     - talons: pounce player state, talon bonus in the movement autoloads.
   
   Copy those back from the snapshot files.
2. **Broadsword, halberd, crossbow:** their code lived inside `melee_weapons.gd`. Restore the relevant parts from the snapshot copy, or turn them into behaviour weapons.
3. **The old balance:** set `ComboMeter.enable_same_weapon_cap = true` and `unscored_weapons = [&"crossbow", &"thrown_dagger"]`.
