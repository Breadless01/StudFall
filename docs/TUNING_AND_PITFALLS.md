# D) TUNING GUIDELINES
# ─────────────────────────────────────────────────────────────────────────────

## CoD-FEELING: Bewegung

| Parameter             | Wert     | Erklärung                                      |
|-----------------------|----------|------------------------------------------------|
| walk_speed            | 5.5 m/s  | CoD MW ~5.4. Nicht zu langsam für Horrorgänge |
| sprint_speed          | 9.0 m/s  | CoD ~8.5–9.5. Snappy sprint feel               |
| crouch_speed          | 2.8 m/s  | Deutlich langsamer, taktisch                   |
| acceleration          | 25.0     | Sehr hoch = sofortiges Ansprechverhalten        |
| friction              | 22.0     | Sofortiger Stopp (kein "gleiten")              |
| air_control           | 0.3      | Etwas Control, kein Floaten                    |
| gravity_mult          | 2.2      | Schwere Landung, kein Moon-Jump                |
| jump_velocity         | 5.0 m/s  | ~0.5m Sprunghöhe bei gravity_mult=2.2          |
| mouse_sensitivity     | 0.002    | Startbasis; User sollte skalieren können       |

## CoD-FEELING: Lean

| Parameter             | Wert     |
|-----------------------|----------|
| lean_angle_max        | 15°      | Subtil, nicht übertrieben                     |
| lean_offset_max       | 0.35 m   | Realistisch, kein 90°-Seitschritt             |
| lean_speed            | 8.0      | Smooth aber nicht träge                       |
| lean_wall_check_dist  | 0.5 m    | Wand-Check verhindert Clipping                |

## WAFFEN-FEELING (Horror = schwer)

| Parameter             | Revolver | Rifle  | Erklärung                                     |
|-----------------------|----------|--------|-----------------------------------------------|
| recoil_vertical       | 3.5°     | 2.0°   | Spürbar, nicht frustrating                    |
| recoil_horizontal     | 0.8°     | 0.5°   | Leichte Zufälligkeit                          |
| recoil_recovery_speed | 4.0      | 6.0    | Langsamer = mehr Gewicht (horror feel)        |
| sway_amount           | 0.06     | 0.04   | Revolver schwerer als Rifle                   |
| damage_falloff_start  | 15 m     | 40 m   |                                               |
| fire_rate             | 1.5/s    | 5.0/s  |                                               |

## AI / SUSPICION

| Parameter                    | Wert    | Erklärung                                     |
|------------------------------|---------|-----------------------------------------------|
| vision_fov_deg               | 90°     | 45° each side. Realistisch                    |
| vision_range                 | 18 m    | Kurze Sicht = more horror                     |
| vision_interval              | 0.15 s  | Nicht per Frame, 6–7x/sec                     |
| suspicion_decay              | 0.08/s  | ~12.5 sek von 1→0 ohne Reize                 |
| suspicion_decay_alerted      | 0.03/s  | ~33 sek nach Alert = bleibt länger misstrauisch|
| alerted_duration             | 8.0 s   | Alerted-Fenster nach letzter Wahrnehmung       |
| chase_speed                  | 5.5 m/s | Schneller als Walk, langsamer als Sprint       |
| attack_cooldown              | 1.5 s   |                                               |
| LOST_TIMEOUT (Chase→Search)  | 4.0 s   | Wie lange Chase ohne Sichtkontakt             |
| SEARCH_DURATION              | 8.0 s   | Suchphase nach Chase                          |
| hearing_range                | 20 m    | Geräusch-Reaktionsradius                      |

## Noise Loudness Werte

| Event                | Loudness | Reichweite (bei hearing_range=20m) |
|----------------------|----------|-------------------------------------|
| shoot (rifle)        | 1.0      | 20 m voll, bis ~20 m                |
| shoot (pistol)       | 0.9      | ~18 m                               |
| footstep_sprint      | 0.4      | ~8 m                                |
| footstep_walk        | 0.15     | ~3 m                                |
| door_open            | 0.5      | ~10 m                               |
| throw                | 0.4      | ~8 m                                |
| interact             | 0.2      | ~4 m                                |

## FEAR SYSTEM

| Parameter                    | Wert    | Effekt                                          |
|------------------------------|---------|-------------------------------------------------|
| gain_enemy_proximity         | 0.06/s  | Bei 0m: 1.0 in 16s. Subtil genug               |
| danger_range                 | 8 m     |                                                 |
| decay_rate                   | 0.05/s  | Ca. 20s auf 0 in Sicherheit                    |
| camera_shake_max             | 0.4     | Max h/v_offset: sehr subtil, kein VR-Schwindel |
| max_sway_mult                | 1.6     | 60% mehr Sway bei Fear=1 → spürbar, nicht nervig|
| kill_bonus_decay             | 0.25    | Töten = Relief-Mechanic                        |


# E) GODOT 4 PITFALLS
# ─────────────────────────────────────────────────────────────────────────────

## 1. Crouch Collision Switching

Problem: set_disabled() auf CollisionShape3D greift nicht sofort —
Godot verarbeitet Collision-Changes erst im nächsten physics frame.

Lösung:
  # Korrekt: beide shapes managen
  col_stand.disabled  = true   # disablen
  col_crouch.disabled = false  # enablen
  # NICHT: shape direkt austauschen, das triggert Re-instanzierung

Außerdem: HeadClearanceRay muss OBEN auf Capsule-Rand zeigen, nicht fest.
  head_ray.target_position = Vector3(0, stand_height * 0.55, 0)
  # Nie head_ray nach UNTEN zeigen (ergibt false positive beim Boden)


## 2. RayQuery Performance

Problem: PhysicsRayQueryParameters3D per Frame für viele Enemies → teuer.

Lösung:
  a) Perception per Timer (0.15s interval), nicht _physics_process jedes Frame
  b) Collision layers sauber trennen: Layer 1 = World, Layer 2 = Player, Layer 3 = Enemies
     → Vision-Ray: mask = Layer1 only (kein Enemy-Geometry scannen)
  c) Bei vielen Enemies: PhysicsServer3D.space_get_direct_state() einmalig cachen


## 3. NavigationAgent3D Pitfalls

Problem: is_navigation_finished() returned true bevor Agent wirklich ankommt.

Lösung:
  nav_agent.path_desired_distance = 0.5   # Stop-Toleranz
  nav_agent.target_desired_distance = 0.8 # Attack-Range Check separat!
  # NICHT: target_position setzen ohne NavigationRegion3D zu haben → silent fail

Problem: NavigationAgent3D moved to wrong layer.
Lösung: Enemy auf Layer "Enemy" in NavigationRegion navigationlayers setzen.

Problem: velocity setzen auf Agent — Agent fährt ins void.
Lösung: Agent gibt nur next_path_position(), Bewegung via CharacterBody3D.velocity immer selbst berechnen.
  var next := nav_agent.get_next_path_position()
  var dir  := (next - global_position).normalized()
  velocity.x = dir.x * speed
  velocity.z = dir.z * speed
  move_and_slide()


## 4. Input Smoothing / Mouse Look

Problem: InputEventMouseMotion.relative gibt bei hoher FPS sehr kleine Werte.

Lösung:
  # Akkumuliere mouse delta pro frame, wende in _physics_process an
  var _mouse_delta := Vector2.ZERO
  func _unhandled_input(event):
    if event is InputEventMouseMotion:
      _mouse_delta += event.relative
  func _physics_process(delta):
    _handle_mouse_look(_mouse_delta)
    _mouse_delta = Vector2.ZERO  # Reset


## 5. Lean Clipping

Problem: Lean bewegt Camera lateral — kann durch dünne Wände clippen.

Lösung: ShapeQuery statt RayCast für soliden Check:
  var params := PhysicsShapeQueryParameters3D.new()
  params.shape = SphereShape3D.new()  # radius = 0.2
  params.transform = Transform3D(Basis(), lean_target_pos)
  var hits := space.intersect_shape(params, 1)
  if hits.size() > 0:
      _lean_input = 0.0


## 6. Tween FOV für ADS

Problem: Mehrere Tweens auf demselben Property = konkurrierende Tweens.

Lösung:
  # In set_fov():
  if _fov_tween and _fov_tween.is_valid():
      _fov_tween.kill()
  _fov_tween = create_tween()
  _fov_tween.tween_property(camera, "fov", target_fov, t)


## 7. Autoload / NoiseBus

Problem: NoiseBus.emit_noise() in _physics_process → Signal emitted mid-physics.

Lösung: Godot 4 Signals sind synchron. Bei sehr hoher Noise-Rate:
  call_deferred("emit_noise", ...)  # oder rate-limit via timer (bereits implementiert)


## 8. State Machine: State-Klassen in einer Datei

Problem: Godot 4 erlaubt nur EINEN class_name pro .gd-Datei.
Mehrere class_name in einer Datei verursachen Kompilierfehler.

Lösung (implementiert): Option (a) — jeder State in eigener Datei:
  - player/player_state_idle.gd, player_state_walk.gd, ...
  - weapons/weapon_state_idle.gd, weapon_state_ads.gd, ...
  - enemy/base/enemy_state_idle.gd, enemy_state_chase.gd, ...
  - interaction/interact_system.gd, pickup_weapon.gd, pickup_object.gd

Alternativen (nicht verwendet):
  b) Inner Classes (kein class_name, nur class Name extends ...)
  c) Prefix nutzen — funktioniert nur wenn EINE class_name pro Datei bleibt


## 9. CharacterBody3D und Gravity

Problem: velocity.y wird nicht resettet wenn is_on_floor() = true → Accumulation.

Lösung:
  if is_on_floor():
      velocity.y = -0.5  # kleiner negativer Wert hält Kontakt
  else:
      velocity.y -= gravity * delta
  # NICHT: velocity.y = 0 setzen — verliert Rampen-Unterstützung


## 10. Weapon Sway mit Mouse Delta

Problem: Mouse delta nur in _input verfügbar, nicht in _physics_process.

Lösung (implementiert): Akkumulieren und konsumieren (gleich wie Punkt 4):
  # In player._unhandled_input():
  if event is InputEventMouseMotion:
      _accumulated_mouse_delta += event.relative
  # In weapon_state_idle.gd / weapon_state_ads.gd _update_sway():
  var mouse_delta := player._accumulated_mouse_delta
  weapon.process_sway(delta, velocity, mouse_delta)
  # Reset in player._physics_process():
  _accumulated_mouse_delta = Vector2.ZERO
